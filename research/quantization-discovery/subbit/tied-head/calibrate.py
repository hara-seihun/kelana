#!/usr/bin/env python3
"""Fit paid per-token head affine terms on train final inputs only."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import evaluate
import codec

HERE=Path(__file__).resolve().parent
DATA=evaluate.DATA


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def fit(k):
    with np.load(DATA/'final-head.npz') as z:
        train=z['train_hidden'][::16].copy()
    with np.load(DATA/f'codebook{k}.npz') as z:
        packet=z['labels'].copy();scales=z['scales'].copy()
        code=z['code'].copy();unit=float(z['unit'])
    labels=codec.unpack(packet,evaluate.COLS//16,int(np.log2(k)))
    w=evaluate.load()[5]
    reference=train@w.T
    response=evaluate.respond(train,labels,scales,code,unit)
    mean_reference=reference.mean(0)
    mean_response=response.mean(0)
    x=response-mean_response
    y=reference-mean_reference
    var=np.mean(x*x,axis=0)
    cov=np.mean(x*y,axis=0)
    penalty=0.25*float(np.median(var))
    alpha=np.clip((cov+penalty)/(var+penalty),0.5,1.5).astype(np.float16)
    beta=(mean_reference-alpha.astype(np.float32)*mean_response).astype(np.float16)
    bias_only=(mean_reference-mean_response).astype(np.float16)
    if not np.isfinite(alpha).all() or not np.isfinite(beta).all():raise ValueError('invalid head calibration')
    image=DATA/f'calibration{k}.npz'
    np.savez_compressed(image,alpha=alpha,beta=beta,bias_only=bias_only)
    manifest={'format':'qwen3-tied-calibration/1','k':k,
        'train_capture_sha256':sha(DATA/'final-head.npz'),
        'codebook_image_sha256':sha(DATA/f'codebook{k}.npz'),
        'source_sha256':sha(Path(__file__)),
        'evaluate_source_sha256':sha(Path(evaluate.__file__)),
        'train_positions':'first 4 train windows, positions 0,16,...,240; 64 normalized inputs',
        'regularizer':'alpha=(covariance + 0.25*median(row response variance))/(variance + same), clipped [0.5,1.5]',
        'numerical_map':'head-only affine alpha*codebook_response+beta, or response+bias_only; input embeddings unchanged',
        'alpha_bytes':alpha.nbytes,'beta_bytes':beta.nbytes,'bias_only_bytes':bias_only.nbytes,
        'image_sha256':sha(image),'array_sha256':{n:hashlib.sha256(v.tobytes()).hexdigest()
             for n,v in (('alpha',alpha),('beta',beta),('bias_only',bias_only))}}
    (DATA/f'calibration{k}.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'k':k,'alpha_range':[float(alpha.min()),float(alpha.max())],
                      'beta_range':[float(beta.min()),float(beta.max())],
                      'image_sha256':manifest['image_sha256']}))


if __name__=='__main__':
    if len(sys.argv)!=2 or int(sys.argv[1]) not in (64,256):raise SystemExit('calibrate.py 64 | 256')
    fit(int(sys.argv[1]))
