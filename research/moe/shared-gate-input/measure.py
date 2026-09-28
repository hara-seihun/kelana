#!/usr/bin/env python3
"""Best shared-input linear projection for original Qwen3.6 BF16 gate/up experts.

This is an isotropic linear-response experiment, not a model-quality measurement.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.linalg import eigh

DEFAULT = Path('/path/to/workspace/data/qwen-moe/experts/layer-0-0-16/gate_up_proj.bf16')


def load_bf16(path):
    raw = np.memmap(path, dtype='<u2', mode='r', shape=(16, 1024, 2048))
    return (np.asarray(raw, dtype=np.uint32) << 16).view(np.float32)


def analyze(weights, ranks):
    # The shared input coordinate is reused across both gate and up branches.
    rows = weights.reshape(-1, 2048)
    gram = rows.T @ rows
    energy = float(np.trace(gram, dtype=np.float64))
    eigenvalues = eigh(gram, eigvals_only=True, check_finite=False, overwrite_a=True,
                       driver='evr')
    eigenvalues = np.maximum(eigenvalues[::-1].astype(np.float64), 0)
    shared = np.cumsum(eigenvalues) / energy
    # Selection costs no dense input transform. It is the optimal shared selection
    # within the original input-axis grammar, and an independent per-expert control.
    columns = np.einsum('eoi,eoi->ei', weights, weights, dtype=np.float64)
    shared_columns = np.cumsum(np.sort(columns.sum(axis=0))[::-1]) / energy
    independent_columns = np.cumsum(np.sort(columns, axis=1)[:, ::-1].sum(axis=0)) / energy
    thresholds = [0.5, 0.9, 0.95, 0.99]
    required = [{'retained_energy': fraction,
                 'minimum_shared_rank': int(np.searchsorted(shared, fraction) + 1),
                 'bf16_bits_per_original_weight': float(16*(2048 + 16*1024)*
                     (np.searchsorted(shared, fraction) + 1)/(16*1024*2048))}
                for fraction in thresholds]
    return {'shape': list(weights.shape), 'total_weight_energy': energy,
            'rank_thresholds': required,
            'per_rank': [{
                'rank': r,
                'best_shared_linear_fraction': float(shared[r-1]),
                'best_shared_column_fraction': float(shared_columns[r-1]),
                'independent_column_fraction': float(independent_columns[r-1]),
                'shared_bf16_weight_bytes_16_experts': 2*(2048*r + 16*1024*r),
                'original_bf16_weight_bytes_16_experts': 2*16*1024*2048,
                'shared_input_products_per_token': 2048*r,
                'eight_expert_output_products_per_token': 8*1024*r,
                'original_eight_expert_products_per_token': 8*1024*2048,
                'input_transform_bf16_bytes': 2*2048*r,
            } for r in ranks]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--image', type=Path, default=DEFAULT)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ranks', type=int, nargs='+', default=[128, 256, 512, 768, 1024, 1536])
    args = parser.parse_args()
    weights = load_bf16(args.image)
    result = analyze(weights, args.ranks)
    result['image_sha256'] = hashlib.sha256(args.image.read_bytes()).hexdigest()
    result['source_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result['per_rank'], indent=2))


if __name__ == '__main__':
    main()
