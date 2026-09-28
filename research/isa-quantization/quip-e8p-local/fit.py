"""CPU port of QuIP# E8P 2-bit Hadamard/LDLQ with its optional low-rank path.

The E8P grid is the upstream generic codebook, not trained on this layer. A full
nearest-grid search replaces upstream's faster E8P projection; 16-bit indices
are row-major rather than CUDA-interleaved. Both decode to the same E8P vectors.
"""
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
FIX = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
N = 128
GRID_ABS = np.frombuffer((HERE/'e8p-abs-grid.bin').read_bytes(), dtype='<u4')


def grid():
    packed = GRID_ABS.astype(np.uint32)
    shuffle = [0, 4, 1, 5, 2, 6, 3, 7]
    absvals = np.stack([((packed >> (4*i)) & 15).astype(np.float32) for i in shuffle], axis=1)
    absvals = (absvals-8)*.5
    codes = np.arange(65536, dtype=np.uint32)
    sign = (codes & 255).copy()
    parity = np.bitwise_xor.reduce(((sign[:,None] >> np.arange(8)) & 1).astype(np.uint8), axis=1)
    sign ^= parity
    signs = 1-2*((sign[:,None] >> np.array(shuffle)) & 1).astype(np.int16)
    return np.ascontiguousarray(absvals[codes >> 8] * signs + (1-2*parity[:,None].astype(np.int16))*.25, dtype=np.float32)


def had(a):
    v=np.asarray(a, dtype=np.float64).copy()
    original=v.shape
    v=v.reshape(-1,N)
    step=1
    while step<N:
        q=v.reshape(-1,N//(2*step),2,step)
        left=q[:,:,0,:].copy();right=q[:,:,1,:].copy()
        q[:,:,0,:]=left+right;q[:,:,1,:]=left-right
        step*=2
    return v.reshape(original)/np.sqrt(N)


PART=np.frombuffer((HERE/'e8p-grid-part.bin').read_bytes(),dtype='<f4').reshape(-1,8)
PART_NORMS=np.sum(PART*PART,axis=1)
PART_ABS=np.frombuffer((HERE/'e8p-part-abs-map.bin').read_bytes(),dtype='<u2')
ABS_ODD=np.frombuffer((HERE/'e8p-abs-odd.bin').read_bytes(),dtype='u1')
assert PART.shape==(1366,8) and PART_ABS.shape==(1366,) and ABS_ODD.shape==(256,)


def official_e8p_quantize(v, cb):
    """Upstream E8P fast_quantize_part, two quarter-shifted parity cosets."""
    out_vals=[];out_idxs=[];errors=[]
    for parity,shift in ((True,.25),(False,-.25)):
        target=np.asarray(v+shift,dtype=np.float32)
        absolute=np.abs(target)
        negative=target<0
        odd=(negative.sum(axis=-1)%2)!=0
        absolute[odd,7]*=-1
        mask=1-2*negative.astype(np.int8)
        mask[odd,7]*=-1
        choose=(2*absolute@PART.T-PART_NORMS).argmax(axis=-1)
        vals=PART[choose]*mask
        abs_idx=PART_ABS[choose].astype(np.uint16)
        signmask=np.logical_xor(PART[choose]<0,mask<0)[:,[0,2,4,6,1,3,5,7]]
        signmask[:,7]=np.logical_xor(signmask[:,7],ABS_ODD[abs_idx].astype(bool))
        signmask[:,0]=np.logical_xor(signmask[:,0],parity)
        bits=(signmask.astype(np.uint16)*(1<<np.arange(8,dtype=np.uint16))).sum(axis=-1,dtype=np.uint16)
        idx=(abs_idx<<8)|bits
        q=vals-shift
        out_vals.append(q);out_idxs.append(idx);errors.append(np.sum((target-vals)**2,axis=-1))
    pick=errors[0]<errors[1]
    idx=np.where(pick,out_idxs[0],out_idxs[1]).astype(np.uint16)
    q=np.where(pick[:,None],out_vals[0],out_vals[1])
    assert np.max(np.abs(q-cb[idx]))<1e-6
    return q,idx


def fit(rank):
    with np.load(FIX) as f:
        x=f['train'][:,:N].astype(np.float64);w=f['weight'][:N,:N].astype(np.float64)
    H=x.T@x
    H=H/np.diag(H).mean()+np.eye(N)*.01  # upstream regularize_H, sigma_reg=.01
    rng=np.random.default_rng(20260924+rank)
    su=rng.choice(np.array([-1,1],dtype=np.int8),N)
    sv=rng.choice(np.array([-1,1],dtype=np.int8),N)
    wr=had(had(w.T*sv).T*su)  # RHT_W: had(had(W.T*SV).T*SU)
    hr=had(had(H*su).T*su)
    wo=wr.copy()
    lhr=np.linalg.cholesky(hr)
    if rank:
        u,s,vh=np.linalg.svd(wr@lhr,full_matrices=False)
        v=vh[:rank].T
        hr=hr-lhr@v@v.T@lhr.T+np.eye(N)*np.diag(hr).mean()*.01
        wr=wr-u[:,:rank]@u[:,:rank].T@wr
    # Block LDLQ: L = chol(H) / block-diagonal chol(H), block size eight.
    lower=np.linalg.cholesky(hr)
    L=lower.copy()
    for k in range(0,N,8):
        L[:,k:k+8] = np.linalg.solve(lower[k:k+8,k:k+8].T,lower[:,k:k+8].T).T
    cb=grid()
    scale=np.sqrt(np.mean(wr**2))/1.03  # upstream E8P opt_scale
    wr=wr/scale
    q=np.zeros_like(wr);idx=np.empty((N,N//8),dtype='<u2')
    for k in reversed(range(N//8)):
        start=8*k;end=start+8
        target=wr[:,start:end]+(wr[:,end:]-q[:,end:])@L[end:,start:end]
        q[:,start:end],idx[:,k]=official_e8p_quantize(target,cb)
    # Upstream default quip_tune_iters=10, exact block H conditional updates.
    for _ in range(10):
        for k in reversed(range(N//8)):
            start=8*k;end=start+8
            target=q[:,start:end]+(wr-q)@hr[:,start:end]@np.linalg.inv(hr[start:end,start:end])
            q[:,start:end],idx[:,k]=official_e8p_quantize(target,cb)
    q=q*scale
    if rank:
        residual=(wo-q)@lhr
        u,s,vh=np.linalg.svd(residual,full_matrices=False)
        a=u[:,:rank]
        b=np.linalg.solve(lhr.T,(s[:rank,None]*vh[:rank]).T).T
        bu,bs,bvh=np.linalg.svd(b,full_matrices=False)
        a=np.asarray(a@bu@np.diag(np.sqrt(bs)),dtype='<f2')
        b=np.asarray(np.diag(np.sqrt(bs))@bvh,dtype='<f2')
    else:
        a=np.zeros((N,0),dtype='<f2');b=np.zeros((0,N),dtype='<f2')
    # The upstream SV FP16 field fuses Wscale; sign masks + one FP16 global
    # scale are an exact alternative to 128 equal-magnitude FP16 fields.
    scale=np.float16(scale)
    image=idx.tobytes()+np.packbits(su<0,bitorder='little').tobytes()+np.packbits(sv<0,bitorder='little').tobytes()+np.array([scale],dtype='<f2').tobytes()+a.tobytes()+b.tobytes()
    expected=4096+32+2+512*rank
    assert len(image)==expected
    (HERE/f'quip-e8p-r{rank}.bin').write_bytes(image)
    print(rank,len(image), 'fit grid scale',float(scale))


if __name__=='__main__':
    import sys
    for rank in map(int,sys.argv[1:] or (0,4,5)):fit(rank)
