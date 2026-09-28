#!/usr/bin/env python3
"""Group identical paid V labels before the exact one-byte plus sparse-overflow dot."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

SUB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SUB / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
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
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    parent_path = DATA / 'value-mass-overflow' / f'layer{layer:02d}.json'
    index_path = DATA / 'value-label-histogram' / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    index = json.loads(index_path.read_text())
    assert sha(MODEL) == parent['model_sha256'] == index['model_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == parent['capture_sha256'] == index['capture_sha256']
    assert sha(image_path) == parent['image_sha256'] == index['image_sha256']
    spec = importlib.util.spec_from_file_location('paid_factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    cum = (p.double().cumsum(-1) * 4095).round().clamp(0, 4095).to(torch.int32)
    cum[..., -1] = 4095
    counts = torch.diff(cum, dim=-1, prepend=torch.zeros_like(cum[..., :1])).numpy()
    assert counts.min() >= 0 and np.all(counts.sum(-1) == 4095)
    scales = json.loads((DATA / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())['scales']
    hashes = []
    output_hash = hashlib.sha256()
    stats = dict(grouped_low_products=0, grouped_correction_products=0,
                 grouped_overflow_labels=0, key_overflow_keys=0,
                 head_key_histogram_adds=0, distinct_label_initializations=0,
                 maximum_grouped_overflow=0, grouped_overflow_rows=0)
    per_window = [dict(grouped_overflow_labels=0, grouped_low_products=0,
                       grouped_correction_products=0, maximum_grouped_overflow=0) for _ in range(4)]
    with np.load(image_path) as image:
        for g in range(8):
            right = decoder.decode({k: image[k][g].copy() for k in image.files}, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            step = torch.tensor(scales[str(g)]['int8_coordinate'], dtype=torch.float16).float()
            codes = (z / step).round().clamp(-127, 127).to(torch.int8).numpy()
            hashes.append(hashlib.sha256(codes.tobytes()).hexdigest())
            for h in range(2):
                response = np.empty((4, 256, 28), dtype='<i4')
                for v in range(4):
                    labels = {}
                    rows = []
                    ids = np.empty(256, dtype=np.uint8)
                    for k, code in enumerate(codes[v]):
                        key = code.tobytes()
                        if key not in labels:
                            labels[key] = len(rows)
                            rows.append(code.astype(np.int64))
                        ids[k] = labels[key]
                    assert len(rows) == index['per_window'][v][g]['distinct_at_256']
                    values = np.stack(rows)
                    for t in range(256):
                        mass = counts[v, 2*g+h, t, :t+1]
                        grouped = np.bincount(ids[:t+1], weights=mass,
                                              minlength=len(rows)).astype(np.int64)[:len(labels)]
                        active = len(set(ids[:t+1].tolist()))
                        base = np.minimum(grouped[:active], 255)
                        excess = grouped[:active] - base
                        overflowing = int(np.count_nonzero(excess))
                        assert overflowing <= 15
                        # The dictionary is first-occurrence ordered, so each prefix is contiguous.
                        assert active == len(set(ids[:t+1].tolist()))
                        result = base @ values[:active] + excess @ values[:active]
                        assert np.array_equal(result, mass.astype(np.int64) @ codes[v, :t+1].astype(np.int64))
                        response[v, t] = result
                        stats['grouped_low_products'] += 28 * active
                        stats['grouped_correction_products'] += 28 * overflowing
                        stats['grouped_overflow_labels'] += overflowing
                        stats['head_key_histogram_adds'] += t + 1
                        stats['distinct_label_initializations'] += active
                        stats['key_overflow_keys'] += int(np.count_nonzero(mass > 255))
                        stats['maximum_grouped_overflow'] = max(stats['maximum_grouped_overflow'], overflowing)
                        stats['grouped_overflow_rows'] += overflowing > 0
                        per_window[v]['grouped_low_products'] += 28 * active
                        per_window[v]['grouped_correction_products'] += 28 * overflowing
                        per_window[v]['grouped_overflow_labels'] += overflowing
                        per_window[v]['maximum_grouped_overflow'] = max(per_window[v]['maximum_grouped_overflow'], overflowing)
                output_hash.update(response.tobytes())
            print(f'group {g}', flush=True)
    assert hashes == parent['code_sha256_by_group']
    assert output_hash.hexdigest() == parent['integer_response_sha256']
    assert stats['grouped_low_products'] == index['totals']['two_head_histogram_code_products']
    assert stats['key_overflow_keys'] == parent['total_overflow_keys']
    assert stats['head_key_histogram_adds'] == index['totals']['two_head_mass_accumulations']
    result = dict(layer=layer, source_sha256=sha(Path(__file__)), parent_sha256=sha(parent_path),
                  index_sha256=sha(index_path), model_sha256=sha(MODEL), image_sha256=sha(image_path),
                  capture_sha256=sha(CAPTURES / f'layer{layer:02d}.npz'), factor_source_sha256=sha(SOURCE),
                  code_sha256_by_group=hashes, integer_response_sha256=output_hash.hexdigest(),
                  domain='four previously inspected 256-token original-producer validation windows; paid rank-28 signed-byte V cache; 4,095 conserved cumulative-rounded counts; 16 heads',
                  stats=stats, per_window=per_window, parent_causal_low_products=parent['causal_byte_dot_products'],
                  parent_key_correction_products=parent['sparse_scalar_correction_products'],
                  cost_contract='Per head/query gather key IDs, scatter-add conserved int32 counts into distinct labels, initialize touched label bins, dot min(count,255) with signed-byte codes, scalar-correct each count >255. Dictionary append, scatter conflicts, padded dot slots, irregular corrections, scale/O, native occupancy and physical cache traffic remain unpaid.')
    dest = DATA / 'value-label-overflow' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'stats': stats, 'parent_low_products': result['parent_causal_low_products'],
                      'parent_correction_products': result['parent_key_correction_products']}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, required=True, choices=(0, 14))
    run(parser.parse_args().layer)
