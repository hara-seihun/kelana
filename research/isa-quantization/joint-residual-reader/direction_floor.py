#!/usr/bin/env python3
"""Hindsight best output-wise gains and biases on fixed source-Jacobian direction."""
import json
import numpy as np
from study import HERE, panels, q3, response, rms

base=q3()
with np.load(HERE/'correction.npz') as f:
    j=f['code'].astype(np.float32)*f['scale'].astype(np.float32)[:,None]
residual=[]; direction=[]; target=[]; q4=[]
for split in ('train','held'):
    x,t,c=panels(split)
    y,_,_=response(x,base)
    residual.append((t-y).astype(np.float64))
    direction.append((x@j.T).astype(np.float64))
    target.append(t.astype(np.float64))
    q4.append(c.astype(np.float64))
r=np.concatenate(residual); d=np.concatenate(direction); t=np.concatenate(target)
r0=r-r.mean(0); d0=d-d.mean(0)
gain=np.sum(r0*d0,axis=0)/np.sum(d0*d0,axis=0)
e=r0-d0*gain
result={'oracle_family':'fixed Q3 and stored Q8 source-J correction; independent unbounded FP64 output gains and biases fit both panels with target hindsight',
        'pooled_relative_rms_floor':float(np.linalg.norm(e)/np.linalg.norm(t)),
        'q4_pooled_relative_rms':rms(np.concatenate(q4),t),
        'gain_quantiles':np.quantile(gain,[0,.1,.5,.9,1]).tolist(),
        'correction_residual_orthogonality':float(np.max(np.abs((e*d0).sum(0))/np.maximum(1,np.linalg.norm(e,axis=0)*np.linalg.norm(d0,axis=0))))}
(HERE/'direction-floor.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
