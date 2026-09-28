#!/usr/bin/env python3
"""Paid Q4/Q5 expert allocation against the actual eight-output routed sum."""
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/qwen-moe')
OUT = ROOT / 'down-joint-allocation'
BUDGETS = (0, 32, 64, 128, 192, 224, 256)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load():
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'down-route-quant'))
    from experiment import capture
    splits = {}
    shards = sorted((ROOT / 'down-rate-allocation').glob('part-*.npz'))
    assert len(shards) == 4
    for path in shards:
        record = json.loads(path.with_suffix('.json').read_text())
        assert record['arrays_sha256'] == sha(path)
    source_shards = [ROOT / 'down-route-quant' / p.name for p in shards]
    for split in ('train', 'held'):
        ids = capture(split)[0]
        delta = np.zeros((*ids.shape, 2048), np.float32)
        q5 = np.zeros((len(ids), 2048), np.float64)
        covered = set()
        for path, source in zip(shards, source_shards):
            with np.load(path) as part:
                first, last = int(part['first']), int(part['last'])
                assert not covered.intersection(range(first, last))
                covered.update(range(first, last))
                delta += part[split]
            with np.load(source) as part:
                q5 += part[f'{split}_q5']
        assert covered == set(range(256))
        splits[split] = (ids, delta.astype(np.float64), float((q5 * q5).sum()))
    return splits, shards, source_shards


def gram(ids, delta):
    g = np.zeros((256, 256), np.float64)
    for row_ids, row_delta in zip(ids, delta):
        local = row_delta @ row_delta.T
        np.add.at(g, (row_ids[:, None], row_ids[None, :]), local)
    return g


def greedy(g):
    q4 = np.ones(256, bool)
    order = []
    for _ in range(256):
        x = q4.astype(np.float64)
        gain = 2 * (g @ x) - np.diag(g)
        gain[~q4] = -np.inf
        e = int(np.argmax(gain))
        q4[e] = False
        order.append(e)
    return order


def refine(g, q4):
    # At fixed bank bytes, exchange a Q4 expert i with retained Q5 expert j.
    # The changed objective is x'Gx'-xGx, x'=x-e_i+e_j.
    q4 = q4.copy()
    nswaps = 0
    for _ in range(100):
        gx = g @ q4.astype(np.float64)
        ii = np.flatnonzero(q4)
        jj = np.flatnonzero(~q4)
        if not len(ii) or not len(jj):
            break
        change = (-2 * gx[ii, None] + 2 * gx[None, jj] +
                  g[ii, ii, None] + g[jj[None, :], jj[None, :]] - 2 * g[np.ix_(ii, jj)])
        k = int(np.argmin(change))
        i, j = np.unravel_index(k, change.shape)
        if change[i, j] >= -1e-12:
            break
        q4[ii[i]], q4[jj[j]] = False, True
        nswaps += 1
    return q4, nswaps


def main():
    splits, shards, sources = load()
    grams = {s: gram(ids, d) for s, (ids, d, _) in splits.items()}
    diagnostics = {}
    for split, g in grams.items():
        diagonal = np.diag(g).copy()
        active = diagonal > 0
        normalized = g[np.ix_(active, active)] / np.sqrt(np.outer(diagonal[active], diagonal[active]))
        np.fill_diagonal(normalized, 0)
        eigen = np.linalg.eigvalsh(normalized)
        diagnostics[split] = {'nonzero_experts': int(active.sum()),
                              'nonzero_offdiagonal_pairs': int(np.count_nonzero(np.triu(g, 1))),
                              'largest_pair_correlation': float(np.max(np.abs(normalized))),
                              'normalized_offdiagonal_eigen_min': float(eigen[0]),
                              'normalized_offdiagonal_eigen_max': float(eigen[-1])}
    train = grams['train']
    rank = np.lexsort((np.arange(256), -np.diag(train)))
    joint = greedy(train)
    panels = []
    for kept in BUDGETS:
        for policy, order in (('independent-energy', rank), ('joint-greedy', joint)):
            q4 = np.ones(256, bool)
            q4[np.asarray(order[:kept], dtype=np.int64)] = False
            candidates = [(policy, q4, 0)]
            if policy == 'joint-greedy':
                improved, swaps = refine(train, q4)
                candidates.append(('joint-swap', improved, swaps))
            for name, mask, swaps in candidates:
                x = mask.astype(np.float64)
                row = {'q5_experts': kept, 'policy': name, 'train_swaps': swaps,
                       'q5_ids': np.flatnonzero(~mask).tolist(),
                       'layer_down_bytes': kept * 720896 + (256-kept) * 589824}
                for split, (ids, _, denom) in splits.items():
                    objective = float(x @ grams[split] @ x)
                    row[split] = {'relative_rms': float(np.sqrt(max(0, objective) / denom)),
                                  'squared_error': objective, 'q4_assignments': int(mask[ids].sum())}
                panels.append(row)
    OUT.mkdir(parents=True, exist_ok=True)
    receipt = {'domain': 'layer-0 actual 113 train and 126 held routed producer tokens; fixed Q4_K recodes against installed Q5_K',
               'source_sha256': sha(Path(__file__)), 'delta_shards_sha256': {p.name: sha(p) for p in shards},
               'q5_shards_sha256': {p.name: sha(p) for p in sources},
               'capture_receipt_sha256': sha(ROOT / 'route-capture/receipt.json'),
               'model_acquisition_sha256': sha(ROOT / 'acquisition.json'),
               'contract': 'CPU FP32 BLAS per-slot differences, FP64 eight-output accumulation; complete 256-expert bank paid bytes; held never enters allocation',
               'diagnostics': diagnostics, 'panels': panels}
    (OUT / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    for p in panels:
        print(p['q5_experts'], p['policy'], p['train_swaps'],
              f"{p['train']['relative_rms']:.6f}", f"{p['held']['relative_rms']:.6f}",
              p['held']['q4_assignments'])


if __name__ == '__main__':
    main()
