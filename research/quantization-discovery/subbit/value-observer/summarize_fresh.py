#!/usr/bin/env python3
"""Aggregate immutable fresh single-layer windows without selecting on them."""
import hashlib
import json
from pathlib import Path

import numpy as np

DATA = Path('/path/to/workspace/data/kelana-subbit/value-observer')
OUT = Path(__file__).with_name('fresh-loss-results.json')
PANELS = {0: {'test': [(0, 3), (4, 11)], 'validation': [(0, 7)]},
          14: {'test': [(0, 7)], 'validation': [(0, 7)]}}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    result = {'format': 'qwen-fresh-narrow-value-summary/1', 'panels': {}}
    for layer, splits in PANELS.items():
        for split, ranges in splits.items():
            paths = [DATA / f'fresh-layer{layer:02d}-{split}-{a:03d}-{b:03d}.json'
                     for a, b in ranges]
            receipts = [json.loads(path.read_text()) for path in paths]
            assert all(p['layer'] == layer and p['split'] == split for p in receipts)
            assert len({p['fixture_tokens_sha256'] for p in receipts}) == 1
            assert len({p['model_weights_sha256'] for p in receipts}) == 1
            assert len({json.dumps(p['images'], sort_keys=True) for p in receipts}) == 1
            assert len({p['joint_rank28_image_sha256'] for p in receipts}) == 1
            rows = [row for panel in receipts for row in panel['windows']]
            assert sorted(row['index'] for row in rows) == list(range(len(rows)))
            names = ('reference', 'uniform_24', 'train_causal_optimum', 'joint_rank28')
            nll = {arm: np.array([row['arms'][arm]['nll'] for row in rows]) for arm in names}
            kl = {arm: np.array([row['arms'][arm]['teacher_kl'] for row in rows]) for arm in names}
            rng = np.random.default_rng(2514)
            draw = rng.integers(0, len(rows), (10000, len(rows)))
            differences = {}
            for metric, values in (('nll', nll), ('teacher_kl', kl)):
                for control in ('uniform_24', 'joint_rank28'):
                    delta = values['train_causal_optimum'] - values[control]
                    differences[f'selected_minus_{control}_{metric}'] = {
                        'mean': float(delta.mean()),
                        'paired_window_bootstrap_95': np.quantile(delta[draw].mean(1), [.025, .975]).tolist(),
                        'windows_selected_better': int((delta < 0).sum())}
            result['panels'][f'layer{layer:02d}_{split}'] = {
                'windows': len(rows), 'predictions': len(rows)*255,
                'raw_panels': {str(path): sha(path) for path in paths},
                'fixture_tokens_sha256': receipts[0]['fixture_tokens_sha256'],
                'model_weights_sha256': receipts[0]['model_weights_sha256'],
                'images': receipts[0]['images'],
                'joint_rank28_image_sha256': receipts[0]['joint_rank28_image_sha256'],
                'metrics': {arm: {'nll': float(nll[arm].mean()),
                                  'teacher_kl': float(kl[arm].mean()),
                                  'argmax_agreement': float(np.mean([row['arms'][arm]['argmax_agreement'] for row in rows]))}
                            for arm in names},
                'paired': differences,
                'per_window_nll': {arm: nll[arm].tolist() for arm in names}}
    OUT.write_text(json.dumps(result, indent=2) + '\n')
    for name, row in result['panels'].items():
        print(name, row['windows'], {arm: round(m['nll'], 6) for arm, m in row['metrics'].items()},
              row['paired']['selected_minus_uniform_24_nll'])


if __name__ == '__main__':
    main()
