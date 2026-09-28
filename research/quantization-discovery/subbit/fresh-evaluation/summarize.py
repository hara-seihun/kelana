#!/usr/bin/env python3
"""Paired per-window NLL, KL and argmax uncertainty from immutable panel rows."""
import argparse
import json
import math
from pathlib import Path

import numpy as np

ARMS = ('spectral_seed', 'spectral_mse_sweeps', 'spectral_attention', 'binary_coordinate_sweeps')
METRICS = ('nll', 'teacher_kl', 'argmax_agreement')


def weighted_mean(rows, arm, metric):
    key = {'nll': 'nll_sum', 'teacher_kl': 'teacher_kl_sum',
           'argmax_agreement': 'argmax_agreements'}[metric]
    return sum(row['arms'][arm][key] for row in rows) / sum(row['predictions'] for row in rows)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--bootstrap', type=int, default=5000)
    a = p.parse_args()
    manifest = json.loads((a.data / 'manifest.json').read_text())
    panels = list((a.data / 'panels').glob('*.jsonl'))
    rows = {}
    for path in panels:
        for line in path.read_text().splitlines():
            entry = json.loads(line)
            key = f"{entry['split']}_{entry['length']}"
            index = entry['index']
            if entry['tokens_sha256'] != manifest['tokens_sha256']:
                raise ValueError(f'{path}: different token image')
            if entry['token_start'] != manifest['windows'][key]['starts'][index]:
                raise ValueError(f'{path}: selected window changed')
            if (key, index) in rows:
                raise ValueError(f'duplicate result {key}[{index}]')
            rows[key, index] = entry
    all_hashes = {json.dumps(row['images_sha256'], sort_keys=True) for row in rows.values()}
    if len(all_hashes) != 1:
        raise ValueError('frozen images differ between groups')
    rng = np.random.default_rng(20260922)
    summary = {'manifest': str(a.data / 'manifest.json'),
               'tokens_sha256': manifest['tokens_sha256'], 'panels': [str(path) for path in panels],
               'bootstrap_replicates': a.bootstrap, 'splits': {}}
    for key, spec in manifest['windows'].items():
        expected = len(spec['starts'])
        present = [rows[key, i] for i in range(expected) if (key, i) in rows]
        if len(present) != expected:
            raise ValueError(f'{key} has {len(present)}/{expected} rows; missing '
                             f'{[i for i in range(expected) if (key,i) not in rows]}')
        observed_hashes = {json.dumps(r['images_sha256'], sort_keys=True) for r in present}
        if len(observed_hashes) != 1:
            raise ValueError(f'{key}: image identities differ between panels')
        group = {'count': expected, 'length': spec['length'],
                 'predictions': sum(row['predictions'] for row in present),
                 'images_sha256': present[0]['images_sha256'], 'arms': {}}
        draw = rng.integers(0, expected, size=(a.bootstrap, expected))
        for arm in ('reference', *ARMS):
            metrics = {}
            for metric in METRICS:
                mean = weighted_mean(present, arm, metric)
                scores = np.array([weighted_mean([row], arm, metric) for row in present])
                bootstrap = scores[draw].mean(axis=1)
                metrics[metric] = {'mean': mean, 'window_bootstrap_95':
                    np.quantile(bootstrap, [.025, .975]).tolist()}
                if arm != 'reference':
                    base = np.array([weighted_mean([row], 'reference', metric) for row in present])
                    against = np.array([weighted_mean([row], 'binary_coordinate_sweeps', metric)
                                        for row in present])
                    diff_reference = scores - base
                    diff_binary = scores - against
                    metrics[metric]['minus_reference'] = {'mean': float(diff_reference.mean()),
                        'window_bootstrap_95': np.quantile(diff_reference[draw].mean(axis=1), [.025,.975]).tolist()}
                    metrics[metric]['minus_binary_coordinate'] = {'mean': float(diff_binary.mean()),
                        'window_bootstrap_95': np.quantile(diff_binary[draw].mean(axis=1), [.025,.975]).tolist(),
                        'wins': int((diff_binary < 0).sum() if metric != 'argmax_agreement'
                                    else (diff_binary > 0).sum())}
            if arm != 'reference':
                metrics['perplexity'] = math.exp(metrics['nll']['mean'])
            group['arms'][arm] = metrics
        group['per_window'] = present
        summary['splits'][key] = group
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(summary, indent=2) + '\n')
    for key, group in summary['splits'].items():
        print(key, group['count'], 'reference NLL', group['arms']['reference']['nll']['mean'])
        for arm in ARMS:
            m = group['arms'][arm]
            print(arm, 'NLL', m['nll']['mean'], 'KL', m['teacher_kl']['mean'],
                  'agreement', m['argmax_agreement']['mean'],
                  'NLL minus binary 95%', m['nll']['minus_binary_coordinate']['window_bootstrap_95'])


if __name__ == '__main__':
    main()
