#!/usr/bin/env python3
"""Causal multiplicity-gated exact aggregation of paid signed-byte value labels."""
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
THRESHOLDS = (1, 2, 3, 4, 8, 257)


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def empty():
    return dict(low_products=0, correction_products=0, correction_keys=0,
                histogram_scatters=0, histogram_initializations=0,
                multiplicity_tests=0, maximum_corrections=0)


def run(layer):
    torch.set_num_threads(8)
    parent_path = DATA / 'value-label-overflow' / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(MODEL) == parent['model_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == parent['capture_sha256']
    assert sha(image_path) == parent['image_sha256']
    spec = importlib.util.spec_from_file_location('paid_factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    cumulative = (p.double().cumsum(-1) * 4095).round().clamp(0, 4095).to(torch.int32)
    cumulative[..., -1] = 4095
    counts = torch.diff(cumulative, dim=-1, prepend=torch.zeros_like(cumulative[..., :1])).numpy()
    assert counts.min() >= 0 and np.all(counts.sum(-1) == 4095)
    scales = json.loads((DATA / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())['scales']
    stats = {str(k): empty() for k in THRESHOLDS}
    per_window = [{str(k): empty() for k in THRESHOLDS} for _ in range(4)]
    hashes = []
    response_hash = hashlib.sha256()
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
                    for t, code in enumerate(codes[v]):
                        key = code.tobytes()
                        if key not in labels:
                            labels[key] = len(rows)
                            rows.append(code.astype(np.int64))
                        ids[t] = labels[key]
                    values = np.stack(rows)
                    for t in range(256):
                        prefix_ids = ids[:t+1].astype(np.intp)
                        mass = counts[v, 2*g+h, t, :t+1].astype(np.int64)
                        multiplicity = np.bincount(prefix_ids, minlength=len(rows))
                        grouped_mass = np.bincount(prefix_ids, weights=mass, minlength=len(rows)).astype(np.int64)
                        raw = mass @ codes[v, :t+1].astype(np.int64)
                        for threshold in THRESHOLDS:
                            selected = multiplicity >= threshold
                            direct = ~selected[prefix_ids]
                            aggregate = grouped_mass[selected]
                            base = np.minimum(aggregate, 255)
                            excess = aggregate - base
                            raw_counts = mass[direct]
                            low = int(direct.sum() + len(aggregate))
                            correction = int(np.count_nonzero(raw_counts > 255) + np.count_nonzero(excess))
                            scatter = int((~direct).sum())
                            for record in (stats[str(threshold)], per_window[v][str(threshold)]):
                                record['low_products'] += 28 * low
                                record['correction_products'] += 28 * correction
                                record['correction_keys'] += correction
                                record['histogram_scatters'] += scatter
                                record['histogram_initializations'] += len(aggregate)
                                record['multiplicity_tests'] += t+1
                                record['maximum_corrections'] = max(record['maximum_corrections'], correction)
                            if threshold == 2:
                                result = (base @ values[selected] + excess @ values[selected]
                                          + raw_counts @ codes[v, :t+1][direct].astype(np.int64))
                                assert np.array_equal(result, raw)
                                response[v, t] = result
                response_hash.update(response.tobytes())
            print(f'group {g}', flush=True)
    assert hashes == parent['code_sha256_by_group']
    assert response_hash.hexdigest() == parent['integer_response_sha256']
    assert stats['1']['low_products'] == parent['stats']['grouped_low_products']
    assert stats['1']['correction_products'] == parent['stats']['grouped_correction_products']
    assert stats['1']['histogram_scatters'] == parent['stats']['head_key_histogram_adds']
    assert stats['257']['low_products'] == parent['parent_causal_low_products']
    assert stats['257']['correction_products'] == parent['parent_key_correction_products']
    result = dict(layer=layer, source_sha256=sha(Path(__file__)), parent_sha256=sha(parent_path),
                  model_sha256=sha(MODEL), capture_sha256=sha(CAPTURES / f'layer{layer:02d}.npz'),
                  image_sha256=sha(image_path), factor_source_sha256=sha(SOURCE),
                  code_sha256_by_group=hashes, integer_response_sha256=response_hash.hexdigest(),
                  domain='four previously inspected 256-token original-producer validation windows; paid rank-28 signed-byte V; 4095 cumulative-rounded causal counts; 16 heads',
                  decision='group whole-row labels whose causal prefix multiplicity reaches threshold; all other key counts dot directly',
                  stats=stats, per_window=per_window,
                  cost_contract='Logical 28-coordinate byte/correction products, count scatters and bin initializations. Multiplicity-test count includes the naive prefix scan for each query. Append maintenance, dot padding, physical reads, softmax/count creation, scale/O and native time are not priced.')
    dest = DATA / 'value-selective-label-aggregation' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'stats': stats}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
