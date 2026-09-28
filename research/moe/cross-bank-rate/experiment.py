#!/usr/bin/env python3
"""Disjoint expert-bank recoding: exact composed routed response, not a linearization."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/qwen-moe')
OUT = ROOT / 'cross-bank-rate'
Q3 = ROOT / 'q3-expert-allocation'
DOWN = ROOT / 'down-rate-allocation'
HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[1] / 'down-route-quant'))
from experiment import capture  # noqa: E402


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(split):
    ids = capture(split)[0]
    q3_files = sorted(Q3.glob('part-*.npz'))
    down_files = sorted(DOWN.glob('part-*.npz'))
    assert len(q3_files) == 8 and len(down_files) == 4
    a = np.concatenate([np.load(p)[split] for p in q3_files])
    b = np.zeros_like(a)
    coverage = set()
    for path in down_files:
        with np.load(path) as part:
            first, last = int(part['first']), int(part['last'])
            assert not coverage.intersection(range(first, last))
            coverage.update(range(first, last))
            delta = part[split]
            for t in range(len(ids)):
                for j, expert in enumerate(ids[t]):
                    if first <= expert < last:
                        b[expert, t] = delta[t, j]
    assert coverage == set(range(256)) and a.shape == b.shape == (256, len(ids), 2048)
    denom = json.loads((Q3 / 'receipt.json').read_text())['reference_squared_norm'][split]
    down_norm = np.zeros((len(ids), 2048), np.float64)
    for path in down_files:
        with np.load(ROOT / 'down-route-quant' / path.name) as part:
            down_norm += part[f'{split}_q5']
    relative_reference = abs(np.sqrt(denom) - np.linalg.norm(down_norm)) / np.sqrt(denom)
    assert relative_reference < .01, relative_reference
    return np.concatenate((a, b)).reshape(512, -1), ids, denom, relative_reference


def gram(matrix):
    return (matrix @ matrix.T).astype(np.float64)


def select(g, qa, qb, seen, first='gate'):
    picks = [[], []]
    mask = np.zeros(512, bool)
    running = np.zeros(512, np.float64)
    steps = ([0] * qa + [1] * qb) if first == 'gate' else ([1] * qb + [0] * qa)
    for family in steps:
        start = family * 256
        candidates = np.arange(start, start + 256)
        eligible = seen.copy() & ~mask[candidates] & ~mask[candidates + (256 if family == 0 else -256)]
        marginal = np.diag(g)[candidates] + 2 * running[candidates]
        marginal[~eligible] = np.inf
        chosen = int(candidates[np.argmin(marginal)])
        assert np.isfinite(marginal[chosen - start])
        mask[chosen] = True
        picks[family].append(chosen - start)
        running += g[chosen]
    return mask, picks


def score(matrix, mask, denominator):
    e = matrix[mask].astype(np.float64).sum(axis=0)
    return float(np.sqrt(np.dot(e, e) / denominator))


def main():
    matrices = {}
    refs = {}
    ids = {}
    checks = {}
    grams = {}
    for split in ('train', 'held'):
        matrices[split], ids[split], refs[split], checks[split] = load(split)
        grams[split] = gram(matrices[split])
    seen = np.bincount(ids['train'].ravel(), minlength=256) > 0
    results = []
    budgets = ((0, 0), (32, 0), (0, 32), (0, 64), (0, 128), (16, 32), (32, 32), (32, 64), (32, 128), (64, 32))
    for qa, qb in budgets:
        for order in ('gate', 'down'):
            selected, picks = select(grams['train'], qa, qb, seen, order)
            row = {'q3_gateup_experts': qa, 'q4_down_experts': qb, 'order': order,
                   'q3_ids': picks[0], 'q4_down_ids': picks[1],
                   'layer_gateup_down_bytes': 301989888 + 184549376 - qa * 278528 - qb * 131072,
                   'conditional_one_read_fraction_saved':
                       (qa * 278528 + qb * 131072) * 40 * 8 / 256 / 2626187904}
            for split in matrices:
                row[split] = {'relative_rms': score(matrices[split], selected, refs[split]),
                              'selected_slots': int(np.isin(ids[split], picks[0] + picks[1]).sum())}
            # Gram is only used for selection; report direct FP64 vector reductions.
            results.append(row)
    OUT.mkdir(parents=True, exist_ok=True)
    inputs = sorted(Q3.glob('part-*.npz')) + sorted(DOWN.glob('part-*.npz'))
    receipt = {'contract': 'Disjoint Q3_K gate/up + Q5_K down OR Q4_K gate/up + Q4_K down per expert; actual producer routes and FP32 slot responses; FP64 eight-expert sum; trained allocation on 113 tokens, evaluated on 126 held tokens. No both-bank recoding of the same expert, no FP32 native identity or complete-model language loss.',
               'source_sha256': sha(HERE), 'input_sha256': {str(p): sha(p) for p in inputs},
               'parent_receipt_sha256': {str(p): sha(p) for p in (Q3 / 'receipt.json', DOWN / 'receipt.json', ROOT / 'route-capture/receipt.json', ROOT / 'acquisition.json')},
               'seen_train_experts': int(seen.sum()), 'held_experts_unseen_train': int((~seen & (np.bincount(ids['held'].ravel(), minlength=256) > 0)).sum()),
               'reference_norm_relative_difference': checks, 'reference_squared_norm': refs, 'results': results}
    (OUT / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    for row in results:
        print(row['q3_gateup_experts'], row['q4_down_experts'], row['order'],
              f"{row['train']['relative_rms']:.6f}", f"{row['held']['relative_rms']:.6f}",
              f"{row['conditional_one_read_fraction_saved']:.6%}", flush=True)
    print('receipt', sha(OUT / 'receipt.json'))


if __name__ == '__main__':
    main()
