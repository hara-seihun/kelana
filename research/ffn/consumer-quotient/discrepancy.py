#!/usr/bin/env python3
"""Oracle search for low-bit hidden codes preserving the actual down projection.

This computes the target projection and repeated gradients. It is deliberately NOT
an online acceleration. It tests representational capacity before kernel design.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'batched' / 'deferred-carrier'))
from carrier_scan import halo_matrix, D, FF


def metric(residual, target):
    return {'relative_rms': float(np.linalg.norm(residual)/np.linalg.norm(target)),
            'worst_row_relative_rms': float(np.max(np.linalg.norm(residual,axis=1)/np.linalg.norm(target,axis=1))),
            'bias': float(residual.mean()), 'max_abs': float(np.abs(residual).max())}


def search(w, v, levels, clip, steps, changes):
    maxima = np.abs(v.reshape(len(v),-1,128)).max(axis=2)
    scale = np.repeat(np.maximum(maxima*clip/levels,1e-30),128,axis=1)
    q = np.clip(np.rint(v/scale),-levels,levels).astype(np.float32)
    target = v @ w.T
    residual = (q*scale)@w.T-target
    original = q.copy()
    norms = (w*w).sum(axis=0)[None,:]*scale**2
    history=[dict(iteration=0, **metric(residual,target))]
    for iteration in range(1,steps+1):
        grad = (residual@w)*scale
        gain_up = -2*grad-norms
        gain_dn = 2*grad-norms
        gain_up[q>=levels]=-np.inf
        gain_dn[q<=-levels]=-np.inf
        delta = np.where(gain_up>gain_dn,1.,-1.).astype(np.float32)
        gain = np.maximum(gain_up,gain_dn)
        proposal = np.zeros_like(q)
        for r in range(len(v)):
            indices = np.argpartition(gain[r],-changes)[-changes:]
            indices = indices[gain[r,indices]>0]
            proposal[r,indices]=delta[r,indices]
        if not np.any(proposal):
            break
        # Accept each token only when its complete coupled update reduces error.
        change = (proposal*scale)@w.T
        accept = ((residual+change)**2).sum(axis=1)<(residual**2).sum(axis=1)
        q[accept]+=proposal[accept]
        residual[accept]+=change[accept]
        if not np.any(accept):
            if changes==1:
                break
            changes=max(1,changes//2)
        if iteration%8==0 or iteration==steps:
            history.append(dict(iteration=iteration,changes_per_step=changes,
                                accepted_rows=int(accept.sum()), **metric(residual,target)))
    # Recompute from scratch so incremental arithmetic cannot flatter the result.
    residual=(q*scale)@w.T-target
    return dict(levels=levels,clip=clip,iterations=iteration,
                changed_codes=int(np.count_nonzero(q!=original)), total_codes=q.size,
                code_histogram={str(k):int(np.count_nonzero(q==k)) for k in range(-levels,levels+1)},
                initial=history[0], final=metric(residual,target),history=history,
                source_rms_error=float(np.linalg.norm(q*scale-v)/np.linalg.norm(v)))


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--layer',default='layer00')
    p.add_argument('--steps',type=int,default=64)
    p.add_argument('--levels',type=int,nargs='+',default=[1,3,7])
    p.add_argument('--clip',type=float,nargs='+',default=[0.6,1.0])
    p.add_argument('--changes',type=int,default=64)
    p.add_argument('--json',required=True)
    a=p.parse_args()
    start=time.monotonic()
    dataset=Path('/path/to/workspace/data/kelana-ffn/ptq1_0')/a.layer
    batch=Path('/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench')/a.layer
    qfile=dataset/'r8/xq_ff.i8'; sfile=dataset/'r8/xs_ff.f32'
    q=np.fromfile(qfile,dtype=np.int8).reshape(8,FF)
    s=np.fromfile(sfile,dtype=np.float32).reshape(8,FF//128)
    v=q.astype(np.float32)*np.repeat(s,128,axis=1)
    w,scales=halo_matrix(str(batch/'down.halo'),D,FF)
    w=w.astype(np.float32)*np.repeat(scales,128,axis=1)
    results=[]
    for levels in a.levels:
        for clip in a.clip:
            result=search(w,v,levels,clip,a.steps,a.changes)
            results.append(result)
            print(levels,clip,result['initial']['relative_rms'],result['final']['relative_rms'],flush=True)
    report={'format':'kelana-consumer-discrepancy/1','layer':a.layer,'tokens':8,
            'target':'actual captured A8 hidden operand projected through scaled ternary down weights',
            'scope':'Oracle capacity experiment, not a runtime speedup or full-model quality test. The target and repeated down/transpose projections are computed during search.',
            'quantizer':'fixed per-token per-128 scales, codes jointly chosen across all 17408 coordinates',
            'source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'inputs':{str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in (qfile,sfile,batch/'down.halo')},
            'elapsed_seconds':time.monotonic()-start,'results':results}
    Path(a.json).parent.mkdir(parents=True,exist_ok=True)
    Path(a.json).write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
