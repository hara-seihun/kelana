"""Output-orthogonal, separately covariance-minorized lower bounds for weighted input pairs."""
import argparse
import json
from pathlib import Path
import numpy as np
from scipy.optimize import linprog
from scipy.sparse import coo_matrix

HERE=Path(__file__).parent
p=argparse.ArgumentParser()
p.add_argument('--signed-certificate',type=Path,default=HERE.parent/'input-programs'/'diagonal-certificate.npz')
a=p.parse_args()
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
with np.load(FIX) as f:
    x=f['train'][:,:128].astype('float64');w=f['weight'][:128,:128].astype('float64')
with np.load(a.signed_certificate) as f:d0=f['diagonal'].astype(float)/2**32
h=x.T@x;hinv=np.linalg.inv(h);norm=float(np.sum((x@w.T)**2));i,j=np.triu_indices(128,1);n=len(i)
inc=coo_matrix((np.ones(2*n),(np.concatenate((i,j)),np.tile(np.arange(n),2))),shape=(128,n)).tocsr()

def evaluate(ray,g):
    ray=ray/np.max(ray)
    gram=np.sqrt(ray)[:,None]*hinv*np.sqrt(ray)[None,:]
    eig,v=np.linalg.eigh(gram)
    d=ray/eig[-1]
    alpha=d[i]*g[i,i];beta=d[j]*g[j,j]
    root=np.sqrt((alpha-beta)**2+4*d[i]*d[j]*g[i,j]**2)
    cost=(alpha+beta-root)/2/norm
    lp=linprog(cost,A_ub=inc,b_ub=np.ones(128),A_eq=np.ones((1,n)),b_eq=[32],bounds=(0,None),method='highs',options={'time_limit':15})
    if not lp.success:raise RuntimeError(lp.message)
    return d,lp,v[:,-1],root,cost

def optimize(g):
    ray=d0.copy();d,lp,v,root,cost=evaluate(ray,g)
    initial=float(lp.fun)
    for step_index in range(40):
        alpha=d[i]*g[i,i];beta=d[j]*g[j,j]
        small=cost*norm
        u2=np.where(root>0,(1-(alpha-beta)/root)/2,.5)
        gradient_d=np.zeros(128)
        np.add.at(gradient_d,i,lp.x*small*u2/d[i]/norm)
        np.add.at(gradient_d,j,lp.x*small*(1-u2)/d[j]/norm)
        gradient=(d*gradient_d-lp.fun*v*v)/lp.fun
        gradient-=gradient.mean();gradient/=max(np.max(np.abs(gradient)),1e-12)
        advanced=False
        for scale in (.7,.35,.175,.0875,.04375,.02,.01):
            candidate_ray=ray*np.exp(scale*gradient)
            cd,clp,cv,croot,ccost=evaluate(candidate_ray,g)
            if clp.fun>lp.fun+1e-12:
                ray,d,lp,v,root,cost=candidate_ray,cd,clp,cv,croot,ccost
                advanced=True;break
        if not advanced:break
    return dict(initial=initial,best=float(lp.fun),steps=step_index,diagonal=d.tolist())

splits={'contiguous':[np.arange(64),np.arange(64,128)],
        'interleaved':[np.arange(0,128,2),np.arange(1,128,2)]}
result={}
for label,groups in splits.items():
    parts=[optimize(w[rows].T@w[rows]) for rows in groups]
    result[label]=dict(parts=parts,initial=sum(p['initial'] for p in parts),best=sum(p['best'] for p in parts))
    print(label,result[label]['initial'],result[label]['best'],flush=True)
(HERE/'split-results.json').write_text(json.dumps(result,indent=2)+'\n')
