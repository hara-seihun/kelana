#!/usr/bin/env python3
"""Aggregate matched sparse/full denominator observers across eight GQA groups."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    args = parser.parse_args()
    paths = [DATA/f'cache-slack-norm/layer{args.layer:02d}-group{g}.json' for g in range(8)]
    reports = [json.loads(p.read_text()) for p in paths]
    assert [r['group'] for r in reports] == list(range(8))
    for name in ('source_sha256', 'norm_source_sha256', 'cache_slack_receipt_sha256',
                 'model_sha256', 'capture_sha256', 'paid_q_sha256', 'paid_k_sha256', 'train_query_positions'):
        assert all(r[name] == reports[0][name] for r in reports), name
    assert all(len(r['selected_planes']) == 16 for r in reports)
    oldpath = DATA/f'causal-key-norm/layer{args.layer:02d}-summary.json'
    old = json.loads(oldpath.read_text())
    arms = {name: np.mean([r['held_kl_by_window'][name] for r in reports], axis=0).tolist()
            for name in ('full', 'unfit', 'causal_fit')}
    arms.update({f'old_112_{name}': old['held_kl_by_window'][name]
                 for name in ('full', '16_untrained', '16_causal_fit')})
    result = {'layer': args.layer, 'group_sha256': {p.name: sha(p) for p in paths},
              'old_summary_sha256': sha(oldpath), 'summarizer_sha256': sha(Path(__file__)),
              'held_kl_by_window': arms, 'mean_held_kl': {name: float(np.mean(v)) for name, v in arms.items()},
              'cost': {'new_selected_rows': 256, 'new_extra_rows': 128, 'old_selected_rows': 224,
                       'old_extra_rows': 128, 'rank': 256, 'common_signed_terms': 262144,
                       'new_output_signed_terms': 98304, 'old_output_signed_terms': 90112,
                       'full_output_signed_terms': 262144,
                       'new_selected_score_products_per_key_two_heads': 512,
                       'old_selected_score_products_per_key_two_heads': 448,
                       'padded_key_cache_bytes_both': 512}}
    out = DATA/f'cache-slack-norm/layer{args.layer:02d}-summary.json'
    out.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result['mean_held_kl'], indent=2))


if __name__ == '__main__':
    main()
