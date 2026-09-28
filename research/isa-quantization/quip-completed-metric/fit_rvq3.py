"""QuIP# E8P12RVQ3B rank-zero under the predeclared source-completed metric."""
from pathlib import Path
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'quip-e8p-local'))
from fit import FIX, grid, official_e8p_quantize

N=1024; M=128; B=8
E81B=np.frombuffer((HERE.parent/'quip-e8p-local/e81b-grid.bin').read_bytes(),dtype='<f2').astype(np.float32).reshape(256,8)
E81B_NORM=(E81B*E81B).sum(axis=-1)


def had(a):
    out=np.asarray(a,dtype=np.float64).copy()
    n=out.shape[-1];shape=out.shape
    out=out.reshape(-1,n)
    width=1
    while width<n:
        v=out.reshape(-1,n//(2*width),2,width)
        left=v[:,:,0,:].copy();right=v[:,:,1,:].copy()
        v[:,:,0,:]=left+right;v[:,:,1,:]=left-right
        width*=2
    return out.reshape(shape)/np.sqrt(n)


def main():
    with np.load(FIX) as f:
        x=f['train'].astype(np.float64);w=f['weight'][:M].astype(np.float64)
    assert x.shape==(2048,N) and w.shape==(M,N)
    H=np.load('/path/to/workspace/data/kelana-subbit/isa-source-law/qwen3-0.6b-layer00-q-input/conditional-completed-train-metric.npy')
    H=H/np.diag(H).mean()+np.eye(N)*.01
    rng=np.random.default_rng(20260924)
    su=rng.choice(np.array([-1,1],dtype=np.int8),N)
    sv=rng.choice(np.array([-1,1],dtype=np.int8),M)
    wr=had(had(w.T*sv).T*su)
    hr=had(had(H*su).T*su)
    lower=np.linalg.cholesky(hr);L=lower.copy()
    for k in range(0,N,B):
        L[:,k:k+B]=np.linalg.solve(lower[k:k+B,k:k+B].T,lower[:,k:k+B].T).T
    scale=np.sqrt(np.mean(wr**2))/.98
    wr/=scale
    q=np.zeros_like(wr)
    base=np.empty((M,N//B),dtype='<u2');resid=np.empty((M,N//B),dtype='u1')
    cb=grid()

    def assign(target):
        initial,indices=official_e8p_quantize(target,cb)
        remaining=(target-initial)*2.04
        j=(2*remaining.astype(np.float32)@E81B.T-E81B_NORM).argmax(axis=-1)
        return initial+E81B[j]/2.04,indices,j.astype('u1')

    for k in reversed(range(N//B)):
        s=B*k;e=s+B
        target=wr[:,s:e]+(wr[:,e:]-q[:,e:])@L[e:,s:e]
        q[:,s:e],base[:,k],resid[:,k]=assign(target)
    for _ in range(10):
        for k in reversed(range(N//B)):
            s=B*k;e=s+B
            target=q[:,s:e]+(wr-q)@hr[:,s:e]@np.linalg.inv(hr[s:e,s:e])
            q[:,s:e],base[:,k],resid[:,k]=assign(target)
    def root_twice(c):
        v=np.zeros(8,dtype=np.int8)
        if c<128:
            if c!=127:
                i=c&7;j=(c>>3)&7;s=1-2*((c>>6)&1)
                v[i]+=2*s;v[j]+=2*s*(1 if i<=j else -1)
        else:
            for i in range(7):v[i]=1-2*((c>>i)&1)
            v[7]=1-2*((c&127).bit_count()&1)
        return v
    alphabet=np.stack([root_twice(c) for c in range(256)])
    original=np.rint(E81B*2).astype(np.int8)
    assert np.array_equal(original.astype(np.float32),E81B*2)
    labels={tuple(v):i for i,v in enumerate(alphabet.tolist())}
    assert len(labels)==256 and set(labels)==set(map(tuple,original.tolist()))
    permutation=np.array([labels[tuple(v)] for v in original.tolist()],dtype='u1')
    root=permutation[resid]
    data=base.tobytes()+root.tobytes()+np.packbits(su<0,bitorder='little').tobytes()+np.packbits(sv<0,bitorder='little').tobytes()+np.array([scale],dtype='<f2').tobytes()
    assert len(data)==49298
    assets=(HERE.parent/'quip-e8p-local/e8p-abs-grid.bin').read_bytes()
    assert len(assets)==1024
    image=data+assets
    assert len(image)==50322
    (HERE/'completed-rvq3-root-50322.bin').write_bytes(image)
    print('E8P12RVQ3B completed-root standalone slab',len(image),'bytes')


if __name__=='__main__':main()
