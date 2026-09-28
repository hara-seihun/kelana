#!/usr/bin/env python3
"""Jointly re-encode Q3 gate/up and their shared-input low-rank correction."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parents[2]/'research/quantization-discovery/subbit'))
from spectral_quant import quantize
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
DATA=Path('/path/to/workspace/data/kelana-subbit/vector-full/capture/isa-response')
RANK=80
NAMES=('gate','up','down')
SHAPES=((3072,1024),(3072,1024),(1024,3072))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source():
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        return tuple(np.ascontiguousarray(f.get_tensor(f'model.layers.0.mlp.{n}_proj.weight').float().numpy()) for n in NAMES)


def encode(matrix,name):
    torch.set_num_threads(1)
    a=quantize(torch.from_numpy(np.ascontiguousarray(matrix)),3,128,'w')
    return {name+'_codes':a['w_codes'],name+'_scales':a['w_scales'],name+'_shape':a['w_shape']}


def decode(f,name):
    rows,cols,bits,group=f[name+'_shape'].tolist()
    assert bits==3 and group==128
    planes=np.unpackbits(f[name+'_codes'],axis=1,bitorder='little')[:,:cols*bits].reshape(rows,cols,bits)
    codes=(planes.astype(np.int16)*(1<<np.arange(bits))).sum(2)
    scale=np.repeat(f[name+'_scales'].astype(np.float32),128,axis=1)[:,:cols]
    return np.ascontiguousarray(((2*codes-7)*scale).astype(np.float32))


def lowrank(error):
    # Deterministic source-only randomized range finder with one power pass.
    rng=np.random.default_rng(240926)
    omega=rng.standard_normal((1024,RANK+16)).astype(np.float32)
    y=error@omega
    q,_=np.linalg.qr(y,mode='reduced')
    y=error@(error.T@q)
    q,_=np.linalg.qr(y,mode='reduced')
    small=q.T@error
    u,s,v=np.linalg.svd(small,full_matrices=False)
    # Split amplitude to keep both FP16 factors well scaled.
    left=(q@(u[:,:RANK]*np.sqrt(s[:RANK]))).astype(np.float16)
    right=(np.sqrt(s[:RANK])[:,None]*v[:RANK]).astype(np.float16)
    return left,right


def fit():
    source_weights=source()
    base={}
    for name,w in zip(NAMES,source_weights):base.update(encode(w,name))
    np.savez(HERE/'base.npz',**base)
    decoded=[decode(base,n) for n in NAMES]
    original=np.concatenate(source_weights[:2]); current=np.concatenate(decoded[:2])
    for version in ('frozen','coded'):
        left,right=lowrank(original-current)
        if version=='coded':
            # Joint code step: Q3 now encodes the source minus the planned shared correction.
            corrected=original-left.astype(np.float32)@right.astype(np.float32)
            base.update(encode(corrected[:3072],'gate'))
            base.update(encode(corrected[3072:],'up'))
            current=np.concatenate([decode(base,'gate'),decode(base,'up')])
            left,right=lowrank(original-current)
        image=dict(base,left=left,right=right)
        np.savez(HERE/f'{version}.npz',**image)
        print(json.dumps({'version':version,'container_sha256':sha(HERE/f'{version}.npz'),
                          'payload_bytes':sum(v.nbytes for v in image.values()),
                          'container_bytes':(HERE/f'{version}.npz').stat().st_size,
                          'source_matrix_relative_error':float(np.linalg.norm(original-current-left.astype(np.float32)@right.astype(np.float32))/np.linalg.norm(original))}),flush=True)


def panels(split):
    chunks=[np.load(DATA/f'{split}-{i}.npz') for i in range(4)]
    return tuple(np.ascontiguousarray(np.concatenate([c[key] for c in chunks])) for key in ('inputs','target','q4'))


def response(x,mats,left=None,right=None):
    if left is None:
        g=x@mats[0].T;u=x@mats[1].T
    else:
        z=x@right.T
        h=z@left.T
        g=x@mats[0].T+h[:,:3072]
        u=x@mats[1].T+h[:,3072:]
    return (g/(1+np.exp(-np.clip(g,-80,80)))*u)@mats[2].T


def rms(y,t):return float(np.linalg.norm((y-t).astype(np.float64))/np.linalg.norm(t.astype(np.float64)))


def replay():
    result={'source_sha256':sha(MODEL),'rank':RANK,'images':{},'control_bytes':4866096,
            'description':'Q3 three matrices; shared gate/up input rank80 FP16 factor correction; source-only joint code quantization, no response trace fit'}
    xtrain,ttrain,qtrain=panels('train')
    xheld,theld,qheld=panels('held')
    result['q4']={'train':rms(qtrain,ttrain),'held':rms(qheld,theld)}
    for version in ('base','frozen','coded'):
        path=HERE/f'{version}.npz'
        with np.load(path) as f:
            matrices=tuple(decode(f,n) for n in NAMES)
            left=f['left'].astype(np.float32) if 'left' in f.files else None
            right=f['right'].astype(np.float32) if 'right' in f.files else None
            payload=sum(f[k].nbytes for k in f.files)
        result['images'][version]={'sha256':sha(path),'payload_bytes':payload,'container_bytes':path.stat().st_size,
                                   'train':rms(response(xtrain,matrices,left,right),ttrain),
                                   'held':rms(response(xheld,matrices,left,right),theld)}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=('fit','replay'))
    action=parser.parse_args().action
    {'fit':fit,'replay':replay}[action]()
