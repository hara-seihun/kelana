#!/usr/bin/env python3
"""Complete 1024-output Qwen MLP response on real full producer states."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit')
MODEL=DATA/'models/qwen3-0.6b/model.safetensors'
CAPTURE=DATA/'vector-full/capture'
Q4=DATA/'full-scalar'
DIMS=(1024,3072,1024)


def bf16(bits):
    return (bits.astype(np.uint32)<<16).view(np.float32)


def q4_decode(path):
    with np.load(path) as f:
        rows,cols,bits,group=f['weight_shape'].tolist()
        assert bits==4 and group==128
        codes=np.unpackbits(f['weight_codes'],axis=1,bitorder='little')[:,:4*cols].reshape(rows,cols,4)
        decoded=np.sum(codes.astype(np.int16)<<np.arange(4),axis=2).astype(np.float32)
        scale=np.repeat(f['weight_scales'].astype(np.float32),group,axis=1)[:,:cols]
        paid=sum(f[field].nbytes for field in ('weight_codes','weight_scales','weight_shape'))
    return np.ascontiguousarray((2*decoded-15)*scale), paid


def response(x, gate, up, down):
    g=x@gate.T
    u=x@up.T
    hidden=(g/(1+np.exp(-np.clip(g,-80,80))))*u
    return hidden, hidden@down.T


def sha(path):
    digest=hashlib.sha256()
    with path.open('rb') as f:
        for part in iter(lambda:f.read(4*1024*1024),b''):
            digest.update(part)
    return digest.hexdigest()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--split',choices=('train','held'),required=True)
    parser.add_argument('--chunk',type=int,choices=range(4))
    args=parser.parse_args()
    split=args.split
    capture=CAPTURE/f'ternary-{"train-464-4" if split=="train" else "validation-8-4"}.npz'
    if args.chunk is None:
        offsets=np.concatenate([np.arange(w*256,w*256+(128 if split=='train' else 64)) for w in range(4)])
        identity=split
    else:
        offsets=np.arange(args.chunk*256,(args.chunk+1)*256)
        identity=f'{split}-{args.chunk}'
    with np.load(capture) as f:
        x=np.ascontiguousarray(bf16(f['layer00'][offsets].copy()))
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        source={name: np.ascontiguousarray(f.get_tensor('model.layers.0.mlp.'+name+'_proj.weight').float().numpy())
                for name in ('gate','up','down')}
    q={};sizes={};paths={}
    for name in source:
        path=Q4/f'model_layers_0_mlp_{name}_proj_weight-g128-b4.npz'
        q[name],sizes[name]=q4_decode(path)
        paths[name]=dict(path=str(path),sha256=sha(path),payload_bytes=sizes[name])
    hidden,target=response(x,source['gate'],source['up'],source['down'])
    _,control=response(x,q['gate'],q['up'],q['down'])
    error=np.linalg.norm((control-target).astype(np.float64))/np.linalg.norm(target.astype(np.float64))
    out=HERE/f'{identity}.npz'
    np.savez_compressed(out,inputs=x,hidden=hidden,target=target,q4=control)
    record=dict(split=split,source_sha256=sha(MODEL),capture_sha256=sha(capture),capture_path=str(capture),
                offsets=offsets.tolist(),shape=list(x.shape),payload_bytes=int(sum(sizes.values())),images=paths,
                q4_relative_rms=float(error),target_norm=float(np.linalg.norm(target.astype(np.float64))),
                response_sha256=hashlib.sha256(target.tobytes()).hexdigest())
    (HERE/f'{identity}.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(dict(identity=identity,shape=list(target.shape),q4_rms=error,payload_bytes=sum(sizes.values()))),flush=True)


if __name__=='__main__': main()
