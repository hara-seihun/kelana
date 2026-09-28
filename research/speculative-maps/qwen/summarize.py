#!/usr/bin/env python3
"""Collect the fixed first-round receipts without running models."""
import json
from pathlib import Path

DATA = Path('/path/to/workspace/data/kelana-speculative')


def load(name):
    return json.loads((DATA/name).read_text())


def main():
    out = {'data': str(DATA), 'captures': {}, 'fits': {}, 'evaluations': {},
           'transition_bridge': load('transition-bridge.json')}
    for name in ['train', 'validation', 'validation-greedy', 'test-greedy']:
        out['captures'][name] = load(name+'.json')
    for steps in [200, 1000]:
        for arm in ['independent', 'conditional']:
            out['fits'][f'{arm}-s{steps}'] = load(f'{arm}-s{steps}.json')
        out['evaluations'][str(steps)] = load(f'evaluation-s{steps}.json')
    destination = Path(__file__).with_name('results.json')
    destination.write_text(json.dumps(out, indent=2)+'\n')
    print(destination)


if __name__ == '__main__':
    main()
