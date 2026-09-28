#!/usr/bin/env python3
"""Isolate FP16 activation-operand rounding in a complete CPU FFN map.

Scaled ternary weights are already exact FP16 values. FP32 BLAS accumulation is
used for both sides. This is not a model of undocumented native WMMA rounding.
"""
import argparse
import hashlib
import json
from pathlib import Path
import time
import numpy as np
from discrepancy import halo_matrix, D, FF, metric
from carrier_scan import hadamard_1024, quantise


def operand(x):
    y=x.astype(np.float16).astype(np.float32)
    return y,dict(relative_rms=float(np.linalg.norm(y-x)/np.linalg.norm(x)),
                  max_abs=float(np.max(np.abs(y-x))),nonfinite=int(np.count_nonzero(~np.isfinite(y))),
                  underflow_to_zero=int(np.count_nonzero((x!=0)&(y==0))),
                  subnormal=int(np.count_nonzero((y!=0)&(np.abs(y)<2**-14))))


def main():
    p=argparse.ArgumentParser();p.add_argument('--layer',default='layer00');p.add_argument('--json',required=True)
    a=p.parse_args();start=time.monotonic()
    d=Path('/path/to/workspace/data/kelana-ffn/ptq1_0')/a.layer/'r8'
    b=Path('/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench')/a.layer
    q=np.fromfile(d/'xq_d.i8',dtype=np.int8).reshape(8,D)
    s=np.fromfile(d/'xs_d.f32',dtype=np.float32).reshape(8,D//128)
    x=q.astype(np.float32)*np.repeat(s,128,axis=1)
    x16,input_stats=operand(x)
    projections=[]
    for name in ('gate','up'):
        w,sc=halo_matrix(str(b/f'{name}.halo'),FF,D)
        w=w.astype(np.float32)*np.repeat(sc,128,axis=1)
        assert np.array_equal(w.astype(np.float16).astype(np.float32),w)
        projections.append((x@w.T,x16@w.T))
        del w
    g,g16=projections[0];u,u16=projections[1]
    signs=np.fromfile(b/'signs_ff.f32',dtype=np.float32)
    def hidden(g,u):
        h=(g/(1+np.exp(-g)))*u
        z=hadamard_1024(h*signs[None,:])
        q,c=quantise(z,128,127)
        return q.astype(np.float32)*np.repeat(c,128,axis=1),q,c
    h,q0,s0=hidden(g,u);hchanged,q1,s1=hidden(g16,u16)
    h16,hidden_stats=operand(hchanged)
    w,sc=halo_matrix(str(b/'down.halo'),D,FF)
    w=w.astype(np.float32)*np.repeat(sc,128,axis=1)
    assert np.array_equal(w.astype(np.float16).astype(np.float32),w)
    y=h@w.T;changed=h16@w.T
    residual=np.fromfile(d/'x_in.f32',dtype=np.float32).reshape(8,D)
    engine=np.fromfile(d/'x_out.f32',dtype=np.float32).reshape(8,D)
    ref=residual+y;candidate=residual+changed
    result=dict(format='kelana-operand-rounding/1',layer=a.layer,tokens=8,
      scope='CPU FP32-BLAS accumulation on both sides. Exact original ternary FP16 scales; A8 codes and dynamic scales; only changing operands rounded to FP16 in candidate. Does not model native WMMA or prove transfer.',
      input_operand=input_stats,hidden_operand=hidden_stats,
      gate=metric(g16-g,g),up=metric(u16-u,u),
      hidden_code_changes=int(np.count_nonzero(q1!=q0)),hidden_codes=q0.size,
      projection_difference=metric(changed-y,y),residual_difference=metric(candidate-ref,ref),
      cpu_reference_vs_engine=metric(ref-engine,engine),candidate_vs_engine=metric(candidate-engine,engine),
      source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),elapsed_seconds=time.monotonic()-start)
    Path(a.json).parent.mkdir(parents=True,exist_ok=True)
    Path(a.json).write_text(json.dumps(result,indent=2)+'\n')
    print(a.layer,result['residual_difference'],flush=True)

if __name__=='__main__':main()
