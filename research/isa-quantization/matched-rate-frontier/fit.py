"""Bounded local full-Hessian GPTQ-style mixed Q3/Q4 control and paid pair readers.

The format is fixed 128x128 or 128x96; all image bytes are charged. A separate
replayer parses the stored bytes without importing any fitting logic.
"""
import json
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
PAIRS=HERE.parent/'weighted-input-pairs/results.json'


def pack(codes,bits):
    flat=np.asarray(codes,dtype=np.uint8)
    nbytes=(len(flat)*bits+7)//8
    out=bytearray(nbytes)
    for i,v in enumerate(flat):
        offset=i*bits; out[offset//8]|=int(v)<<(offset%8)&255
        if offset%8+bits>8:out[offset//8+1]|=int(v)>>(8-offset%8)
    return bytes(out)


def quantize_rows(w,x,bits):
    """Same full damped-Hessian sequential error compensation as calibrated.py.

    Three clipping starts / four affine LS alternations, FP16 grids, then each
    row independently selects its lowest actual full-covariance response loss.
    """
    gram=x.T@x
    diagonal=gram.diagonal().mean()
    inv=np.linalg.inv(gram+np.eye(len(gram))*diagonal*.01)
    upper=np.linalg.cholesky(inv).T
    nrow,ncol=w.shape
    result=[]
    for row in range(nrow):
        v=w[row];best=None
        for shrink in (1.,.85,.7):
            origin=v.min()*shrink
            step=max((v.max()-v.min())*shrink/(2**bits-1),1e-10)
            for _ in range(4):
                codes=np.clip(np.rint((v-origin)/step),0,2**bits-1)
                cm=codes.mean();vm=v.mean()
                step=max(np.dot(codes-cm,v-vm)/max(np.dot(codes-cm,codes-cm),1e-12),1e-10)
                origin=vm-step*cm
            step=float(np.float16(step));origin=float(np.float16(origin))
            working=v.copy();q=np.zeros(ncol,dtype=np.uint8)
            for col in range(ncol):
                digit=int(np.clip(np.rint((working[col]-origin)/step),0,2**bits-1))
                q[col]=digit
                error=(working[col]-(digit*step+origin))/upper[col,col]
                if col+1<ncol:working[col+1:]-=error*upper[col,col+1:]
            decoded=q.astype(float)*step+origin
            delta=v-decoded
            cost=float(delta@gram@delta)
            if best is None or cost<best[0]:best=(cost,q,step,origin)
        result.append(best)
    return result


def response_refit(rows,w,x):
    """Once codes are fixed, solve their exact full-covariance two-grid fit.

    Retain each prior grid if FP16 rounding would worsen its train response.
    This is a grid-family optimization, not another code-search iteration.
    """
    gram=x.T@x
    refined=[]
    for teacher,(old_cost,code,old_step,old_origin) in zip(w,rows):
        basis=np.stack((code.astype(float),np.ones(len(code))))
        lhs=basis@gram@basis.T
        rhs=basis@gram@teacher
        if np.linalg.cond(lhs)>1e12:
            refined.append((old_cost,code,old_step,old_origin));continue
        step,origin=np.linalg.solve(lhs,rhs)
        step=float(np.float16(step));origin=float(np.float16(origin))
        if not np.isfinite(step) or step<=0 or not np.isfinite(origin):
            refined.append((old_cost,code,old_step,old_origin));continue
        delta=teacher-(code*step+origin)
        cost=float(delta@gram@delta)
        refined.append((cost,code,step,origin) if cost<old_cost else
                       (old_cost,code,old_step,old_origin))
    return refined


def control_image(rows3,rows4,upgrades):
    chosen=set(upgrades)
    mask=bytearray(16)
    for row in chosen:mask[row//8]|=1<<(row%8)
    out=bytearray(mask)
    for row in range(128):
        _,codes,scale,origin=(rows4 if row in chosen else rows3)[row]
        out.extend(pack(codes,4 if row in chosen else 3))
        out.extend(np.array([scale,origin],dtype='<f2').tobytes())
    return bytes(out)


def pair_image(x,w,selected,affine,refit=False):
    pairs=json.loads(PAIRS.read_text())['pairs']
    indices=np.asarray([(i,j) for i,j,_ in pairs],dtype=np.uint8)
    ratios=np.array([r for _,_,r in pairs],dtype='<f2')
    used=set(indices.flatten().tolist())
    singles=np.asarray([k for k in range(128) if k not in used],dtype=np.uint8)
    assert indices.shape==(32,2) and singles.shape==(64,)
    t=np.zeros((128,96))
    for k,(i,j) in enumerate(indices):t[i,k]=1;t[j,k]=float(ratios[k])
    for k,i in enumerate(singles,32):t[i,k]=1
    z=x@t;y=x@w.T
    zfit=z-z.mean(axis=0) if affine else z
    yfit=y-y.mean(axis=0) if affine else y
    reader=np.linalg.lstsq(zfit,yfit,rcond=None)[0].T
    rows=quantize_rows(reader,zfit,4)
    if refit:rows=response_refit(rows,reader,zfit)
    decoded=np.array([q.astype(float)*s+o for _,q,s,o in rows])
    center=(y.mean(axis=0)-z.mean(axis=0)@decoded.T) if affine else np.zeros(128)
    center=np.asarray(center,dtype='<f2')
    out=bytearray(indices.tobytes()+singles.tobytes()+ratios.tobytes())
    for _,q,s,o in rows:
        out.extend(pack(q,4));out.extend(np.array([s,o],dtype='<f2').tobytes())
    if affine:out.extend(center.tobytes())
    assert len(out)==(7104 if affine else 6848)
    (HERE/selected).write_bytes(out)


def main():
    with np.load(FIX) as f:
        x=f['train'][:,:128].astype(float);w=f['weight'][:128,:128].astype(float)
    rows3=quantize_rows(w,x,3)
    rows4=quantize_rows(w,x,4)
    gains=np.array([r3[0]-r4[0] for r3,r4 in zip(rows3,rows4)])
    order=np.argsort(-gains)
    refined3=response_refit(rows3,w,x)
    refined4=response_refit(rows4,w,x)
    refined_gain=np.array([r3[0]-r4[0] for r3,r4 in zip(refined3,refined4)])
    refined_order=np.argsort(-refined_gain)
    for k,size in ((11,6848),(27,7104)):
        image=control_image(rows3,rows4,order[:k])
        improved=control_image(refined3,refined4,refined_order[:k])
        assert len(image)==len(improved)==size
        (HERE/f'mixed-q3q4-{size}.bin').write_bytes(image)
        (HERE/f'refit-mixed-q3q4-{size}.bin').write_bytes(improved)
    pair_image(x,w,'weighted-pair-6848.bin',False)
    pair_image(x,w,'affine-pair-7104.bin',True)
    pair_image(x,w,'refit-weighted-pair-6848.bin',False,True)
    pair_image(x,w,'refit-affine-pair-7104.bin',True,True)
    print('Fitted eight paid images; run independent replay.py for results.')

if __name__=='__main__':main()
