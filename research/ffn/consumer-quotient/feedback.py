#!/usr/bin/env python3
"""Weight-prepared blockwise inverse-Cholesky error feedback for activation codes.

The consumer metric W.T@W supplies a GPTQ-style sequential rounding map. Preparation
uses only W, never activations. The actual full projection is used only for scoring.
"""
import argparse
import hashlib
import json
from pathlib import Path
import time
import numpy as np
from discrepancy import halo_matrix, metric, D, FF


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--layer',default='layer00')
    p.add_argument('--block',type=int,default=128)
    p.add_argument('--levels',type=int,nargs='+',default=[1,3,7])
    p.add_argument('--clip',type=float,default=1.0)
    p.add_argument('--cache',required=True)
    p.add_argument('--json',required=True)
    a=p.parse_args();begin=time.monotonic()
    if FF%a.block or a.block%128:
        raise SystemExit('Block must be a multiple of 128 dividing FF')
    d=Path('/path/to/workspace/data/kelana-ffn/ptq1_0')/a.layer/'r8'
    b=Path('/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench')/a.layer
    q=np.fromfile(d/'xq_ff.i8',dtype=np.int8).reshape(8,FF)
    s=np.fromfile(d/'xs_ff.f32',dtype=np.float32).reshape(8,FF//128)
    v=q.astype(np.float32)*np.repeat(s,128,axis=1)
    w,s=halo_matrix(str(b/'down.halo'),D,FF)
    w=w.astype(np.float32)*np.repeat(s,128,axis=1)
    sha=hashlib.sha256((b/'down.halo').read_bytes()).hexdigest()
    cache=Path(a.cache);meta=Path(str(cache)+'.json')
    if cache.exists():
        if json.loads(meta.read_text())['weights_sha256']!=sha:
            raise SystemExit('Wrong weight cache')
        feedback=np.load(cache)
        if feedback.shape!=(FF//a.block,a.block,a.block):
            raise SystemExit('Wrong block size in cache')
    else:
        feedback=[]
        for lo in range(0,FF,a.block):
            part=w[:,lo:lo+a.block].astype(np.float64)
            gram=part.T@part
            # Small explicit damping stabilizes inversion, and is part of the map.
            gram+=np.eye(a.block)*1e-4*np.diag(gram).mean()
            upper=np.linalg.cholesky(np.linalg.inv(gram)).T
            feedback.append((upper/np.diag(upper)[:,None]).astype(np.float32))
        feedback=np.stack(feedback)
        cache.parent.mkdir(parents=True,exist_ok=True);np.save(cache,feedback)
        meta.write_text(json.dumps(dict(weights_sha256=sha,block=a.block,damping=1e-4,
          offline='inverse-Cholesky of each principal block of W.T@W, normalized diagonal to one'),indent=2)+'\n')
    target=v@w.T
    maxima=np.abs(v.reshape(8,-1,128)).max(axis=2)
    reports=[]
    for levels in a.levels:
        scale=np.repeat(np.maximum(maxima*a.clip/levels,1e-30),128,axis=1)
        nearest=np.clip(np.rint(v/scale),-levels,levels)
        work=v.copy().reshape(8,FF//a.block,a.block)
        codes=np.empty_like(work)
        scales=scale.reshape(work.shape)
        # Blocks and tokens are independent. Only the position inside a block is sequential.
        for j in range(a.block):
            chosen=np.clip(np.rint(work[:,:,j]/scales[:,:,j]),-levels,levels)
            codes[:,:,j]=chosen
            err=work[:,:,j]-chosen*scales[:,:,j]
            work[:,:,j:]-=err[:,:,None]*feedback[None,:,j,j:]
        chosen=codes.reshape(8,FF)
        reports.append(dict(levels=levels,clip=a.clip,
          before=metric((nearest*scale-v)@w.T,target),after=metric((chosen*scale-v)@w.T,target),
          changed_codes=int(np.count_nonzero(chosen!=nearest)),
          source_relative_error=float(np.linalg.norm(chosen*scale-v)/np.linalg.norm(v))))
        print(a.layer,a.block,levels,reports[-1]['before']['relative_rms'],reports[-1]['after']['relative_rms'],flush=True)
    result=dict(format='kelana-consumer-feedback/1',layer=a.layer,tokens=8,block=a.block,
                source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),weights_sha256=sha,
                feedback_MAC_per_token=FF*(a.block-1)//2,
                feedback_MAC_fraction_of_down=(a.block-1)/(2*D),
                triangular_fp32_bytes=FF*(a.block-1)//2*4,
                scope='CPU map and operation model only, no native throughput or full-model quality. Fixed weight-only feedback; no target projection in code selection. Per-128 dynamic scales retained.',
                elapsed_seconds=time.monotonic()-begin,results=reports)
    Path(a.json).parent.mkdir(parents=True,exist_ok=True)
    Path(a.json).write_text(json.dumps(result,indent=2)+'\n')

if __name__=='__main__':main()
