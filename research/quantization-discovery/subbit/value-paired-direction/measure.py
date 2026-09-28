#!/usr/bin/env python3
"""Price direction selection after duplicate-only whole-value-row aggregation."""
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
    return dict(a_corrections=0, b_corrections=0, adaptive_corrections=0,
                adaptive_b_rows=0, adaptive_b_ties=0, adaptive_saving_rows=0,
                a_first_overflow=0, b_first_overflow=0,
                a_difference_overflow=0, b_difference_overflow=0,
                first_byte_uses=0, difference_uses=0, diff_4_padded=0,
                diff_32_padded=0, scatters=0, initialized_bins=0,
                max_a_corrections=0, max_b_corrections=0,
                max_adaptive_corrections=0)


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
                    bb = aa + dd
                    low_a, low_b = np.minimum(aa, 255), np.minimum(bb, 255)
                    low_d, low_rev = np.clip(dd, -128, 127), np.clip(-dd, -128, 127)
                    extra_a, extra_b = aa-low_a, bb-low_b
                    extra_d, extra_rev = dd-low_d, -dd-low_rev
                    first = low_a @ vv + extra_a @ vv
                    second = first + low_d @ vv + extra_d @ vv
                    reverse_second = low_b @ vv + extra_b @ vv
                    reverse_first = reverse_second + low_rev @ vv + extra_rev @ vv
                    raw_a = a @ codes[v, :t+1].astype(np.int64)
                    raw_b = b @ codes[v, :t+1].astype(np.int64)
                    assert np.array_equal(first, raw_a) and np.array_equal(second, raw_b)
                    assert np.array_equal(reverse_first, raw_a) and np.array_equal(reverse_second, raw_b)
                    responses[0, v, t] = first
                    responses[1, v, t] = second
                    active = int(np.count_nonzero(dd))
                    ca = int(np.count_nonzero(extra_a) + np.count_nonzero(extra_d))
                    cb = int(np.count_nonzero(extra_b) + np.count_nonzero(extra_rev))
                    assert max(ca, cb) <= 77
                    s = stats[v]
                    s['a_corrections'] += ca
                    s['b_corrections'] += cb
                    s['adaptive_corrections'] += min(ca, cb)
                    s['adaptive_b_rows'] += cb < ca
                    s['adaptive_b_ties'] += cb == ca
                    s['adaptive_saving_rows'] += ca != cb
                    s['a_first_overflow'] += np.count_nonzero(extra_a)
                    s['b_first_overflow'] += np.count_nonzero(extra_b)
                    s['a_difference_overflow'] += np.count_nonzero(extra_d)
                    s['b_difference_overflow'] += np.count_nonzero(extra_rev)
                    s['first_byte_uses'] += len(aa)
                    s['difference_uses'] += active
                    s['diff_4_padded'] += 4*((active+3)//4)
                    s['diff_32_padded'] += 32*((active+31)//32)
                    s['scatters'] += 2*int(grouped.sum())
                    s['initialized_bins'] += 2*len(ga)
                    s['max_a_corrections'] = max(s['max_a_corrections'], ca)
                    s['max_b_corrections'] = max(s['max_b_corrections'], cb)
                    s['max_adaptive_corrections'] = max(s['max_adaptive_corrections'], min(ca, cb))
            for h in range(2):
                for v in range(4):
                    output_hash.update(responses[h, v].tobytes())
            print(f'group {g}', flush=True)
    assert code_hashes == parent['code_sha256_by_group']
    assert output_hash.hexdigest() == parent['integer_response_sha256']
    stats = [{k: int(value) for k, value in s.items()} for s in stats]
    totals = {k: max(s[k] for s in stats) if k.startswith('max_')
              else sum(s[k] for s in stats) for k in stats[0]}
    duplicate = parent['stats']['2']
    assert totals['scatters'] == duplicate['histogram_scatters']
    assert totals['initialized_bins'] == duplicate['histogram_initializations']
    assert totals['first_byte_uses'] + totals['difference_uses'] == json.loads((DATA / 'value-paired-label-difference' / f'layer{layer:02d}.json').read_text())['totals']['low_uses']
    assert totals['a_corrections'] == json.loads((DATA / 'value-paired-label-difference' / f'layer{layer:02d}.json').read_text())['totals']['correction_uses']
    assert totals['first_byte_uses'] * 2 <= 2*duplicate['low_products']//28
    result = dict(layer=layer, source_sha256=sha(Path(__file__)), parent_sha256=sha(parent_path),
                  paired_parent_sha256=sha(DATA / 'value-paired-label-difference' / f'layer{layer:02d}.json'),
                  cohead_parent_sha256=sha(co_path), model_sha256=sha(MODEL),
                  capture_sha256=sha(CAPTURES / f'layer{layer:02d}.npz'), image_sha256=sha(image_path),
                  factor_source_sha256=sha(SOURCE), integer_count_sha256=co['integer_count_sha256'],
                  code_sha256_by_group=code_hashes, integer_response_sha256=output_hash.hexdigest(),
                  domain='four previously inspected separate Qwen3-0.6B original-producer validation windows, 256 causal queries each, 8 GQA groups, frozen paid rank-28 V/O',
                  per_window=stats, totals=totals,
                  cost_contract='Static and adaptive orientations share the first byte-dot length, signed difference support, padding and histogram work. Only overflow correction keys change. Per-query selection adds a comparison and output routing. Native time, append/count construction and O are unpaid.')
    dest = DATA / 'value-paired-direction' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'totals': totals}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
