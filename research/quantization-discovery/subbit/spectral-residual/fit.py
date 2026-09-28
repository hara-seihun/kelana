#!/usr/bin/env python3
"""Fit response-spectral FP16 modes and a NanoQuant binary residual at fixed matrix BPW."""
import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
BINARY = HERE.parent / 'binary-factors'
sys.path.insert(0, str(BINARY))
from compare import load_upstream, pack_sign, rank_for_rate, response_error  # noqa: E402

FIXTURES = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')
UPSTREAM = BINARY / 'nanoquant_admm.py'


def pack_image(path, a, b, pre, post, left, right):
    # Real-valued left/right and all scales are FP16; signs are row-major packed bits.
    np.savez(path, U=pack_sign(a), V=pack_sign(b),
             scale_pre=pre.reshape(-1).half().numpy(), scale_post=post.reshape(-1).half().numpy(),
             left=left.half().numpy(), right=right.half().numpy(),
             dimensions=np.array([a.shape[0], b.shape[1], a.shape[1], left.shape[1]], dtype=np.int32))


def decode_image(path):
    with np.load(path) as image:
        n, k, rank, spectral = map(int, image['dimensions'])
        a = torch.from_numpy(np.unpackbits(image['U'], axis=1, bitorder='little')[:, :rank].astype(np.float32)) * 2 - 1
        b = torch.from_numpy(np.unpackbits(image['V'], axis=1, bitorder='little')[:, :k].astype(np.float32)) * 2 - 1
        pre = torch.from_numpy(image['scale_pre'].astype(np.float32))
        post = torch.from_numpy(image['scale_post'].astype(np.float32))
        left = torch.from_numpy(image['left'].astype(np.float32))
        right = torch.from_numpy(image['right'].astype(np.float32))
        binary_bytes = image['U'].nbytes + image['V'].nbytes
        real_bytes = image['left'].nbytes + image['right'].nbytes
        scale_bytes = image['scale_pre'].nbytes + image['scale_post'].nbytes
    weight = (a * post[:, None]) @ (b * pre[None, :]) + left @ right
    return weight, {'binary_factor_bytes': binary_bytes, 'spectral_factor_bytes': real_bytes,
                    'scale_bytes': scale_bytes, 'payload_bytes': binary_bytes + real_bytes + scale_bytes}


def spectral_response_basis(weight, train, rank, seed):
    # Top output directions of the train response; right=left.T@W is the optimal
    # weight map with this orthonormal output span under the empirical response loss.
    torch.manual_seed(seed)
    response = train @ weight.T
    left, _, _ = torch.svd_lowrank(response.T, q=rank + 8, niter=4)
    left = left[:, :rank]
    right = left.T @ weight
    return left, right


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixture', type=Path, required=True)
    p.add_argument('--spectral-rank', type=int, default=4)
    p.add_argument('--fit-post-scales', action='store_true',
                   help='least-squares fit each binary output scale to train residual responses')
    p.add_argument('--rates', type=float, nargs='+', default=[.55, .8, 1.])
    p.add_argument('--upstream', type=Path, default=UPSTREAM)
    p.add_argument('--outer-iters', type=int, default=400)
    p.add_argument('--inner-iters', type=int, default=5)
    p.add_argument('--threads', type=int, default=8)
    p.add_argument('--seed', type=int, default=0)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    if a.spectral_rank < 1:
        p.error('spectral rank must be positive')
    torch.set_num_threads(a.threads)
    a.out.mkdir(parents=True, exist_ok=True)
    with np.load(a.fixture) as fixture:
        weight = torch.from_numpy(fixture['weight'].copy()).float()
        train = torch.from_numpy(fixture['train'].copy()).float()
        validation = torch.from_numpy(fixture['validation'].copy()).float()
    n, k = weight.shape
    i_norm = train.square().mean(0)
    i_norm = .6 * i_norm + .4 * i_norm.mean()
    solver = load_upstream(a.upstream)
    start = time.monotonic()
    left, right = spectral_response_basis(weight, train, a.spectral_rank, a.seed)
    spectral_seconds = time.monotonic() - start
    # Fit the residual against the exact FP16 spectral image used at runtime.
    left = left.half().float()
    right = right.half().float()
    residual = weight - left @ right
    results = []
    for rate in a.rates:
        nominal_rank = rank_for_rate(n, k, rate)
        binary_rank = nominal_rank - 16 * a.spectral_rank
        if binary_rank < 32:
            p.error(f'rate {rate} cannot fit spectral rank {a.spectral_rank} and one binary rank-32 block')
        torch.manual_seed(a.seed)
        start = time.monotonic()
        factors = solver(residual, i_norm, torch.ones(n), binary_rank,
                         outer_iters=a.outer_iters, inner_iters=a.inner_iters,
                         rho_scheduler='linear', is_transpose=n < k)
        admm_seconds = time.monotonic() - start
        u = factors['A'].T.sign()
        v = factors['B'].sign()
        u[u == 0] = 1
        v[v == 0] = 1
        pre = factors['scale_pre'].reshape(-1).half().float()
        post = factors['scale_post'].reshape(-1)
        if a.fit_post_scales:
            # Optimizes the entire observed input covariance for every output
            # row, with binary signs and spectral image held fixed.
            response = ((train * pre[None, :]) @ v.T) @ u.T
            target = train @ residual.T
            post = (response * target).sum(0) / response.square().sum(0).clamp_min(1e-12)
        suffix = '_postfit' if a.fit_post_scales else ''
        path = a.out / f'{a.fixture.stem}_spectral{a.spectral_rank}_rate{rate:g}{suffix}.npz'
        pack_image(path, u, v, pre, post, left, right)
        reconstructed, bytes_map = decode_image(path)
        entry = {'target_bpw': rate, 'binary_rank': binary_rank, 'spectral_rank': a.spectral_rank,
                 **bytes_map, 'matrix_payload_bpw': 8 * bytes_map['payload_bytes'] / (n * k),
                 'serialized_file_bytes': path.stat().st_size,
                 'spectral_fit_seconds': spectral_seconds, 'admm_seconds': admm_seconds,
                 'train_response': response_error(weight, reconstructed, train),
                 'validation_response': response_error(weight, reconstructed, validation),
                 'weight_relative_squared_error':
                 ((reconstructed - weight).square().sum() / weight.square().sum()).item(),
                 'online_signed_accumulations': binary_rank * (n + k),
                 'online_real_fma_terms': a.spectral_rank * (n + k),
                 'artifact': str(path)}
        results.append(entry)
        print(json.dumps(entry), flush=True)
    report = {'method': 'empirical train-response output-span FP16 SVD plus upstream binary ADMM residual',
              'fixture': str(a.fixture), 'post_scales_fitted_to_train_responses': a.fit_post_scales,
              'train_samples': int(train.shape[0]),
              'validation_samples': int(validation.shape[0]), 'dimensions': [n, k],
              'seed': a.seed, 'threads': a.threads, 'outer_iters': a.outer_iters,
              'inner_iters': a.inner_iters, 'input_norm': 'forward squared mean, 0.4 shrinkage',
              'output_norm': 'uniform ones', 'entries': results}
    suffix = '_postfit' if a.fit_post_scales else ''
    (a.out / f'{a.fixture.stem}_spectral{a.spectral_rank}{suffix}.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
