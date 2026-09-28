#!/usr/bin/env python3
"""Exact count-domain direction choice for the two-head signed-byte V reader."""
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
    # [group, head, query, key]. The arithmetic below is independent of V labels.
    a, b = counts[:, 0].astype(np.int32), counts[:, 1].astype(np.int32)
    d = b - a
    support = (d != 0).sum(-1)
    e_a = np.maximum(a - 255, 0)
    e_b = np.maximum(b - 255, 0)
    # a first uses clip(d,-128,127); b first uses clip(-d,-128,127).
    xa = d - np.clip(d, -128, 127)
    xb = -d - np.clip(-d, -128, 127)
    ca = (e_a > 0).sum(-1) + (xa != 0).sum(-1)
    cb = (e_b > 0).sum(-1) + (xb != 0).sum(-1)
    choose_b = cb < ca
    chosen = np.where(choose_b, cb, ca)
    # Check the integer responses on the full reachable code alphabet's endpoints
    # and on a distinct deterministic interior code at each key.
    for q in (np.full(a.shape[-1], -127, np.int32),
              np.full(a.shape[-1], 127, np.int32),
              (np.arange(a.shape[-1], dtype=np.int32) * 97 % 255) - 127):
        aa = (a * q).sum(-1, dtype=np.int64)
        bb = (b * q).sum(-1, dtype=np.int64)
        reconstructed_b = ((np.minimum(a, 255) + e_a + np.clip(d, -128, 127) + xa) * q).sum(-1, dtype=np.int64)
        reconstructed_a = ((np.minimum(b, 255) + e_b + np.clip(-d, -128, 127) + xb) * q).sum(-1, dtype=np.int64)
        assert np.array_equal(aa, reconstructed_a) and np.array_equal(bb, reconstructed_b)
    assert int(max(ca.max(), cb.max())) <= 77  # 15 base + 62 signed difference
    rows = ca.size
    return {
        'rows': rows,
        'base_a_correction_keys': int(ca.sum()),
        'base_b_correction_keys': int(cb.sum()),
        'adaptive_correction_keys': int(chosen.sum()),
        'adaptive_b_rows': int(choose_b.sum()),
        'base_a_overflow_keys': int((e_a > 0).sum()),
        'base_b_overflow_keys': int((e_b > 0).sum()),
        'signed_diff_overflow_a_first': int((xa != 0).sum()),
        'signed_diff_overflow_b_first': int((xb != 0).sum()),
        'exact_endpoint_128_a_first': int((d == -128).sum()),
        'exact_endpoint_128_b_first': int((d == 128).sum()),
        'nonzero_difference_uses': int(support.sum()),
        'padded_32_difference_uses': int((32 * ((support + 31) // 32)).sum()),
        'max_correction_keys_a_first': int(ca.max()),
        'max_correction_keys_b_first': int(cb.max()),
        'max_correction_keys_adaptive': int(chosen.max()),
        'rows_with_any_saving_vs_a': int((chosen < ca).sum()),
        'selector_groups': rows,
    }


def run(layer):
    torch.set_num_threads(8)
    parent_path = DATA / 'value-cohead-mass-share' / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    cap = CAPTURES / f'layer{layer:02d}.npz'
    assert sha(MODEL) == parent['model_sha256']
    assert sha(cap) == parent['capture_sha256']
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    cum = (p.double().cumsum(-1) * 4095).round().clamp(0, 4095).to(torch.int32)
    cum[..., -1] = 4095
    n = torch.diff(cum, dim=-1, prepend=torch.zeros_like(cum[..., :1]))
    assert hashlib.sha256(n.numpy().tobytes()).hexdigest() == parent['integer_count_sha256']
    windows = [panel(v) for v in n.numpy().reshape(4, 8, 2, 256, 256)]
    additive = [k for k in windows[0] if not k.startswith('max_')]
    totals = {k: sum(v[k] for v in windows) for k in additive}
    result = {
        'layer': layer, 'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(parent_path),
        'model_sha256': parent['model_sha256'], 'capture_sha256': parent['capture_sha256'],
        'integer_count_sha256': parent['integer_count_sha256'],
        'domain': 'four inspected original-producer Qwen3-0.6B validation windows, 256 causal tokens, eight two-head groups',
        'per_window': windows, 'totals': totals,
    }
    dest = DATA / 'value-cohead-direction' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'totals': totals}))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(ap.parse_args().layer)
