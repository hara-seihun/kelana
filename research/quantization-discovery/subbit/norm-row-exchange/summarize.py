#!/usr/bin/env python3
"""Combine fixed-budget causal K norm row exchanges for the two recorded layers."""
import hashlib
import json
from pathlib import Path

import numpy as np

DATA = Path('/path/to/workspace/data/kelana-subbit/norm-row-exchange')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    for layer in (0, 14):
        paths = [DATA/f'layer{layer:02d}-group{g}.json' for g in range(8)]
        groups = [json.loads(path.read_text()) for path in paths]
        assert all(r['layer'] == layer and r['group'] == g and r['rounds_requested'] == 2
                   for g, r in enumerate(groups))
        for field in ('source_sha256', 'score_receipt_sha256', 'model_sha256', 'capture_sha256',
                      'paid_q_sha256', 'paid_k_sha256'):
            assert len({r[field] for r in groups}) == 1, field
        assert all(len(r['exchanged_rows']) == 16 and len(set(r['exchanged_rows'])) == 16
                   and len(r['selected_planes']) == 16 for r in groups)
        means = {}
        windows = {}
        for arm in ('parent', 'exchanged_fixed_coeff', 'exchanged_refit'):
            values = np.array([r['held_kl_by_window'][arm] for r in groups])
            assert values.shape == (8, 4)
            means[arm] = float(values.mean())
            windows[arm] = values.mean(axis=0).tolist()
        receipt = {'layer': layer, 'held_mean_two_head_kl': means, 'held_kl_by_window': windows,
                   'exchanges_per_group': [len(r['exchanges']) for r in groups],
                   'group_held_kl': [{arm: float(np.mean(r['held_kl_by_window'][arm]))
                                      for arm in means} for r in groups],
                   'raw_rows_per_layer': 384, 'signed_factor_terms_per_token': 360448,
                   'score_products_per_key_two_heads': 512, 'key_cache_bytes_per_token': 512,
                   'group_receipt_sha256': {path.name: sha(path) for path in paths},
                   'source_sha256': groups[0]['source_sha256'],
                   'model_sha256': groups[0]['model_sha256'],
                   'capture_sha256': groups[0]['capture_sha256'],
                   'paid_q_sha256': groups[0]['paid_q_sha256'],
                   'paid_k_sha256': groups[0]['paid_k_sha256']}
        path = DATA/f'layer{layer:02d}-summary.json'
        path.write_text(json.dumps(receipt, indent=2)+'\n')
        print(layer, means, 'windows', windows['exchanged_refit'])


if __name__ == '__main__':
    main()
