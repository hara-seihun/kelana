#!/usr/bin/env python3
"""Fit SiLU's even part and enumerate the bounded FP16 consumer domain."""
import hashlib
import json
from pathlib import Path
import numpy as np
from scipy.optimize import linprog


def silu(x):
    return x/(1+np.exp(-x))


def half(x):
    return np.asarray(x,dtype=np.float16).astype(np.float64)


def evaluate(g, coefficients, fp16):
    rnd = half if fp16 else lambda x:x
    x = rnd(g)
    z = rnd(x*x)
    c = rnd(coefficients)
    v = np.zeros_like(x)+c[-1]
    for a in c[-2::-1]:
        v = rnd(z*v+a)
    return rnd(z*v+rnd(.5*x))


def fit(degree, radius):
    x = np.linspace(0,radius,4097)
    target = silu(x)-x/2
    b = np.stack([x**k for k in range(2,degree+1,2)],axis=1)
    res = linprog([0.]*(degree//2)+[1.],
                  A_ub=np.concatenate([np.c_[b,-np.ones(len(x))],np.c_[-b,-np.ones(len(x))]]),
                  b_ub=np.concatenate([target,-target]), bounds=[(None,None)]*(degree//2)+[(0,None)],method='highs')
    if not res.success: raise RuntimeError(res.message)
    return res.x[:-1],res.x[-1]


def refine_half(g, c):
    c=half(c)
    truth=silu(g)
    def score(a):return float(np.max(abs(evaluate(g,a,True)-truth)))
    best=score(c)
    for _ in range(4):
        changed=False
        for j in range(len(c)):
            for direction in (-np.inf,np.inf):
                trial=c.copy();trial[j]=float(np.nextafter(np.float16(c[j]),np.float16(direction)))
                value=score(trial)
                if value < best:
                    c,best,changed=trial,value,True
        if not changed:break
    return c,best


def run():
    raw=np.arange(65536,dtype=np.uint16).view(np.float16).astype(float)
    records=[]
    for radius in (3.5,5.):
        g=raw[np.isfinite(raw)&(abs(raw)<=radius)]
        for degree in (4,6,8):
            c,lpbound=fit(degree,radius)
            ch,err=refine_half(g,c)
            v=evaluate(g,ch,True);truth=silu(g)
            i=np.argmax(abs(v-truth))
            records.append({'degree':degree,'radius':radius,'coefficients':c.tolist(),
                'half_coefficients':ch.tolist(),'lp_grid_max_error':float(lpbound),
                'finite_fp16_inputs':len(g),'half_max_abs_error':err,
                'half_error_rms':float(np.sqrt(np.mean((v-truth)**2))),
                'worst_gate':float(g[i]),'worst_output':float(v[i]),'worst_reference':float(truth[i]),
                'fp32_real_coeff_error_on_half_inputs':float(np.max(abs(evaluate(g,c,False)-truth)))})
    return {'scope':'LP on4097points then exhaustive bounded binary16 inputs. Half fma simulated as float64 product+sum rounded once tohalf; reference uses host float64 exp. Not a formal continuous real bound or native GPU check.',
            'polynomial':'g/2 + g²*(c2+g²*(c4+...))','fits':records}


if __name__=='__main__':
    r=run();r['source_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    Path(__file__).with_name('fit.json').write_text(json.dumps(r,indent=2)+'\n')
    for f in r['fits']:print(f['degree'],f['radius'],f['half_max_abs_error'],f['half_coefficients'])
