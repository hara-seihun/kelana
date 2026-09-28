"""Exact integer/rational replay of a universal free-ratio matching floor."""
import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import runpy

import numpy as np

HERE=Path(__file__).parent
INPUT=HERE.parent/'input-programs'
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
parser=argparse.ArgumentParser()
parser.add_argument('--signed-certificate',type=Path,default=INPUT/'diagonal-certificate.npz')
parser.add_argument('--signed-verifier',type=Path,default=INPUT/'verify_diagonal.py')
parser.add_argument('--signed-receipt',type=Path,default=INPUT/'verified-diagonal.json')
parser.add_argument('--q4-image',type=Path,default=HERE.parent/'producer-screen'/'affine-q4.bin')
args=parser.parse_args()

with np.load(args.signed_certificate) as f: d=f['diagonal']; L=f['factor']
with np.load(HERE/'weighted-dual.npz') as f: vertex=f['vertex']; cardinal=int(f['cardinality'][0])
assert len(d)==len(vertex)==128 and L.shape==(128,128) and np.all(vertex<=0)
with np.load(FIX) as f:
    x=f['train'][:,:128].astype('float64'); w=f['weight'][:128,:128].astype('float64')
assert np.all(np.isfinite(x)) and np.all(np.isfinite(w))
assert np.array_equal(x*2**27,np.rint(x*2**27))
assert np.array_equal(w*2**28,np.rint(w*2**28))
limit=np.iinfo(np.int64).max
assert np.max(np.abs(x*2**27))<limit and np.max(np.abs(w*2**28))<limit
xi=np.rint(x*2**27).astype('int64');wi=np.rint(w*2**28).astype('int64')
h=runpy.run_path(str(args.signed_verifier))['exact_gram'](xi)
g=wi.astype(object).T@wi.astype(object)
norm=int(np.sum(h*g));assert norm>0
residual=h*2**26-np.diag(d.astype(object)*2**48)-L.astype(object)@L.astype(object).T
assert all(int(residual[k,k])>sum(abs(int(residual[k,m])) for m in range(128) if m!=k)
           for k in range(128)), 'signed certificate diagonal PSD minorant failed'
response_norm=Fraction(norm,2**110)
smallest_margin=None
for i in range(128):
    di=Fraction(int(d[i]),2**32)
    for j in range(i+1,128):
        dj=Fraction(int(d[j]),2**32)
        price=int(vertex[i])+int(vertex[j])+cardinal
        if price<=0:continue
        threshold=Fraction(price,2**50)*response_norm
        a=di*Fraction(int(g[i,i]),2**56)-threshold
        b=dj*Fraction(int(g[j,j]),2**56)-threshold
        correlation=di*dj*Fraction(int(g[i,j])**2,2**112)
        assert a>=0 and b>=0 and a*b>=correlation,(i,j)
        slack=a*b-correlation
        if smallest_margin is None or slack<smallest_margin:smallest_margin=slack
bound=Fraction(sum(int(z) for z in vertex)+32*cardinal,2**50)
# The prior exact checker establishes the Q4 rational response from the same
# fixture/image; recheck its named receipt and certificate hashes.
receipt=json.loads(args.signed_receipt.read_text())
assert receipt['fixture_sha256']==hashlib.sha256(FIX.read_bytes()).hexdigest()
assert receipt['certificate_sha256']==hashlib.sha256(args.signed_certificate.read_bytes()).hexdigest()
assert receipt['q4_sha256']==hashlib.sha256(args.q4_image.read_bytes()).hexdigest()
q4=Fraction(int(receipt['exact_q4_error_numerator']),int(receipt['exact_response_norm_numerator']))
assert 0<bound<q4
result=dict(signed_certificate_sha256=receipt['certificate_sha256'],
            dual_sha256=hashlib.sha256((HERE/'weighted-dual.npz').read_bytes()).hexdigest(),
            dual_numerator=str(bound.numerator),dual_denominator=str(bound.denominator),
            exact_lower=float(bound),exact_q4=float(q4),gap_to_q4=float(q4-bound),
            min_cone_slack_numerator=str(smallest_margin.numerator),
            min_cone_slack_denominator=str(smallest_margin.denominator))
(HERE/'verified-weighted.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
