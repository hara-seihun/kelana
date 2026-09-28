"""Combinatorial E8P magnitude byte and direct whole-dot reader."""
from pathlib import Path
import hashlib
import importlib.util
import json
from math import comb
import numpy as np

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('root_reader',HERE.parent/'e8-root-program/replay.py')
root=importlib.util.module_from_spec(spec);spec.loader.exec_module(root)
PERM=np.array([0,4,1,5,2,6,3,7])
INVERSE=np.argsort(PERM)


def subset(rank,k):
    mask=0
    for i in range(7,-1,-1):
        if k and comb(i,k)<=rank:
            mask |= 1<<i
            rank -= comb(i,k)
            k -= 1
    assert rank==0 and k==0
    return mask


def masks(code,exceptions):
    code=int(code)
    assert 0<=code<256 and len(exceptions)==29
    if code>=192:
        i,j=code&7,(code>>3)&7
        return (0 if i==j else 1<<j),1<<i
    if code>=163:
        return int(exceptions[code-163]),0
    offsets=(0,1,9,37,93,163)
    k=next(k for k in range(5) if code<offsets[k+1])
    return subset(code-offsets[k],k),0


def magnitudes(code,exceptions):
    threes,fives=masks(code,exceptions)
    assert threes&fives==0
    out=np.array([1+2*((threes>>i)&1)+4*((fives>>i)&1) for i in range(8)],dtype=np.int16)
    if threes.bit_count()&1:out[7]*=-1
    return out


def main_four(code,exceptions):
    code=int(code)
    sign=code&255
    parity=sign.bit_count()&1
    sign ^= parity
    v=magnitudes(code>>8,exceptions)
    return (2*v*(1-2*((sign>>np.arange(8))&1))+(1-2*parity))[PERM]


def dot_four(code,z,exceptions):
    code=int(code);threes,fives=masks(code>>8,exceptions)
    parity=(code&255).bit_count()&1
    sign=(code&255)^parity
    inputs=np.asarray(z)[...,INVERSE]
    terms=[(1-2*((sign>>i)&1))*inputs[...,i] for i in range(8)]
    value=2*sum(terms)+(1-2*parity)*np.sum(inputs,axis=-1)
    value+=4*sum((terms[i] for i in range(8) if (threes>>i)&1),np.zeros_like(value))
    value+=8*sum((terms[i] for i in range(8) if (fives>>i)&1),np.zeros_like(value))
    if threes.bit_count()&1:
        mag7=1+2*((threes>>7)&1)+4*((fives>>7)&1)
        value-=4*mag7*terms[7]
    return value


def decode(data):
    assert len(data)==49327
    exceptions=data[49298:]
    assert len(set(exceptions))==29 and all(x.bit_count()==5 for x in exceptions)
    codes=np.frombuffer(data,dtype='<u2',count=16384).reshape(128,128)
    residual=np.frombuffer(data,dtype='u1',count=16384,offset=32768)
    su=1-2*np.unpackbits(np.frombuffer(data[49152:49280],dtype='u1'),bitorder='little').astype(np.int16)
    sv=1-2*np.unpackbits(np.frombuffer(data[49280:49296],dtype='u1'),bitorder='little').astype(np.int16)
    scale=float(np.frombuffer(data[49296:49298],dtype='<f2')[0]);assert np.isfinite(scale) and scale>0
    base=np.stack([main_four(c,exceptions) for c in codes.flat]).reshape(128,128,8)*.25
    extra=np.stack([root.root_twice(c) for c in residual]).reshape(128,128,8)*.5
    transformed=(base+extra/2.04).reshape(128,1024)*scale
    return root.had((root.had(transformed)*su).T).T*sv[:,None]


def main():
    data=(HERE/'quip-combinatorial-standalone.bin').read_bytes()
    receipt=json.loads((HERE/'image.json').read_text())
    assert hashlib.sha256(data).hexdigest()==receipt['image_sha256']
    old=(HERE.parent/'e8-root-program/quip-root-standalone.bin').read_bytes()
    assert hashlib.sha256(old).hexdigest()==receipt['source_sha256']
    w=decode(data)
    assert np.array_equal(w,root.decode(old))
    assert hashlib.sha256(root.FIX.read_bytes()).hexdigest()==root.FIX_SHA
    with np.load(root.FIX) as f:
        target=f['weight'][:128].astype(np.float64)
        scores={key:float(np.sum((f[field].astype(np.float64)@(w-target).T)**2)/np.sum((f[field].astype(np.float64)@target.T)**2))
                for key,field in [('train','train'),('held','validation')]}
    result={**receipt,'independent_weight_replay_equal':True,'relative_squared_response_error':scores}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
