#!/usr/bin/env python3
"""Train a canonical Huffman difference stream and price exact narrow-V block payloads."""
import argparse
import hashlib
import heapq
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve()
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'value-observer'))
from fit import CAPTURES, load_capture
from fit_direct import SOURCE

DATA = Path('/path/to/workspace/data/kelana-subbit/value-entropy-ceiling')
IMAGE = Path('/path/to/workspace/data/kelana-subbit/value-observer')
PARENT = Path('/path/to/workspace/data/kelana-subbit/value-nibble-joint-fit')


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as stream:
        for part in iter(lambda: stream.read(1 << 20), b''):
            digest.update(part)
    return digest.hexdigest()


def canonical(hist):
    # A pseudocount on every possible difference makes the frozen table total.
    heap = [(int(n) + 1, i, (i,)) for i, n in enumerate(hist)]
    heapq.heapify(heap)
    lengths = [0] * 31
    serial = 31
    while len(heap) > 1:
        a = heapq.heappop(heap)
        b = heapq.heappop(heap)
        for symbol in a[2] + b[2]:
            lengths[symbol] += 1
        heapq.heappush(heap, (a[0] + b[0], serial, a[2] + b[2]))
        serial += 1
    assert max(lengths) <= 31
    code, prev = 0, 0
    mapping = {}
    for symbol in sorted(range(31), key=lambda i: (lengths[i], i)):
        length = lengths[symbol]
        code <<= length - prev
        mapping[symbol] = (code, length)
        code += 1
        prev = length
    return lengths, mapping


def roundtrip(symbols, mapping):
    # Pack MSB first, byte-align the group at each independently addressed block.
    bits = ''.join(format(mapping[int(s)][0], f'0{mapping[int(s)][1]}b') for s in symbols)
    raw = int(bits + '0' * ((-len(bits)) % 8), 2).to_bytes((len(bits)+7)//8, 'big') if bits else b''
    reverse = {(v, n): s for s, (v, n) in mapping.items()}
    out = []
    prefix = 0
    width = 0
    for byte in raw:
        for shift in range(7, -1, -1):
            if len(out) == len(symbols):
                break
            prefix = (prefix << 1) | ((byte >> shift) & 1)
            width += 1
            if (prefix, width) in reverse:
                out.append(reverse[prefix, width])
                prefix = width = 0
    assert out == list(map(int, symbols))
    return raw


def codes(layer, split, right, steps, lows, windows):
    x = load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
    grouped = []
    for group in range(8):
        z = (x @ right[group].T).to(torch.bfloat16).float()
        grouped.append(torch.maximum((z / torch.tensor(steps[group])).round().clamp(max=7),
                                     torch.tensor(lows[group])).to(torch.int8).numpy())
    result = np.stack(grouped, axis=2)
    assert result.shape == (windows, 256, 8, 28)
    return result


def run(layer):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('paid_factor_decode', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    image = IMAGE / f'layer{layer:02d}-joint-r28.npz'
    parent = PARENT / f'layer{layer:02d}-8x4.json'
    selected = json.loads(parent.read_text())['selected']
    with np.load(image) as factor:
        right = [decoder.decode({name: factor[name][group].copy() for name in factor.files}, 'right')
                 for group in range(8)]
    steps = [s['steps'] for s in selected]
    lows = [s['lows'] for s in selected]
    train = codes(layer, 'train', right, steps, lows, 8)
    held = codes(layer, 'validation', right, steps, lows, 4)
    rows = []
    for block in (32, 256):
        def differences(c):
            return np.concatenate([c[:, start+1:start+block].astype(np.int16) -
                                   c[:, start:start+block-1].astype(np.int16)
                                   for start in range(0, 256, block)], axis=1)
        td = differences(train)
        hd = differences(held)
        tables = []
        for group in range(8):
            hist = np.bincount((td[:, :, group, :] + 15).ravel(), minlength=31)
            lengths, mapping = canonical(hist)
            tables.append((lengths, mapping))
        per_window = []
        coord_window = []
        max_coord_bytes = 0
        decode_hash = hashlib.sha256()
        for window in range(4):
            total = 0
            coordinate_total = 0
            for start in range(0, 256, block):
                # 112-byte absolute anchor and one 4-byte block offset.
                total += 116
                # Independent coordinate streams add 224 one-byte offsets per block.
                coordinate_total += 116 + 224
                for group in range(8):
                    d = (held[window, start+1:start+block, group].astype(np.int16) -
                         held[window, start:start+block-1, group].astype(np.int16))
                    symbols = (d + 15).ravel()
                    encoded = roundtrip(symbols, tables[group][1])
                    total += len(encoded)
                    for coordinate in range(28):
                        stream = roundtrip(d[:, coordinate] + 15, tables[group][1])
                        coordinate_total += len(stream)
                        max_coord_bytes = max(max_coord_bytes, len(stream))
                    reconstructed = held[window, start, group].astype(np.int16) + np.cumsum(d, axis=0)
                    assert np.array_equal(reconstructed, held[window, start+1:start+block, group])
                    decode_hash.update(encoded)
            per_window.append(total)
            coord_window.append(coordinate_total)
        assert max_coord_bytes <= 255
        entropy = []
        for group in range(8):
            counts = np.bincount((hd[:, :, group, :] + 15).ravel(), minlength=31)
            probs = counts[counts > 0] / counts.sum()
            entropy.append(float(-(probs*np.log2(probs)).sum()))
        # Each group's 31 code lengths fits five bits; a code is canonical from lengths.
        table_bytes = (8*31*5 + 7)//8
        rows.append({'restart_keys': block, 'held_bytes_per_window': per_window,
                     'held_coordinate_bytes_per_window': coord_window,
                     'max_coordinate_stream_bytes': max_coord_bytes,
                     'held_coordinate_bytes_per_token': (sum(coord_window)+table_bytes)/1024,
                     'held_payload_bytes': sum(per_window), 'table_bytes_per_layer': table_bytes,
                     'held_total_bytes': sum(per_window)+table_bytes,
                     'held_total_bytes_per_token': (sum(per_window)+table_bytes)/1024,
                     'held_group_entropy_bits_per_difference': entropy,
                     'held_encoded_payload_sha256': decode_hash.hexdigest(),
                     'train_code_lengths': [pair[0] for pair in tables]})
    receipt = {'layer': layer, 'source_sha256': sha(HERE), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': sha(image), 'parent_sha256': sha(parent),
               'shape': list(held.shape), 'train_windows': 8, 'inspected_held_windows': 4,
               'static_nibble_bytes': 112*1024, 'blocks': rows,
               'contract': 'exact int16 code differences; canonical Huffman per group; byte-aligned group or per-coordinate streams per block; block anchor, offset and coordinate offsets; metadata once per layer'}
    DATA.mkdir(parents=True, exist_ok=True)
    output = DATA / f'layer{layer:02d}.json'
    output.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(output), 'rates': [(r['restart_keys'], r['held_total_bytes_per_token']) for r in rows]}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
