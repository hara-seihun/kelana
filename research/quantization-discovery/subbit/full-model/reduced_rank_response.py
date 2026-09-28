#!/usr/bin/env python3
"""Globally optimal rank-r ridge correction of a frozen binary layer-0 MLP hidden response."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch

from mlp_factor_response import ROOT, PARTS, digest, error, mlp, unpack_bf16, weight


def fit(features, residual, ranks, ridge_fraction):
    center = features.mean(0)
    x = features - center
    y = residual - residual.mean(0)
    gram = x @ x.T
    lam = ridge_fraction * torch.trace(gram) / len(x)
    eigenvalues, u = torch.linalg.eigh(gram)
    eigenvalues = eigenvalues.clamp_min(0)
    s = eigenvalues.sqrt()
    nonzero = s > s.max() * 1e-5
    t = s / (eigenvalues + lam).sqrt()
    cross = t[:, None] * (u.T @ y)
    # Cross is the ridge-whitened target. Eckart-Young gives its globally
    # optimal rank-r truncation for the regularized squared-response objective.
    p, singular, vh = torch.linalg.svd(cross, full_matrices=False)
    inv = torch.where(nonzero, 1 / (s * (eigenvalues + lam).sqrt()).clamp_min(1e-12), 0)
    factors = {}
    for rank in ranks:
        right = (x.T @ (u @ (inv[:, None] * p[:, :rank]))).to(torch.float16).float()
        left = (vh[:rank].T * singular[:rank]).to(torch.float16).float()
        offset = (residual - (features @ right) @ left.T).mean(0).to(torch.float16).float()
        factors[rank] = (right, left, offset)
    return factors, float(lam), [float((singular[:r] ** 2).sum()) for r in ranks]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--train-rows', type=int, choices=(512, 1024, 2048), default=512)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    torch.set_num_threads(8)
    files = {}
    weights = {}
    for part in PARTS:
        for quant in (False, True):
            w, path, sha = weight(part, quant)
            weights[part, quant] = w
            files[path] = sha
    capture = ROOT / 'capture/layer00.npz'
    files[str(capture)] = digest(capture)
    with np.load(capture) as f:
        inputs = {'train': unpack_bf16(f['train_gate_up'][:args.train_rows]),
                  'held': unpack_bf16(f['validation_gate_up'][:1024])}
    rows = {}
    for split, x in inputs.items():
        _, target = mlp(x, *(weights[p, False] for p in PARTS))
        features, base = mlp(x, *(weights[p, True] for p in PARTS))
        rows[split] = (target, features, base)
    y, h, q = rows['train']
    ranks = (8, 16, 32)
    factors, lam, spectral_gains = fit(h, y - q, ranks, 0.01)
    result = {'format': 'layer0-frozen-hidden-optimal-ridge/1',
              'source_sha256': digest(Path(__file__)), 'inputs_sha256': files,
              'train_rows': args.train_rows, 'held_rows': len(inputs['held']),
              'ridge_lambda': lam, 'ranks': list(ranks),
              'ridge_whitened_energy_removed': spectral_gains,
              'observation': 'FP32 SwiGLU original-producer captured inputs; frozen binary gate/up/down; rank-optimal continuous ridge map followed by paid FP16 storage',
              'results': {}}
    for split, (target, features, base) in rows.items():
        result['results'][split] = {'binary': error(target, base)}
        for rank, (right, left, bias) in factors.items():
            prediction = base + (features @ right) @ left.T + bias
            result['results'][split][f'rank{rank}'] = error(target, prediction)
    for rank in ranks:
        result['results'][f'rank{rank}_bytes'] = 2 * (rank * (3072 + 1024) + 1024)
        result['results'][f'rank{rank}_factor_terms_per_token'] = rank * (3072 + 1024)
    out = args.output or ROOT / f'mlp-optimal-response-{args.train_rows}.json'
    out.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result['results'], indent=2))


if __name__ == '__main__':
    main()
