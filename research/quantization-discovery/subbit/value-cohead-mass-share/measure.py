#!/usr/bin/env python3
"""Count the exact co-head shared-mass opportunity on frozen causal Q/K captures."""
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


def panel(counts):
    # [group, head, query, key], including padded causal zeroes.
    a, b = counts[:, 0], counts[:, 1]
    base = np.minimum(a, b)
    da, db = a - base, b - base
    positive = (a > 0).sum() + (b > 0).sum()
    equal = ((a == b) & (a > 0)).sum()
    shared = (base > 0).sum()
    assert not np.any((da > 0) & (db > 0))
    assert int((base > 0).sum() + (da > 0).sum() + (db > 0).sum()) == int(positive - equal)
    assert np.array_equal(base + da, a) and np.array_equal(base + db, b)
    # One dense base dot plus one signed difference dot; this may be a worse
    # instruction program than two dense byte dots even when nonzero products fall.
    diff = b - a
    first_low = np.minimum(a, 255)
    diff_low = np.clip(diff, -128, 127)
    first_extra = a - first_low
    diff_extra = diff - diff_low
    assert np.array_equal(first_low + first_extra + diff_low + diff_extra, b)
    return {
        'two_head_positive_key_uses': int(positive),
        'both_positive_keys': int(shared),
        'equal_positive_keys': int(equal),
        'min_base_positive_keys': int((base > 0).sum()),
        'disjoint_residual_positive_keys': int((da > 0).sum() + (db > 0).sum()),
        'signed_difference_nonzero_keys': int((diff != 0).sum()),
        'signed_difference_outside_i8_keys': int((diff_extra != 0).sum()),
        'first_head_overflow_keys': int((first_extra > 0).sum()),
        'original_two_head_overflow_keys': int((a > 255).sum() + (b > 255).sum()),
        'causal_group_keys': int(a.shape[0] * a.shape[1] * (a.shape[1] + 1) // 2),
        'difference_four_key_padded_uses': int((4 * np.ceil((diff != 0).sum(-1) / 4)).sum()),
        'difference_32_key_padded_uses': int((32 * np.ceil((diff != 0).sum(-1) / 32)).sum()),
        'common_mass_units': int(base.sum()),
        'two_head_mass_units': int(a.sum() + b.sum()),
        'max_min_base_keys_per_group_query': int((base > 0).sum(-1).max()),
        'max_signed_difference_keys_per_group_query': int((diff != 0).sum(-1).max()),
    }


def run(layer):
    torch.set_num_threads(8)
    parent_path = DATA / 'value-overflow-union' / f'layer{layer:02d}.json'
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
    assert sha_bytes(n.numpy().tobytes()) == parent['integer_count_sha256']
    windows = [panel(v) for v in n.numpy().reshape(4, 8, 2, 256, 256)]
    sums = {key: sum(v[key] for v in windows) for key in windows[0] if not key.startswith('max_')}
    result = {
        'layer': layer, 'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(parent_path),
        'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
        'integer_count_sha256': parent['integer_count_sha256'],
        'domain': 'four previously inspected original-producer Qwen3-0.6B validation windows of 256 causal tokens, eight two-head groups',
        'mass_per_head': mass, 'value_coordinates_per_group': 28,
        'per_window': windows, 'totals': sums,
    }
    dest = DATA / 'value-cohead-mass-share' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'totals': sums}))


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
