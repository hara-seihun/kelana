#!/usr/bin/env python3
"""Exact finite-policy ceiling from the frozen complete paid-gain receipts."""
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path('/path/to/workspace/data/kelana-subbit/full-model')
ARMS = ('1,1', '2,1.75', '2,1.5')


def load(names, split, indices, arms):
    paths = [ROOT / name for name in names]
    records = [(path, json.loads(path.read_text())) for path in paths]
    first = records[0][1]
    windows = []
    for path, record in records:
        assert record['split'] == split
        assert record['gains'] == list(arms)
        assert record['source_sha256'] == first['source_sha256']
        assert record['inputs_sha256'] == first['inputs_sha256']
        assert record['payload_bytes'] == first['payload_bytes']
        assert record['online_terms_delta'] == 0
        assert [w['index'] for w in record['windows']] == list(range(record['start'], record['start'] + record['count']))
        windows.extend(record['windows'])
    windows.sort(key=lambda w: w['index'])
    assert [w['index'] for w in windows] == list(indices)
    assert len({w['token_sha256'] for w in windows}) == len(windows)
    assert all(set(w['nll']) == set(arms) for w in windows)
    return windows, {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}, first


def mean(values):
    return sum(values) / len(values)


def summarize(windows, arms):
    averages = {arm: mean([w['nll'][arm] for w in windows]) for arm in arms}
    fixed = min(averages, key=averages.get)
    winners = [min(arms, key=w['nll'].get) for w in windows]
    oracle = mean([w['nll'][winner] for w, winner in zip(windows, winners)])
    return {
        'mean_nll_by_arm': averages,
        'best_fixed': fixed,
        'best_fixed_nll': averages[fixed],
        'gold_label_oracle_nll': oracle,
        'maximum_per_window_selection_gain': averages[fixed] - oracle,
        'base_to_oracle_gain': averages['1,1'] - oracle,
        'winner_counts': dict(Counter(winners)),
        'per_window': [{'index': w['index'], 'token_sha256': w['token_sha256'],
                        'winner': winner, 'fixed_minus_oracle': w['nll'][fixed] - w['nll'][winner],
                        'base_minus_oracle': w['nll']['1,1'] - w['nll'][winner]}
                       for w, winner in zip(windows, winners)],
    }


def main():
    train_names = ['complete-paid-fit-train-' + n + '.json' for n in ('0', '1-2', '3-4', '5-6', '7')]
    train, train_hashes, _ = load(train_names, 'train', range(8),
                                  ('1,1', '1,1.5', '1,2', '1.5,1', '1.5,1.5',
                                   '1.5,2', '2,1', '2,1.5', '2,2'))
    result = {'format': 'complete-paid-finite-oracle/1', 'train_receipts_sha256': train_hashes,
              'train': summarize(train, tuple(train[0]['nll'])), 'held': {}}
    result['train']['leave_one_window_out_selected'] = [
        min(train[0]['nll'], key=lambda a: mean([w['nll'][a] for w in train if w['index'] != i]))
        for i in range(8)]
    for split, indices in (('validation', range(8, 16)), ('test', range(16, 24))):
        names = [f'complete-paid-evaluate-{split}-{i}-{i+3}.json' for i in (indices.start, indices.start + 4)]
        windows, hashes, first = load(names, split + '_256', indices, ARMS)
        result['held'][split] = summarize(windows, ARMS)
        result['held'][split]['receipts_sha256'] = hashes
        result['held'][split]['source_sha256'] = first['source_sha256']
        result['held'][split]['inputs_sha256'] = first['inputs_sha256']
        result['held'][split]['payload_bytes'] = first['payload_bytes']
        result['held'][split]['payload_bpw'] = first['payload_bpw']
    output = ROOT / 'complete-paid-finite-oracle.json'
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(output)
    for split, panel in result['held'].items():
        print(split, panel['mean_nll_by_arm'], 'oracle', panel['gold_label_oracle_nll'],
              'base-to-oracle', panel['base_to_oracle_gain'])


if __name__ == '__main__':
    main()
