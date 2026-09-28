#!/usr/bin/env python3
"""Pack a shared tied image and measure held head/embedding quality with train-only calibration."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from safetensors import safe_open
from scipy.optimize import minimize
from scipy.special import logsumexp

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'tied-head'))
import codec
import evaluate as reference
sys.path.insert(0,str(HERE))
from fit import DATA,HEAD,MODEL,ROWS,WIDTH,RANK,sha

TOKENS=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz')


def assemble():
    with np.load(HEAD/'codebook64.npz') as z:
        original={k:z[k].copy() for k in z.files}
    with np.load(DATA/'basis.npz') as z: basis=z['basis'].copy()
    signed=[];amplitude=[];receipts=[]
    for part in range(8):
        p=DATA/f'shard{part}.npz'
        receipt=json.loads((DATA/f'shard{part}.json').read_text())
        if sha(p)!=receipt['image_sha256'] or receipt['basis_sha256']!=sha(DATA/'basis.npz'):
            raise ValueError('shard provenance differs')
        with np.load(p) as z:signed.append(z['signs'].copy());amplitude.append(z['amplitude'].copy())
        receipts.append(sha(DATA/f'shard{part}.json'))
    signs=np.vstack(signed);amp=np.concatenate(amplitude)
    if signs.shape!=(ROWS,RANK//8) or amp.shape!=(ROWS,):raise ValueError('factor image dimension')
    image=DATA/'signed64.npz'
    np.savez_compressed(image,**original,basis=basis,signs=signs,amplitude=amp)
    arrays={**original,'basis':basis,'signs':signs,'amplitude':amp}
    sizes={k:int(v.nbytes) for k,v in arrays.items()}
    sizes['unit']=4
    payload=sum(sizes.values())
    receipt={'format':'qwen3-tied-signed-factor/1','image_sha256':sha(image),
             'source_sha256':sha(HERE/'evaluate.py'),'fit_source_sha256':sha(HERE/'fit.py'),
             'model_sha256':sha(MODEL/'model.safetensors'),
             'head_capture_sha256':sha(HEAD/'final-head.npz'),
             'frequency_sha256':sha(HEAD/'frequency.npz'),
             'base_sha256':sha(HEAD/'codebook64.npz'),
             'basis_sha256':sha(DATA/'basis.npz'),'shard_receipts':receipts,
             'payload_arrays_bytes':sizes,'base_payload_bytes':int(sum(sizes[k] for k in ('labels','scales','code','unit'))),
             'payload_bytes':payload,'bits_per_weight':8*payload/(ROWS*WIDTH),
             'bit_order':'little-endian codebook label packet; little-endian signed factor bits, bit 1 is positive',
             'recovery':'code[label] * unit * FP16 block scale + FP16 row factor amplitude * (2 * sign_bit - 1) @ FP16 basis; optional exact BF16 rows override'}
    (DATA/'signed64.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'payload_bytes':payload,'bits_per_weight':receipt['bits_per_weight'],'sha256':receipt['image_sha256']}))


def response(hidden,labels,scales,code,unit,basis,signs,amp):
    base=reference.respond(hidden,labels,scales,code,unit)
    projected=hidden@basis.T
    # Raw packed bytes remain the online representation; this grouped CPU replay
    # separates each bit plane rather than materializing an expanded weight image.
    for j in range(RANK):
        signed=((signs[:,j//8]>>(j%8))&1).astype(np.float32)*2.-1.
        base+=projected[:,j,None]*(signed[None,:]*amp[None,:])
    return base


def decode(ids,labels,scales,code,unit,basis,signs,amp):
    b=reference.decode_rows(ids,labels,scales,code,unit)
    bit=np.unpackbits(signs[ids],axis=1,bitorder='little')[:,:RANK].astype(np.float32)*2.-1.
    return b+amp[ids,None]*(bit@basis)


def run(keep):
    receipt=json.loads((DATA/'signed64.json').read_text())
    if sha(DATA/'signed64.npz')!=receipt['image_sha256']:raise ValueError('image provenance')
    with np.load(DATA/'signed64.npz') as z:
        packet=z['labels'].copy();scales=z['scales'].copy();code=z['code'].copy();unit=float(z['unit'])
        basis=z['basis'].astype(np.float32);signs=z['signs'].copy();amp=z['amplitude'].astype(np.float32)
    labels=codec.unpack(packet,64,6)
    hidden,original,gold,train_counts,val_counts,w,bits=reference.load()
    ids=np.lexsort((np.arange(ROWS),-train_counts))[:keep]
    exact_image=DATA/f'factor-exact{keep}.npz'
    np.savez_compressed(exact_image,ids=ids.astype('<u4'),bf16_bits=bits[ids])
    selected=np.asarray([0,7,2048,8191,ROWS-1],np.int32)
    decoded=decode(selected,labels,scales,code,unit,basis,signs,amp)
    candidate=response(hidden,labels,scales,code,unit,basis,signs,amp)
    np.testing.assert_allclose(candidate[:4,selected],hidden[:4]@decoded.T,rtol=5e-4,atol=5e-3)
    rare=np.ones(ROWS,bool);rare[ids]=False
    positions=np.arange(0,255,8)
    with np.load(HEAD/'final-head.npz') as z:train_hidden=z['train_hidden'].copy()
    sample=np.concatenate([np.arange(i*256,(i+1)*256)[positions] for i in range(4)])
    inputs=train_hidden[sample]
    with np.load(TOKENS) as z:train_gold=z['train'][:4,positions+1].reshape(-1)
    train=response(inputs,labels,scales,code,unit,basis,signs,amp)
    train[:,ids]=inputs@w[ids].T
    rscore=train[:,rare].astype(np.float64)
    exact_score=train[:,ids].astype(np.float64)
    indexed=np.arange(len(train_gold))
    gold_rare=rare[train_gold]
    gold_raw=train[indexed,train_gold]
    def objective(theta):
        t,b=theta
        zr=logsumexp(t*rscore+b,axis=1)
        ze=logsumexp(exact_score,axis=1)
        normalizer=np.logaddexp(zr,ze)
        rare_p=np.exp(zr-normalizer)
        prob=np.exp(t*rscore+b-normalizer[:,None])
        chosen=np.where(gold_rare,t*gold_raw+b,gold_raw)
        loss=np.mean(normalizer-chosen)
        grad_t=np.mean(np.sum(prob*rscore,axis=1)-np.where(gold_rare,gold_raw,0.))
        grad_b=np.mean(rare_p-gold_rare)
        return loss,np.array([grad_t,grad_b])
    fit=minimize(objective,(1.,0.),jac=True,bounds=((0.25,2.),(-10.,10.)),method='L-BFGS-B',options={'maxiter':40})
    if not fit.success:raise ValueError(fit.message)
    temperature,offset=map(float,fit.x)
    candidate[:,rare]=candidate[:,rare]*temperature+offset
    candidate[:,ids]=hidden@w[ids].T
    quality=reference.quality(original,candidate,gold)
    # Input embedding is the same tied image. Held token-frequency counts weight
    # every seen rare row; full validation corpus, not just selected head positions.
    seen=np.flatnonzero(val_counts)
    errors=[];norms=[]
    for start in range(0,len(seen),4096):
        pick=seen[start:start+4096]
        d=decode(pick,labels,scales,code,unit,basis,signs,amp)
        diff=(d-w[pick]);sq=np.sum(diff*diff,axis=1);base=np.sum(w[pick]*w[pick],axis=1)
        sq[~rare[pick]]=0
        errors.append(np.dot(val_counts[pick],sq));norms.append(np.dot(val_counts[pick],base))
    embed_rms=float(np.sqrt(sum(errors)/sum(norms)))
    rare_seen=seen[rare[seen]]
    # A rare-only statistic is needed: frequent exact rows dominate the aggregate.
    rare_error=0.;rare_norm=0.
    for start in range(0,len(rare_seen),4096):
        pick=rare_seen[start:start+4096];d=decode(pick,labels,scales,code,unit,basis,signs,amp)
        rare_error+=float(np.dot(val_counts[pick],np.sum((d-w[pick])**2,axis=1)))
        rare_norm+=float(np.dot(val_counts[pick],np.sum(w[pick]**2,axis=1)))
    bytes_total=receipt['payload_bytes']+keep*(WIDTH*2+4)+8
    output={'format':'qwen3-tied-signed-factor-quality/1','image_sha256':receipt['image_sha256'],
            'capture_sha256':sha(HEAD/'final-head.npz'),'frequency_sha256':sha(HEAD/'frequency.npz'),
            'source_sha256':sha(HERE/'evaluate.py'),'exact_rows':keep,'exact_rows_bf16_ids_bytes':keep*(WIDTH*2+4),
            'exact_image_sha256':sha(exact_image),
            'payload_bytes':bytes_total,'bits_per_tied_weight':8*bytes_total/(ROWS*WIDTH),
            'temperature_rare':temperature,'offset_rare':offset,'train_nll':float(fit.fun),
            'held_embedding_weighted_rms':embed_rms,'held_rare_only_embedding_weighted_rms':float(np.sqrt(rare_error/rare_norm)),
            'held_validation_token_exact_coverage':float(val_counts[ids].sum()/val_counts.sum()),
            'rare_distinct_validation_token_rows':len(rare_seen),
            'direct_vs_dense_rows_checked':selected.tolist(),
            'sample_contract':'64 held validation positions, original-model final normalized inputs, captured BF16 logits; no quantized input propagation',
            'train_calibration_contract':'128 train positions; gold next tokens; rare global temperature and offset, two FP32 scalars',
            'head':quality}
    (DATA/f'quality{keep}.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({k:output[k] for k in ('exact_rows','bits_per_tied_weight','held_embedding_weighted_rms','held_rare_only_embedding_weighted_rms','held_validation_token_exact_coverage')} | {'head':quality,'train_nll':output['train_nll']}))

if __name__=='__main__':
    if len(sys.argv)==2 and sys.argv[1]=='assemble':assemble()
    elif len(sys.argv)==3 and sys.argv[1]=='assess':run(int(sys.argv[2]))
    else:raise SystemExit('evaluate.py assemble | assess EXACT_ROWS')
