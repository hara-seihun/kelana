#!/usr/bin/env python3
"""Head logits and input-embedding error from stored labels and common exact rows."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from safetensors import safe_open
import torch
import codec

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit/tied-head')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b')
ROWS=151936
COLS=1024


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def load():
    with np.load(DATA/'final-head.npz') as z:
        pos=z['selected_positions']
        hidden=z['validation_hidden'][pos[:,0]*256+pos[:,1]].copy()
        original=z['selected_logits'].copy()
        gold=z['selected_gold'].copy()
    with np.load(DATA/'frequency.npz') as z:
        train=z['train'].copy();validation=z['validation'].copy()
    with safe_open(MODEL/'model.safetensors',framework='pt',device='cpu') as f:
        tensor=f.get_tensor('model.embed_tokens.weight')
        weight=tensor.float().numpy().copy()
        bits=tensor.view(torch.int16).numpy().copy().view(np.uint16)
    return hidden,original,gold,train,validation,weight,bits


def quality(original,candidate,gold):
    original=original.astype(np.float64)
    candidate=candidate.astype(np.float64)
    zo=np.logaddexp.reduce(original,axis=1)
    zc=np.logaddexp.reduce(candidate,axis=1)
    prob=np.exp(original-zo[:,None])
    divergence=np.sum(prob*(original-candidate),axis=1)+zc-zo
    if np.min(divergence)<-1.e-6:raise ValueError('negative categorical divergence')
    indexes=np.arange(len(gold))
    first=np.argmax(original,axis=1)
    second=np.argmax(candidate,axis=1)
    return {'nll':float(np.mean(zc-candidate[indexes,gold])),
            'reference_nll':float(np.mean(zo-original[indexes,gold])),
            'mean_kl_reference_to_candidate':float(np.mean(divergence)),
            'top_token_agreement':float(np.mean(first==second)),
            'top_token_matches':int(np.sum(first==second)),
            'top_token_samples':int(len(first)),
            'logit_rms_difference':float(np.sqrt(np.mean((candidate-original)**2))),
            'logit_max_difference':float(np.max(abs(candidate-original)))}


def respond(hidden,labels,scales,code,unit):
    rows,segments=labels.shape
    scores=np.zeros((len(hidden),rows),np.float32)
    for segment in range(segments):
        table=hidden[:,segment*16:(segment+1)*16] @ code.astype(np.float32).T
        scores+=table[:,labels[:,segment]]*(unit*scales[None,:,segment//8].astype(np.float32))
    return scores


def decode_rows(ids,labels,scales,code,unit):
    selected=labels[ids]
    block_scale=np.repeat(scales[ids].astype(np.float32),128,axis=1)
    return code[selected].reshape(len(ids),COLS).astype(np.float32)*float(unit)*block_scale


def evaluate(k):
    image=DATA/f'codebook{k}.npz'
    receipt=json.loads((DATA/f'codebook{k}.json').read_text())
    if sha(image)!=receipt['image_sha256']:raise ValueError('codebook image changed')
    hidden,original,gold,train_counts,val_counts,w,bits=load()
    with np.load(image) as z:
        packet=z['labels'].copy();scales=z['scales'].copy()
        code=z['code'].copy();unit=float(z['unit'])
    labels=codec.unpack(packet,COLS//16,int(np.log2(k)))
    if len(labels)!=ROWS or scales.shape!=(ROWS,8):raise ValueError('image dimensions')
    calibration_path=DATA/f'calibration{k}.npz'
    calibration_receipt=json.loads((DATA/f'calibration{k}.json').read_text())
    if sha(calibration_path)!=calibration_receipt['image_sha256']:
        raise ValueError('calibration image changed')
    with np.load(calibration_path) as z:
        alpha=z['alpha'].copy();beta=z['beta'].copy();bias_only=z['bias_only'].copy()
    score=respond(hidden,labels,scales,code,unit)
    checked_rows=np.asarray([0,63,2048,8191,ROWS-1],np.int64)
    decoded=(code[labels[checked_rows]].reshape(len(checked_rows),COLS).astype(np.float32)*unit*
             np.repeat(scales[checked_rows].astype(np.float32),128,axis=1))
    np.testing.assert_allclose(score[:4,checked_rows],hidden[:4]@decoded.T,rtol=3e-4,atol=3e-3)
    dense_source=hidden@w.T
    baseline={'bf16_head_vs_float32_original':quality(original,dense_source,gold),
              'bf16_head_self':quality(original,original,gold)}
    order=np.lexsort((np.arange(ROWS),-train_counts))
    counts={256:(0,512,2048,2560),64:(0,1024,3072,3584)}[k]
    maximum=max(counts)
    common_ids=order[:maximum]
    common_bits=bits[common_ids]
    common_values=(common_bits.astype(np.uint32)<<16).view(np.float32)
    if not np.array_equal(common_values,w[common_ids]):
        raise ValueError('exact common row differs from source')
    np.savez_compressed(DATA/f'common{k}.npz',ids=common_ids.astype('<u4'),bf16_bits=common_bits)
    common_sha=sha(DATA/f'common{k}.npz')
    plans={str(count):order[:count] for count in counts}
    mixed_shas={}
    for kind in ('mixed','loss'):
        selected_path=DATA/f'{kind}{k}.npz'
        if not selected_path.exists():continue
        selection_receipt=json.loads((DATA/f'{kind}{k}.json').read_text())
        if sha(selected_path)!=selection_receipt['image_sha256']:
            raise ValueError(f'{kind} common-row image changed')
        with np.load(selected_path) as z:
            selected_ids=z['ids'].copy()
            if not np.array_equal(z['bf16_bits'],bits[selected_ids]):
                raise ValueError(f'{kind} common rows differ from source')
        plans[f'{kind}2048']=selected_ids
        mixed_shas[kind]=sha(selected_path)
    validation_ids=np.flatnonzero(val_counts)
    decoded=decode_rows(validation_ids,labels,scales,code,unit)
    source=w[validation_ids]
    norms=(source*source).sum(1)
    errors=((decoded-source)**2).sum(1)
    results={}
    for name,ids in plans.items():
        keep=len(ids)
        exact=w[ids]
        candidate=score.copy()
        if keep:candidate[:,ids]=hidden@exact.T
        keep_mask=np.isin(validation_ids,ids,assume_unique=False)
        weighted=np.where(keep_mask,0.,errors)
        embed_error=float(np.sqrt((val_counts[validation_ids]*weighted).sum() /
                                  (val_counts[validation_ids]*norms).sum()))
        static=receipt['total_payload_bytes']+keep*(4+2*COLS)
        bits_per_weight=8*static/(ROWS*COLS)
        quality_record=quality(original,candidate,gold)
        calibrated={}
        for variant,adjusted,extra_bytes in (
            ('bias_only',score+bias_only[None,:],bias_only.nbytes),
            ('affine',score*alpha[None,:]+beta[None,:],alpha.nbytes+beta.nbytes)):
            if keep:adjusted[:,ids]=hidden@exact.T
            paid=static+extra_bytes
            calibrated[variant]={'paid_bytes':paid,
                'bits_per_tied_weight':8*paid/(ROWS*COLS),**quality(original,adjusted,gold)}
        tuned=None
        tune_path=DATA/f'tune{k}-{name}.json'
        if tune_path.exists():
            tune=json.loads(tune_path.read_text())
            if tune['codebook_sha256']!=sha(image) or tune['head_capture_sha256']!=sha(DATA/'final-head.npz'):
                raise ValueError('rare-head calibration bound to another image')
            adjusted=score.copy()
            rare=np.ones(ROWS,bool);rare[ids]=False
            adjusted[:,rare]=tune['temperature_rare']*adjusted[:,rare]+tune['offset_rare']
            if keep:adjusted[:,ids]=hidden@exact.T
            paid=static+tune['extra_payload_bytes']
            tuned={'paid_bytes':paid,'bits_per_tied_weight':8*paid/(ROWS*COLS),
                   'tune_receipt_sha256':sha(tune_path),**quality(original,adjusted,gold)}
        results[name]={'paid_bytes':static,'bits_per_tied_weight':bits_per_weight,
            'common_rows':keep,'common_row_id_bytes':keep*4,'common_bf16_bytes':keep*2*COLS,
            'train_token_coverage':float(train_counts[ids].sum()/train_counts.sum()),
            'validation_token_coverage':float(val_counts[ids].sum()/val_counts.sum()),
            'validation_frequency_weighted_embedding_relative_rms':embed_error,
            'gold_token_in_common':int(np.isin(gold,ids).sum()),
            'calibrated':calibrated,'train_fitted_rare_head':tuned,**quality_record}
    record={'format':'qwen3-tied-head-quality/1','k':k,
        'numerical_boundary':'captured unquantized BF16 head logits on 64 held validation positions; candidate FP32 table response on fixed captured normalized inputs; no changed embedding/producer propagation',
        'source_sha256':sha(Path(__file__)),
        'codec_source_sha256':sha(Path(codec.__file__)),
        'capture_sha256':sha(DATA/'final-head.npz'),
        'frequency_sha256':sha(DATA/'frequency.npz'),
        'image_sha256':sha(image),'common_image_sha256':common_sha,
        'packed_direct_vs_independent_dense_rows_checked':checked_rows.tolist(),
        'objective_selected_common_image_sha256':mixed_shas,
        'calibration_image_sha256':sha(calibration_path),
        'common_rank':'descending full WikiText train corpus token count; ID ascending on tie; validation frequencies used only for reporting',
        'baseline':baseline,'plans':results,
        'online_work':{'table_float_products_per_query':receipt['online_float_products_per_query_table'],
                       'table_bytes_per_query':receipt['transient_table_bytes_per_query'],
                       'row_table_lookups_per_query':receipt['row_lookups_per_query'],
                       'exact_common_row_dot_products_per_query_at_max_keep':maximum*COLS}}
    (DATA/f'evaluate{k}.json').write_text(json.dumps(record,indent=2)+'\n')
    for keep,r in results.items():
        print('k',k,'keep',keep,'bits',round(r['bits_per_tied_weight'],4),
              'nll',round(r['nll'],4),'KL',round(r['mean_kl_reference_to_candidate'],4),
              'top',r['top_token_matches'],'/',r['top_token_samples'],
              'embed_rms',round(r['validation_frequency_weighted_embedding_relative_rms'],4),
              'freq_cover',round(r['validation_token_coverage'],4))
        for kind,c in r['calibrated'].items():
            print('  ',kind,'bits',round(c['bits_per_tied_weight'],4),
                  'nll',round(c['nll'],4),'KL',round(c['mean_kl_reference_to_candidate'],4),
                  'top',c['top_token_matches'])
        if r['train_fitted_rare_head'] is not None:
            c=r['train_fitted_rare_head']
            print('  rare_head_train_fit','bits',round(c['bits_per_tied_weight'],4),
                  'nll',round(c['nll'],4),'KL',round(c['mean_kl_reference_to_candidate'],4),
                  'top',c['top_token_matches'])
    print('baseline fp32',baseline['bf16_head_vs_float32_original'])


if __name__=='__main__':
    if len(sys.argv)!=2 or int(sys.argv[1]) not in (64,256):raise SystemExit('evaluate.py 64 | 256')
    evaluate(int(sys.argv[1]))
