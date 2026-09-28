#!/usr/bin/env python3
"""Predeclared two-round, train-only Euclidean-label/response-gain Q-head fit."""
import hashlib
import importlib.util
from pathlib import Path
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'e8-root-program'
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
ROOT_SHA='d39500d3a5fbfd3260f4139d064ab00654582e15e4fc461fc923502d841f907a'
FIX_SHA='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
spec=importlib.util.spec_from_file_location('root',SOURCE/'replay.py')
root=importlib.util.module_from_spec(spec);spec.loader.exec_module(root)
PERM=np.array([0,4,1,5,2,6,3,7]); INV=np.argsort(PERM)
EVEN=np.array([i for i in range(256) if i.bit_count()%2==0],dtype=np.uint8)
SIGNS=(1-2*((EVEN[:,None].astype(np.int16)>>np.arange(8))&1)).astype(np.float64)
ROOT=np.stack([root.root_twice(i) for i in range(256)]).astype(np.float64)*(.5/2.04)


def sources():
    image=(SOURCE/'quip-root-standalone.bin').read_bytes()
    assert hashlib.sha256(image).hexdigest()==ROOT_SHA
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()==FIX_SHA
    with np.load(FIX) as f:
        W=f['weight'][:128].astype(np.float64)
        X=f['train'].astype(np.float64)
    su=1-2*np.unpackbits(np.frombuffer(image[49152:49280],dtype='u1'),bitorder='little').astype(np.int16)
    sv=1-2*np.unpackbits(np.frombuffer(image[49280:49296],dtype='u1'),bitorder='little').astype(np.int16)
    scale=np.frombuffer(image[49296:49298],dtype='<f2')[0].item()
    target=root.had((root.had(W*su)*sv[:,None]).T).T/scale
    Xh=root.had(X*su)
    return image,W,X,Xh,target,scale


def main_vectors(high,low):
    bits=(high[...,None]>>np.arange(8))&1
    parity=np.array([int(s).bit_count()&1 for s in low.flat]).reshape(low.shape)
    sign=low^parity
    a=(1+2*bits)*(.5*(1-2*((sign[...,None]>>np.arange(8))&1)))
    a+=(1-2*parity)[...,None]*.25
    return a[...,PERM]


def assign_main(want):
    """Nearest main to N desired eight-vectors, deterministic low/high tie ordering."""
    n=len(want);w=want[:,INV]
    best=np.full(n,np.inf);best_hi=np.zeros(n,dtype=np.uint8);best_lo=np.zeros(n,dtype=np.uint8)
    for parity in (0,1):
        offset=(1-2*parity)*.25
        shifted=w-offset
        for ix,sgn in enumerate(SIGNS):
            product=shifted*sgn
            bits=product>1.0 # 1 or 3 magnitude in integer units, scaled by 1/2
            value=sgn*(.5+bits.astype(np.float64))
            err=np.sum((value-shifted)**2,axis=1)
            better=err<best
            best[better]=err[better]
            best_hi[better]=np.packbits(bits[better].astype(np.uint8),axis=1,bitorder='little')[:,0]
            best_lo[better]=EVEN[ix]^parity
    return best_hi,best_lo


def assign_root(want):
    # N*256 similarities, with exact squared-distance selection and stable ties.
    norms=np.sum(ROOT**2,axis=1)
    return np.argmin(norms[None,:]-2*want@ROOT.T,axis=1).astype(np.uint8)


def chunk(first,last,round_no):
    image,W,X,Xh,T,scale=sources()
    assert 0<=first<last<=128 and round_no in (0,1)
    T=T[first:last];rows=last-first
    if round_no:
        prior=np.load(HERE/f'emit/round0-{first}-{last}.npz')
        high=prior['high'].copy();low=prior['low'].copy();r=prior['root'].copy()
        gain=prior['gain'].astype(np.float64)
    else:
        high=np.zeros((rows,128),dtype=np.uint8);low=np.zeros_like(high)
        r=np.full_like(high,127);gain=np.ones((rows,4),dtype=np.float64)
    for row in range(rows):
        z=T[row].reshape(128,8)/np.repeat(gain[row],32)[:,None]
        # Three fixed code decisions per round, never chosen by held quality.
        high[row],low[row]=assign_main(z-ROOT[r[row]])
        main=main_vectors(high[row],low[row])
        r[row]=assign_root(z-main)
        high[row],low[row]=assign_main(z-ROOT[r[row]])
    Q=(main_vectors(high,low)+ROOT[r]).reshape(rows,4,256)
    for row in range(rows):
        A=np.stack([Xh[:,i*256:(i+1)*256]@Q[row,i] for i in range(4)],axis=1)
        rhs=Xh@T[row]
        solved=np.linalg.lstsq(A,rhs,rcond=None)[0]
        assert np.isfinite(solved).all() and (np.abs(solved)<65504).all() and (solved!=0).all()
        gain[row]=solved.astype(np.float16).astype(np.float64)
    path=HERE/f'emit/round{round_no}-{first}-{last}.npz'
    np.savez_compressed(path,high=high,low=low,root=r,gain=gain.astype(np.float16))
    print(f'round={round_no} rows=[{first},{last}) gains_range=[{gain.min():.5g},{gain.max():.5g}]')


def finish():
    image,W,X,Xh,T,scale=sources()
    blocks=[]
    for first in range(0,128,8):
        with np.load(HERE/f'emit/round1-{first}-{first+8}.npz') as f:
            blocks.append(tuple(f[k].copy() for k in ('high','low','root','gain')))
    high,low,residual,gain=[np.concatenate([b[i] for b in blocks]) for i in range(4)]
    # One low sign byte, one literal mask byte and one root byte for each block.
    codes=(high.astype('<u2')<<8)|low.astype('<u2')
    result=(codes.astype('<u2').tobytes()+residual.tobytes()+image[49152:49298]+gain.astype('<f2').tobytes())
    assert len(result)==50322
    (HERE/'bitmask-root-standalone.bin').write_bytes(result)
    print('image_bytes',len(result),'sha256',hashlib.sha256(result).hexdigest())


if __name__=='__main__':
    if sys.argv[1]=='chunk':chunk(int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4]))
    elif sys.argv[1]=='finish':finish()
    else:raise ValueError(sys.argv)
