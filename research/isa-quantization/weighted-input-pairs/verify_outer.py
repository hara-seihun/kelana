"""Exact rational certificate-class upper bound: no optimizer or float solver trusted."""
import argparse
from fractions import Fraction as F
import hashlib
import json
from pathlib import Path
import runpy
import numpy as np

HERE=Path(__file__).parent
INPUT=HERE.parent/'input-programs'
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
p=argparse.ArgumentParser()
p.add_argument('--gram-source',type=Path,default=INPUT/'verify_diagonal.py')
p.add_argument('--q4-image',type=Path,default=HERE.parent/'producer-screen'/'affine-q4.bin')
p.add_argument('--q4-decoder',type=Path,default=HERE.parent/'producer-screen'/'screen.py')
a=p.parse_args()
with np.load(HERE/'outer-certificate.npz') as f:
    edges=f['edge_ids'];anchor=f['anchors'];ratio=f['ratios'];q=f['edge_weights'];v=f['psd_vectors'];psd=f['psd_weights'];ident=f['identity_weights']
assert len(edges)==len(q)==len(anchor)==len(ratio)
assert v.shape==(len(psd),128) and ident.shape==(128,)
assert all(int(t)>0 for t in q) and all(int(t)>=0 for t in psd) and all(int(t)>=0 for t in ident)
with np.load(FIX) as f:
    x=f['train'][:,:128].astype('float64');w=f['weight'][:128,:128].astype('float64')
limit=np.iinfo(np.int64).max
assert np.all(np.isfinite(x)) and np.all(np.isfinite(w))
assert np.array_equal(x*2**27,np.rint(x*2**27)) and np.array_equal(w*2**28,np.rint(w*2**28))
assert np.max(np.abs(x*2**27))<limit and np.max(np.abs(w*2**28))<limit
xi=np.rint(x*2**27).astype('int64');wi=np.rint(w*2**28).astype('int64')
h=runpy.run_path(str(a.gram_source))['exact_gram'](xi)
g=wi.astype(object).T@wi.astype(object)
norm=int(np.sum(h*g));assert norm>0
I,J=np.triu_indices(128,1)
deg=[0]*128;gradient=[F(0)]*128
for k,edge in enumerate(edges):
    index=int(edge);i,j=int(I[index]),int(J[index]);Q=int(q[k]);deg[i]+=Q;deg[j]+=Q
    di=F(int(anchor[k,0]),2**24);dj=F(int(anchor[k,1]),2**24);t=F(int(ratio[k]),2**24)
    assert di>0 and dj>0
    ai=F(int(g[i,i]),2**56);aj=F(int(g[j,j]),2**56);cross=F(int(g[i,j]),2**56)
    denominator=di+t*t*dj
    numerator=di*di*ai+2*t*di*dj*cross+t*t*dj*dj*aj
    gi=(ai-(2*di*ai+2*t*dj*cross)/denominator+numerator/denominator**2)*F(2**110,norm)
    gj=(aj-(2*t*di*cross+2*t*t*dj*aj)/denominator+t*t*numerator/denominator**2)*F(2**110,norm)
    gradient[i]+=F(Q,2**40)*gi;gradient[j]+=F(Q,2**40)*gj
assert sum(int(z) for z in q)==32*2**40
assert max(deg)<=2**40
bound=F(0)
for k,weight in enumerate(psd):
    vector=v[k].astype(object)
    energy=sum(int(vector[i])*int(h[i,j])*int(vector[j]) for i in range(128) for j in range(128))
    assert energy>=0
    bound+=F(int(weight)*energy,2**152) # weight 2^-50, v² 2^-48, H 2^-54
    for i in range(128):gradient[i]-=F(int(weight)*int(v[k,i])**2,2**98)
for i,weight in enumerate(ident):
    gradient[i]-=F(int(weight),2**55)
    bound+=F(int(weight)*int(h[i,i]),2**109)
assert all(t<=0 for t in gradient), 'weighted dual has an uncovered d coefficient'
q4=runpy.run_path(str(a.q4_decoder))['decode_q4'](a.q4_image.read_bytes())
assert np.array_equal(q4*2**28,np.rint(q4*2**28))
e=wi.astype(object)-np.rint(q4*2**28).astype('int64').astype(object)
q4error=F(int(np.sum((e.T@e)*h)),norm)
assert bound<q4error, 'outer bound fails to exclude the Q4 threshold'
receipt=dict(fixture_sha256=hashlib.sha256(FIX.read_bytes()).hexdigest(),
             q4_sha256=hashlib.sha256(a.q4_image.read_bytes()).hexdigest(),
             certificate_sha256=hashlib.sha256((HERE/'outer-certificate.npz').read_bytes()).hexdigest(),
             active_edge_cuts=len(edges),active_psd_cuts=len(psd),
             max_vertex_degree_numerator=max(deg),degree_denominator=2**40,
             smallest_stationarity_slack_numerator=str(min(-t for t in gradient).numerator),
             smallest_stationarity_slack_denominator=str(min(-t for t in gradient).denominator),
             upper=float(bound),q4_error=float(q4error),strict_margin=float(q4error-bound),
             exact_bound_numerator=str(bound.numerator),exact_bound_denominator=str(bound.denominator),
             exact_q4_numerator=str(q4error.numerator),exact_q4_denominator=str(q4error.denominator))
(HERE/'verified-outer.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:receipt[k] for k in ('upper','q4_error','strict_margin','active_edge_cuts','active_psd_cuts')},indent=2))
