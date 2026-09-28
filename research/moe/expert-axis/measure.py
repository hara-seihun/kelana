#!/usr/bin/env python3
"""Expert-index low-rank gate/up map, with a composed SwiGLU/down control."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe/experts/layer-0-0-16')


def bf16(path, shape):
    raw = np.memmap(path, dtype='<u2', mode='r', shape=shape)
    return (np.asarray(raw, dtype=np.uint32) << 16).view(np.float32)


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def rms(error, reference):
    return float(np.sqrt(np.sum(np.square(error, dtype=np.float64)) /
                         np.sum(np.square(reference, dtype=np.float64))))


def swiglu(z):
    gate, up = np.split(z, 2, axis=0)
    return (gate / (1 + np.exp(-gate))) * up


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', type=Path, default=BASE)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--samples', type=int, default=32)
    args = parser.parse_args()
    gate_file, down_file = (args.base / (name + '.bf16') for name in ('gate_up_proj', 'down_proj'))
    w = bf16(gate_file, (16, 1024, 2048))
    down = bf16(down_file, (16, 2048, 512))
    flat = w.reshape(16, -1)
    gram = np.asarray(flat @ flat.T, dtype=np.float64)
    eigenvalues, eigenvectors = np.linalg.eigh(gram)
    order = np.argsort(eigenvalues)[::-1]
    eigenvalues = np.maximum(eigenvalues[order], 0)
    eigenvectors = eigenvectors[:, order]
    energy = float(np.sum(eigenvalues))
    fractions = np.cumsum(eigenvalues) / energy
    rng = np.random.default_rng(20260923)
    x = rng.standard_normal((2048, args.samples), dtype=np.float32)
    scores = rng.standard_normal((8, args.samples), dtype=np.float32)
    scores -= scores.max(axis=0)
    probabilities = np.exp(scores)
    probabilities /= probabilities.sum(axis=0)
    selected = np.stack([rng.permutation(16)[:8] for _ in range(args.samples)], axis=1)
    route = np.zeros((16, args.samples), dtype=np.float32)
    np.put_along_axis(route, selected, probabilities, axis=0)
    exact_z = np.stack([w[e] @ x for e in range(16)])
    exact_y = np.stack([down[e] @ swiglu(exact_z[e]) for e in range(16)])
    weighted = np.einsum('es,eds->ds', route, exact_y)
    rows = []
    for rank in (0, 1, 2, 4, 7, 8, 12, 16):
        if rank == 0:
            approx_z = np.zeros_like(exact_z)
        elif rank == 16:
            approx_z = exact_z.copy()
        else:
            # Basis matrices live in the original 1024-by-2048 coordinate.
            # This is an expert-axis factor, not a shared 2048-input basis.
            basis = np.einsum('ek,eoi->koi', eigenvectors[:, :rank], w, optimize=True)
            prepared = np.stack([b @ x for b in basis])
            approx_z = np.einsum('ek,kos->eos', eigenvectors[:, :rank], prepared, optimize=True)
        approx_y = np.stack([down[e] @ swiglu(approx_z[e]) for e in range(16)])
        routed = np.einsum('es,eds->ds', route, approx_y)
        rows.append({
            'rank': rank,
            'retained_isotropic_gate_up_energy_16': float(fractions[rank-1]) if rank else 0.,
            'gate_up_relative_rms_all16': rms(approx_z - exact_z, exact_z),
            'routed_post_swiglu_down_relative_rms': rms(routed - weighted, weighted),
            'bf16_shared_basis_bytes': 2 * rank * 1024 * 2048,
            'bf16_coefficient_bytes': 2 * 16 * rank,
            'eight_expert_gate_up_product_ratio': (rank * 1024 * 2048 + 8 * rank * 1024) / (8 * 1024 * 2048),
        })
    result = {
        'model_revision': '995ad96eacd98c81ed38be0c5b274b04031597b0',
        'gate_up_sha256': digest(gate_file), 'down_sha256': digest(down_file),
        'source_sha256': digest(Path(__file__)), 'shape_gate_up': list(w.shape),
        'shape_down': list(down.shape), 'samples': args.samples, 'seed': 20260923,
        'route': 'uniform eight without replacement from sixteen; independently drawn softmax Gaussian scores per sample',
        'inputs': 'shared seeded unit normal, not model activations',
        'total_gate_up_weight_energy': energy,
        'expert_axis_energy_eigenvalues': eigenvalues.tolist(),
        'expert_norms': np.sqrt(np.diag(gram)).tolist(),
        'maximum_absolute_pairwise_weight_cosine': float(np.max(np.abs(gram / np.sqrt(np.outer(np.diag(gram), np.diag(gram))) - np.eye(16)))),
        'rank_thresholds': {str(t): int(np.searchsorted(fractions, t) + 1) for t in (.5, .9, .95)},
        'results': rows,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'thresholds': result['rank_thresholds'], 'rows': rows}, indent=2))


if __name__ == '__main__':
    main()
