#!/usr/bin/env python3
"""Frozen factor family over nested, complete calibration-window subsets."""
import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch

from spectral_quant import decode, quantize, sha


def run(args):
    torch.set_num_threads(8)
    with np.load(args.fixture) as f:
        w = torch.from_numpy(f['weight'].copy()).float()
        train = torch.from_numpy(f['train'].copy()).float()
        validation = torch.from_numpy(f['validation'].copy()).float()
    n, k = w.shape
    yv = validation @ w.T
    windows = len(train)//256
    records = []
    cache = {}
    for seed in (101, 202, 303):
        order = np.random.default_rng(seed).permutation(windows)
        for count in (1, 2, 4, 8):
            indices = tuple(sorted(map(int, order[:count])))
            x = torch.cat([train[256*i:256*(i+1)] for i in indices])
            y = x @ w.T
            for alpha in (0., .4):
                key = (indices, alpha)
                if key not in cache:
                    start = time.monotonic()
                    metric = y
                    if alpha:
                        moment = x.square().mean(0)
                        diagonal = .6*moment + .4*moment.mean()
                        metric = torch.cat((y*math.sqrt(1-alpha),
                                            (w*diagonal.sqrt()).T*math.sqrt(len(x)*alpha)))
                    _, _, vh = torch.linalg.svd(metric, full_matrices=False)
                    left = vh[:args.rank].T.contiguous()
                    right = left.T @ w
                    amplitude = right.square().sum(1).sqrt().clamp_min(1e-20).sqrt()
                    left *= amplitude
                    right /= amplitude[:, None]
                    arrays = quantize(left, args.left_bits, 128, 'left')
                    left_q = decode(arrays, 'left')
                    right = torch.linalg.solve(left_q.T@left_q + torch.eye(args.rank)*1e-8,
                                               left_q.T@w)
                    arrays.update(quantize(right, args.right_bits, 128, 'right'))
                    right_q = decode(arrays, 'right')
                    pred = (validation@right_q.T)@left_q.T
                    ptr = (x@right_q.T)@left_q.T
                    seconds = time.monotonic()-start
                    artifact = args.out / (args.fixture.stem+'-windows'+','.join(map(str,indices))+
                                           f'-cov{alpha:g}.npz')
                    np.savez(artifact, **arrays)
                    cache[key] = {'train_relative_squared_error': ((ptr-y).square().sum()/y.square().sum()).item(),
                                  'validation_relative_squared_error': ((pred-yv).square().sum()/yv.square().sum()).item(),
                                  'fit_seconds': seconds, 'payload_bytes': sum(a.nbytes for a in arrays.values()),
                                  'artifact': str(artifact), 'artifact_sha256': sha(artifact)}
                records.append({'seed': seed, 'window_indices': list(indices), 'train_rows': len(x),
                                'covariance_shrinkage': alpha, **cache[key]})
    report = {'method': 'fixed quantized response factors, complete nested training windows',
              'fixture': str(args.fixture), 'fixture_sha256': sha(args.fixture),
              'rank': args.rank, 'left_bits': args.left_bits, 'right_bits': args.right_bits,
              'group': 128, 'balance': .5, 'rank_precision_selected_before_curve': True,
              'train_windows_available': windows, 'validation_rows': len(validation),
              'sources': {p.name: sha(p) for p in (Path(__file__),Path(__file__).with_name('spectral_quant.py'))},
              'unique_fits': len(cache), 'entries': records}
    (args.out / (args.fixture.stem+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    for count in (1, 2, 4, 8):
        print(json.dumps({'train_windows': count, 'validation_errors_by_shrinkage':
              {str(alpha): [r['validation_relative_squared_error'] for r in records
                            if r['train_rows']==256*count and r['covariance_shrinkage']==alpha]
               for alpha in (0.,.4)}}),flush=True)


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixture',type=Path,required=True)
    p.add_argument('--rank',type=int,default=88)
    p.add_argument('--left-bits',type=int,default=4)
    p.add_argument('--right-bits',type=int,default=4)
    p.add_argument('--out',type=Path,default=Path('/path/to/workspace/data/kelana-subbit/calibration-curve'))
    args=p.parse_args()
    args.out.mkdir(parents=True,exist_ok=True)
    run(args)
