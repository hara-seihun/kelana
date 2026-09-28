"""QuIP# E8P12RVQ3B CPU quantizer, default rank zero; fixed 128x128 tile."""
from pathlib import Path
import numpy as np
from fit import FIX, HERE, N, had, grid, official_e8p_quantize

E81B=np.frombuffer((HERE/'e81b-grid.bin').read_bytes(),dtype='<f2').astype(np.float32).reshape(256,8)
E81B_NORM=(E81B*E81B).sum(axis=-1)


def main():
    with np.load(FIX) as f:
        x=f['train'][:,:N].astype(np.float64);w=f['weight'][:N,:N].astype(np.float64)
    H=x.T@x;H=H/np.diag(H).mean()+np.eye(N)*.01
    rng=np.random.default_rng(20260924)
    su=rng.choice(np.array([-1,1],dtype=np.int8),N)
    sv=rng.choice(np.array([-1,1],dtype=np.int8),N)
    wr=had(had(w.T*sv).T*su)
    hr=had(had(H*su).T*su)
    lower=np.linalg.cholesky(hr);L=lower.copy()
    for k in range(0,N,8):
        L[:,k:k+8]=np.linalg.solve(lower[k:k+8,k:k+8].T,lower[:,k:k+8].T).T
    scale=np.sqrt(np.mean(wr**2))/.98
    wr=wr/scale
    q=np.zeros_like(wr)
    base=np.empty((N,16),dtype='<u2');resid=np.empty((N,16),dtype='u1')
    cb=grid()

    def assign(target):
        initial,indices=official_e8p_quantize(target,cb)
        remaining=(target-initial)*2.04
        j=(2*remaining.astype(np.float32)@E81B.T-E81B_NORM).argmax(axis=-1)
        return initial+E81B[j]/2.04,indices,j.astype('u1')

    for k in reversed(range(16)):
        s=8*k;e=s+8
        target=wr[:,s:e]+(wr[:,e:]-q[:,e:])@L[e:,s:e]
        q[:,s:e],base[:,k],resid[:,k]=assign(target)
    for _ in range(10):
        for k in reversed(range(16)):
            s=8*k;e=s+8
            target=q[:,s:e]+(wr-q)@hr[:,s:e]@np.linalg.inv(hr[s:e,s:e])
            q[:,s:e],base[:,k],resid[:,k]=assign(target)
    data=base.tobytes()+resid.tobytes()+np.packbits(su<0,bitorder='little').tobytes()+np.packbits(sv<0,bitorder='little').tobytes()+np.array([scale],dtype='<f2').tobytes()
    assert len(data)==6178
    (HERE/'quip-rvq3-r0.bin').write_bytes(data)
    print('E8P12RVQ3B rank0',len(data),'bytes')


if __name__=='__main__':main()
