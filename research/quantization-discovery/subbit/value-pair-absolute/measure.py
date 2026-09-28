#!/usr/bin/env python3
"""Price directly consumed fixed-width absolute V-pair rows on a paid cache."""
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
DATA = Path('/path/to/workspace/data/kelana-subbit/value-pair-absolute')
spec = importlib.util.spec_from_file_location('absolute_rows', SUBBIT / 'value-absolute-entropy' / 'measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
base = parent.base


def fit(train, bits, pairing):
    codes = (train.astype(np.int16) + 8).reshape(-1, 8, 28).astype(np.uint8)
    groups = []
    for g in range(8):
        hist = {}
        for i in range(28):
            for j in range(i+1, 28):
                values = (codes[:, g, i].astype(np.uint16) << 4) | codes[:, g, j]
                hist[i, j] = np.bincount(values, minlength=256)
        remaining = set(range(28))
        pairs = []
        while remaining:
            if pairing == 'adjacent':
                i = min(remaining)
                j = i+1
            else:
                i, j = max(((i, j) for i in remaining for j in remaining if i < j),
                           key=lambda pair: (sum(sorted(hist[pair], reverse=True)[:(1 << bits)-1]),
                                             -pair[0], -pair[1]))
            pairs.append((i, j))
            remaining.remove(i)
            remaining.remove(j)
        tables = [np.argsort(-hist[i, j], kind='stable')[:(1 << bits)-1].astype(np.uint8).tolist()
                  for i, j in pairs]
        groups.append((pairs, tables))
    return groups


def fit_mixed(train):
    codes = (train.astype(np.int16) + 8).reshape(-1, 8, 28).astype(np.uint8)
    groups = []
    for g in range(8):
        widths, tables = [], []
        for i in range(0, 28, 2):
            values = (codes[:, g, i].astype(np.uint16) << 4) | codes[:, g, i+1]
            hist = np.bincount(values, minlength=256)
            ranked = np.argsort(-hist, kind='stable')
            def cost(bits):
                if bits == 8:
                    return 8
                size = (1 << bits)-1
                return bits + 8*(1-hist[ranked[:size]].sum()/hist.sum()) + 8*size/1024
            bits = min(range(4, 9), key=lambda b: (cost(b), b))
            widths.append(bits)
            tables.append([] if bits == 8 else ranked[:(1 << bits)-1].astype(np.uint8).tolist())
        groups.append(([(i, i+1) for i in range(0, 28, 2)], tables, widths))
    return groups


def row_image(row, groups, bits):
    # One fixed-width code plane followed by raw eight-bit escape pairs. A rank of
    # earlier escapes gives each lane its payload address, without a Huffman walk.
    labels = row.reshape(8, 28).astype(np.int16) + 8
    values = [(int(labels[g, i]) << 4) | int(labels[g, j])
              for g, group in enumerate(groups) for i, j in group[0]]
    tables = [table for group in groups for table in group[1]]
    widths = [width for group in groups for width in (group[2] if bits is None else [bits]*14)]
    maps = [{value: n for n, value in enumerate(table)} for table in tables]
    symbols = [value if width == 8 else mapping.get(value, (1 << width)-1)
               for mapping, value, width in zip(maps, values, widths)]
    extras = bytes(value for value, symbol, width in zip(values, symbols, widths)
                   if width != 8 and symbol == (1 << width)-1)
    packed = bytearray((sum(widths)+7)//8)
    pos = 0
    for symbol, width in zip(symbols, widths):
        for bit in range(width):
            packed[pos//8] |= ((symbol >> (width-1-bit)) & 1) << (7-pos%8)
            pos += 1
    read = []
    rank = pos = 0
    for table, width in zip(tables, widths):
        symbol = 0
        for bit in range(width):
            symbol = (symbol << 1) | ((packed[pos//8] >> (7-pos%8)) & 1)
            pos += 1
        if width != 8 and symbol == (1 << width)-1:
            read.append(extras[rank])
            rank += 1
        else:
            read.append(symbol if width == 8 else table[symbol])
    assert read == values and rank == len(extras)
    return bytes(packed)+extras, len(extras)


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
    for bits in (4, 5, 6, 7):
        for pairing in ('adjacent', 'greedy'):
            raw_groups = fit(train, bits, pairing)
            groups = [(pairs, tables, [bits]*14) for pairs, tables in raw_groups]
            # Each pair table stores its direct eight-bit labels. Each pairing stores
            # two five-bit coordinate indices per pair; avoid relying on implicit order.
            static = 8*14*((1 << bits)-1) + ((8*14*10+7)//8 if pairing == 'greedy' else 0)
            per_window = []
            extra_counts = []
            payload = hashlib.sha256()
            for window in range(4):
                block = bytearray(2*256)
                escapes = 0
                for t in range(256):
                    struct.pack_into('<H', block, 2*t, len(block))
                    encoded, count = row_image(held[window, t], groups, bits)
                    block.extend(encoded)
                    payload.update(encoded)
                    escapes += count
                # One four-byte global block pointer, paid per 256-key window.
                per_window.append(len(block)+4)
                extra_counts.append(escapes)
            result = {'pairing': pairing, 'bits': bits, 'held_bytes_per_window': per_window,
                      'escapes_per_window': extra_counts, 'held_bytes_per_token': (sum(per_window)+static)/1024,
                      'static_bytes': static, 'max_row_bytes_full_domain': 14*8*bits//8+112,
                      'max_block_bytes_full_domain': 512+256*(14*bits+112),
                      'payload_sha256': payload.hexdigest(),
                      'coordinate_pairs_and_tables': groups}
            results.append(result)
            print(layer, bits, pairing, result['held_bytes_per_token'], flush=True)
    groups = fit_mixed(train)
    static = sum(len(table) for group in groups for table in group[1]) + (8*14*3+7)//8
    per_window, extra_counts = [], []
    payload = hashlib.sha256()
    for window in range(4):
        block = bytearray(2*256)
        escapes = 0
        for t in range(256):
            struct.pack_into('<H', block, 2*t, len(block))
            encoded, count = row_image(held[window, t], groups, None)
            block.extend(encoded)
            payload.update(encoded)
            escapes += count
        per_window.append(len(block)+4)
        extra_counts.append(escapes)
    results.append({'pairing': 'adjacent-mixed', 'bits': [group[2] for group in groups],
                    'held_bytes_per_window': per_window, 'escapes_per_window': extra_counts,
                    'held_bytes_per_token': (sum(per_window)+static)/1024,
                    'static_bytes': static, 'max_row_bytes_full_domain': 224,
                    'max_block_bytes_full_domain': 512+256*224,
                    'payload_sha256': payload.hexdigest(), 'coordinate_pairs_and_tables': groups})
    print(layer, 'mixed', results[-1]['held_bytes_per_token'], flush=True)
    receipt = {'layer': layer, 'source_sha256': base.sha(HERE), 'capture_sha256': base.sha(base.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': base.sha(image), 'parent_sha256': base.sha(source),
               'train_windows': 8, 'inspected_held_windows': 4, 'shape': list(held.shape),
               'contract': 'frozen paid signed-nibble absolute V labels; 112 group-local coordinate pairs/row; train-only adjacent or greedy pairing and top-frequency fixed-width pair tables; reserved all-ones escape plus one raw byte/pair; fixed bitplane and escape tail each append as one independently addressed row; 16-bit relative row directory (worst block <=57856 bytes on the full signed-nibble domain) and 4-byte block pointer; static tables, optional ten pairing bits/pair or mixed three-bit widths charged once over 1024 keys; exact integer direct mass response, no int4 expansion required',
               'results': results}
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / f'layer{layer:02d}.json').write_text(json.dumps(receipt, indent=2)+'\n')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(ap.parse_args().layer)
