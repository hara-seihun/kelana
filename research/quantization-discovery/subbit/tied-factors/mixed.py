#!/usr/bin/env python3
"""Spend the last head bit budget on RTN4 rare rows chosen with train head and embedding usage."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from scipy.special import logsumexp
from scipy.optimize import minimize

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'tied-head'))
import codec
import evaluate as head
sys.path.insert(0,str(HERE))
from fit import DATA,HEAD,MODEL,ROWS,WIDTH,sha

TOKENS=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz')
EXACT=2048
RARE=1920


def decode_rtn(packed,scales):
    if packed.shape[1]!=WIDTH//2:raise ValueError('RTN4 row packet width')
    codes=np.empty((len(packed),WIDTH),np.uint8)
    codes[:,0::2]=packed&15
    codes[:,1::2]=packed>>4
    return ((codes.reshape(-1,8,128).astype(np.float32)-7.5)*scales.astype(np.float32)[:,:,None]).reshape(-1,WIDTH)


def build():
    DATA.mkdir(parents=True,exist_ok=True)
    hidden,_,_,freq,_,w,bits=head.load()
    with np.load(HEAD/'codebook256.npz') as z:
        packet=z['labels'].copy();scales=z['scales'].copy();code=z['code'].copy();unit=z['unit'].copy()
    labels=codec.unpack(packet,64,8)
    order=np.lexsort((np.arange(ROWS),-freq))
    common=order[:EXACT]
    with np.load(HEAD/'final-head.npz') as z:train_hidden=z['train_hidden'][::8].copy()
    original=train_hidden@w.T
    approximate=head.respond(train_hidden,labels,scales,code,float(unit))
    approximate[:,common]=original[:,common]
    p=np.exp(original-logsumexp(original,axis=1)[:,None])
    q=np.exp(approximate-logsumexp(approximate,axis=1)[:,None])
    importance=np.mean(abs(p-q),axis=0)
    importance[common]=-np.inf
    # One fourth of the paid rare precision goes to actual train input-token
    # frequency; the rest repairs rows influential at the final head.
    head_rows=np.lexsort((np.arange(ROWS),-importance))[:RARE*3//4]
    selected=np.zeros(ROWS,bool);selected[common]=True;selected[head_rows]=True
    embed_rows=order[~selected[order]][:RARE//4]
    rare=np.concatenate((head_rows,embed_rows)).astype('<u4')
    if len(np.unique(np.r_[common,rare]))!=EXACT+RARE:raise ValueError('overlapping row allocations')
    blocks=w[rare].reshape(RARE,8,128)
    scalar_scale=(np.max(abs(blocks),axis=2)/7.5).clip(min=1.e-20).astype(np.float16)
    levels=np.rint(w[rare].reshape(RARE,8,128)/scalar_scale.astype(np.float32)[:,:,None]+7.5).clip(0,15).astype(np.uint8).reshape(RARE,WIDTH)
    packed=(levels[:,0::2]|(levels[:,1::2]<<4)).astype(np.uint8)
    decoded=decode_rtn(packed,scalar_scale)
    if not np.allclose(decoded, (levels.reshape(RARE,8,128).astype(np.float32)-7.5).reshape(RARE,8,128).reshape(RARE,WIDTH)*np.repeat(scalar_scale.astype(np.float32),128,axis=1)):
        raise ValueError('RTN4 unpack failed')
    image=DATA/'mixed256.npz'
    np.savez_compressed(image,labels=packet,scales=scales,code=code,unit=unit,
                        exact_ids=common.astype('<u4'),exact_bf16=bits[common],
                        rare_ids=rare,rare_packed=packed,rare_scales=scalar_scale)
    sizes={'labels':int(packet.nbytes),'scales':int(scales.nbytes),'code':int(code.nbytes),'unit':4,
           'exact_ids':int(common.astype('<u4').nbytes),'exact_bf16':int(bits[common].nbytes),
           'rare_ids':int(rare.nbytes),'rare_packed':int(packed.nbytes),'rare_scales':int(scalar_scale.nbytes)}
    receipt={'format':'qwen3-tied-mixed-precision/1','image_sha256':sha(image),'source_sha256':sha(HERE/'mixed.py'),
             'capture_sha256':sha(HEAD/'final-head.npz'),'model_sha256':sha(MODEL/'model.safetensors'),
             'frequency_sha256':sha(HEAD/'frequency.npz'),'base_sha256':sha(HEAD/'codebook256.npz'),
             'row_allocation':'2048 most frequent train token rows exact BF16; 1440 remaining rows ranked by mean absolute train head softmax discrepancy; 480 further rows by train input-token count',
             'ranking_input_positions':'128 train normalized final-head inputs, every eighth position of four train windows',
             'array_payload_bytes':sizes,'payload_bytes':sum(sizes.values()),
             'bits_per_tied_weight':8*sum(sizes.values())/(ROWS*WIDTH),
             'rare_rt4_decode_rms':float(np.sqrt(np.mean((decoded-w[rare])**2))),
             'consumer':'base K256 signed-byte response lookup for all rows; replace 2048 logits by BF16 exact dot and 1920 logits by unpacked group128 RTN4 dot; input embedding selects exactly one row from the same image'}
    (DATA/'mixed256.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'bits':receipt['bits_per_tied_weight'],'payload_bytes':receipt['payload_bytes'],'image_sha256':receipt['image_sha256']}))


def assess():
    receipt=json.loads((DATA/'mixed256.json').read_text())
    if sha(DATA/'mixed256.npz')!=receipt['image_sha256']:raise ValueError('mixed image changed')
    with np.load(DATA/'mixed256.npz') as z:
        packet=z['labels'].copy();scales=z['scales'].copy();code=z['code'].copy();unit=float(z['unit'])
        exact=z['exact_ids'].copy();exact_bf16=z['exact_bf16'].copy()
        rare=z['rare_ids'].copy();rare_packed=z['rare_packed'].copy();rare_scales=z['rare_scales'].copy()
    labels=codec.unpack(packet,64,8)
    hidden,original,gold,freq,val,w,bits=head.load()
    if not np.array_equal(exact_bf16,bits[exact]):raise ValueError('exact rows changed')
    rt4=decode_rtn(rare_packed,rare_scales)
    def scores(inputs):
        out=head.respond(inputs,labels,scales,code,unit)
        out[:,exact]=inputs@w[exact].T
        out[:,rare]=inputs@rt4.T
        return out
    with np.load(HEAD/'final-head.npz') as z:train=z['train_hidden'][::8].copy()
    with np.load(TOKENS) as z:tokens=z['train'][:4,np.arange(0,255,8)+1].reshape(-1)
    train_scores=scores(train)
    compressed=np.ones(ROWS,bool);compressed[exact]=False;compressed[rare]=False
    q=train_scores[:,compressed].astype(np.float64)
    known=train_scores[:,~compressed].astype(np.float64)
    chosen=train_scores[np.arange(len(tokens)),tokens].astype(np.float64)
    is_compressed=compressed[tokens]
    def objective(theta):
        t,b=theta
        zc=logsumexp(t*q+b,axis=1);ze=logsumexp(known,axis=1)
        norm=np.logaddexp(zc,ze)
        p=np.exp(t*q+b-norm[:,None]);mass=np.exp(zc-norm)
        loss=float(np.mean(norm-np.where(is_compressed,t*chosen+b,chosen)))
        return loss,np.array([np.mean(np.sum(p*q,axis=1)-np.where(is_compressed,chosen,0.)),
                              np.mean(mass-is_compressed)])
    result=minimize(objective,(1.,0.),jac=True,bounds=((0.25,2.),(-10.,10.)),method='L-BFGS-B',options={'maxiter':40})
    if not result.success:raise ValueError(result.message)
    output=scores(hidden)
    output[:,compressed]=result.x[0]*output[:,compressed]+result.x[1]
    check=np.asarray([0,63,2048,8191,ROWS-1],np.int32)
    for ids,reconstruction in ((check,head.decode_rows(check,labels,scales,code,unit)),(rare[:5],rt4[:5])):
        if ids is check:
            other=(np.isin(ids,exact)|np.isin(ids,rare))
            ids=ids[~other];reconstruction=reconstruction[~other]
            expected=hidden[:4]@reconstruction.T
            np.testing.assert_allclose((output[:4,ids]-result.x[1])/result.x[0],expected,rtol=5e-4,atol=5e-3)
        else:
            np.testing.assert_allclose(output[:4,ids],hidden[:4]@reconstruction.T,rtol=5e-4,atol=5e-3)
    selected=np.zeros(ROWS,bool);selected[exact]=True;selected[rare]=True
    rare_position={int(row):i for i,row in enumerate(rare)}
    observed=np.flatnonzero(val)
    numerator=denominator=rare_numerator=rare_denominator=0.
    for start in range(0,len(observed),4096):
        ids=observed[start:start+4096]
        source=w[ids]
        decoded=head.decode_rows(ids,labels,scales,code,unit)
        mask=np.isin(ids,rare)
        if mask.any():decoded[mask]=rt4[[rare_position[int(row)] for row in ids[mask]]]
        decoded[np.isin(ids,exact)]=source[np.isin(ids,exact)]
        err=np.sum((decoded-source)**2,axis=1)
        norm=np.sum(source*source,axis=1)
        numerator+=float(np.dot(val[ids],err));denominator+=float(np.dot(val[ids],norm))
        rare_mask=~selected[ids]
        rare_numerator+=float(np.dot(val[ids[rare_mask]],err[rare_mask]))
        rare_denominator+=float(np.dot(val[ids[rare_mask]],norm[rare_mask]))
    quality=head.quality(original,output,gold)
    record={'format':'qwen3-tied-mixed-precision-quality/1','image_sha256':receipt['image_sha256'],
            'source_sha256':sha(HERE/'mixed.py'),'capture_sha256':sha(HEAD/'final-head.npz'),
            'payload_bytes':receipt['payload_bytes']+8,'bits_per_tied_weight':8*(receipt['payload_bytes']+8)/(ROWS*WIDTH),
            'held_head':quality,'held_embedding_weighted_rms':float(np.sqrt(numerator/denominator)),
            'held_compressed_row_embedding_weighted_rms':float(np.sqrt(rare_numerator/rare_denominator)),
            'held_token_coverage_exact':float(val[exact].sum()/val.sum()),
            'held_token_coverage_rt4':float(val[rare].sum()/val.sum()),
            'held_gold_exact':int(np.isin(gold,exact).sum()),'held_gold_rt4':int(np.isin(gold,rare).sum()),
            'train_rare_temperature':float(result.x[0]),'train_rare_offset':float(result.x[1]),
            'train_calibration_nll':float(result.fun),'validation_positions':64,
            'boundary':'captured BF16 producer hidden and original BF16 logits; no quantized input embedding propagation'}
    (DATA/'mixed-quality.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record))

if __name__=='__main__':
    if len(sys.argv)==2 and sys.argv[1]=='build':build()
    elif len(sys.argv)==2 and sys.argv[1]=='assess':assess()
    else:raise SystemExit('mixed.py build | assess')
