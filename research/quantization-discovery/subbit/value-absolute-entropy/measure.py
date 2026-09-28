#!/usr/bin/env python3
"""Charge append-only absolute V-label rows against difference-coded rows."""
import argparse
import hashlib
import importlib.util
import json
import struct
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit/value-absolute-entropy')
SPEC = importlib.util.spec_from_file_location('value_row_parent', SUBBIT / 'value-row-entropy' / 'measure.py')
parent = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(parent)
base = parent.base


def fit(train, ntable):
    hist = np.stack([np.bincount((train[:, :, g, j].ravel() + 8).astype(np.int64), minlength=16)
                     for g in range(8) for j in range(28)]).reshape(8, 28, 16)
    ids = np.zeros((8, 28), dtype=np.uint8)
    tables = []
    for g in range(8):
        p = hist[g] / hist[g].sum(axis=1, keepdims=True)
        entropy = -np.sum(np.where(p > 0, p * np.log2(np.maximum(p, 1e-30)), 0), axis=1)
        order = sorted(range(28), key=lambda j: (entropy[j], j))
        for rank, j in enumerate(order):
            ids[g, j] = min(ntable - 1, rank * ntable // 28)
        tables.append([base.canonical(hist[g, ids[g] == bucket].sum(axis=0))[0]
                       for bucket in range(ntable)])
    return ids, tables


def mappings(ids, tables):
    result = []
    for g in range(8):
        for j in range(28):
            lengths = tables[g][int(ids[g, j])]
            code = previous = 0
            mapping = {}
            for symbol in sorted(range(16), key=lambda s: (lengths[s], s)):
                length = lengths[symbol]
                code <<= length - previous
                mapping[symbol] = (code, length)
                code += 1
                previous = length
            result.append(mapping)
    return result


def run(layer):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('paid_factor_decode', base.SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    image = base.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    source = base.PARENT / f'layer{layer:02d}-8x4.json'
    selected = json.loads(source.read_text())['selected']
    with np.load(image) as factor:
        right = [decoder.decode({name: factor[name][g].copy() for name in factor.files}, 'right') for g in range(8)]
    train = base.codes(layer, 'train', right, [s['steps'] for s in selected], [s['lows'] for s in selected], 8)
    held = base.codes(layer, 'validation', right, [s['steps'] for s in selected], [s['lows'] for s in selected], 4)
    results = []
    for ntable in (1, 2, 4):
        ids, tables = fit(train, ntable)
        maps = mappings(ids, tables)
        reverse = [{(code, length): symbol for symbol, (code, length) in m.items()} for m in maps]
        table_bytes = (8 * ntable * 16 * 4 + 7) // 8
        assignment_bytes = 0 if ntable == 1 else (8 * 28 * (ntable.bit_length() - 1) + 7) // 8
        for streams in (1, 2, 4, 8):
            per_window = []
            digest = hashlib.sha256()
            maximum = 0
            for window in range(4):
                # 32-bit row starts cover even an adversarial signed-nibble history.
                block = bytearray(bytes(4 * 256))
                for t in range(256):
                    start = len(block)
                    assert start < 2**32
                    struct.pack_into('<I', block, 4*t, start)
                    row = (held[window, t].reshape(224).astype(np.int16) + 8)
                    chunks = []
                    for part in range(streams):
                        lo, hi = part * 224 // streams, (part + 1) * 224 // streams
                        raw = parent.pack_decode(row[lo:hi], maps[lo:hi], reverse[lo:hi])
                        assert len(raw) <= 255
                        chunks.append(raw)
                        digest.update(raw)
                    block.extend(bytes(len(raw) for raw in chunks[:-1]))
                    for raw in chunks:
                        block.extend(raw)
                    assert struct.unpack_from('<I', block, 4*t)[0] == start
                    maximum = max(maximum, len(block))
                per_window.append(len(block) + 4)
            results.append({'tables_per_group': ntable, 'streams_per_row': streams,
                            'serial_symbols_per_parser': 224 // streams,
                            'held_bytes_per_window': per_window,
                            'held_bytes_per_token': (sum(per_window) + table_bytes + assignment_bytes) / 1024,
                            'max_block_bytes': maximum, 'static_table_and_assignment_bytes': table_bytes + assignment_bytes,
                            'payload_sha256': digest.hexdigest(), 'table_lengths': tables, 'bucket_ids': ids.tolist()})
            print(layer, ntable, streams, results[-1]['held_bytes_per_token'], flush=True)
    receipt = {'layer': layer, 'source_sha256': base.sha(HERE),
               'capture_sha256': base.sha(base.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': base.sha(image), 'parent_sha256': base.sha(source),
               'train_windows': 8, 'inspected_held_windows': 4,
               'shape': list(held.shape), 'contract': 'absolute signed-nibble V labels, one append-only 256-row block per window; four-byte global address, 1024-byte 32-bit row directory valid for every signed-nibble history, 1-8 independent canonical Huffman parsers and per-parser one-byte lengths except the last, byte-aligned row streams; train-only entropy-rank bucket assignments, static lengths charged once over 1024 held tokens; direct integer weighted-value response without temporal suffix scan',
               'results': results}
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / f'layer{layer:02d}.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
