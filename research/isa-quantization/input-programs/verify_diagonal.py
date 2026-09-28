"""Replay the diagonal PSD and matching-dual certificate with exact integers.

The source BF16/FP32 arrays and decoded FP16 Q4 coefficients are dyadic. The
floating optimizer and Cholesky only propose integers; no solver status or
floating eigenvalue enters these checks.
"""
import hashlib
import json
import runpy
from pathlib import Path
import numpy as np

HERE=Path(__file__).parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
C=HERE/'diagonal-certificate.npz'
Q4=HERE.parent/'producer-screen'/'affine-q4.bin'

def exact_gram(x):
    hi=x>>16
    lo=x-(hi<<16)
    limit=np.iinfo(np.int64).max
    n=len(x)
    mh=max(abs(int(hi.min())),abs(int(hi.max())))
    ml=max(abs(int(lo.min())),abs(int(lo.max())))
    assert max(n*mh*mh,n*mh*ml,n*ml*ml)<=limit, 'int64 Gram limb product may overflow'
    hh=hi.T@hi
    hl=hi.T@lo
    lh=lo.T@hi
    ll=lo.T@lo
    return hh.astype(object)*2**32 + (hl.astype(object)+lh.astype(object))*2**16 + ll.astype(object)

def main():
    with np.load(FIX) as f:
        x=f['train'][:,:128].astype('float64'); w=f['weight'][:128,:128].astype('float64')
    with np.load(C) as f:
        d=f['diagonal']; L=f['factor']; vertex=f['dual_vertex']; cardinal=int(f['dual_cardinality'][0])
    assert len(d)==len(vertex)==128 and L.shape==(128,128)
    assert np.all(d>0) and np.all(vertex<=0)
    assert np.array_equal(x*2**27,np.rint(x*2**27))
    assert np.array_equal(w*2**28,np.rint(w*2**28))
    xscaled=np.rint(x*2**27)
    wscaled=np.rint(w*2**28)
    limit=np.iinfo(np.int64).max
    assert np.all(np.isfinite(xscaled)) and np.all(np.isfinite(wscaled))
    assert np.max(np.abs(xscaled))<limit and np.max(np.abs(wscaled))<limit, 'scaled dyadics do not fit int64'
    xi=xscaled.astype('int64')
    wi=wscaled.astype('int64')
    h=exact_gram(xi)
    g=wi.astype(object).T@wi.astype(object)
    norm=int(np.sum(h*g))
    assert norm>0
    # Scale all entries to 2^80: H/2^54, d/2^32, L/2^40.
    residual=h*2**26 - np.diag(d.astype(object)*2**48) - L.astype(object)@L.astype(object).T
    margins=[]
    for row in range(128):
        margin=int(residual[row,row])-sum(abs(int(residual[row,col])) for col in range(128) if col!=row)
        margins.append(margin)
    assert min(margins)>0, 'strict diagonal dominance of exact PSD remainder failed'
    minslack=None
    for i in range(128):
        for j in range(i+1,128):
            plus=int(g[i,i]+g[j,j]+2*g[i,j]); minus=int(g[i,i]+g[j,j]-2*g[i,j])
            numerator=int(d[i])*int(d[j])*min(plus,minus)*2**22
            denominator=(int(d[i])+int(d[j]))*norm
            dual=int(vertex[i])+int(vertex[j])+cardinal
            slack=numerator*2**50-dual*denominator
            if minslack is None or slack<minslack: minslack=slack
            assert slack>=0, (i,j,slack)
    q4=runpy.run_path(str(HERE.parent/'producer-screen'/'screen.py'))['decode_q4'](Q4.read_bytes())
    assert np.array_equal(q4*2**28,np.rint(q4*2**28))
    e=wi.astype(object)-np.rint(q4*2**28).astype('int64').astype(object)
    error=int(np.sum((e.T@e)*h))
    dualsum=sum(int(v) for v in vertex)+32*cardinal
    assert dualsum*norm > error*2**50
    result=dict(fixture_sha256=hashlib.sha256(FIX.read_bytes()).hexdigest(),
                q4_sha256=hashlib.sha256(Q4.read_bytes()).hexdigest(),
                certificate_sha256=hashlib.sha256(C.read_bytes()).hexdigest(),
                exact_psd_min_diagonal_dominance_numerator=str(min(margins)),
                exact_matching_min_slack_numerator=str(minslack),
                exact_dual_numerator=str(dualsum),exact_dual_denominator=str(2**50),
                exact_q4_error_numerator=str(error),exact_response_norm_numerator=str(norm),
                proven_dual_floor=float(dualsum/2**50),exact_q4_error=float(error/norm),
                floor_minus_q4=float(dualsum/2**50-error/norm))
    (HERE/'verified-diagonal.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__': main()
