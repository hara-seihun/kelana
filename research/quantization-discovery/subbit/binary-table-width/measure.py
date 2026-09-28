#!/usr/bin/env python3
"""Exact narrow response-table stages for packed Qwen binary factors."""
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
IMAGES = ROOT / 'binary-factors/fixtures'
FIXTURES = ROOT / 'fixtures/qwen3-0.6b-wikitext'
OUT = ROOT / 'binary-table-width/receipt.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def quant_groups(values, bits, cap=8):
    groups = values.reshape(-1, 32)
    peak = np.max(np.abs(groups), axis=1)
    top = max(float(peak.max()), 1e-30)
    qmax = (1 << (bits - 1)) - 1
    exponent = np.clip(np.floor(np.log2(top / np.maximum(peak, 1e-30))).astype(np.int32), 0, cap)
    upper = (top / qmax) * np.exp2(-exponent.astype(np.float64))
    smaller = (peak / qmax <= .75 * upper) & (exponent < cap)
    steps = np.where(smaller, .75 * upper, upper)
    multipliers = np.where(smaller, 3 << (cap - 1 - exponent), 1 << (cap + 1 - exponent)).astype(np.int64)
    code = np.clip(np.rint(groups / steps[:, None]), -qmax - 1, qmax).astype(np.int16)
    return code, multipliers, top / qmax * 2.0 ** -(cap + 1)


def tables_and_dots(packed, codes, partition, dtype):
    rows, packed_bytes = packed.shape
    q = codes.reshape(-1)
    width = q.size
    assert packed_bytes * 8 == width and 8 % partition == 0
    signs = np.unpackbits(packed, axis=1, bitorder='little').reshape(rows, width // partition, partition)
    anchor = signs[:, :, 0]
    relative = signs[:, :, 1:] == anchor[:, :, None]
    index = np.sum(relative.astype(np.int64) * (1 << np.arange(partition - 1)), axis=2)
    chunks = q.reshape(-1, partition).astype(np.int64)
    patterns = np.arange(1 << (partition - 1), dtype=np.int64)
    coeff = np.concatenate((np.ones((len(patterns), 1), dtype=np.int64),
                            2 * ((patterns[:, None] >> np.arange(partition - 1)) & 1) - 1), axis=1)
    tables = chunks @ coeff.T
    assert tables.min() >= np.iinfo(dtype).min and tables.max() <= np.iinfo(dtype).max
    table_values = tables.astype(dtype)
    selected = table_values[np.arange(width // partition)[None, :], index].astype(np.int64)
    signed = np.where(anchor != 0, selected, -selected)
    group_dots = signed.reshape(rows, width // 32, 32 // partition).sum(axis=2, dtype=np.int64)
    return group_dots, (int(tables.min()), int(tables.max()))


def stage(packed, codes, multipliers, partition, dtype):
    groups, bounds = tables_and_dots(packed, codes, partition, dtype)
    bits = np.unpackbits(packed, axis=1, bitorder='little').astype(np.int32)
    independent = (2 * bits - 1).reshape(len(bits), -1, 32)
    direct = np.einsum('rgk,gk->rg', independent, codes.astype(np.int32), optimize=True)
    assert np.array_equal(groups, direct)
    return groups @ multipliers, bounds


def main():
    entries = []
    for image_path in sorted(IMAGES.glob('*_0.55.npz')):
        with np.load(image_path) as image:
            n, k, rank = map(int, image['dimensions'])
            u, v = image['U'].copy(), image['V'].copy()
            pre, post = image['scale_pre'].astype(np.float64), image['scale_post'].astype(np.float64)
        layer = int(image_path.name.split('_')[2])
        key = image_path.stem.split('_weight_')[0].split(f'model_layers_{layer}_')[1]
        fixture = FIXTURES / f'layer{layer:02d}-{key}.npz'
        with np.load(fixture) as data:
            inputs = data['validation'][:4].astype(np.float64)
        samples = []
        for x in inputs:
            for bits, partition, dtype in ((6, 4, np.int8), (6, 8, np.int16),
                                           (7, 4, np.int16), (7, 8, np.int16)):
                first_code, first_weights, first_base = quant_groups(x * pre, bits)
                h, first_bounds = stage(v, first_code, first_weights, partition, dtype)
                second_code, second_weights, second_base = quant_groups(h, bits)
                y, second_bounds = stage(u, second_code, second_weights, partition, dtype)
                samples.append({'bits': bits, 'partition': partition, 'first_table_range': first_bounds,
                                'second_table_range': second_bounds,
                                'first_integer_sha256': hashlib.sha256(h.tobytes()).hexdigest(),
                                'final_integer_sha256': hashlib.sha256(y.tobytes()).hexdigest(),
                                'max_abs_final_integer': int(np.max(np.abs(y))),
                                'final_scaled_norm': float(np.linalg.norm(y * first_base * second_base * post))})
            for j in (0, 2):
                assert samples[-4+j]['first_integer_sha256'] == samples[-3+j]['first_integer_sha256']
                assert samples[-4+j]['final_integer_sha256'] == samples[-3+j]['final_integer_sha256']
        entries.append({'image': str(image_path), 'image_sha256': sha(image_path),
                        'fixture_sha256': sha(fixture), 'shape': [n, k, rank], 'samples': samples})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    result = {'source_sha256': sha(Path(__file__)), 'domain': '16 paid .55 packed binary-factor images; first four previously inspected validation inputs per image; A6/A7 two-choice C8 integer-ladder quantization at both factor boundaries',
              'entries': entries}
    OUT.write_text(json.dumps(result, indent=2) + '\n')
    ranges = {}
    for bits, partition in ((6, 4), (6, 8), (7, 4), (7, 8)):
        bounds = [pair for e in entries for s in e['samples']
                  if s['bits'] == bits and s['partition'] == partition
                  for pair in (s['first_table_range'], s['second_table_range'])]
        ranges[f'{bits}/{partition}'] = [min(low for low, _ in bounds), max(high for _, high in bounds)]
    print(json.dumps({'receipt': str(OUT), 'images': len(entries), 'inputs': 4 * len(entries),
                      'observed_table_ranges': ranges}, indent=2))


if __name__ == '__main__':
    main()
