#!/usr/bin/env python3
"""Price exact radix-256 byte-dot correction of the grouped two-head V reader."""
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


def padded(n, width):
    return width * ((n + width - 1) // width)


def run(layer):
    torch.set_num_threads(8)
    previous_path = DATA / 'value-paired-direction' / f'layer{layer:02d}.json'
    previous = json.loads(previous_path.read_text())
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(MODEL) == previous['model_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == previous['capture_sha256']
    assert sha(image_path) == previous['image_sha256']
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
    assert hashlib.sha256(n.tobytes()).hexdigest() == previous['integer_count_sha256']
    scales = json.loads((DATA / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())['scales']
    names = ('base_high', 'difference_high', 'base_high_4', 'difference_high_4',
             'base_high_16', 'difference_high_16', 'base_high_32', 'difference_high_32',
             'base_high_64', 'difference_high_64', 'max_base_high', 'max_difference_high',
             'base_low', 'difference_low', 'difference_low_32', 'group_queries')
    stats = [{key: 0 for key in names} for _ in range(4)]
    codes_hash = []
    output_hash = hashlib.sha256()
    with np.load(image_path) as image:
        for g in range(8):
            right = decoder.decode({k: image[k][g].copy() for k in image.files}, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            step = torch.tensor(scales[str(g)]['int8_coordinate'], dtype=torch.float16).float()
            codes = (z / step).round().clamp(-127, 127).to(torch.int8).numpy()
            codes_hash.append(hashlib.sha256(codes.tobytes()).hexdigest())
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
                s = stats[v]
                for t in range(256):
                    idx = ids[:t+1]
                    a = n[v, 2*g, t, :t+1].astype(np.int64)
                    b = n[v, 2*g+1, t, :t+1].astype(np.int64)
                    mult = np.bincount(idx, minlength=len(rows))
                    selected = mult >= 2
                    singleton = ~selected[idx]
                    ga = np.bincount(idx, weights=a, minlength=len(rows)).astype(np.int64)[selected]
                    gb = np.bincount(idx, weights=b, minlength=len(rows)).astype(np.int64)[selected]
                    # B is the base. Group the duplicate labels, leave singletons direct.
                    base = np.concatenate((gb, b[singleton]))
                    delta = np.concatenate((ga-gb, (a-b)[singleton]))
                    code = np.concatenate((values[selected], codes[v, :t+1][singleton].astype(np.int64)))
                    base_lo = (base & 255).astype(np.uint8)
                    base_hi = (base >> 8).astype(np.uint8)
                    delta_lo = (((delta + 128) & 255) - 128).astype(np.int8)
                    delta_hi = ((delta - delta_lo.astype(np.int64)) // 256).astype(np.int8)
                    assert np.array_equal(base, base_lo.astype(np.int64) + 256*base_hi.astype(np.int64))
                    assert np.array_equal(delta, delta_lo.astype(np.int64) + 256*delta_hi.astype(np.int64))
                    first = base_lo.astype(np.int64) @ code + 256*(base_hi.astype(np.int64) @ code)
                    second = first + delta_lo.astype(np.int64) @ code + 256*(delta_hi.astype(np.int64) @ code)
                    assert np.array_equal(first, b @ codes[v, :t+1].astype(np.int64))
                    assert np.array_equal(second, a @ codes[v, :t+1].astype(np.int64))
                    # Parent response hash is in A, B head order, not execution order.
                    responses[0, v, t] = second
                    responses[1, v, t] = first
                    hb = int(np.count_nonzero(base_hi))
                    hd = int(np.count_nonzero(delta_hi))
                    active = int(np.count_nonzero(delta))
                    s['group_queries'] += 1
                    s['base_high'] += hb
                    s['difference_high'] += hd
                    s['max_base_high'] = max(s['max_base_high'], hb)
                    s['max_difference_high'] = max(s['max_difference_high'], hd)
                    s['base_low'] += len(base)
                    s['difference_low'] += active
                    s['difference_low_32'] += padded(active, 32)
                    for width in (4, 16, 32, 64):
                        s[f'base_high_{width}'] += padded(hb, width)
                        s[f'difference_high_{width}'] += padded(hd, width)
            for head in range(2):
                for v in range(4):
                    output_hash.update(responses[head, v].tobytes())
            print('group', g, flush=True)
    assert codes_hash == previous['code_sha256_by_group']
    assert output_hash.hexdigest() == previous['integer_response_sha256']
    totals = {key: max(s[key] for s in stats) if key.startswith('max_')
              else sum(s[key] for s in stats) for key in names}
    assert totals['base_high'] == previous['totals']['b_first_overflow']
    assert totals['difference_high'] == previous['totals']['b_difference_overflow']
    assert totals['base_high'] + totals['difference_high'] == previous['totals']['b_corrections']
    assert totals['base_low'] == previous['totals']['first_byte_uses']
    assert totals['difference_low_32'] == previous['totals']['diff_32_padded']
    result = dict(layer=layer, source_sha256=sha(Path(__file__)), parent_sha256=sha(previous_path),
                  factor_source_sha256=sha(SOURCE), image_sha256=sha(image_path),
                  model_sha256=sha(MODEL), capture_sha256=sha(CAPTURES / f'layer{layer:02d}.npz'),
                  integer_count_sha256=previous['integer_count_sha256'],
                  code_sha256_by_group=codes_hash,
                  integer_response_sha256=output_hash.hexdigest(), per_window=stats, totals=totals,
                  domain='four inspected original-producer validation windows, 8 groups, 256 causal queries/window, frozen rank-28 paid signed-byte V/O codes',
                  cost_contract='Byte-dot coordinate terms only: each high list uses one byte dot with packed 32-coordinate V; 4/16/32/64 row padding counted. No count/list construction, gather, routing, scale, O, latency or native claim.')
    dest = DATA / 'value-shortlist-radix' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'totals': totals}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
