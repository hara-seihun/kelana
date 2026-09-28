"""Numerical multi-mode cross-pair dual; proposals, not a real-panel certificate."""
import json
from pathlib import Path
import numpy as np
from scipy.optimize import linprog
from scipy.sparse import coo_matrix

ROOT=Path(__file__).resolve().parents[1]
with np.load('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz') as f:
    x=f['train'][:,:128].astype(float);w=f['weight'][:128,:128].astype(float)
with np.load(ROOT/'input-programs/diagonal-certificate.npz') as f:d=f['diagonal'].astype(float)/2**32
h=x.T@x; norm=np.sum((x@w.T)**2);r=h-np.diag(d)
eig,vec=np.linalg.eigh(r)
i,j=np.triu_indices(128,1);n=len(i)
inc=coo_matrix((np.ones(2*n),(np.r_[i,j],np.tile(np.arange(n),2))),shape=(128,n)).tocsr()

def evaluate(m,v,s):
    p=m@v.T;target=w+p/d[None,:];g=target.T@target
    aa=d[i]*g[i,i];bb=d[j]*g[j,j];c=np.sqrt(d[i]*d[j])*g[i,j]
    root=np.hypot(aa-bb,2*c);cost=(aa+bb-root)/2
    lp=linprog(cost/norm,A_ub=inc,b_ub=np.ones(128),A_eq=np.ones((1,n)),b_eq=[32],bounds=(0,None),method='highs')
    if not lp.success:raise RuntimeError(lp.message)
    penalty=np.sum(m*(m@s))/norm
    zi2=np.where(root>0,(1-(aa-bb)/root)/2,.5);zj2=1-zi2
    zij=-np.sign(c)*np.sqrt(zi2*zj2)
    ei=target[:,i]*zi2+target[:,j]*(np.sqrt(d[j]/d[i])*zij)
    ej=target[:,j]*zj2+target[:,i]*(np.sqrt(d[i]/d[j])*zij)
    e=np.zeros_like(w);np.add.at(e.T,i,(ei*lp.x).T);np.add.at(e.T,j,(ej*lp.x).T)
    return float(lp.fun-penalty),e,lp

results=[]
for k in (48,):
    v=vec[:,-k:]; beta=.90*eig[-k:]
    if np.any(beta<=0):continue
    s=np.diag(1/beta)+(v.T/d)@v
    m=np.zeros((128,k));value,e,_=evaluate(m,v,s);first=value
    for iteration in range(24):
        proposed=np.linalg.solve(s,v.T@e.T).T
        direction=proposed-m;advanced=False
        for rate in (1.,.5,.25,.125,.0625,.03125,.015625):
            nv,ne,_=evaluate(m+rate*direction,v,s)
            if nv>value+1e-12:
                m,value,e=m+rate*direction,nv,ne;advanced=True;break
        if not advanced:break
    print(k,first,value,iteration,flush=True)
    results.append({'rank':k,'initial':first,'best':value,'iterations':iteration})
    vv=np.rint(v*2**32).astype('int64'); bb=np.floor(beta*2**24).astype('int64'); mm=np.rint(m*2**32).astype('int64')
    dv=vv.astype(float)/2**32; db=bb.astype(float)/2**24
    residual=h-np.diag(d)-(dv*db)@dv.T
    ll=np.linalg.cholesky(residual-5e-5*np.eye(128))
    lv=np.rint(ll*2**40).astype('int64')
    _,_,certlp=evaluate(mm.astype(float)/2**32,dv,np.diag(1/db)+(dv.T/d)@dv)
    vertex=np.minimum(0,np.floor((certlp.ineqlin.marginals-1e-8)*2**50)).astype('int64')
    cardinal=int(np.floor((certlp.eqlin.marginals[0]-1e-7)*2**50))
    np.savez_compressed(Path(__file__).with_name('spectral-certificate.npz'),vector=vv,beta=bb,dual_output=mm,factor=lv,vertex=vertex,cardinality=np.array([cardinal],dtype='int64'))
Path(__file__).with_name('spectral-results.json').write_text(json.dumps(results,indent=2)+'\n')
