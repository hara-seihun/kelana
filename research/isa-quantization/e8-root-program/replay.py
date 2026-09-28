#!/usr/bin/env python3
"""Table-free E81B residual reader; main E8P absolute table remains paid."""
from pathlib import Path
import hashlib
import importlib.util
import json
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
FIX_SHA='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'


def root_twice(code):
    """Each of 256 byte labels computes one integer vector 2*g, with no table."""
    code=int(code)
    assert 0<=code<256
    out=np.zeros(8,dtype=np.int8)
    if code<128:
        if code==127:
            return out
        i=code&7
        j=(code>>3)&7
        sign=1-2*((code>>6)&1)
        out[i]+=2*sign
        out[j]+=2*sign*(1 if i<=j else -1)
    else:
        signs=code&127
        for i in range(7):
            out[i]=1-2*((signs>>i)&1)
        out[7]=1-2*(signs.bit_count()&1)
    return out


def root_dot(code,z):
    """g(code) dot z for an arbitrary real eight-vector; no coefficient table."""
    code=int(code)
    if code<128:
        if code==127:
            return np.zeros(z.shape[:-1],dtype=z.dtype)
        i=code&7
        j=(code>>3)&7
        sign=1-2*((code>>6)&1)
        return sign*(z[...,i]+(1 if i<=j else -1)*z[...,j])
    signs=code&127
    value=(1-2*(signs.bit_count()&1))*z[...,7]
    for i in range(7):
        value=value+(1-2*((signs>>i)&1))*z[...,i]
    return value*.5


def had(a):
    out=np.asarray(a,dtype=np.float64).copy()
    n=out.shape[-1]
    assert n>0 and n&(n-1)==0
    width=1
    while width<n:
        shaped=out.reshape(-1,n//(2*width),2,width)
        left=shaped[:,:,0,:].copy()
        right=shaped[:,:,1,:].copy()
        shaped[:,:,0,:]=left+right
        shaped[:,:,1,:]=left-right
        width*=2
    return out/np.sqrt(n)


def decode(data):
    assert len(data)==50322
    main=np.frombuffer(data,dtype='<u2',count=16384).reshape(128,128)
    root=np.frombuffer(data,dtype='u1',count=16384,offset=32768).reshape(128,128)
    su=1-2*np.unpackbits(np.frombuffer(data[49152:49280],dtype='u1'),bitorder='little').astype(np.int16)
    sv=1-2*np.unpackbits(np.frombuffer(data[49280:49296],dtype='u1'),bitorder='little').astype(np.int16)
    scale=float(np.frombuffer(data[49296:49298],dtype='<f2')[0])
    assert np.isfinite(scale) and scale>0
    absolute=data[49298:50322]
    assert hashlib.sha256(absolute).hexdigest()=='efc2c03c60acd955dc812ff2bade9ec6cc31259807e48473506161f3a9a230ce'
    packed=np.frombuffer(absolute,dtype='<u4')[main>>8]
    signs=main&255
    parity=np.bitwise_xor.reduce((signs[...,None]>>np.arange(8))&1,axis=-1)
    signs=signs^parity
    perm=np.array([0,4,1,5,2,6,3,7])
    base=np.stack([((packed>>(4*i))&15).astype(np.float64) for i in perm],axis=-1)
    base=(base-8)*.5*(1-2*((signs[...,None]>>perm)&1).astype(np.int16))
    base+=(1-2*parity.astype(np.int16))[...,None]*.25
    # Formula evaluation per index, not a retained generic residual lookup array.
    residual=np.stack([root_twice(c) for c in root.flat]).reshape(128,128,8).astype(np.float64)*.5
    transformed=(base+residual/2.04).reshape(128,1024)*scale
    weight=had((had(transformed)*su).T).T*sv[:,None]
    return weight


def main():
    data=(HERE/'quip-root-standalone.bin').read_bytes()
    manifest=json.loads((HERE/'image.json').read_text())
    assert hashlib.sha256(data).hexdigest()==manifest['image_sha256']
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()==FIX_SHA
    weight=decode(data)
    with np.load(FIX) as f:
        target=f['weight'][:128].astype(np.float64)
        panels={'train':f['train'].astype(np.float64),'held':f['validation'].astype(np.float64)}
    scores={key:float(np.linalg.norm(x@(weight-target).T)**2/np.linalg.norm(x@target.T)**2)
            for key,x in panels.items()}
    result={**manifest,'relative_squared_response_error':scores}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
