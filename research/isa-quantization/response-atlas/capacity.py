#!/usr/bin/env python3
"""All-affine finite-panel residual floors via complete-output orthogonal projection."""
import json
from pathlib import Path
import numpy as np
import scipy.linalg
from screen import HERE, load, router


def floor(x,y):
    # Giving a chart an arbitrary FP64 matrix and intercept and even letting it
    # see every validation target can only reduce its finite-panel error.
    design=np.column_stack((np.ones(len(x)),x))
    q,_=scipy.linalg.qr(design,mode='economic',check_finite=False)
    residual_matrix=y-q@(q.T@y)
    residual=float(np.sum(residual_matrix**2))
    orthogonality=float(np.linalg.norm(design.T@residual_matrix)/(
        np.linalg.norm(design)*np.linalg.norm(y)))
    return residual,q.shape[1],orthogonality


def main():
    train=load('train'); held=load('held')
    x=np.concatenate((train['inputs'],held['inputs']))
    y=np.concatenate((train['target'],held['target']))
    q4=np.concatenate((train['q4'],held['q4']))
    p,t,_=router(train)
    route=x@p>=t
    energy=float(np.sum(y*y))
    global_residual,global_dim,global_orthogonality=floor(x,y)
    routed=[]
    routed_residual=0.
    for r in (False,True):
        ids=np.flatnonzero(route==r)
        error,dimension,orthogonality=floor(x[ids],y[ids])
        routed.append(dict(states=len(ids),affine_design_dimension=dimension,
                           free_fp64_least_squares_residual=error,
                           design_residual_orthogonality=orthogonality))
        routed_residual+=error
    actual_q4=float(np.linalg.norm(q4-y)/np.linalg.norm(y))
    result=dict(domain='union of actual captured 1024 train + 1024 separate validation producer states, all 1024 outputs',
        q4_relative_rms=actual_q4,
        global_all_affine_free_fit_rms=float(np.sqrt(global_residual/energy)),
        two_chart_all_affine_free_fit_rms=float(np.sqrt(routed_residual/energy)),
        routed_chart_diagnostics=routed,
        full_output_energy=energy,
        one_chart_design_dimension=global_dim,
        one_chart_design_residual_orthogonality=global_orthogonality,
        validation_targets_used_to_establish_optimistic_floors=True,
        exact_status='numerical QR projection floor on this finite input/output matrix, not a symbolic or whole-model theorem')
    (HERE/'capacity.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__': main()
