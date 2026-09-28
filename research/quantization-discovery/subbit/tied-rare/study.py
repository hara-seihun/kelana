#!/usr/bin/env python3
"""Paid low-rank correction to the packed tied head and embedding, fitted on source weights."""
import hashlib
import json
from pathlib import Path
import sys
import numpy as np
from scipy.special import logsumexp
from scipy.optimize import minimize

PARENT = Path(__file__).resolve().parents[1] / 'tied-head'
sys.path.insert(0, str(PARENT))
import evaluate
import codec

DATA = Path('/path/to/workspace/data/kelana-subbit/tied-rare')
SOURCE = evaluate.DATA
RANK = 16
SEED = 20260922

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def image_and_residual():
    image = SOURCE/'codebook256.npz'
    with np.load(image) as z:
        labels = codec.unpack(z['labels'],64,8)
        scales = z['scales'].astype(np.float32)
        code = z['code'].astype(np.float32)
        unit = float(z['unit'])
    # Load the pinned tied BF16 source once. The original decoder is the control.
    hidden, logits, gold, train, validation, weight, bits = evaluate.load()
    residual = weight.copy()
    for s in range(64):
        residual[:,s*16:(s+1)*16] -= code[labels[:,s]] * (unit * scales[:,s//8,None])
    return image, labels, scales, code, unit, hidden, logits, gold, train, validation, weight, residual

def fit():
    image, labels, scales, code, unit, hidden, logits, gold, train, validation, weight, r = image_and_residual()
    rng = np.random.default_rng(SEED)
    omega = rng.standard_normal((1024,32)).astype(np.float32)
    q,_ = np.linalg.qr(r @ omega,mode='reduced')
    # One power iteration resolves the correlated rank-16 response missed by a random sketch.
    z = r.T @ q
    q,_ = np.linalg.qr(r @ z,mode='reduced')
    small = q.T @ r
    u,s,vt = np.linalg.svd(small,full_matrices=False)
    left = ((q @ u[:,:RANK]) * s[:RANK]).astype(np.float16)
    right = vt[:RANK].astype(np.float16)
    path = DATA/'rank16.npz'
    np.savez_compressed(path,left=left,right=right)
    print(json.dumps({'image_sha256':sha(path),'source_sha256':sha(image),'rank':RANK,
        'factor_payload_bytes':left.nbytes+right.nbytes,'base_payload_bytes':json.loads((SOURCE/'codebook256.json').read_text())['total_payload_bytes']}))

def calibrate(scores, original, train_scores, train_gold, exact):
    # A common scalar calibration is available to both competitors at the same training budget.
    mask = np.ones(evaluate.ROWS,bool)
    mask[exact] = False
    train_scores = train_scores.astype(np.float32)
    rows = np.arange(len(train_gold))
    def objective(t):
        candidate = train_scores.astype(np.float64)
        candidate[:,mask] = t[0]*candidate[:,mask] + t[1]
        lse = logsumexp(candidate,axis=1)
        probs = np.exp(candidate-lse[:,None])
        rare_gold = mask[train_gold]
        gradient_scale = np.mean((probs[:,mask]*train_scores[:,mask]).sum(axis=1) -
                                 rare_gold*train_scores[rows,train_gold])
        gradient_offset = np.mean(probs[:,mask].sum(axis=1)-rare_gold)
        return float(np.mean(lse-candidate[rows,train_gold])),np.array([gradient_scale,gradient_offset])
    result = minimize(objective,[1.,0.],jac=True,method='L-BFGS-B',bounds=((0.25,2.),(-10.,10.)),options={'maxiter':40})
    adjusted = scores.copy()
    adjusted[:,mask] = result.x[0]*adjusted[:,mask] + result.x[1]
    return adjusted, {'temperature':float(result.x[0]),'offset':float(result.x[1]),'train_nll':float(result.fun)}

def assess():
    path=DATA/'rank16.npz'
    image,labels,scales,code,unit,hidden,original,gold,train,val,w,r = image_and_residual()
    with np.load(path) as z:
        left=z['left'].copy();right=z['right'].copy()
    approximation = left.astype(np.float32) @ right.astype(np.float32)
    base = evaluate.respond(hidden,labels,scales,code,unit)
    rank = base + (hidden @ right.astype(np.float32).T) @ left.astype(np.float32).T
    order = np.lexsort((np.arange(evaluate.ROWS),-train))
    keep=order[:2560]
    exact=base.copy();exact[:,keep] = hidden @ w[keep].T
    # Half the factor rank trades its freed bytes for 1,280 exact high-frequency rows.
    mixed_keep=order[:1280]
    mixed_left=left[:,:8].astype(np.float32)
    mixed_right=right[:8].astype(np.float32)
    mixed=base + (hidden@mixed_right.T)@mixed_left.T
    mixed[:,mixed_keep]=hidden@w[mixed_keep].T
    with np.load(SOURCE/'frequency.npz') as z: val_counts=z['validation'].copy()
    ids = np.flatnonzero(val_counts)
    ebase=np.sum(r[ids]**2,axis=1)
    erank=np.sum((r[ids]-approximation[ids])**2,axis=1)
    denom=np.sum(val_counts[ids]*np.sum(w[ids]**2,axis=1))
    metrics={}
    base_bytes=json.loads((SOURCE/'codebook256.json').read_text())['total_payload_bytes']
    mixed_error=np.sum((r[ids]-(mixed_left@mixed_right)[ids])**2,axis=1)
    for name,scores,bytes_,e in [('base',base,base_bytes,ebase),('rank16',rank,base_bytes+left.nbytes+right.nbytes,erank),('rank8_exact1280',mixed,base_bytes+(mixed_left.size+mixed_right.size)*2+len(mixed_keep)*(4+2048),np.where(np.isin(ids,mixed_keep),0,mixed_error)),('exact2560',exact,base_bytes+len(keep)*(4+2048),np.where(np.isin(ids,keep),0,ebase))]:
        metrics[name]={'paid_bytes':int(bytes_),'bpw':8*bytes_/(evaluate.ROWS*1024),
            'embedding_validation_weighted_relative_rms':float(np.sqrt(np.sum(val_counts[ids]*e)/denom)),
            'head':evaluate.quality(original,scores,gold)}
    # Independent held train positions; neither model sees validation logits in calibration.
    with np.load(SOURCE/'final-head.npz') as z: train_hidden=z['train_hidden'].copy()
    with np.load('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz') as z:
        positions=np.arange(0,255,32)
        train_gold=z['train'][:4,positions+1].reshape(-1)
    inputs=train_hidden[np.concatenate([np.arange(i*256,(i+1)*256)[positions] for i in range(4)])]
    train_base=evaluate.respond(inputs,labels,scales,code,unit)
    for name,scores,train_scores,exact_ids in [('base',base,train_base,[]),('rank16',rank,train_base+(inputs@right.astype(np.float32).T)@left.astype(np.float32).T,[]),('rank8_exact1280',mixed,train_base+(inputs@mixed_right.T)@mixed_left.T,mixed_keep),('exact2560',exact,train_base.copy(),keep)]:
        if len(exact_ids):train_scores[:,exact_ids]=inputs@w[exact_ids].T
        corrected,tune=calibrate(scores,original,train_scores,train_gold,exact_ids)
        metrics[name]['train_fitted_head']=evaluate.quality(original,corrected,gold)
        metrics[name]['calibration']=tune
        metrics[name]['paid_bytes']+=8
        metrics[name]['bpw']=8*metrics[name]['paid_bytes']/(evaluate.ROWS*1024)
    receipt={'format':'tied-rank-residual/1','source_image_sha256':sha(image),'factor_image_sha256':sha(path),
        'source_sha256':sha(__file__),'capture_sha256':sha(SOURCE/'final-head.npz'),
        'model_revision':'c1899de289a04d12100db370d81485cdf75e47ca',
        'rank':RANK,'seed':SEED,'fit':'rank-16 randomized SVD of FP32 source minus decoded K256 codebook; 32 sketch columns, one power iteration, FP16 factors',
        'calibration':'32 train head positions, four separate train windows, common two-scalar rare-head NLL fit, validation only for reporting',
        'boundary':'original BF16 model final hidden; no embedding propagation; FP32 factor response and original BF16 reference logits',
        'online_extra':'16x1024 input-factor float products and 151936x16 output-factor float products per head query; embedding row requires another 16x1024 factor products and 1024 additions',
        'metrics':metrics}
    (DATA/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    for k,v in metrics.items():print(k,json.dumps(v))

if __name__=='__main__':
    {'fit':fit,'assess':assess}[sys.argv[1]]()
