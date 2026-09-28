#!/usr/bin/env python3
"""Fit the best diagonal RoPE-plane score decoder on pinned Q/K covariances."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from safetensors import safe_open
import torch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'rope-plane-consumer'))
from planes import digest, score_gram, select_planes
sys.path.insert(0, str(ROOT / 'rope-key-orbit'))
from orbit import orbit_covariance


def fit(matrix, selected):
    indices = np.array(sorted(selected))
    block = matrix[np.ix_(indices, indices)]
    target = matrix[indices].sum(axis=1)
    # Covariance Gram is positive definite for the pinned matrices. The
    # pseudoinverse also defines the projection when the observation is singular.
    gain = np.linalg.lstsq(block, target, rcond=1e-12)[0]
    return gain


def error(matrix, selected, gain):
    indices = np.array(sorted(selected))
    target = matrix[indices].sum(axis=1)
    block = matrix[np.ix_(indices, indices)]
    return float(matrix.sum() - 2 * gain @ target + gain @ block @ gain)


def exchange(matrix, selected):
    selected = sorted(selected)
    while True:
        current = error(matrix, selected, fit(matrix, selected))
        winner = None
        for leave in selected:
            for enter in range(64):
                if enter in selected:
                    continue
                candidate = sorted((set(selected) - {leave}) | {enter})
                trial = error(matrix, candidate, fit(matrix, candidate))
                if trial < current - matrix.sum() * 1e-12:
                    current, winner = trial, candidate
        if winner is None:
            return selected
        selected = winner


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--allocation', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/rope-plane-rate-allocation/receipt.json'))
    args = parser.parse_args()
    allocation = json.loads(args.allocation.read_text())
    model_path = args.model / 'model.safetensors'
    config_path = args.model / 'config.json'
    config = json.loads(config_path.read_text())
    result = dict(model_sha256=digest(model_path), config_sha256=digest(config_path), source_sha256=digest(Path(__file__)),
                  allocation_sha256=digest(args.allocation), horizon=4096,
                  observation='independent isotropic hidden inputs, two original Q heads and original K, real score variance', layers={})
    assert allocation['model_sha256'] == result['model_sha256'] and allocation['horizon'] == result['horizon']
    with safe_open(model_path, framework='pt', device='cpu') as file:
        for layer in (0, 14):
            stem = f'model.layers.{layer}.self_attn.'
            kw = file.get_tensor(stem + 'k_proj.weight').to(dtype=torch.float64).numpy()
            qw = file.get_tensor(stem + 'q_proj.weight').to(dtype=torch.float64).numpy()
            groups = []
            for g in range(8):
                key = kw[128*g:128*(g+1)]
                query = np.concatenate((qw[256*g:256*g+128], qw[256*g+128:256*(g+1)]), axis=1) / np.sqrt(2)
                matrix = score_gram(query, orbit_covariance(key, config['rope_theta'], 4096))
                prior, _, _ = select_planes(matrix, 14)
                selected = exchange(matrix, prior)
                total = float(matrix.sum())
                choices = {}
                for name, mask in [('uniform', prior), ('uniform-exchanged', selected),
                                   ('capped16', allocation['layers'][str(layer)]['weighted']['choices']['capped16']['masks'][g])]:
                    alpha = fit(matrix, mask)
                    rounded = alpha.astype(np.float16).astype(np.float64)
                    baseline = error(matrix, mask, np.ones(len(mask)))
                    fitted = error(matrix, mask, alpha)
                    paid = error(matrix, mask, rounded)
                    choices[name] = dict(planes=sorted(mask), baseline_retained=1-baseline/total,
                                         real_gain_retained=1-fitted/total, fp16_gain_retained=1-paid/total,
                                         fp16_gains=rounded.tolist(), max_gain=float(max(alpha)), min_gain=float(min(alpha)))
                groups.append(dict(group=g, total_score_variance=total, choices=choices,
                                   gram_sha256=hashlib.sha256(np.ascontiguousarray(matrix).tobytes()).hexdigest()))
            result['layers'][str(layer)] = groups
            total = sum(x['total_score_variance'] for x in groups)
            for name in ('uniform', 'uniform-exchanged', 'capped16'):
                print(layer, name, 'baseline/real/fp16', *[
                    round(sum(x['total_score_variance']*x['choices'][name][field] for x in groups)/total, 8)
                    for field in ('baseline_retained', 'real_gain_retained', 'fp16_gain_retained')])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
