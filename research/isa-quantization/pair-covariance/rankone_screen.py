"""Rank-one covariance-aware matching bound for all freely weighted disjoint pairs."""
import argparse
import json
from pathlib import Path
import numpy as np
from scipy.optimize import linprog
from scipy.sparse import coo_matrix

HERE=Path(__file__).parent
parser=argparse.ArgumentParser();parser.add_argument('--signed-certificate',type=Path,default=HERE.parent/'input-programs'/'diagonal-certificate.npz');args=parser.parse_args()
with np.load('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz') as f:
    x=f['train'][:,:128].astype(float);w=f['weight'][:128,:128].astype(float)
with np.load(args.signed_certificate) as f:d0=f['diagonal'].astype(float)/2**32
h=x.T@x;norm=float(np.sum((x@w.T)**2));I,J=np.triu_indices(128,1);n=len(I)
inc=coo_matrix((np.ones(2*n),(np.concatenate((I,J)),np.tile(np.arange(n),2))),shape=(128,n)).tocsr()


def bound(d,v,beta,m):
    shift=v/d
    target=w+np.outer(m,shift)
    gram=target.T@target
    a=d[I]*gram[I,I];b=d[J]*gram[J,J]
    root=np.sqrt((a-b)**2+4*d[I]*d[J]*gram[I,J]**2)
    costs=(a+b-root)/2
    lp=linprog(costs/norm,A_ub=inc,b_ub=np.ones(128),A_eq=np.ones((1,n)),b_eq=[32],bounds=(0,None),method='highs')
    if not lp.success:raise RuntimeError(lp.message)
    penalty=(np.dot(v*v,1/d)+1/beta)*np.dot(m,m)
    value=float(lp.fun-penalty/norm)
    zi2=np.where(root>0,(1-(a-b)/root)/2,.5)
    zj2=1-zi2
    sign=np.sign(gram[I,J]);zij=-sign*np.sqrt(zi2*zj2)
    # The smaller right-singular vector has squared components zi2,zj2.
    # The residual after best rank-one fit is B z z^T; reconstruct its two
    # columns without choosing a sign for z.
    u=d[I]*zi2+0.0
    mii=zi2; mij=zij;mjj=zj2
    e_i=target[:,I]*mii+target[:,J]*(np.sqrt(d[J]/d[I])*mij)
    e_j=target[:,J]*mjj+target[:,I]*(np.sqrt(d[I]/d[J])*mij)
    gradient=2*np.sum((v[I][None,:]*e_i+v[J][None,:]*e_j)*lp.x[None,:],axis=1)
    gradient-=2*(np.sum(v*v/d)+1/beta)*m
    return value,gradient,lp

report=[]
for scale in (.7,.85,.95):
    d=d0*scale;residual=h-np.diag(d)
    _,directions=np.linalg.eigh(residual)
    v=directions[:,-1]
    beta=.95/float(v@np.linalg.solve(residual,v))
    m=np.zeros(128)
    value,gradient,_=bound(d,v,beta,m)
    first=value
    for step in range(18):
        direction=gradient/max(np.linalg.norm(gradient),1e-20)
        advanced=False
        for rate in (10,5,2,1,.5,.25,.125,.0625):
            candidate=m+rate*direction
            newvalue,newgradient,_=bound(d,v,beta,candidate)
            if newvalue>value+1e-12:
                m,value,gradient=candidate,newvalue,newgradient
                advanced=True;break
        if not advanced:break
    report.append(dict(scale=scale,beta=beta,zero_m=first,best=value,iterations=step,
                       m_norm=float(np.linalg.norm(m)),v=v.tolist(),m=m.tolist()))
    print(scale,'zero',first,'best',value,'beta',beta,'steps',step,flush=True)
(HERE/'rankone-results.json').write_text(json.dumps(report,indent=2)+'\n')
