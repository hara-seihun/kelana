#!/usr/bin/env python3
"""Reprice a complete reference-query image against other actual final-head inputs."""
import json
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE/'build'
CACHE=Path('/path/to/workspace/data/bonsai2/PTQ1_0.gguf.halo')


def main():
    raw=np.memmap(CACHE,dtype=np.uint8,mode='r',offset=24576,shape=(7760,40,896))
    bits=np.ascontiguousarray(raw[:,:,768:].reshape(7760,40,32,4)[:,:,:,2:4])
    scales=bits.view('<f2').reshape(7760,40,32).astype(np.float64).transpose(0,2,1).reshape(248320,40)
    q0=np.fromfile(ROOT/'captures/case0/query.i8',dtype=np.int8).astype(np.float64).reshape(40,128)
    xs0=np.fromfile(ROOT/'captures/case0/scales.f32',dtype=np.float32).astype(np.float64)
    score0=np.fromfile(ROOT/'score0.f64',dtype='<f8')
    report=[]
    for case in (1,2):
        q=np.fromfile(ROOT/f'captures/case{case}/query.i8',dtype=np.int8).astype(np.float64).reshape(40,128)
        xs=np.fromfile(ROOT/f'captures/case{case}/scales.f32',dtype=np.float32).astype(np.float64)
        target=np.fromfile(ROOT/f'score{case}.f64',dtype='<f8')
        delta=np.abs(q*xs[:,None]-q0*xs0[:,None]).sum(axis=1)
        bound=score0+scales@delta
        winner=int(np.argmax(target));oracle=float(target[winner])
        failures=int(np.count_nonzero(target>bound+1e-10))
        if failures:raise ValueError(f'anchor not a valid bound: {failures} rows')
        survivors=int(np.count_nonzero(bound>=oracle-1e-8))
        report.append({'case':case,'real_winner':winner,'survivors_with_free_real_oracle':survivors,
                       'anchor_score_bytes_f64':int(score0.nbytes),'scale_bytes':int(scales.size*2),
                       'online_scale_terms':int(scales.size),'delta_l1_scaled':float(delta.sum()),
                       'upper_failures':failures})
    (HERE/'anchor-results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
