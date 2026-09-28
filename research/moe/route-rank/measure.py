#!/usr/bin/env python3
"""Oracle route-specific shared down-output coordinates on pinned BF16 experts.

The reported residual is the exact optimum for independent isotropic expert hidden
vectors with equal fixed coefficients, not language-model quality. No GPU is used.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.linalg import eigh

D, F = 2048, 512
ROUTES = ((0, 1, 2, 3, 4, 5, 6, 7),
          (8, 9, 10, 11, 12, 13, 14, 15),
          (0, 2, 4, 6, 8, 10, 12, 14))
RANKS = (256, 512, 1024)


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def covariance(weights, indices):
    gram = np.zeros((D, D), dtype=np.float32)
    for i in indices:
        w = weights[i]
        gram += w @ w.T
    return gram


def top_basis(gram):
    values, vectors = eigh(gram, subset_by_index=(D - max(RANKS), D - 1),
                           driver='evr', check_finite=False, overwrite_a=True)
    return values, vectors


def residual(weights, indices, basis, rank):
    total = 0.0
    captured = 0.0
    c = basis[:, -rank:]
    for i in indices:
        w = weights[i]
        total += float(np.sum(w.astype(np.float64) ** 2))
        captured += float(np.sum((c.T @ w).astype(np.float64) ** 2))
    return float(np.sqrt(max(0., 1. - captured / total)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('weights', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--panel', choices=('all16', 'route0', 'route1', 'route2'), required=True)
    args = parser.parse_args()
    raw = np.memmap(args.weights, dtype='<u2', mode='r')
    if raw.size != 16 * D * F:
        parser.error('expected sixteen [2048,512] BF16 experts')
    weights = (np.asarray(raw, dtype='<u4') << 16).view('<f4').reshape(16, D, F)
    panels = []
    choices = [('all16', tuple(range(16))), *[(f'route{i}', r) for i, r in enumerate(ROUTES)]]
    for name, train in choices:
        if name != args.panel:
            continue
        gram = covariance(weights, train)
        energy = float(np.trace(gram, dtype=np.float64))
        eig, basis = top_basis(gram)
        rows = {}
        for rank in RANKS:
            top = float(np.sum(eig[-rank:].astype(np.float64)))
            rows[str(rank)] = {
                'optimal_fit_relative_rms': float(np.sqrt(max(0., 1. - top / energy))),
                'direct_projection_relative_rms': [residual(weights, r, basis, rank) for r in ROUTES],
            }
        panels.append({'name': name, 'fit_experts': list(train), 'energy': energy,
                       'ranks': rows})
    out = {
        'source': str(args.weights), 'source_sha256': digest(args.weights),
        'script_sha256': digest(Path(__file__)),
        'domain': 'independent N(0,I_512) hidden per selected expert, fixed equal nonzero coefficients; exact real-weight response, first 16 layer-0 BF16 experts',
        'objective': 'minimum mean squared error of common orthogonal rank-r output projection for each fixed eight-expert route',
        'routes': [list(r) for r in ROUTES], 'panels': panels,
        'cost': {'direct_routed_down_macs': 8 * D * F,
                 'rank512_routed_down_macs': 8 * 512 * F + D * 512,
                 'rank1024_routed_down_macs': 8 * 1024 * F + D * 1024,
                 'number_of_eight_expert_routes_within_16': 12870,
                 'per_route_rank512_basis_bf16_bytes': D * 512 * 2},
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(out, indent=2) + '\n')
    print(json.dumps({'output': str(args.output), 'panels': panels}, indent=2))


if __name__ == '__main__':
    main()
