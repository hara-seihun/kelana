#!/usr/bin/env python3
"""Independent parser of the paid image; no fitting/selection code imported."""
from pathlib import Path
import hashlib
import json
import numpy as np

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
FIX_SHA='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
IMAGE_SHA='3f4d8ba94bc67a9fe7801b77975918c996e075b304dc0d7651bb9a68d81e9cce'


def had(array):
    result=np.array(array,dtype=np.float64,copy=True)
    n=result.shape[-1];assert n>0 and n&(n-1)==0
    width=1
    while width<n:
        view=result.reshape(-1,n//(2*width),2,width)
        left=view[:,:,0,:].copy();right=view[:,:,1,:].copy()
        view[:,:,0,:]=left+right;view[:,:,1,:]=left-right
        width*=2
    return result/np.sqrt(n)


def residual(byte):
    byte=int(byte);out=np.zeros(8,dtype=np.float64)
    if byte<128:
        if byte==127:return out
        i=byte&7;j=(byte>>3)&7;sign=-1 if byte&64 else 1
        out[i]+=sign
        out[j]+=sign if i<=j else -sign
    else:
        s=byte&127
        for i in range(7):out[i]=-.5 if s>>i&1 else .5
        out[7]=-.5 if s.bit_count()&1 else .5
    return out


def decode(data):
    assert len(data)==50322
    code=np.frombuffer(data,dtype='<u2',count=16384).reshape(128,128)
    extra=np.frombuffer(data,dtype='u1',offset=32768,count=16384).reshape(128,128)
    su=1-2*np.unpackbits(np.frombuffer(data[49152:49280],dtype='u1'),bitorder='little').astype(np.int16)
    sv=1-2*np.unpackbits(np.frombuffer(data[49280:49296],dtype='u1'),bitorder='little').astype(np.int16)
    scale=np.frombuffer(data[49296:49298],dtype='<f2')[0].item()
    gain=np.frombuffer(data[49298:],dtype='<f2').reshape(128,4).astype(np.float64)
    assert np.isfinite(gain).all() and np.all(gain>0) and np.isfinite(scale) and scale>0
    high=code>>8;low=code&255
    parity=np.stack([(low>>i)&1 for i in range(8)]).sum(0)&1
    corrected=(low^parity).astype(np.int64)
    p=np.array([0,4,1,5,2,6,3,7])
    bits=(high.astype(np.int64)[...,None]>>p)&1
    sign=1-2*((corrected[...,None]>>p)&1).astype(np.int16)
    main=(1+2*bits)*.5*sign+(1-2*parity.astype(np.int16))[...,None]*.25
    root=np.stack([residual(c) for c in extra.flat]).reshape(128,128,8)/2.04
    template=(main+root).reshape(128,4,256)*gain[:,:,None]
    t=template.reshape(128,1024)*scale
    return had((had(t).T)).T*sv[:,None]*su[None,:]


def main():
    image=(HERE/'bitmask-root-standalone.bin').read_bytes()
    assert hashlib.sha256(image).hexdigest()==IMAGE_SHA
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()==FIX_SHA
    W=decode(image)
    with np.load(FIX) as f:
        teacher=f['weight'][:128].astype(np.float64)
        panels={'train':f['train'].astype(np.float64),'held':f['validation'].astype(np.float64)}
    scores={name:float(np.sum((x@(W-teacher).T)**2)/np.sum((x@teacher.T)**2)) for name,x in panels.items()}
    result={'image_sha256':IMAGE_SHA,'fixture_sha256':FIX_SHA,'bytes':len(image),'model_specific_bytes':len(image),'generic_assets_bytes':0,'train_held_raw_response':scores}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
