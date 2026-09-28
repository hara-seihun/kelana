"""Covariance-aware single-edge and simultaneous-matching lower bounds."""
import json
import numpy as np
from scipy.optimize import linprog
from scipy.sparse import coo_matrix, vstack
from pathlib import Path

FIXTURE=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
OUT=Path(__file__).with_name('certificate-results.json')
with np.load(FIXTURE) as f:
    x=f['train'][:,:128].astype('float64'); w=f['weight'][:128,:128].astype('float64')
h=x.T@x; inv=np.linalg.inv(h); y=x@w.T; norm=float(np.sum(y*y))
I,J=np.triu_indices(128,1); n=len(I)
minus=np.sum((w[:,I]-w[:,J])**2,axis=0)
plus=np.sum((w[:,I]+w[:,J])**2,axis=0)
prec_minus=inv[I,I]+inv[J,J]-2*inv[I,J]
prec_plus=inv[I,I]+inv[J,J]+2*inv[I,J]
a=np.minimum(plus/prec_plus,minus/prec_minus)
print('edge floor sum32',np.sum(np.partition(a,31)[:32])/norm)
vertex=coo_matrix((np.ones(2*n), (np.concatenate((I,J)),np.tile(np.arange(n),2))), shape=(128,n)).tocsr()
lp=linprog(a, A_ub=vertex, b_ub=np.ones(128), A_eq=np.ones((1,n)), b_eq=[32],
           bounds=(0,1), method='highs', options={'time_limit':25})
if not lp.success: raise RuntimeError(f'matching LP did not solve: {lp.message}')
# For any disjoint matching of 32 edges, the normalized precision Gram has
# diagonal one and off-diagonal bounded by mu across disjoint pairs. Gershgorin:
# M <= (1+31 mu) diag(M). Replacing each exact signed-edge score by the
# minimum over signs avoids assuming the matching's selected sign.
maxmu=0.; top31max=0.
for k in range(n):
    u,v=I[k],J[k]
    disjoint=(I!=u)&(J!=u)&(I!=v)&(J!=v)
    row=np.zeros(n)
    for source_sign,source_den in ((1.,prec_minus[k]),(-1.,prec_plus[k])):
        cross_base=inv[u,I]-source_sign*inv[v,I]
        cross_tail=inv[u,J]-source_sign*inv[v,J]
        minus_corr=np.abs(cross_base-cross_tail)/np.sqrt(source_den*prec_minus)
        plus_corr=np.abs(cross_base+cross_tail)/np.sqrt(source_den*prec_plus)
        row=np.maximum(row,np.maximum(minus_corr,plus_corr))
    vals=row[disjoint]
    maxmu=max(maxmu,float(np.max(vals)))
    top31max=max(top31max,float(np.sum(np.partition(vals,-31)[-31:])))
result={'single_edge_sum32':float(np.sum(np.partition(a,31)[:32])/norm),
        'fractional_disjoint_matching_sum32':float(lp.fun/norm),
        'max_disjoint_pair_precision_correlation':maxmu,
        'max_top31_disjoint_precision_correlations':top31max,
        'gershgorin_bound':float(np.sum(np.partition(a,31)[:32])/norm/(1+top31max)),
        'q4_response_error':0.00517361437725947}
OUT.write_text(json.dumps(result,indent=2)+'\n'); print(result)
