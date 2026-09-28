#!/usr/bin/env python3
"""Count shared physical V-row reads for the exact conserved-count overflow map."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

SUB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SUB / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from measure import probabilities

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def run(layer):
    torch.set_num_threads(8)
    parent_path = DATA / 'value-mass-overflow' / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    assert sha(MODEL) == parent['model_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == parent['capture_sha256']
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    mass = 4095
    cum = (p.double().cumsum(-1) * mass).round().clamp(0, mass).to(torch.int32)
    cum[..., -1] = mass
    n = torch.diff(cum, dim=-1, prepend=torch.zeros_like(cum[..., :1]))
    e = (n > 255).numpy().reshape(4, 8, 2, 256, 256)
    n_hash = hashlib.sha256(n.numpy().tobytes()).hexdigest()
    per_window = []
    for v in range(4):
        head = e[v].sum(axis=-1)
        group = e[v].any(axis=1)
        group_keys = group.sum(axis=-1)
        shared = np.logical_and(e[v, :, 0], e[v, :, 1]).sum()
        all_keys = group.any(axis=0)
        # A physical 224-byte row comprises 64-byte cache lines. Count the
        # distinct lines needed by the eight groups' 28-byte exception vectors.
        line_total = 0
        head_line_total = 0
        group_line_total = 0
        for q in range(256):
            lines = set()
            for g in range(8):
                group_lines = set()
                for h in range(2):
                    head_lines = set()
                    for k in np.flatnonzero(e[v, g, h, q]):
                        lo = int(k) * 224 + g * 28
                        head_lines.update(range(lo // 64, (lo + 27) // 64 + 1))
                    head_line_total += len(head_lines)
                    group_lines.update(head_lines)
                group_line_total += len(group_lines)
                lines.update(group_lines)
            line_total += len(lines)
        per_window.append({
            'head_exceptions': int(head.sum()), 'group_union_keys': int(group.sum()),
            'two_head_shared_keys': int(shared), 'all_group_distinct_keys': int(all_keys.sum()),
            'group_union_max': int(group_keys.max()), 'all_group_union_max': int(all_keys.sum(axis=-1).max()),
            'unique_64_byte_lines': line_total,
            'per_head_64_byte_lines': head_line_total,
            'per_group_64_byte_lines': group_line_total,
            'causal_keys': 256 * 257 // 2,
        })
    result = {
        'layer': layer, 'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(parent_path),
        'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
        'integer_count_sha256': n_hash,
        'domain': 'four previously inspected 256-token original-producer validation windows; 16 heads in eight two-head groups',
        'mass_per_head': mass, 'value_row_bytes': 224, 'group_coordinate_bytes': 28,
        'per_window': per_window,
        'totals': {k: sum(v[k] for v in per_window) for k in ('head_exceptions', 'group_union_keys', 'two_head_shared_keys', 'all_group_distinct_keys', 'unique_64_byte_lines', 'per_head_64_byte_lines', 'per_group_64_byte_lines', 'causal_keys')},
        'physical_cost_assumption': 'cold unique 64-byte line per query; 224 contiguous bytes per key, 28 per group; no reuse credited between queries; neither line count nor correction products are native time',
    }
    assert result['totals']['head_exceptions'] == parent['total_overflow_keys']
    dest = DATA / 'value-overflow-union' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'totals': result['totals'], 'max_group': max(v['group_union_max'] for v in per_window)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
