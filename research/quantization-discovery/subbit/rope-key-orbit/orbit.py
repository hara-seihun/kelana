#!/usr/bin/env python3
"""Exact finite-position covariance for a position-independent linear RoPE key cache."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from safetensors import safe_open
import torch


def orbit_covariance(weight, theta, positions):
    dim = weight.shape[0]
    half = dim // 2
    freqs = theta ** (-np.arange(half, dtype=np.float64) / half)
    angles = np.arange(positions, dtype=np.float64)[:, None] * freqs
    c, s = np.cos(angles), np.sin(angles)
    cc, cs = c.T @ c / positions, c.T @ s / positions
    sc, ss = s.T @ c / positions, s.T @ s / positions
    base = weight @ weight.T
    a, b, d = base[:half, :half], base[:half, half:], base[half:, half:]
    tl = cc * a - cs * b - sc * b.T + ss * d
    tr = cs * a + cc * b - ss * b.T - sc * d
    br = ss * a + sc * b + cs * b.T + cc * d
    return np.block([[tl, tr], [tr.T, br]])


def retained(cov, ranks):
    eigen = np.linalg.eigvalsh(cov)[::-1]
    return {str(rank): float(eigen[:rank].sum() / eigen.sum()) for rank in ranks}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    config_path = args.model / 'config.json'
    model_path = args.model / 'model.safetensors'
    config = json.loads(config_path.read_text())
    dim = config['head_dim']
    groups = config['num_key_value_heads']
    ranks = (28, 64, 96)
    with model_path.open('rb') as model_file:
        model_digest = hashlib.file_digest(model_file, 'sha256').hexdigest()
    result = {
        'model_sha256': model_digest,
        'source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'config_sha256': hashlib.sha256(config_path.read_bytes()).hexdigest(),
        'theta': config['rope_theta'], 'head_dim': dim, 'kv_groups': groups,
        'positions': [256, 4096], 'ranks': list(ranks),
        'domain': 'isotropic real input and isotropic score query, original BF16 K weights cast to FP64',
        'layers': {},
    }
    with safe_open(model_path, framework='pt', device='cpu') as file:
        for layer in (0, 14):
            key = f'model.layers.{layer}.self_attn.k_proj.weight'
            matrix = file.get_tensor(key).to(dtype=torch.float64).numpy()
            assert matrix.shape[0] == groups * dim, matrix.shape
            entries = []
            for group in range(groups):
                weight = matrix[group * dim:(group + 1) * dim]
                base = weight @ weight.T
                first_column = weight[:, 0]
                complex_magnitudes = np.hypot(first_column[:dim // 2], first_column[dim // 2:])
                assert np.allclose(orbit_covariance(weight, config['rope_theta'], 1), base, atol=1e-11)
                entry = {'group': group, 'unrotated': retained(base, ranks), 'orbit': {},
                         'first_column_min_plane_magnitude': float(complex_magnitudes.min()),
                         'key_projection_min_singular_value': float(np.linalg.svd(weight, compute_uv=False)[-1])}
                for n in result['positions']:
                    cov = orbit_covariance(weight, config['rope_theta'], n)
                    entry['orbit'][str(n)] = retained(cov, ranks)
                entries.append(entry)
            result['layers'][str(layer)] = entries
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    for layer, entries in result['layers'].items():
        for n in result['positions']:
            print('layer', layer, 'positions', n, 'rank28 unrotated/orbit means',
                  round(np.mean([e['unrotated']['28'] for e in entries]), 6),
                  round(np.mean([e['orbit'][str(n)]['28'] for e in entries]), 6),
                  'orbit range', round(min(e['orbit'][str(n)]['28'] for e in entries), 6),
                  round(max(e['orbit'][str(n)]['28'] for e in entries), 6))


if __name__ == '__main__':
    main()
