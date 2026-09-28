"""Optimize a heterogeneous diagonal PSD minorant through normalized safe rays."""
import json
from pathlib import Path
import numpy as np
from scipy.optimize import linprog
from scipy.sparse import coo_matrix

FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
OUT=Path(__file__).with_name('diagonal-results.json')
with np.load(FIX) as f:
    x=f['train'][:,:128].astype('float64'); w=f['weight'][:128,:128].astype('float64')
h=x.T@x; inv=np.linalg.inv(h); y=x@w.T; ynorm=float(np.sum(y*y))
i,j=np.triu_indices(128,1); n=len(i)
weight_diff=np.minimum(np.sum((w[:,i]-w[:,j])**2,axis=0),np.sum((w[:,i]+w[:,j])**2,axis=0))
incidence=coo_matrix((np.ones(2*n),(np.concatenate((i,j)),np.tile(np.arange(n),2))),shape=(128,n)).tocsr()

def evaluate(ray):
    ray=np.asarray(ray,dtype='float64'); ray/=np.max(ray)
    g=np.sqrt(ray)[:,None]*inv*np.sqrt(ray)[None,:]
    eigen, vectors=np.linalg.eigh(g)
    scale=float(eigen[-1]); principal=vectors[:,-1]
    d=ray/scale
    cost=d[i]*d[j]/(d[i]+d[j])*weight_diff/ynorm
    lp=linprog(cost,A_ub=incidence,b_ub=np.ones(128),A_eq=np.ones((1,n)),b_eq=[32],bounds=(0,None),method='highs',options={'time_limit':15})
    if not lp.success: raise RuntimeError(lp.message)
    return dict(d=d, floor=float(lp.fun), edge32=float(np.sum(np.partition(cost,31)[:32])),
                psd_scale=scale, min_eigen_residual=float(np.linalg.eigvalsh(h-np.diag(d))[0]),
                matching_dual_vertex=lp.ineqlin.marginals.tolist(),
                matching_dual_cardinality=float(lp.eqlin.marginals[0]),
                min_dual_slack=float(np.min(cost-incidence.T@lp.ineqlin.marginals-lp.eqlin.marginals[0])),
                matching_primal=lp.x, principal=principal, ray=ray)

power=[]
for exponent in (-2,-1,-.5,0,.5,1,1.5,2):
    ray=np.diag(inv)**(-exponent)
    v=evaluate(ray); power.append(dict(exponent=exponent, **{k:q for k,q in v.items() if k not in ('d','matching_dual_vertex','matching_primal','principal','ray')}))
print('power',[(p['exponent'],p['floor']) for p in power])
# Gradient-free piecewise adjustment of the diagonal ray. No claim of global
# optimum: investigate whether a cheaply generated feasible PSD minorant exists.
best_ray=np.diag(inv)**(-max(power,key=lambda p:p['floor'])['exponent'])
best=evaluate(best_ray)
for seed in range(4):
    rng=np.random.default_rng(20260924+seed)
    for trial in range(6):
        ray=best_ray*np.exp(rng.normal(0,.25,size=128))
        candidate=evaluate(ray)
        if candidate['floor']>best['floor']:
            best,best_ray=candidate,ray
for iteration in range(36):
    d=best['d']; xmatch=best['matching_primal']; principal=best['principal']
    dc=d[i]+d[j]
    derivative=np.zeros(128)
    np.add.at(derivative,i,xmatch*weight_diff/ynorm * d[j]**2/dc**2)
    np.add.at(derivative,j,xmatch*weight_diff/ynorm * d[i]**2/dc**2)
    gradient=(d*derivative-best['floor']*principal**2)/best['floor']
    gradient-=np.mean(gradient)
    gradient/=max(np.max(np.abs(gradient)),1e-12)
    progressed=False
    for step in (.7,.35,.175,.0875,.04375,.02,.01):
        proposed_ray=best_ray*np.exp(step*gradient)
        proposed=evaluate(proposed_ray)
        if proposed['floor']>best['floor']+1e-12:
            best,best_ray=proposed,proposed_ray
            progressed=True
            break
    if not progressed: break
print('best',best['floor'],best['edge32'],best['min_eigen_residual'],'steps',iteration)
# Create an interior, dyadic candidate whose PSD condition and matching dual
# can be checked in exact integer arithmetic without trusting the solver.
safe_d=np.floor(best['d']*(1-1e-5)*2**32).astype('int64')
safe_float=safe_d.astype('float64')/2**32
safe_cost=safe_float[i]*safe_float[j]/(safe_float[i]+safe_float[j])*weight_diff/ynorm
safe_lp=linprog(safe_cost,A_ub=incidence,b_ub=np.ones(128),A_eq=np.ones((1,n)),b_eq=[32],bounds=(0,None),method='highs')
if not safe_lp.success: raise RuntimeError(safe_lp.message)
dual_vertex=np.minimum(0,np.floor(safe_lp.ineqlin.marginals*2**50)).astype('int64')
dual_cardinality=int(np.floor((safe_lp.eqlin.marginals[0]-1e-7)*2**50))
slack=np.min(safe_cost-(incidence.T@dual_vertex+dual_cardinality)/2**50)
print('safe candidate',safe_lp.fun,'dual lower', (dual_vertex.sum()+32*dual_cardinality)/2**50,'float slack',slack)
psd_matrix=h-np.diag(safe_d/2**32)
tri=np.rint(np.linalg.cholesky(psd_matrix-1e-5*np.eye(128))*2**40).astype('int64')
np.savez_compressed(Path(__file__).with_name('diagonal-certificate.npz'),diagonal=safe_d,
                    factor=tri,dual_vertex=dual_vertex,dual_cardinality=np.array([dual_cardinality],dtype='int64'))
result=dict(q4_error=0.00517361437725947, previous_lambda_floor=0.0011897403202238766,
            power_sweep=power, dyadic_candidate=dict(lp_value=float(safe_lp.fun),
                dual_lower_float=float((dual_vertex.sum()+32*dual_cardinality)/2**50),
                min_float_dual_slack=float(slack)),
            best=dict(**{k:v for k,v in best.items() if k not in ('d','matching_dual_vertex','matching_primal','principal','ray')},
                                       diagonal=best['d'].tolist(),matching_dual_vertex=best['matching_dual_vertex']))
OUT.write_text(json.dumps(result,indent=2)+'\n')
