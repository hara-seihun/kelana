#!/usr/bin/env python3
"""Source-averaged output-Jacobian repair of a calibrated Q3 full MLP reader."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / 'research/quantization-discovery/subbit'))
from spectral_quant import quantize
DATA = Path('/path/to/workspace/data/kelana-subbit/vector-full/capture/isa-response')
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
CONTROL = Path('/path/to/workspace/data/kelana-subbit/full-scalar')
NAMES = ('gate', 'up', 'down')
SHAPES = ((3072,1024),(3072,1024),(1024,3072))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def panels(split):
    chunks = [np.load(DATA/f'{split}-{i}.npz') for i in range(4)]
    return tuple(np.ascontiguousarray(np.concatenate([c[key] for c in chunks])) for key in ('inputs','target','q4'))


def source():
    with safe_open(MODEL, framework='pt', device='cpu') as f:
        return tuple(np.ascontiguousarray(f.get_tensor(f'model.layers.0.mlp.{name}_proj.weight').float().numpy()) for name in NAMES)


def decode_codes(codes, scales, shape, bits):
    n,k = shape
    plane = np.unpackbits(codes, axis=1, bitorder='little')[:,:bits*k].reshape(n,k,bits)
    values = (plane.astype(np.int16) * (1 << np.arange(bits))).sum(2)
    return np.ascontiguousarray(((values*2-((1<<bits)-1))*np.repeat(scales.astype(np.float32),128,axis=1)[:,:k]).astype(np.float32))


def fit_q3():
    torch.set_num_threads(1)
    arrays = {}
    for name, weights in zip(NAMES, source()):
        image = quantize(torch.from_numpy(weights),3,128,'w')
        arrays[name+'_codes'] = image['w_codes']
        arrays[name+'_scales'] = image['w_scales']
        arrays[name+'_shape'] = image['w_shape']
    np.savez(HERE/'q3.npz',**arrays)
    print(json.dumps({'q3_container_sha256':sha(HERE/'q3.npz'),'payload_bytes':sum(v.nbytes for v in arrays.values()),'container_bytes':(HERE/'q3.npz').stat().st_size}))


def q3():
    with np.load(HERE/'q3.npz') as f:
        assert all(tuple(f[name+'_shape']) == (*shape,3,128) for name,shape in zip(NAMES,SHAPES))
        return tuple(decode_codes(f[name+'_codes'],f[name+'_scales'],shape,3) for name,shape in zip(NAMES,SHAPES))


def response(x,mats):
    g=x@mats[0].T
    u=x@mats[1].T
    h=(g/(1+np.exp(-np.clip(g,-80,80))))*u
    return h@mats[2].T,g,u


def jacobian(mats, g, u):
    # Source-informed mean derivative: the only output fit is a 1024-vector bias.
    s=1/(1+np.exp(-np.clip(g,-80,80)))
    ds=s*(1+g*(1-s))
    a=np.mean(ds*u,axis=0)
    b=np.mean(s*g,axis=0)
    return mats[2]@(a[:,None]*mats[0]+b[:,None]*mats[1])


def fit_correction():
    x,t,_=panels('train')
    src=source()
    base=q3()
    y,g,u=response(x,base)
    with np.load(DATA/'preactivation-train.npz') as f:
        gs,us=(f[key].astype(np.float32) for key in ('g','u'))
    j=jacobian(src,gs,us)-jacobian(base,g,u)
    residual=t-y
    bias=(residual.mean(0)-x.mean(0)@j.T).astype(np.float16)
    # Signed symmetric 8-bit per-output scale; only offline FP32 Jacobian is free.
    scale=(np.max(np.abs(j),axis=1)/127).astype(np.float16)
    code=np.clip(np.rint(j/scale.astype(np.float32)[:,None]),-127,127).astype(np.int8)
    np.savez(HERE/'correction.npz',code=code,scale=scale,bias=bias)
    print(json.dumps({'correction_container_sha256':sha(HERE/'correction.npz'),'payload_bytes':sum(z.nbytes for z in (code,scale,bias)),'container_bytes':(HERE/'correction.npz').stat().st_size}))


def rms(y,t):
    return float(np.linalg.norm((y-t).astype(np.float64))/np.linalg.norm(t.astype(np.float64)))


def replay():
    base=q3()
    with np.load(HERE/'correction.npz') as f:
        j=np.ascontiguousarray(f['code'].astype(np.float32)*f['scale'].astype(np.float32)[:,None])
        bias=f['bias'].astype(np.float32)
        repair_payload=sum(f[z].nbytes for z in ('code','scale','bias'))
    with np.load(HERE/'q3.npz') as f:
        base_payload=sum(f[z].nbytes for z in f.files)
    scores={}
    for split in ('train','held'):
        x,t,q4=panels(split)
        y,_,_=response(x,base)
        corrected=y+x@j.T+bias
        scores[split]={'q3':rms(y,t),'q3_corrected':rms(corrected,t),'q4':rms(q4,t),
                       'correction_only_rms':rms(x@j.T+bias,t-y)}
    result={'method':'all-three Q3 group128 calibrated source + source mean-Jacobian residual; per-output signed Q8 correction, FP16 row scales and intercept',
            'model_sha256':sha(MODEL),'q3_sha256':sha(HERE/'q3.npz'),'correction_sha256':sha(HERE/'correction.npz'),
            'q3_payload_bytes':base_payload,'correction_payload_bytes':repair_payload,'total_payload_bytes':base_payload+repair_payload,
            'q4_payload_bytes':4866096,'scores':scores,
            'online_products':3*3072*1024+1024*1024,
            'provenance':'separate previously inspected validation; trained Jacobian averages and bias use 1024 train states'}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('action',choices=('q3','fit','replay'))
    args=p.parse_args()
    {'q3':fit_q3,'fit':fit_correction,'replay':replay}[args.action]()
