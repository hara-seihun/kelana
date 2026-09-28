#!/usr/bin/env python3
"""Pair two GQA integer-mass readers after exact whole-value-row label aggregation."""
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


def empty():
    return dict(low_uses=0, correction_uses=0, first_overflow=0,
                difference_overflow=0, scatters=0, initialized_bins=0,
                difference_zero_labels=0, difference_zero_keys=0,
                diff_4_padded=0, diff_32_padded=0, max_difference_corrections=0)


def run(layer):
    torch.set_num_threads(8)
    parent_path = DATA / 'value-selective-label-aggregation' / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    co_path = DATA / 'value-cohead-mass-share' / f'layer{layer:02d}.json'
    co = json.loads(co_path.read_text())
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(MODEL) == parent['model_sha256'] == co['model_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == parent['capture_sha256'] == co['capture_sha256']
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
    n = torch.diff(cumulative, dim=-1, prepend=torch.zeros_like(cumulative[..., :1])).numpy()
    assert hashlib.sha256(n.tobytes()).hexdigest() == co['integer_count_sha256']
    scales = json.loads((DATA / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())['scales']
    stats = [empty() for _ in range(4)]
    output_hash = hashlib.sha256()
    code_hashes = []
    with np.load(image_path) as image:
        for g in range(8):
            right = decoder.decode({k: image[k][g].copy() for k in image.files}, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            step = torch.tensor(scales[str(g)]['int8_coordinate'], dtype=torch.float16).float()
            codes = (z / step).round().clamp(-127, 127).to(torch.int8).numpy()
            code_hashes.append(hashlib.sha256(codes.tobytes()).hexdigest())
            responses = np.empty((2, 4, 256, 28), dtype='<i4')
            for v in range(4):
                labels = {}
                rows = []
                ids = np.empty(256, dtype=np.intp)
                for k, code in enumerate(codes[v]):
                    key = code.tobytes()
                    if key not in labels:
                        labels[key] = len(rows)
                        rows.append(code.astype(np.int64))
                    ids[k] = labels[key]
                values = np.stack(rows)
                for t in range(256):
                    idx = ids[:t+1]
                    a = n[v, 2*g, t, :t+1].astype(np.int64)
                    b = n[v, 2*g+1, t, :t+1].astype(np.int64)
                    mult = np.bincount(idx, minlength=len(rows))
                    grouped = mult[idx] >= 2
                    singleton = ~grouped
                    selected = mult >= 2
                    ga = np.bincount(idx, weights=a, minlength=len(rows)).astype(np.int64)[selected]
                    gb = np.bincount(idx, weights=b, minlength=len(rows)).astype(np.int64)[selected]
                    # The signed difference is formed after routing equal codes to one label.
                    aa = np.concatenate((ga, a[singleton]))
                    dd = np.concatenate((gb-ga, (b-a)[singleton]))
                    vv = np.concatenate((values[selected], codes[v, :t+1][singleton].astype(np.int64)))
                    low_a = np.minimum(aa, 255)
                    low_d = np.clip(dd, -128, 127)
                    extra_a = aa - low_a
                    extra_d = dd - low_d
                    first = (low_a @ vv + extra_a @ vv)
                    second = first + (low_d @ vv + extra_d @ vv)
                    raw_a = a @ codes[v, :t+1].astype(np.int64)
                    raw_b = b @ codes[v, :t+1].astype(np.int64)
                    assert np.array_equal(first, raw_a) and np.array_equal(second, raw_b)
                    responses[0, v, t] = first
                    responses[1, v, t] = second
                    active = int(np.count_nonzero(dd))
                    corrections = int(np.count_nonzero(extra_d))
                    assert corrections <= 62 and np.count_nonzero(extra_a) <= 15
                    s = stats[v]
                    s['low_uses'] += len(aa) + active
                    s['correction_uses'] += int(np.count_nonzero(extra_a)) + corrections
                    s['first_overflow'] += int(np.count_nonzero(extra_a))
                    s['difference_overflow'] += corrections
                    s['scatters'] += 2*int(grouped.sum())
                    s['initialized_bins'] += 2*len(ga)
                    s['difference_zero_labels'] += int(np.count_nonzero((gb-ga) == 0))
                    s['difference_zero_keys'] += int(np.count_nonzero((b-a)[singleton] == 0))
                    s['diff_4_padded'] += 4*((active+3)//4)
                    s['diff_32_padded'] += 32*((active+31)//32)
                    s['max_difference_corrections'] = max(s['max_difference_corrections'], corrections)
            for h in range(2):
                for v in range(4):
                    output_hash.update(responses[h, v].tobytes())
            print(f'group {g}', flush=True)
    assert code_hashes == parent['code_sha256_by_group']
    assert output_hash.hexdigest() == parent['integer_response_sha256']
    totals = {k: sum(s[k] for s in stats) if k != 'max_difference_corrections'
              else max(s[k] for s in stats) for k in stats[0]}
    duplicate = parent['stats']['2']
    assert totals['scatters'] == duplicate['histogram_scatters']
    assert totals['initialized_bins'] == duplicate['histogram_initializations']
    assert totals['low_uses'] <= 2*duplicate['low_products']//28
    result = dict(layer=layer, source_sha256=sha(Path(__file__)), parent_sha256=sha(parent_path),
                  cohead_parent_sha256=sha(co_path), model_sha256=sha(MODEL),
                  capture_sha256=sha(CAPTURES / f'layer{layer:02d}.npz'), image_sha256=sha(image_path),
                  factor_source_sha256=sha(SOURCE), integer_count_sha256=co['integer_count_sha256'],
                  code_sha256_by_group=code_hashes, integer_response_sha256=output_hash.hexdigest(),
                  domain='four previously inspected separate Qwen3-0.6B original-producer validation windows, 256 causal queries each, 8 GQA groups, frozen paid rank-28 V/O',
                  per_window=stats, totals=totals,
                  cost_contract='One 28-coordinate signed-byte term per first-head distinct label and per nonzero signed label difference; scalar overflow corrections charged separately; two histogram scatters per duplicate key; padding of only the difference list. Input-dependent count creation, label routing, initialization, scatter serialization, memory, O and GPU time are not priced.')
    dest = DATA / 'value-paired-label-difference' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'totals': totals}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
