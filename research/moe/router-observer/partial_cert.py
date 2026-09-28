#!/usr/bin/env python3
"""Certified real top-eight from prefixes of actual layer-0 Qwen router dots."""
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
OUT = BASE / 'router-observer' / 'partial-certificate.json'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def certificate(x, w, order, kind):
    """First certified prefix for each row; the final dot chooses the route offline."""
    result = []
    rows = w.shape[0]
    w2_suffix = np.sqrt(np.maximum(0, np.cumsum((w[:, ::-1] ** 2), axis=1)[:, ::-1]))
    w2_suffix = np.concatenate((w2_suffix, np.zeros((rows, 1))), axis=1)
    for vector in x:
        if kind == 'input-energy':
            priority = np.abs(vector) * np.sqrt((w*w).sum(axis=0))
            cols = np.argsort(-priority, kind='stable')
        else:
            cols = order
        ww = w[:, cols]
        vv = vector[cols]
        terms = ww * vv
        prefix = np.concatenate((np.zeros((rows, 1)), np.cumsum(terms, axis=1)), axis=1)
        final = prefix[:, -1]
        chosen = np.argsort(-final, kind='stable')[:8]
        others = np.setdiff1d(np.arange(rows), chosen, assume_unique=True)
        if kind == 'natural':
            tail_w = w2_suffix
        else:
            tail_w = np.sqrt(np.maximum(0, np.cumsum((ww[:, ::-1]**2), axis=1)[:, ::-1]))
            tail_w = np.concatenate((tail_w, np.zeros((rows, 1))), axis=1)
        tail_x = np.sqrt(np.maximum(0, np.cumsum((vv[::-1]**2))[::-1]))
        tail_x = np.concatenate((tail_x, [0.]))
        norm_radius = tail_w * tail_x
        # This is a deliberately free hindsight envelope: it reads every
        # unevaluated product and is not a candidate online shortcut.
        absolute_radius = np.concatenate((np.cumsum(np.abs(terms[:, ::-1]), axis=1)[:, ::-1],
                                          np.zeros((rows, 1))), axis=1)
        positions = np.arange(len(vv) + 1)
        outcomes = {}
        for name, radius in (('norm', norm_radius), ('absolute-oracle', absolute_radius)):
            low = np.min(prefix[chosen] - radius[chosen], axis=0)
            high = np.max(prefix[others] + radius[others], axis=0)
            good = np.flatnonzero(low > high + 1e-7)
            outcomes[name] = int(good[0]) if len(good) else int(positions[-1])
        result.append(outcomes)
    return result


def main():
    inventory = BASE / 'traffic.json'
    info = json.loads(inventory.read_text())
    router = next(t for t in info['tensors'] if t['name'] == 'blk.0.ffn_gate_inp.weight')
    model = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    offset = (info['header_bytes'] + 31) // 32 * 32 + router['offset']
    weights = np.memmap(model, '<f4', 'r', offset=offset, shape=(256, 2048)).astype(np.float64)
    order = np.argsort(-(weights*weights).sum(axis=0), kind='stable')
    result = {
        'contract': 'Layer-0 decoded F32 router; exact-real full top-eight, strict interval certificate for partial dot. Absolute tail is an offline oracle requiring all omitted products. Input-energy order is an uncharged token-dependent permutation. No native FP32 bit identity, inference timing or whole-model result.',
        'source_sha256': digest(Path(__file__)), 'inventory_sha256': digest(inventory),
        'model_sha256': json.loads((BASE/'acquisition.json').read_text())['sha256'],
        'captures': {}, 'splits': {}, 'dimensions': 2048, 'experts': 256,
    }
    for split in ('train', 'held'):
        path = BASE / 'route-capture' / f'{split}.0.attn_post_norm-0.bin'
        ids_path = BASE / 'route-capture' / f'{split}.0.ffn_moe_topk-0.bin'
        x = np.memmap(path, '<f4').reshape(-1, 2048).astype(np.float64)
        ids = np.memmap(ids_path, '<i4').reshape(-1, 8)
        logits = x @ weights.T
        matches = sum(set(np.argsort(-row, kind='stable')[:8]) == set(route) for row, route in zip(logits, ids))
        result['captures'][split] = {'input': digest(path), 'ids': digest(ids_path)}
        measures = {}
        dot_magnitude = np.abs(x) @ np.abs(weights).T
        gamma64 = 2048 * np.finfo(np.float64).eps / (1 - 2048 * np.finfo(np.float64).eps)
        result['splits'][split] = {'rows': len(x), 'route_matches_native': matches,
                                   'max_sequential_fp64_dot_bound': float(gamma64 * dot_magnitude.max())}
        for kind, cols in (('natural', np.arange(2048)), ('static-weight-energy', order), ('input-energy', None)):
            raw = certificate(x, weights, cols, kind)
            measures[kind] = {name: {
                'first_prefix': [r[name] for r in raw],
                'mean': float(np.mean([r[name] for r in raw])),
                'median': float(np.median([r[name] for r in raw])),
                'count_at_1536': sum(r[name] <= 1536 for r in raw),
                'count_at_1920': sum(r[name] <= 1920 for r in raw),
                'count_at_2000': sum(r[name] <= 2000 for r in raw),
            } for name in ('norm', 'absolute-oracle')}
        result['splits'][split]['measures'] = measures
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({split: {kind: {name: {key: value for key, value in v.items() if key != 'first_prefix'}
                         for name, v in m.items()} for kind, m in data['measures'].items()}
                      for split, data in result['splits'].items()}, indent=2))


if __name__ == '__main__':
    main()
