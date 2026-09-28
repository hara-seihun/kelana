#!/usr/bin/env python3
"""Output-aware code selection with an offline diagonal-plus-low-rank metric.

Full down projections are used only for reporting, never for choosing updates.
This is a CPU map experiment; native throughput and full-model quality are separate.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time
import numpy as np
from discrepancy import metric, halo_matrix, D, FF

HERE=Path(__file__).resolve().parent


def optimize(v,w,l,levels,clip,steps,changes):
    maxima=np.abs(v.reshape(len(v),-1,128)).max(axis=2)
    scales=np.repeat(np.maximum(maxima*clip/levels,1e-30),128,axis=1)
    q=np.clip(np.rint(v/scales),-levels,levels).astype(np.float32)
    start=q.copy()
    diagonal=np.maximum((w*w).sum(axis=0)-(l*l).sum(axis=0),0)
    norm=((l*l).sum(axis=0)+diagonal)[None,:]*scales**2
    def objective(e):
        return ((e@l.T)**2).sum(axis=1)+(e*e*diagonal[None,:]).sum(axis=1)
    backtracks=0
    for _ in range(steps):
        e=q*scales-v
        z=e@l.T
        grad=(z@l+e*diagonal[None,:])*scales
        up=-2*grad-norm; dn=2*grad-norm
        up[q>=levels]=-np.inf;dn[q<=-levels]=-np.inf
        gain=np.maximum(up,dn)
        delta=np.where(up>dn,1.,-1.).astype(np.float32)
        order=np.argsort(gain,axis=1)[:,::-1]
        pending=np.ones(len(v),dtype=bool)
        count=changes
        while np.any(pending):
            proposal=np.zeros_like(q)
            for r in np.flatnonzero(pending):
                ids=order[r,:count]
                ids=ids[gain[r,ids]>0]
                proposal[r,ids]=delta[r,ids]
            change=proposal*scales
            dz=change@l.T
            energy_delta=(2*z*dz+dz*dz).sum(axis=1)+((2*e*change+change*change)*diagonal).sum(axis=1)
            accept=pending & (energy_delta<0)
            q[accept]+=proposal[accept]
            pending &= ~accept
            if count==1:
                break
            count=max(1,count//2)
            backtracks+=1
    # This is the first use of the full consumer during optimization/reporting.
    target=v@w.T
    before=(start*scales-v)@w.T
    after=(q*scales-v)@w.T
    return dict(rank=len(l),levels=levels,clip=clip,steps=steps,
                changed_codes=int(np.count_nonzero(q!=start)),
                before=metric(before,target),after=metric(after,target),
                surrogate_before=float(objective(start*scales-v).sum()),
                surrogate_after=float(objective(q*scales-v).sum()),
                acceptance_backtracks=backtracks,
                dense_projection_MAC_fraction=(3*steps+backtracks)*len(l)/D,
                cost_scope='Two rank-r projections for gradient plus one per proposed update, including backtracking; ignores sorting, scalar work, launches, and traffic. No speed claim.')


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--layer',default='layer00')
    p.add_argument('--rank',type=int,nargs='+',default=[8,32,128])
    p.add_argument('--steps',type=int,nargs='+',default=[1,4])
    p.add_argument('--levels',type=int,nargs='+',default=[1,3,7])
    p.add_argument('--clip',type=float,default=1.0)
    p.add_argument('--basis',required=True)
    p.add_argument('--json',required=True)
    a=p.parse_args();t=time.monotonic()
    d=Path('/path/to/workspace/data/kelana-ffn/ptq1_0')/a.layer/'r8'
    b=Path('/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench')/a.layer
    q=np.fromfile(d/'xq_ff.i8',dtype=np.int8).reshape(8,FF)
    s=np.fromfile(d/'xs_ff.f32',dtype=np.float32).reshape(8,FF//128)
    v=q.astype(np.float32)*np.repeat(s,128,axis=1)
    w,s=halo_matrix(str(b/'down.halo'),D,FF)
    w=w.astype(np.float32)*np.repeat(s,128,axis=1)
    basis=Path(a.basis);meta=Path(str(basis)+'.json')
    weight_sha=hashlib.sha256((b/'down.halo').read_bytes()).hexdigest()
    maxrank=max(a.rank)
    if basis.exists():
        info=json.loads(meta.read_text())
        if info['weights_sha256']!=weight_sha or info['rank']<maxrank:
            raise SystemExit('Basis belongs to different weights or has insufficient rank')
        l=np.load(basis)
    else:
        rng=np.random.default_rng(84123)
        # Offline randomized left singular subspace. No activation data enters.
        z=rng.standard_normal((FF,maxrank+16),dtype=np.float32)
        u=np.linalg.qr(w@z,mode='reduced')[0]
        for _ in range(2):
            u=np.linalg.qr(w@(w.T@u),mode='reduced')[0]
        projected=u.T@w
        gram=projected@projected.T
        eigenvalues,rot=np.linalg.eigh(gram)
        order=np.argsort(eigenvalues)[::-1][:maxrank]
        l=np.ascontiguousarray(rot[:,order].T@projected)
        basis.parent.mkdir(parents=True,exist_ok=True);np.save(basis,l)
        meta.write_text(json.dumps(dict(weights_sha256=weight_sha,rank=maxrank,
          algorithm='randomized left subspace, 16 oversamples, 2 power iterations, no activation data',
          seed=84123,eigenvalues=eigenvalues[order].tolist()),indent=2)+'\n')
    results=[]
    for rank in a.rank:
        for levels in a.levels:
            for steps in a.steps:
                r=optimize(v,w,l[:rank],levels,a.clip,steps,64)
                results.append(r)
                print(rank,levels,steps,r['before']['relative_rms'],r['after']['relative_rms'],flush=True)
    report=dict(format='kelana-consumer-sketch/1',layer=a.layer,tokens=8,
                weights_sha256=weight_sha,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                scope='Output-aware code selection; objective and update use only diagonal plus a weight-only rank-r sketch. Full W is used for reporting and offline preparation. No native speed or model quality claim.',
                elapsed_seconds=time.monotonic()-t,results=results)
    Path(a.json).parent.mkdir(parents=True,exist_ok=True)
    Path(a.json).write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
