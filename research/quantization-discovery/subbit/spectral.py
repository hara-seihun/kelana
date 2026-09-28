#!/usr/bin/env python3
"""Low-rank response maps at the same factor-bit budgets as binary quantizers."""
import argparse
import hashlib
import json
import math
import time
from pathlib import Path

import numpy as np
import torch


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def run(args):
    torch.set_num_threads(args.threads)
    with np.load(args.fixture) as f:
        w = torch.from_numpy(f['weight'].copy())
        x = torch.from_numpy(f['train'].copy())
        xv = torch.from_numpy(f['validation'].copy())
    n, k = w.shape
    y = x @ w.T
    yv = xv @ w.T
    records = []
    for affine in (False, True):
        mean_x = x.mean(0) if affine else torch.zeros(k)
        mean_y = y.mean(0) if affine else torch.zeros(n)
        centered = y - mean_y
        begin = time.monotonic()
        _, s, vh = torch.linalg.svd(centered, full_matrices=False)
        seconds = time.monotonic() - begin
        for target in args.bits:
            budget = math.floor(target * n * k)
            rank = min(n, k, (budget - 16 * n * int(affine)) // (16 * (n + k)))
            if rank < 1:
                continue
            left = vh[:rank].T.contiguous()
            right = left.T @ w
            bias = mean_y - left @ (right @ mean_x) if affine else None
            left_array = left.numpy().astype(np.float16)
            right_array = right.numpy().astype(np.float16)
            arrays = {'left': left_array, 'right': right_array}
            if affine:
                arrays['bias'] = bias.numpy().astype(np.float16)
            artifact = args.out / f'{args.fixture.stem}-r{rank}-affine{int(affine)}.npz'
            np.savez(artifact, **arrays)
            left = torch.from_numpy(left_array).float()
            right = torch.from_numpy(right_array).float()
            qbias = torch.from_numpy(arrays['bias']).float() if affine else torch.zeros(n)
            pred_train = (x @ right.T) @ left.T + qbias
            pred = (xv @ right.T) @ left.T + qbias
            stored_bits = sum(a.nbytes * 8 for a in arrays.values())
            records.append({'target_bpw': target, 'rank': rank, 'affine': affine,
                            'dimensions': [n, k], 'payload_bits': stored_bits,
                            'payload_bpw': stored_bits / (n * k),
                            'serialized_bytes': artifact.stat().st_size,
                            'serialized_bpw': 8 * artifact.stat().st_size / (n * k),
                            'train_relative_squared_error': ((pred_train-y).square().sum()/y.square().sum()).item(),
                            'validation_relative_squared_error': ((pred-yv).square().sum()/yv.square().sum()).item(),
                            'empirical_best_rank_relative_squared_error': (s[rank:].square().sum()/y.square().sum()).item(),
                            'svd_seconds_shared_across_rates': seconds,
                            'fma_terms_per_vector': rank * (n+k),
                            'wmma16_padded_fma_terms_per_vector': math.ceil(rank/16)*16*(n+k),
                            'bias_adds_per_vector': n * int(affine),
                            'artifact': str(artifact), 'artifact_sha256': sha(artifact)})
            print(json.dumps(records[-1]), flush=True)
    report = {'method': 'empirical response-subspace projection; FP16 factors, optional FP16 output bias',
              'fixture': str(args.fixture), 'fixture_sha256': sha(args.fixture),
              'source_sha256': sha(Path(__file__)), 'torch': torch.__version__,
              'threads': args.threads, 'train_rows': len(x), 'validation_rows': len(xv),
              'native_timing': False, 'entries': records}
    (args.out / f'{args.fixture.stem}.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixture', type=Path, required=True)
    p.add_argument('--bits', type=float, nargs='+', default=[.5390625, .7734375, .9609375])
    p.add_argument('--threads', type=int, default=8)
    p.add_argument('--out', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/spectral'))
    args = p.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    run(args)
