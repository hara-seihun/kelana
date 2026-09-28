"""Finite cutting-plane outer relaxation of joint diagonal/matching certificate optimum."""
import argparse
import json
from pathlib import Path
import numpy as np
from scipy.optimize import linprog
from scipy.sparse import csr_matrix, vstack

HERE=Path(__file__).parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
parser=argparse.ArgumentParser()
parser.add_argument('--certificate',type=Path,default=HERE.parent/'input-programs'/'diagonal-certificate.npz')
CERT=parser.parse_args().certificate
with np.load(FIX) as f:
    x=f['train'][:,:128].astype('float64');w=f['weight'][:128,:128].astype('float64')
with np.load(CERT) as f:d0=f['diagonal'].astype(float)/2**32
h=x.T@x; g=w.T@w; norm=float(np.sum((x@w.T)**2)); I,J=np.triu_indices(128,1); n=len(I)
N=257
c=np.zeros(N);c[128:256]=-1;c[256]=-32
bounds=[(0,float(h[k,k])) for k in range(128)]+[(None,0)]*128+[(None,None)]
rows=[];rhs=[];kind=[]

def add_tangents(d,indices):
    a=d[I[indices]]*g[I[indices],I[indices]]
    b=d[J[indices]]*g[J[indices],J[indices]]
    root=np.sqrt((a-b)**2+4*d[I[indices]]*d[J[indices]]*g[I[indices],J[indices]]**2)
    small=(a+b-root)/2
    p=np.where(root>1e-20,(1-(a-b)/root)/2,.5)
    gi=small*p/d[I[indices]]/norm
    gj=small*(1-p)/d[J[indices]]/norm
    for t,k in enumerate(indices):
        r=np.zeros(N);r[I[k]]=-gi[t];r[J[k]]=-gj[t];r[128+I[k]]=1;r[128+J[k]]=1;r[256]=1
        off=np.sqrt(d[I[k]]*d[J[k]])*g[I[k],J[k]]
        big=(a[t]+b[t]+root[t])/2
        if abs(off)<1e-25: ratio=0. if a[t]>=b[t] else 1e12
        else: ratio=(big-a[t])/off*np.sqrt(d[I[k]]/d[J[k]])
        rows.append(r);rhs.append(0.);kind.append(('edge',int(k),float(d[I[k]]),float(d[J[k]]),float(ratio)))

def add_psd(v):
    r=np.zeros(N);r[:128]=v*v
    rows.append(r);rhs.append(float(v@h@v));kind.append(('psd',v.copy()))

add_tangents(d0,np.arange(n))
for k in range(128):add_psd(np.eye(128)[k])
log=[]
for iteration in range(26):
    mat=csr_matrix(np.stack(rows));
    lp=linprog(c,A_ub=mat,b_ub=np.array(rhs),bounds=bounds,method='highs',options={'time_limit':15})
    if not lp.success:raise RuntimeError(lp.message)
    d=lp.x[:128]; u=lp.x[128:256]; cardinal=lp.x[256]
    eigen,vec=np.linalg.eigh(h-np.diag(d));
    neg=np.where(eigen<-1e-7)[0]
    a=d[I]*g[I,I];b=d[J]*g[J,J]
    actual=(a+b-np.sqrt((a-b)**2+4*d[I]*d[J]*g[I,J]**2))/2/norm
    violation=u[I]+u[J]+cardinal-actual
    bad=np.flatnonzero(violation>1e-9)
    log.append(dict(iter=iteration,upper=float(-lp.fun),negative_eigen_count=len(neg),
                    min_eigen=float(eigen[0]),bad_edges=len(bad),worst_edge=float(np.max(violation))))
    print(log[-1],flush=True)
    if -lp.fun<0.00517:
        active=np.flatnonzero(-lp.ineqlin.marginals>1e-9)
        edge_records=[];psd_records=[]
        for idx in active:
            record=kind[idx]
            if record[0]=='edge': edge_records.append([*record[1:],float(-lp.ineqlin.marginals[idx])])
            else: psd_records.append([record[1].tolist(),float(-lp.ineqlin.marginals[idx])])
        np.savez_compressed(HERE/'outer-proposal.npz',edge_records=np.array(edge_records),
                            psd_vectors=np.array([r[0] for r in psd_records]),
                            psd_weights=np.array([r[1] for r in psd_records]),
                            upper=float(-lp.fun))
    if not len(neg) and not len(bad):break
    if len(neg):
        for k in neg[:min(len(neg),8)]:add_psd(vec[:,k])
    if len(bad):add_tangents(np.maximum(d,1e-7),bad[np.argsort(violation[bad])[-min(len(bad),256):]])
HERE.joinpath('outer-results.json').write_text(json.dumps(log,indent=2)+'\n')
