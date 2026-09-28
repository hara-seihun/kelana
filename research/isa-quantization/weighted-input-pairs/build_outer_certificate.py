"""Round a cutting-plane LP dual into a finite exact upper-bound witness."""
import argparse
from fractions import Fraction as F
from pathlib import Path
import runpy
import numpy as np

HERE=Path(__file__).parent
parser=argparse.ArgumentParser()
parser.add_argument('--gram-source',type=Path,default=HERE.parent/'input-programs'/'verify_diagonal.py')
args=parser.parse_args()
PROPOSAL=HERE/'outer-proposal.npz'
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
with np.load(PROPOSAL) as data:
    records=data['edge_records']; psd=data['psd_vectors']; weights=data['psd_weights']
I,J=np.triu_indices(128,1)
qe=np.floor(records[:,4]*2**40).astype('int64')
deg=np.zeros(128,dtype='int64')
for k,r in enumerate(records):
    a,b=int(I[int(r[0])]),int(J[int(r[0])]);deg[a]+=qe[k];deg[b]+=qe[k]
deficit=32*2**40-int(sum(int(q) for q in qe))
choices=[k for k,r in enumerate(records) if deg[I[int(r[0])]]+deficit<=2**40 and deg[J[int(r[0])]]+deficit<=2**40]
assert choices
qe[choices[0]]+=deficit
anchor=np.rint(records[:,1:3]*2**24).astype('int64')
ratio=np.rint(records[:,3]*2**24).astype('int64')
v=np.rint(psd*2**24).astype('int64')
p=np.ceil(weights*2**50).astype('int64')
with np.load(FIX) as f:
    x=f['train'][:,:128].astype('float64');w=f['weight'][:128,:128].astype('float64')
assert np.array_equal(x*2**27,np.rint(x*2**27))
assert np.array_equal(w*2**28,np.rint(w*2**28))
wi=np.rint(w*2**28).astype('int64')
# Reuse only the exact integer Gram routine; the certificate checker recomputes
# it independently, including input bounds and final objective comparison.
xi=np.rint(x*2**27).astype('int64')
h=runpy.run_path(str(args.gram_source))['exact_gram'](xi)
g=wi.astype(object).T@wi.astype(object)
norm=int(np.sum(h*g))
slopes=[F(0)]*128
for k,r in enumerate(records):
    edge=int(r[0]);i,j=int(I[edge]),int(J[edge]);d1=F(int(anchor[k,0]),2**24);d2=F(int(anchor[k,1]),2**24);t=F(int(ratio[k]),2**24)
    a=F(int(g[i,i]),2**56);b=F(int(g[j,j]),2**56);cross=F(int(g[i,j]),2**56)
    den=d1+t*t*d2
    numer=d1*d1*a+2*t*d1*d2*cross+t*t*d2*d2*b
    gi=(a-(2*d1*a+2*t*d2*cross)/den+numer/den**2)*F(2**110,norm)
    gj=(b-(2*t*d1*cross+2*t*t*d2*b)/den+t*t*numer/den**2)*F(2**110,norm)
    q=F(int(qe[k]),2**40);slopes[i]+=q*gi;slopes[j]+=q*gj
for k in range(len(p)):
    for i in range(128):slopes[i]-=F(int(p[k])*int(v[k,i])**2,2**98)
identity=np.array([max(0,(s.numerator*2**55+s.denominator-1)//s.denominator)+1 for s in slopes],dtype='int64')
np.savez_compressed(HERE/'outer-certificate.npz',edge_ids=records[:,0].astype('int64'),
                    anchors=anchor,ratios=ratio,edge_weights=qe,
                    psd_vectors=v,psd_weights=p,identity_weights=identity)
print('edge count',len(records),'psd count',len(p),'identity nonzero',int(np.count_nonzero(identity)))
