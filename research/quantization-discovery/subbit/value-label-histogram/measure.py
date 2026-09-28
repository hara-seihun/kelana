#!/usr/bin/env python3
"""Count exact repeated paid narrow-value labels and direct histogram work."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch

SUB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SUB / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def run(layer):
    torch.set_num_threads(8)
    parent_path = DATA / 'value-int8-consumer' / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    scale_parent = json.loads((DATA / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(MODEL) == parent['model_sha256']
    assert sha(image_path) == parent['image_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == parent['capture_sha256']
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    windows = [[] for _ in range(4)]
    x_unique = [int(np.unique(x[v].numpy(), axis=0).shape[0]) for v in range(4)]
    hashes = []
    with np.load(image_path) as image:
        for g in range(8):
            right = decoder.decode({k: image[k][g].copy() for k in image.files}, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            step = torch.tensor(scale_parent['scales'][str(g)]['int8_coordinate'], dtype=torch.float16).float()
            code = (z / step).round().clamp(-127, 127).to(torch.int8).numpy()
            hashes.append(hashlib.sha256(code.tobytes()).hexdigest())
            for v in range(4):
                rows = code[v].copy()
                _, first, inverse = np.unique(rows, axis=0, return_index=True, return_inverse=True)
                # Prefix distinct counts are independent of np.unique's sorted label order.
                seen = set()
                prefix = []
                for key in map(bytes, rows):
                    seen.add(key)
                    prefix.append(len(seen))
                # Check the exact integer histogram identity on a deterministic count row.
                n = np.arange(1, 257, dtype=np.int64) % 19
                direct = n @ rows.astype(np.int64)
                hist = np.bincount(inverse, weights=n, minlength=len(first)).astype(np.int64)
                grouped = hist @ rows[first].astype(np.int64)
                assert np.array_equal(direct, grouped)
                windows[v].append({'group': g, 'distinct_at_32': prefix[31], 'distinct_at_64': prefix[63],
                                   'distinct_at_128': prefix[127], 'distinct_at_256': prefix[255],
                                   'prefix_unique_sum': int(sum(prefix)), 'prefix_keys': 32896,
                                   'code_sha256': hashlib.sha256(rows.tobytes()).hexdigest(),
                                   'label_index_sha256': hashlib.sha256(inverse.astype('<u2').tobytes()).hexdigest(),
                                   'integer_dot_sha256': hashlib.sha256(direct.astype('<i8').tobytes()).hexdigest()})
    assert hashes == parent['code_sha256_by_group']
    for v, group_rows in enumerate(windows):
        assert all(row['distinct_at_256'] == x_unique[v] for row in group_rows)
    groups = [r for w in windows for r in w]
    unique = sum(r['prefix_unique_sum'] for r in groups)
    keys = sum(r['prefix_keys'] for r in groups)
    result = {'layer': layer, 'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(parent_path),
              'distinct_qkv_inputs_per_window': x_unique,
              'full_block_dictionary_bytes_per_window': [224 * u + 256 + 6 for u in x_unique],
              'full_block_direct_bytes_per_window': [224 * 256] * 4,
              'block_layout': 'append one contiguous 224-byte code per distinct input, one uint8 index per key, one uint16 dictionary count and one uint32 block arena address; 256 is the largest legal distinct count in this block. Index is shared across eight groups on these captures because code fibers equal QKV-input fibers.',
              'image_sha256': sha(image_path), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
              'model_sha256': sha(MODEL), 'factor_source_sha256': sha(SOURCE),
              'domain': 'four previously inspected original-producer validation windows, 256 positions, eight GQA groups, 28 signed-byte coordinates per code',
              'per_window': windows,
              'totals': {'causal_key_group_pairs': keys, 'causal_distinct_label_group_pairs': unique,
                         'two_head_direct_code_products': 56 * keys,
                         'two_head_histogram_code_products': 56 * unique,
                         'two_head_mass_accumulations': 2 * keys,
                         'product_reduction_fraction': 1 - unique / keys,
                         'full_256_key_distinct_total': sum(r['distinct_at_256'] for r in groups),
                         'full_256_key_max_distinct': max(r['distinct_at_256'] for r in groups)},
              'cost_model': 'For each causal query and group: build two int32 histograms from key->label and two counts/key; then dot each distinct label into 28 signed-byte coordinates for each head. Count costs exclude histogram initialization, index gathers, scatter conflicts, dynamic dictionary construction and O; native time not inferred.'}
    dest = DATA / 'value-label-histogram' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'totals': result['totals']}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, required=True, choices=(0, 14))
    run(parser.parse_args().layer)
