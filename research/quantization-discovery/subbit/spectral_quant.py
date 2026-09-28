#!/usr/bin/env python3
"""Trade rank against coefficient precision in an activation-response subspace."""
import argparse
import hashlib
import json
import math
import time
from pathlib import Path

import numpy as np
import torch


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def packed_bytes(rows, cols, bits, group):
    if bits == 16:
        return 2 * rows * cols
    return rows * math.ceil(cols * bits / 8) + 2 * rows * math.ceil(cols / group)


def pack_codes(codes, bits):
    shifts = np.arange(bits, dtype=np.uint8)
    planes = (codes[..., None] >> shifts) & 1
    return np.packbits(planes.reshape(len(codes), -1), axis=1, bitorder='little')


def decode(arrays, name):
    rows, cols, bits, group = arrays[name + '_shape'].tolist()
    if bits == 16:
        return torch.from_numpy(arrays[name + '_values']).float()
    planes = np.unpackbits(arrays[name + '_codes'], axis=1, bitorder='little')[:, :cols * bits]
    codes = (planes.reshape(rows, cols, bits).astype(np.int16) << np.arange(bits)).sum(-1)
    scale = np.repeat(arrays[name + '_scales'].astype(np.float32), group, axis=1)[:, :cols]
    return torch.from_numpy((2 * codes - (2 ** bits - 1)) * scale).float()


def quantize(matrix, bits, group, name):
    rows, cols = matrix.shape
    arrays = {name + '_shape': np.array([rows, cols, bits, group], dtype=np.int32)}
    if bits == 16:
        arrays[name + '_values'] = matrix.numpy().astype(np.float16)
        return arrays
    padded_cols = math.ceil(cols / group) * group
    padded = torch.nn.functional.pad(matrix, (0, padded_cols - cols)).reshape(rows, -1, group)
    valid = torch.arange(padded_cols).reshape(1, -1, group) < cols
    top = 2 ** bits - 1
    max_scale = padded.abs().amax(-1, keepdim=True).clamp_min(1e-20) / top
    best_error = torch.full_like(max_scale, float('inf'))
    best_scale = max_scale.clone()
    for clip in (0.55, 0.7, 0.85, 1.0):
        scale = max_scale * clip
        for _ in range(5):
            codes = ((padded / scale + top) / 2).round().clamp(0, top)
            signed = (2 * codes - top) * valid
            scale = ((padded * signed).sum(-1, keepdim=True) /
                     signed.square().sum(-1, keepdim=True).clamp_min(1)).clamp_min(1e-20)
        error = (((padded - signed * scale) * valid).square()).sum(-1, keepdim=True)
        choose = error < best_error
        best_scale = torch.where(choose, scale, best_scale)
        best_error = torch.minimum(error, best_error)
    scales = best_scale.squeeze(-1).numpy().astype(np.float16)
    rounded_scale = torch.from_numpy(scales).float().unsqueeze(-1).clamp_min(1e-20)
    codes = ((padded / rounded_scale + top) / 2).round().clamp(0, top)
    codes = codes.reshape(rows, padded_cols)[:, :cols].numpy().astype(np.uint8)
    arrays[name + '_codes'] = pack_codes(codes, bits)
    arrays[name + '_scales'] = scales
    return arrays


def run(args):
    torch.set_num_threads(args.threads)
    with np.load(args.fixture) as f:
        w = torch.from_numpy(f['weight'].copy()).float()
        x = torch.from_numpy(f['train'].copy()).float()
        xv = torch.from_numpy(f['validation'].copy()).float()
    n, k = w.shape
    y, yv = x @ w.T, xv @ w.T
    begin = time.monotonic()
    alpha = args.covariance_shrinkage
    metric_rows = y
    if alpha:
        channel_moment = x.square().mean(0)
        diagonal = .6 * channel_moment + .4 * channel_moment.mean()
        metric_rows = torch.cat((y * math.sqrt(1-alpha),
                                 (w * diagonal.sqrt()).T * math.sqrt(len(x)*alpha)))
    _, spectrum, vh = torch.linalg.svd(metric_rows, full_matrices=False)
    svd_seconds = time.monotonic() - begin
    basis = vh.T.contiguous()
    coordinates = basis.T @ w
    records = []
    choices = [(2, 2), (3, 3), (4, 4), (8, 8), (2, 4), (4, 2), (4, 8), (8, 4), (4, 16), (16, 4)]
    for target in args.bits:
        for left_bits, right_bits in choices:
            for group in args.groups:
                rank = 0
                for r in range(8, min(n, k) + 1, 8):
                    size = packed_bytes(n, r, left_bits, group) + packed_bytes(r, k, right_bits, group) + 32
                    if 8 * size > target * n * k:
                        break
                    rank = r
                if not rank:
                    continue
                for balance in args.balance:
                    left = basis[:, :rank].clone()
                    right = coordinates[:rank].clone()
                    amplitude = right.square().sum(1).sqrt().clamp_min(1e-20) ** balance
                    left *= amplitude
                    right /= amplitude[:, None]
                    start = time.monotonic()
                    arrays = quantize(left, left_bits, group, 'left')
                    arrays.update(quantize(right, right_bits, group, 'right'))
                    left_q, right_q = decode(arrays, 'left'), decode(arrays, 'right')
                    # Projection back onto the stored output basis repairs its quantization
                    # before quantizing the input-side coefficients again.
                    if args.refit:
                        right_fit = torch.linalg.solve(left_q.T @ left_q + torch.eye(rank) * 1e-8,
                                                       left_q.T @ w)
                        arrays.update(quantize(right_fit, right_bits, group, 'right'))
                        right_q = decode(arrays, 'right')
                    pred_train = (x @ right_q.T) @ left_q.T
                    pred = (xv @ right_q.T) @ left_q.T
                    seconds = time.monotonic() - start
                    artifact = args.out / (f'{args.fixture.stem}-b{target:g}-l{left_bits}r{right_bits}'
                                           f'-g{group}-s{balance:g}-f{int(args.refit)}-cov{alpha:g}.npz')
                    np.savez(artifact, **arrays)
                    size = sum(a.nbytes for a in arrays.values())
                    entry = {'target_bpw': target, 'rank': rank, 'left_bits': left_bits,
                             'right_bits': right_bits, 'group': group, 'balance': balance,
                             'refit_input_factor': args.refit, 'covariance_shrinkage': alpha,
                             'dimensions': [n, k],
                             'payload_bytes_including_shapes': size, 'payload_bpw': 8 * size / (n*k),
                             'serialized_bytes': artifact.stat().st_size,
                             'serialized_bpw': 8 * artifact.stat().st_size / (n*k),
                             'train_relative_squared_error': ((pred_train-y).square().sum()/y.square().sum()).item(),
                             'validation_relative_squared_error': ((pred-yv).square().sum()/yv.square().sum()).item(),
                             'surrogate_best_rank_relative_squared_error': (spectrum[rank:].square().sum()/y.square().sum()).item(),
                             'factor_fma_terms_per_vector': rank * (n+k),
                             'wmma16_padded_fma_terms_per_vector': math.ceil(rank/16)*16*(n+k),
                             'fit_seconds': seconds, 'artifact': str(artifact), 'artifact_sha256': sha(artifact)}
                    records.append(entry)
        selected = min((r for r in records if r['target_bpw'] == target),
                       key=lambda r: r['train_relative_squared_error'])
        print(json.dumps({'train_selected': selected}), flush=True)
    report = {'method': 'quantized empirical response-subspace factors, two-stage FP32 evaluation',
              'fixture': str(args.fixture), 'fixture_sha256': sha(args.fixture),
              'source_sha256': sha(Path(__file__)), 'torch': torch.__version__,
              'train_rows': len(x), 'validation_rows': len(xv), 'threads': args.threads,
              'svd_seconds': svd_seconds, 'covariance_shrinkage': alpha,
              'metric': '(1-alpha) empirical second moment + alpha diagonal with 0.4 channel shrinkage',
              'native_timing': False, 'entries': records}
    path = args.out / f'{args.fixture.stem}-refit{int(args.refit)}-cov{alpha:g}.json'
    path.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture', type=Path, required=True)
    parser.add_argument('--bits', type=float, nargs='+', default=[.5390625, .7734375, .9609375])
    parser.add_argument('--groups', type=int, nargs='+', default=[128])
    parser.add_argument('--balance', type=float, nargs='+', default=[0, .5])
    parser.add_argument('--refit', action='store_true')
    parser.add_argument('--covariance-shrinkage', type=float, default=0)
    parser.add_argument('--threads', type=int, default=8)
    parser.add_argument('--out', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/spectral-quant'))
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    run(args)
