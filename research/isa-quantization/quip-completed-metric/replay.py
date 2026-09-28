"""Independent stored-image decoders and all predeclared score axes."""
from pathlib import Path
import hashlib
import json
import numpy as np

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
DATA=Path('/path/to/workspace/data/kelana-subbit/isa-source-law/qwen3-0.6b-layer00-q-input')
G_FILE=DATA/'uniform-id-second-moment.npy'
M_FILE=DATA/'conditional-completed-train-metric.npy'


def had(a):
    arr=np.asarray(a,dtype=float).copy();n=arr.shape[-1]
    width=1
    while width<n:
        b=arr.reshape(-1,n//(2*width),2,width)
        left=b[:,:,0].copy();right=b[:,:,1].copy()
        b[:,:,0]=left+right;b[:,:,1]=left-right
        width*=2
    return arr/np.sqrt(n)


def quip_root(data):
    assert len(data)==50322
    main=np.frombuffer(data,dtype='<u2',count=16384).reshape(128,128)
    root=np.frombuffer(data,dtype='u1',count=16384,offset=32768).reshape(128,128)
    su=1-2*np.unpackbits(np.frombuffer(data[49152:49280],dtype='u1'),bitorder='little').astype(np.int16)
    sv=1-2*np.unpackbits(np.frombuffer(data[49280:49296],dtype='u1'),bitorder='little').astype(np.int16)
    scale=float(np.frombuffer(data[49296:49298],dtype='<f2')[0]);assert np.isfinite(scale) and scale>0
    abs_table=data[49298:]
    assert hashlib.sha256(abs_table).hexdigest()=='efc2c03c60acd955dc812ff2bade9ec6cc31259807e48473506161f3a9a230ce'
    packed=np.frombuffer(abs_table,dtype='<u4')[main>>8]
    sign=(main&255).astype(np.uint32)
    parity=np.bitwise_xor.reduce((sign[...,None]>>np.arange(8))&1,axis=-1)
    sign^=parity.astype(np.uint32)
    perm=np.array([0,4,1,5,2,6,3,7])
    base=np.stack([((packed>>(4*i))&15).astype(float) for i in perm],axis=-1)
    base=(base-8)*.5*(1-2*((sign[...,None]>>perm)&1).astype(np.int16))
    base+=(1-2*parity.astype(np.int16))[...,None]*.25
    residual=np.zeros((*root.shape,8),dtype=float)
    i=root&7;j=(root>>3)&7;s=1-2*((root>>6)&1).astype(np.int16)
    ii,jj=np.indices(root.shape)
    for k in range(8):
        residual[:,:,k]+=np.where((root<128)&(root!=127)&(i==k),s,0)
        residual[:,:,k]+=np.where((root<128)&(root!=127)&(j==k),s*np.where(i<=j,1,-1),0)
        if k<7:
            residual[:,:,k]+=np.where(root>=128,(1-2*((root>>k)&1).astype(np.int16))*.5,0)
        else:
            bits=(root&127).copy();p=np.zeros(root.shape,dtype='u1')
            for bit in range(7):p^=(bits>>bit)&1
            residual[:,:,k]+=np.where(root>=128,(1-2*p.astype(np.int16))*.5,0)
    transformed=(base+residual/2.04).reshape(128,1024)*scale
    return had((had(transformed)*su).T).T*sv[:,None]


def scalar(data):
    assert len(data)==50320
    mask=np.unpackbits(np.frombuffer(data[:128],dtype='u1'),bitorder='little').reshape(128,8)
    assert mask.sum()==191
    offset=128;w=np.empty((128,1024),dtype=float)
    for row in range(128):
        for group in range(8):
            bits=2 if mask[row,group] else 3
            payload=data[offset:offset+16*bits];offset+=16*bits
            codes=np.empty(128,dtype=float)
            for col in range(128):
                shift=col*bits
                val=payload[shift//8]>>(shift%8)
                if shift%8+bits>8:val|=payload[shift//8+1]<<(8-shift%8)
                codes[col]=val&((1<<bits)-1)
            step,origin=np.frombuffer(data[offset:offset+4],dtype='<f2').astype(float);offset+=4
            assert np.isfinite(step) and step>0 and np.isfinite(origin)
            w[row,128*group:128*(group+1)]=codes*step+origin
    assert offset==len(data)
    return w


def energy(a,h):return float(np.sum(a*(a@h)))


def main():
    with np.load(FIX) as f:
        w=f['weight'][:128].astype(float)
        x=f['train'].astype(float);v=f['validation'].astype(float)
    H=x.T@x/len(x);V=v.T@v/len(v)
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    assert hashlib.sha256(G_FILE.read_bytes()).hexdigest()=='48446e3398f37e867e0e79b6538252b3cf1cb155739fb7d737d5ec423393ad7d'
    assert hashlib.sha256(M_FILE.read_bytes()).hexdigest()=='0775bf85e7fca7b475766d5f4cbe89ed67a1a0184ef2c04afe0bc34dffddc1c9'
    G=np.load(G_FILE);M=np.load(M_FILE)
    metrics={'empirical_train':H,'source_uniform_id':G,'conditional_completion':M,'inspected_held':V}
    original_quip=(HERE.parent/'e8-root-program/quip-root-standalone.bin').read_bytes()
    old_scalar_data=(HERE.parent/'quip-root-matched-scalar/refit-group-q2q3-50320.bin').read_bytes()
    assert hashlib.sha256(original_quip).hexdigest()=='d39500d3a5fbfd3260f4139d064ab00654582e15e4fc461fc923502d841f907a'
    assert hashlib.sha256(old_scalar_data).hexdigest()=='e41d273bd2d5ea7ef497e6c2749bf6ac5b1529124f8e24d2ea2448132dfdfd15'
    images=[('original_rvq3_root',original_quip),
            ('completed_rvq3_root',(HERE/'completed-rvq3-root-50322.bin').read_bytes()),
            ('original_scalar',old_scalar_data),
            ('completed_scalar',(HERE/'completed-group-q2q3-50320.bin').read_bytes())]
    out={'fixture_sha256':hashlib.sha256(FIX.read_bytes()).hexdigest(),'metric_sha256':hashlib.sha256(M_FILE.read_bytes()).hexdigest(),'images':{}}
    expected={'completed_rvq3_root':'1375c3809f12a7484fba1a49d5573b529c6f0946e73408a2f0232a8dd61ae2b0',
              'completed_scalar':'bbf25784aba49c5687c3af203471dc4f91d6beb14dc4eaddb4f7e3377bb323f5'}
    for name,image in images:
        if name in expected:assert hashlib.sha256(image).hexdigest()==expected[name]
        decoded=quip_root(image) if 'rvq3' in name else scalar(image)
        D=decoded-w
        scores={key:{'absolute_error':energy(D,cov),'relative_squared_error':energy(D,cov)/energy(w,cov)} for key,cov in metrics.items()}
        out['images'][name]={'sha256':hashlib.sha256(image).hexdigest(),'bytes':len(image),'scores':scores}
    assert out['images']['original_rvq3_root']['scores']['empirical_train']['relative_squared_error']<.004
    (HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(out,indent=2))

if __name__=='__main__':main()
