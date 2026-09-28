"""Integer replay of a full-covariance weighted-pair exclusion certificate.

The numerical spectral optimizer is not imported. Every source matrix, cone,
PSD remainder, matching dual and final comparison is checked as integers.
"""
import hashlib
import json
import runpy
from fractions import Fraction
from pathlib import Path
import numpy as np
from importlib.util import spec_from_file_location, module_from_spec

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
CERT=HERE/'spectral-certificate.npz'
BASE=ROOT/'input-programs/diagonal-certificate.npz'
Q4=ROOT/'producer-screen/affine-q4.bin'
spec=spec_from_file_location('exact_signed',ROOT/'input-programs/verify_diagonal.py')
mod=module_from_spec(spec);spec.loader.exec_module(mod)


def integer_field(fields,name,shape):
    value=fields[name]
    assert value.shape==shape and value.dtype.kind in 'iu',(name,value.shape,str(value.dtype))
    return value.astype(object)


def main():
    assert hashlib.sha256(FIX.read_bytes()).hexdigest() == '389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    assert hashlib.sha256(Q4.read_bytes()).hexdigest() == '8c4b03a9696bee7f0bd80c344f2996a4d6247651ca11f671d07e0c27a86f82c6'
    with np.load(FIX) as f:
        x=f['train'][:,:128].astype('float64');w=f['weight'][:128,:128].astype('float64')
    assert x.shape==(2048,128) and w.shape==(128,128)
    assert np.array_equal(x*2**27,np.rint(x*2**27))
    assert np.array_equal(w*2**28,np.rint(w*2**28))
    xs=np.rint(x*2**27); ws=np.rint(w*2**28)
    limit=np.iinfo(np.int64).max
    assert np.all(np.isfinite(xs)) and np.all(np.isfinite(ws))
    assert np.max(np.abs(xs))<limit and np.max(np.abs(ws))<limit
    xi=xs.astype('int64'); wi=ws.astype('int64')
    h=mod.exact_gram(xi); g=wi.astype(object).T@wi.astype(object)
    norm=int(np.sum(h*g)); assert norm>0
    with np.load(BASE) as f:d=integer_field(f,'diagonal',(128,))
    with np.load(CERT) as f:
        v=integer_field(f,'vector',(128,48));beta=integer_field(f,'beta',(48,))
        m=integer_field(f,'dual_output',(128,48));l=integer_field(f,'factor',(128,128))
        vertex=integer_field(f,'vertex',(128,));card=int(integer_field(f,'cardinality',(1,))[0])
    assert all(int(t)>0 for t in d) and all(int(t)>0 for t in beta)
    assert all(int(t)<=0 for t in vertex)
    assert np.all(np.triu(l,1)==0)
    # Common denominator 2^88 for H, D, V diag(beta) V^T and LL^T.
    residual=h*2**34-np.diag(d*2**56)-(v*beta)@v.T-(l@l.T)*2**8
    margins=[]
    for i in range(128):
        margins.append(int(residual[i,i])-sum(abs(int(residual[i,j])) for j in range(128) if i!=j))
    assert min(margins)>0, ('PSD remainder',min(margins))
    p=m@v.T
    # z_i=d_i*w_i+p_i, scaled by 2^64. Source d_i/2^32,
    # teacher w_i/2^28, V and M each /2^32.
    z=wi.astype(object)*d[None,:]*16+p
    zg=z.T@z
    mincone=None
    for i in range(128):
        for j in range(i+1,128):
            dual=int(vertex[i])+int(vertex[j])+card
            ai=int(zg[i,i])*2**64-dual*norm*int(d[i])
            aj=int(zg[j,j])*2**64-dual*norm*int(d[j])
            slack=ai*aj-int(zg[i,j])**2*2**128
            assert ai>=0 and aj>=0 and slack>=0,(i,j,ai,aj,slack)
            if mincone is None or slack<mincone:mincone=slack
    # The shared-mode square inequality pays this penalty for any V;
    # neither column independence nor a pseudoinverse identity is required.
    penalty=sum((Fraction(sum(int(p[o,i])**2 for o in range(128)),int(d[i])*2**96) for i in range(128)),Fraction(0))
    penalty+=sum((Fraction(sum(int(m[o,k])**2 for o in range(128)),int(beta[k])*2**40) for k in range(48)),Fraction(0))
    q4=runpy.run_path(str(ROOT/'producer-screen/screen.py'))['decode_q4'](Q4.read_bytes())
    qs=np.rint(q4*2**28)
    assert np.array_equal(q4*2**28,qs) and np.all(np.isfinite(qs))
    assert np.max(np.abs(qs))<limit
    e=wi.astype(object)-qs.astype('int64').astype(object)
    error=int(np.sum((e.T@e)*h))
    totaldual=sum(int(t) for t in vertex)+32*card
    floor=Fraction(totaldual,2**50)-penalty*Fraction(2**110,norm)
    baseline=Fraction(error,norm)
    assert floor>baseline,('certificate does not beat Q4',float(floor),float(baseline))
    receipt={'fixture_sha256':hashlib.sha256(FIX.read_bytes()).hexdigest(),
             'certificate_sha256':hashlib.sha256(CERT.read_bytes()).hexdigest(),
             'baseline_sha256':hashlib.sha256(Q4.read_bytes()).hexdigest(),
             'diagonal_source_sha256':hashlib.sha256(BASE.read_bytes()).hexdigest(),
             'universal_floor_rational':str(floor),'q4_error_rational':str(baseline),
             'strict_margin_rational':str(floor-baseline),
             'psd_min_diagonal_dominance_numerator':str(min(margins)),
             'min_cone_determinant_slack_numerator':str(mincone),
             'universal_weighted_pair_floor':float(floor),
             'exact_q4_error':float(baseline),'strict_margin':float(floor-baseline)}
    (HERE/'verified.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({key:value for key,value in receipt.items() if not key.endswith('_rational')},indent=2))

if __name__=='__main__':main()
