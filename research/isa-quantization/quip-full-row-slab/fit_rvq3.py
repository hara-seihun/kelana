"""Full-input-coordinate QuIP# E8P12RVQ3B rank-zero CPU port."""
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
    H=x.T@x;H=H/np.diag(H).mean()+np.eye(N)*.01
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
    data=base.tobytes()+resid.tobytes()+np.packbits(su<0,bitorder='little').tobytes()+np.packbits(sv<0,bitorder='little').tobytes()+np.array([scale],dtype='<f2').tobytes()
    assert len(data)==49298
    assets=(HERE.parent/'quip-e8p-local/e8p-abs-grid.bin').read_bytes()+(HERE.parent/'quip-e8p-local/e81b-grid.bin').read_bytes()
    assert len(assets)==5120
    image=data+assets
    assert len(image)==54418
    (HERE/'quip-rvq3-standalone.bin').write_bytes(image)
    print('E8P12RVQ3B standalone slab',len(image),'bytes; payload',len(data),'generic tables',len(assets))


if __name__=='__main__':main()
