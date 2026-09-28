#!/usr/bin/env python3
"""Aggregate the eight disjoint group fits without losing per-window evidence."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--data', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/causal-key-norm'))
    args = parser.parse_args()
    paths = [args.data/f'layer{args.layer:02d}-group{g}.json' for g in range(8)]
    receipts = [json.loads(path.read_text()) for path in paths]
    assert [r['group'] for r in receipts] == list(range(8))
    assert all(r['layer'] == args.layer for r in receipts)
    for key in ('source_sha256', 'model_sha256', 'capture_sha256', 'paid_q_sha256',
                'paid_k_sha256', 'previous_receipt_sha256', 'train_query_positions'):
        assert all(r[key] == receipts[0][key] for r in receipts)
    arms = {'full': [r['full_held_kl_by_window'] for r in receipts]}
    for count in ('0', '16', '32'):
        for name in receipts[0]['candidates'][count]['arms']:
            arms[f'{count}_{name}'] = [r['candidates'][count]['arms'][name]['held_kl_by_window']
                                        for r in receipts]
    result = {'layer': args.layer, 'group_receipt_sha256': {p.name: sha(p) for p in paths},
              'summarizer_sha256': sha(Path(__file__)),
              'mean_held_kl': {name: float(np.mean(values)) for name, values in arms.items()},
              'held_kl_by_window': {name: np.mean(values, axis=0).tolist() for name, values in arms.items()},
              'mean_relative_denominator_rms': {
                  f'{count}_{name}': float(np.mean([r['candidates'][count]['arms'][name]['held_relative_denominator_rms']
                                                   for r in receipts]))
                  for count in ('0', '16', '32') for name in receipts[0]['candidates'][count]['arms']}}
    out = args.data/f'layer{args.layer:02d}-summary.json'
    out.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
