#!/usr/bin/env python3
"""Independent set-partition oracle and mean-decoder replay for near-full carriers."""
import itertools
import json
from pathlib import Path

import numpy as np

from exact import exact_near_full


def partitions(n):
    labels = [0] * n
    def visit(pos, largest):
        if pos == n:
            yield [tuple(i for i, label in enumerate(labels) if label == c)
                   for c in range(largest+1)]
            return
        for label in range(largest+2):
            labels[pos] = label
            yield from visit(pos+1, max(largest, label))
    yield from visit(1, 0)


def oracle(y, m):
    centered = y - y.mean(axis=0)
    energy = np.sum(centered*centered)
    return min(sum(np.sum((y[list(s)]-y[list(s)].mean(axis=0))**2)
                   for s in p)/energy for p in partitions(len(y)) if len(p) <= m)


def test():
    for seed in range(4):
        y = np.random.default_rng(seed).normal(size=(6, 4))
        result = exact_near_full(y)
        for m in (4, 5):
            v = result[str(m)]
            assert np.isclose(v['sse_fraction'], oracle(y, m), rtol=1e-12)
            clusters = v['merged_states']
            assert 6-sum(len(s)-1 for s in clusters) == m
            assert len(set(itertools.chain.from_iterable(clusters))) == sum(map(len, clusters))
            reconstructed = y.copy()
            for s in clusters:
                reconstructed[list(s)] = y[list(s)].mean(axis=0)
            assert np.isclose(v['sse_fraction'],
                              np.sum((y-reconstructed)**2)/np.sum((y-y.mean(axis=0))**2), rtol=1e-12)
    triple = np.array([[0.0], [0.01], [0.02], [10.0], [20.0], [30.0]])
    assert len(exact_near_full(triple)['4']['merged_states']) == 1
    assert np.isclose(exact_near_full(triple)['4']['sse_fraction'], oracle(triple, 4))
    directory = Path(__file__).resolve().parent
    for path in directory.glob('layer??-anchor???.json'):
        record = json.loads(path.read_text())
        assert len(record['cases']) == 9
        for case in record['cases']:
            for m in ('25', '26'):
                value = case['optima'][m]
                assert np.isclose(value['sse_fraction'], value['rel_rms']**2)
                assert 27-sum(len(s)-1 for s in value['merged_states']) == int(m)
    print('six-state exhaustive partitions, triple branch and all 36 recorded partitions pass')


if __name__ == '__main__':
    test()
