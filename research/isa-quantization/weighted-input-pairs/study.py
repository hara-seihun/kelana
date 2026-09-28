"""Weighted two-coordinate carrier screen on the real Qwen subprojection."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.optimize import linprog
from scipy.sparse import coo_matrix

HERE=Path(__file__).parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
DEFAULT_CERT=HERE.parent/'input-programs'/'diagonal-certificate.npz'
parser=argparse.ArgumentParser()
parser.add_argument('--certificate',type=Path,default=DEFAULT_CERT)
CERT=parser.parse_args().certificate

def error(actual,target): return float(np.sum((actual-target)**2)/np.sum(target**2))

def alphabet_cost(d,g,i,j,ratios,norm):
    a=d[i]*g[i,i]; b=d[j]*g[j,j]
    costs=[]
    for ratio in ratios:
        gain=(d[i]**2*g[i,i]+2*ratio*d[i]*d[j]*g[i,j]+ratio**2*d[j]**2*g[j,j])/(d[i]+ratio**2*d[j])
        costs.append((a+b-gain)/norm)
    return np.min(np.stack(costs),axis=0)


def matching_floor(edge_cost,inc,n):
    lp=linprog(edge_cost,A_ub=inc,b_ub=np.ones(128),A_eq=np.ones((1,n)),b_eq=[32],bounds=(0,None),method='highs',options={'time_limit':15})
    if not lp.success: raise RuntimeError(lp.message)
    return float(lp.fun)


def fit_pairs(x,v,w,pairs):
    t=np.zeros((128,96)); paired=set()
    for k,(i,j,ratio) in enumerate(pairs,64): t[i,k]=1; t[j,k]=ratio; paired.update((i,j))
    for k,i in enumerate(i for i in range(128) if i not in paired): t[i,k]=1
    y=x@w.T; z=x@t; reader=np.linalg.lstsq(z,y,rcond=None)[0]
    return error(z@reader,y),error(v@t@reader,v@w.T)

with np.load(FIX) as f:
    x=f['train'][:,:128].astype('float64');v=f['validation'][:,:128].astype('float64');w=f['weight'][:128,:128].astype('float64')
with np.load(CERT) as f: starting_d=f['diagonal'].astype('float64')/2**32
h=x.T@x; inv=np.linalg.inv(h);g=w.T@w; y=x@w.T; norm=float(np.sum(y*y))
i,j=np.triu_indices(128,1); n=len(i)
inc=coo_matrix((np.ones(2*n),(np.concatenate((i,j)),np.tile(np.arange(n),2))),shape=(128,n)).tocsr()

def evaluate(ray):
    ray=ray/np.max(ray)
    gram=np.sqrt(ray)[:,None]*inv*np.sqrt(ray)[None,:]
    eigen,vec=np.linalg.eigh(gram)
    d=ray/eigen[-1]
    a=d[i]*g[i,i]; b=d[j]*g[j,j]; c2=d[i]*d[j]*g[i,j]**2
    root=np.sqrt((a-b)**2+4*c2)
    cost=(a+b-root)/2/norm
    lp=linprog(cost,A_ub=inc,b_ub=np.ones(128),A_eq=np.ones((1,n)),b_eq=[32],bounds=(0,None),method='highs',options={'time_limit':15})
    if not lp.success: raise RuntimeError(lp.message)
    return d,cost,lp,vec[:,-1],root

# The signed study's dyadic d is an independently verified PSD minorant.
# Produce a conservative dyadic dual on precisely that retained d; the
# separate verifier checks its every two-by-two eigenvalue cone exactly.
start_a=starting_d[i]*g[i,i];start_b=starting_d[j]*g[j,j]
start_cost=(start_a+start_b-np.sqrt((start_a-start_b)**2+
                                  4*starting_d[i]*starting_d[j]*g[i,j]**2))/2/norm
start_lp=linprog(start_cost,A_ub=inc,b_ub=np.ones(128),A_eq=np.ones((1,n)),
                 b_eq=[32],bounds=(0,None),method='highs')
if not start_lp.success:raise RuntimeError(start_lp.message)
vertex=np.minimum(0,np.floor(start_lp.ineqlin.marginals*2**50)).astype('int64')
cardinality=int(np.floor((start_lp.eqlin.marginals[0]-1e-7)*2**50))
np.savez_compressed(HERE/'weighted-dual.npz',vertex=vertex,cardinality=np.array([cardinality],dtype='int64'))
ray=starting_d.copy(); d,cost,lp,principal,root=evaluate(ray)
initial_floor=float(start_lp.fun)
for iteration in range(48):
    # Derivatives of the smaller eigenvalue in each positive diagonal d_i.
    a=d[i]*g[i,i]; b=d[j]*g[j,j]
    eigen_small=cost*norm
    u2=np.where(root>0,(1-(a-b)/root)/2,.5)
    v2=1-u2
    derivative=np.zeros(128)
    np.add.at(derivative,i,lp.x*eigen_small*u2/d[i]/norm)
    np.add.at(derivative,j,lp.x*eigen_small*v2/d[j]/norm)
    gradient=(d*derivative-lp.fun*principal**2)/lp.fun
    gradient-=np.mean(gradient)
    gradient/=max(np.max(np.abs(gradient)),1e-12)
    advanced=False
    for step in (.7,.35,.175,.0875,.04375,.02,.01):
        proposed_ray=ray*np.exp(step*gradient)
        nd,nc,nlp,npvec,nroot=evaluate(proposed_ray)
        if nlp.fun>lp.fun+1e-12:
            ray,d,cost,lp,principal,root=proposed_ray,nd,nc,nlp,npvec,nroot
            advanced=True
            break
    if not advanced: break
print('free-ratio floor start/best',initial_floor,lp.fun,'iterations',iteration)
# Numerically check the two-coordinate weighted rank-one formula directly on a
# small deterministic pair and compare the exact full-panel projection below.
order=np.argsort(cost); used=set(); pairs=[]
for k in order:
    u,z=int(i[k]),int(j[k]);
    if u in used or z in used: continue
    cov=np.array([[d[u]*g[u,u],np.sqrt(d[u]*d[z])*g[u,z]],
                  [np.sqrt(d[u]*d[z])*g[u,z],d[z]*g[z,z]]])
    eig,vec=np.linalg.eigh(cov); inputdirection=vec[:,-1]/np.sqrt([d[u],d[z]])
    if abs(inputdirection[0])<1e-10: continue
    ratio=float(inputdirection[1]/inputdirection[0]); pairs.append((u,z,ratio));used.update((u,z))
    if len(pairs)==32: break
train,held=fit_pairs(x,v,w,pairs)
alphabets={
    'signed':[-1.,1.],
    'signed_and_doubled':[-2.,-1.,1.,2.],
    'signed_half_double':[-2.,-1.,-.5,.5,1.,2.],
}
alphabet_floors={name:matching_floor(alphabet_cost(d,g,i,j,ratios,norm),inc,n)
                 for name,ratios in alphabets.items()}
signed_cost=alphabet_cost(d,g,i,j,[-1.,1.],norm)
ratio_improvement=dict(edges_strictly_better=int(np.sum(cost<signed_cost-1e-12)),
                       total_edges=n, max_single_edge_reduction=float(np.max(signed_cost-cost)),
                       mean_single_edge_reduction=float(np.mean(signed_cost-cost)))

def alphabet_evaluate(ray,ratios):
    ray=ray/np.max(ray)
    gram=np.sqrt(ray)[:,None]*inv*np.sqrt(ray)[None,:]
    eigen,vec=np.linalg.eigh(gram)
    diag=ray/eigen[-1]
    values=[]
    for ratio in ratios:
        u=diag[i]; v=diag[j]; denominator=u+ratio**2*v
        gain=(u*u*g[i,i]+2*ratio*u*v*g[i,j]+ratio**2*v*v*g[j,j])/denominator
        values.append((u*g[i,i]+v*g[j,j]-gain)/norm)
    values=np.stack(values)
    winners=np.argmin(values,axis=0)
    costs=values[winners,np.arange(n)]
    lp=linprog(costs,A_ub=inc,b_ub=np.ones(128),A_eq=np.ones((1,n)),b_eq=[32],bounds=(0,None),method='highs')
    if not lp.success: raise RuntimeError(lp.message)
    return diag,lp,vec[:,-1],np.asarray(ratios)[winners]

alphabet_optimized={}
for name in ('signed_and_doubled','signed_half_double'):
    ratios=alphabets[name]; aray=starting_d.copy(); ad,alp,apr,chosen=alphabet_evaluate(aray,ratios)
    initial=float(alp.fun)
    for turn in range(32):
        u=ad[i]; v=ad[j]; ratio=chosen; denominator=u+ratio**2*v
        dot_i=(u*g[i,i]+ratio*v*g[i,j])/denominator
        dot_j=(u*g[i,j]+ratio*v*g[j,j])/denominator
        norma=(u*u*g[i,i]+2*ratio*u*v*g[i,j]+ratio**2*v*v*g[j,j])/denominator**2
        grad_i=(g[i,i]-2*dot_i+norma)/norm
        grad_j=(g[j,j]-2*ratio*dot_j+ratio**2*norma)/norm
        derivative=np.zeros(128)
        np.add.at(derivative,i,alp.x*grad_i)
        np.add.at(derivative,j,alp.x*grad_j)
        gradient=(ad*derivative-alp.fun*apr**2)/alp.fun
        gradient-=np.mean(gradient); gradient/=max(np.max(np.abs(gradient)),1e-12)
        advanced=False
        for step in (.7,.35,.175,.0875,.04375,.02,.01):
            proposed=aray*np.exp(step*gradient)
            nd,nlp,npr,nchosen=alphabet_evaluate(proposed,ratios)
            if nlp.fun>alp.fun+1e-12:
                aray,ad,alp,apr,chosen=proposed,nd,nlp,npr,nchosen
                advanced=True;break
        if not advanced:break
    alphabet_optimized[name]=dict(start=initial,best=float(alp.fun),steps=turn)
result=dict(fixture_sha256=hashlib.sha256(FIX.read_bytes()).hexdigest(),
            signed_pair_certificate_sha256=hashlib.sha256(CERT.read_bytes()).hexdigest(),
            rank=96, pairs=[[i,j,r] for i,j,r in pairs],
            free_ratio_diagonal_matching_LP_floor=float(lp.fun),
            free_ratio_initial_diagonal_matching_LP_floor=initial_floor,
            retained_dyadic_dual_proposal=float((sum(int(z) for z in vertex)+32*cardinality)/2**50),
            chosen_diagonal=d.tolist(),
            ratio_alphabet_floors=alphabet_floors,
            ratio_improvement=ratio_improvement,
            ratio_alphabet_optimized=alphabet_optimized,
            chosen_free_ratio_real_readout_train=train,chosen_free_ratio_real_readout_held=held,
            prior_signed_pair_universal_floor=0.005176814521502315,
            scalar_q4_train=0.005173614377259471)
HERE.joinpath('results.json').write_text(json.dumps(result,indent=2)+'\n')
print({k:v for k,v in result.items() if k not in ('pairs','chosen_diagonal','fixture_sha256','signed_pair_certificate_source')})
