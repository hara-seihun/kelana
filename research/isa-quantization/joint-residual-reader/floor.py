#!/usr/bin/env python3
"""Generous pooled-panel lower bound for any affine correction to fixed Q3 base."""
import json
import numpy as np
from study import HERE, panels, q3, response, rms

base=q3()
xs=[]; rs=[]; ts=[]; cs=[]
for split in ('train','held'):
    x,t,control=panels(split)
    y,_,_=response(x,base)
    xs.append(x.astype(np.float64)); rs.append((t-y).astype(np.float64))
    ts.append(t.astype(np.float64)); cs.append(control.astype(np.float64))
x=np.concatenate(xs); r=np.concatenate(rs); t=np.concatenate(ts); c=np.concatenate(cs)
# Centering removes the intercept exactly; solve the favorable unrestricted FP64 problem.
x -= x.mean(0); r0=r-r.mean(0)
q,_=np.linalg.qr(x,mode='reduced')
err=r0-q@(q.T@r0)
result={'pooled_states':len(x),'affine_dimension':x.shape[1]+1,
        'q3_plus_unrestricted_affine_oracle_relative_rms':float(np.linalg.norm(err)/np.linalg.norm(t)),
        'q4_pooled_relative_rms':rms(c,t),
        'orthogonality_relative':float(np.linalg.norm(x.T@err)/(np.linalg.norm(x)*np.linalg.norm(err))),
        'note':'optimistic oracle fits both train and previously inspected held targets with unlimited precision and uncharged coefficients; finite-panel only'}
(HERE/'floor.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
