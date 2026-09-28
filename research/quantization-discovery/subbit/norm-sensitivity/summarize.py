#!/usr/bin/env python3
"""Aggregate train-selected support across the eight groups of each frozen layer."""
import hashlib
import json
from pathlib import Path

import numpy as np

DATA = Path('/path/to/workspace/data/kelana-subbit')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    directory = DATA/'norm-sensitivity'
    for layer in (0, 14):
        original, selected, groups = [], [], []
        common = None
        for group in range(8):
            parent_path = DATA/f'cache-slack-norm/layer{layer:02d}-group{group}.json'
            parent = json.loads(parent_path.read_text())
            candidate_path = directory/f'layer{layer:02d}-group{group}.json'
            candidate = json.loads(candidate_path.read_text()) if candidate_path.exists() else None
            if candidate is not None:
                assert candidate['parent_receipt_sha256'] == digest(parent_path)
                assert (candidate['layer'], candidate['group']) == (layer, group)
                assert candidate['held_kl_by_window_original'] == parent['held_kl_by_window']['causal_fit']
            else:
                assert all(a > .1 for a in parent['denominator_coeff_fp16'][1:])
            identity = tuple(parent[k] for k in ('model_sha256', 'capture_sha256', 'paid_q_sha256', 'paid_k_sha256'))
            assert common is None or common == identity
            common = identity
            before = parent['held_kl_by_window']['causal_fit']
            keep = candidate is not None and candidate['train_ce_without_penalty']['refit'] <= candidate['train_ce_without_penalty']['original']
            after = candidate['held_kl_by_window_refit'] if keep else before
            original.append(before)
            selected.append(after)
            groups.append({'group': group, 'delete': candidate['deleted_bins'] if keep else [],
                           'rows_saved': candidate['deleted_raw_rows'] if keep else 0,
                           'parent_sha256': digest(parent_path),
                           'candidate_sha256': digest(candidate_path) if candidate else None,
                           'held_group_kl_before': float(np.mean(before)),
                           'held_group_kl_after': float(np.mean(after))})
        raw_rows = 384 - sum(item['rows_saved'] for item in groups)
        result = {'layer': layer, 'group_receipts': groups,
                  'model_capture_factor_sha256': common,
                  'raw_k_rows': raw_rows,
                  'factor_signed_terms_per_token': 262144 + 256*raw_rows,
                  'held_kl_before_by_window': np.mean(original, axis=0).tolist(),
                  'held_kl_after_by_window': np.mean(selected, axis=0).tolist(),
                  'held_kl_before': float(np.mean(original)),
                  'held_kl_after': float(np.mean(selected)),
                  'source_sha256': digest(Path(__file__))}
        path = directory/f'layer{layer:02d}-summary.json'
        path.write_text(json.dumps(result, indent=2)+'\n')
        print(layer, raw_rows, result['held_kl_before'], result['held_kl_after'])


if __name__ == '__main__':
    main()
