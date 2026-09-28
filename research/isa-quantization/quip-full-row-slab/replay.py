"""Independent parsers of two standalone full-input q-projection images."""
from pathlib import Path
import hashlib
import json
import numpy as np

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')


def had(a):
    arr=np.asarray(a,dtype=np.float64)
    shape=arr.shape;n=shape[-1]
    out=arr.copy().reshape(-1,n)
    stride=1
    while stride<n:
        for start in range(0,n,2*stride):
            left=out[:,start:start+stride].copy()
            right=out[:,start+stride:start+2*stride].copy()
            out[:,start:start+stride]=left+right
            out[:,start+stride:start+2*stride]=left-right
        stride*=2
    return out.reshape(shape)/np.sqrt(n)


def quip():
    data=(HERE/'quip-rvq3-standalone.bin').read_bytes()
    assert len(data)==54418
    assert hashlib.sha256(data).hexdigest()=='7234c67cc269f945b2826ad8686207336208ed531023ede0be7925c1c041ad43'
    indices=np.frombuffer(data[:32768],dtype='<u2').reshape(128,128)
    residual=np.frombuffer(data[32768:49152],dtype='u1').reshape(128,128)
    su=1-2*np.unpackbits(np.frombuffer(data[49152:49280],dtype='u1'),bitorder='little').astype(np.int16)
    sv=1-2*np.unpackbits(np.frombuffer(data[49280:49296],dtype='u1'),bitorder='little').astype(np.int16)
    scale=float(np.frombuffer(data[49296:49298],dtype='<f2')[0]);assert np.isfinite(scale) and scale>0
    abs_table=data[49298:50322]
    residual_table=data[50322:54418]
    assert hashlib.sha256(abs_table).hexdigest()=='efc2c03c60acd955dc812ff2bade9ec6cc31259807e48473506161f3a9a230ce'
    assert len(residual_table)==4096
    assert hashlib.sha256(residual_table).hexdigest()=='d65cecfd0258df8b7aaabfe7ce66ac5b0ec9385274c60b83f3fe3714321337eb'
    abs_packed=np.frombuffer(abs_table,dtype='<u4')[indices>>8]
    sign=(indices&255).astype(np.uint32)
    parity=np.bitwise_xor.reduce(((sign[...,None]>>np.arange(8))&1).astype(np.uint8),axis=-1)
    sign^=parity
    permutation=[0,4,1,5,2,6,3,7]
    main=np.stack([((abs_packed>>(4*i))&15).astype(np.float64) for i in permutation],axis=-1)
    main=(main-8)*.5*(1-2*((sign[...,None]>>np.array(permutation))&1).astype(np.int16))
    main+=(1-2*parity.astype(np.int16))[...,None]*.25
    small=np.frombuffer(residual_table,dtype='<f2').astype(np.float64).reshape(256,8)
    transformed=(main+small[residual]/2.04).reshape(128,1024)*scale
    w=(had((had(transformed)*su).T)*sv).T
    return w,{'bytes':len(data),'model_specific_bytes':49298,'e8p_indices':32768,'e81b_indices':16384,'hadamard_signs':144,'global_fp16_scale':2,'once_charged_generic_codebooks':5120,'image_sha256':hashlib.sha256(data).hexdigest(),'generic_e81b_table_sha256':hashlib.sha256(residual_table).hexdigest()}


def scalar():
    data=(HERE/'refit-group-q3q4-54416.bin').read_bytes()
    assert len(data)==54416
    assert hashlib.sha256(data).hexdigest()=='78b66990378f3dcae85458c50f4db04bc4d1e2b40d748b4100b078bfb055aec1'
    modes=np.unpackbits(np.frombuffer(data[:128],dtype='u1'),bitorder='little').reshape(128,8)
    assert int(modes.sum())==65
    offset=128;rows=np.empty((128,1024),dtype=np.float64)
    for row in range(128):
        for g in range(8):
            bits=4 if modes[row,g] else 3
            count=16*bits
            payload=data[offset:offset+count];offset+=count
            code=np.empty(128,dtype=np.float64)
            for i in range(128):
                bit=i*bits;digit=payload[bit//8]>>(bit%8)
                if bit%8+bits>8:digit|=payload[bit//8+1]<<(8-bit%8)
                code[i]=digit&((1<<bits)-1)
            step,origin=np.frombuffer(data[offset:offset+4],dtype='<f2').astype(float);offset+=4
            assert np.isfinite(step) and step>0 and np.isfinite(origin)
            rows[row,128*g:128*(g+1)]=step*code+origin
    assert offset==len(data)
    return rows,{'bytes':len(data),'coefficients':49152+65*16,'fp16_group_fields':4096,'mode_mask':128,'upgraded_groups':65,'image_sha256':hashlib.sha256(data).hexdigest()}


def main():
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    with np.load(FIX) as f:
        w=f['weight'][:128].astype(float)
        panels={'train':f['train'].astype(float),'held':f['validation'].astype(float)}
    result={}
    for name,decode in (('quip_rvq3_standalone',quip),('scalar_group128',scalar)):
        qw,ledger=decode()
        assert qw.shape==w.shape==(128,1024)
        score={key:float(np.linalg.norm(x@(qw-w).T)**2/np.linalg.norm(x@w.T)**2) for key,x in panels.items()}
        result[name]={**ledger,'relative_squared_response_error':score}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
