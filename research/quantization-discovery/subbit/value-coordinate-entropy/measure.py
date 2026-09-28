#!/usr/bin/env python3
"""Train coordinate-conditioned temporal V Huffman tables; price complete block images."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit/value-coordinate-entropy')
BASE = SUBBIT / 'value-entropy-ceiling' / 'measure.py'
spec = importlib.util.spec_from_file_location('value_entropy_base', BASE)
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def differences(codes, width):
    return np.concatenate([codes[:, start+1:start+width].astype(np.int16) -
                           codes[:, start:start+width-1].astype(np.int16)
                           for start in range(0, 256, width)], axis=1) + 15


def fit(train, ntable):
    # Eight train groups. Assign by empirical entropy rank; never consult held labels.
    hist = np.stack([np.bincount(train[:, :, g, j].ravel(), minlength=31)
                     for g in range(8) for j in range(28)]).reshape(8, 28, 31)
    ids = np.zeros((8, 28), dtype=np.uint8)
    tables = []
    for g in range(8):
        p = hist[g] / hist[g].sum(axis=1, keepdims=True)
        entropy = -np.sum(np.where(p > 0, p*np.log2(np.maximum(p, 1e-30)), 0), axis=1)
        order = sorted(range(28), key=lambda j: (entropy[j], j))
        for rank, j in enumerate(order):
            ids[g, j] = min(ntable-1, rank*ntable//28)
        group = []
        for bucket in range(ntable):
            selected = hist[g, ids[g] == bucket].sum(axis=0)
            group.append(base.canonical(selected)[0])
        tables.append(group)
    return ids, tables


def pack_mixed(symbols, mappings):
    """Round-trip a group stream whose prefix tree changes with the coordinate."""
    bits = ''.join(format(mappings[j % 28][int(s)][0], f'0{mappings[j % 28][int(s)][1]}b')
                   for j, s in enumerate(symbols))
    raw = int(bits + '0' * (-len(bits) % 8), 2).to_bytes((len(bits)+7)//8, 'big')
    reverse = [{(code, length): s for s, (code, length) in mapping.items()}
               for mapping in mappings]
    out, prefix, length = [], 0, 0
    for byte in raw:
        for bit in range(7, -1, -1):
            if len(out) == len(symbols):
                break
            prefix = (prefix << 1) | ((byte >> bit) & 1)
            length += 1
            symbol = reverse[len(out) % 28].get((prefix, length))
            if symbol is not None:
                out.append(symbol)
                prefix = length = 0
    assert out == symbols
    return raw


def reachable_max_bits(lengths, width):
    """Exact max-plus path on all 16 signed-nibble states, any block anchor."""
    states = np.arange(-8, 8)
    edge = np.asarray(lengths)[states[None, :] - states[:, None] + 15]
    scores = np.zeros(16, dtype=np.int32)
    for _ in range(width-1):
        scores = (scores[:, None] + edge).max(axis=0)
    return int(scores.max())


def payload(held, width, ids, tables, per_coordinate, check=False):
    total_per_window = []
    payload_hash = hashlib.sha256()
    max_length = 0
    max_bits = 0
    for w in range(4):
        total = 0
        for start in range(0, 256, width):
            total += 116  # 112-byte anchor and four-byte offset per block
            if per_coordinate:
                total += 224  # byte length per separately addressable stream
            for g in range(8):
                d = held[w, start+1:start+width, g].astype(np.int16) - held[w, start:start+width-1, g].astype(np.int16) + 15
                mappings = []
                for table in tables[g]:
                    mapping = {}
                    code = prev = 0
                    for symbol in sorted(range(31), key=lambda s: (table[s], s)):
                        length = table[symbol]
                        code <<= length - prev
                        mapping[symbol] = (code, length)
                        code += 1
                        prev = length
                    mappings.append(mapping)
                if per_coordinate:
                    streams = [[int(s) for s in d[:, j]] for j in range(28)]
                    maps = [mappings[ids[g, j]] for j in range(28)]
                else:
                    streams = [[int(d[t, j]) for t in range(width-1) for j in range(28)]]
                    # Variable tables are valid within a single group stream; prefix decoding
                    # uses the known coordinate index modulo 28, not one common tree.
                    maps = [None]
                for stream, mapping in zip(streams, maps):
                    if mapping is not None:
                        bits = sum(mapping[s][1] for s in stream)
                        if check:
                            encoded = base.roundtrip(stream, mapping)
                            assert len(encoded) == (bits+7)//8
                            payload_hash.update(encoded)
                    else:
                        bits = sum(mappings[ids[g, j]][int(d[t, j])][1]
                                   for t in range(width-1) for j in range(28))
                        if check:
                            encoded = pack_mixed(stream, [mappings[ids[g, j]] for j in range(28)])
                            assert len(encoded) == (bits+7)//8
                            payload_hash.update(encoded)
                    total += (bits+7)//8
                    max_length = max(max_length, (bits+7)//8)
                    max_bits = max(max_bits, bits)
        total_per_window.append(total)
    return total_per_window, max_length, max_bits, payload_hash.hexdigest() if check else None


def run(layer):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('paid_factor_decode', base.SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    image = base.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    parent = base.PARENT / f'layer{layer:02d}-8x4.json'
    selected = json.loads(parent.read_text())['selected']
    with np.load(image) as factor:
        right = [decoder.decode({name: factor[name][group].copy() for name in factor.files}, 'right') for group in range(8)]
    steps, lows = [s['steps'] for s in selected], [s['lows'] for s in selected]
    train = base.codes(layer, 'train', right, steps, lows, 8)
    held = base.codes(layer, 'validation', right, steps, lows, 4)
    results = []
    for width in (32, 256):
        td, hd = differences(train, width), differences(held, width)
        for ntable in (1, 2, 4, 28):
            ids, tables = fit(td, ntable)
            table_bytes = (8*ntable*31*5+7)//8
            # Bucket ID is implicit for one and 28 tables, otherwise explicitly stored.
            assignment_bytes = (8*28*math.ceil(math.log2(ntable))+7)//8 if 1 < ntable < 28 else 0
            # Each coordinate has a fixed worst-case slot for all signed-nibble histories.
            # This permits in-place incremental append without stream repacking or relocation.
            reachable = [[reachable_max_bits(table, width) for table in group] for group in tables]
            fixed_slots_per_block = sum((reachable[g][ids[g, j]] + 7)//8
                                        for g in range(8) for j in range(28))
            fixed_total_rate = ((fixed_slots_per_block + 116) * (256//width) * 4 +
                                table_bytes + assignment_bytes) / 1024
            for layout in ('group', 'coordinate'):
                # Byte length cannot describe a group stream. Coordinate length must fit 255.
                window_bytes, max_length, max_bits, stream_hash = payload(
                    held, width, ids, tables, layout == 'coordinate', check=(ntable == 4))
                if layout == 'coordinate':
                    assert max_length <= 255
                results.append({'restart_keys': width, 'tables_per_group': ntable, 'layout': layout,
                                'payload_bytes_per_window': window_bytes, 'table_bytes': table_bytes,
                                'assignment_bytes': assignment_bytes,
                                'total_bytes_per_token': (sum(window_bytes)+table_bytes+assignment_bytes)/1024,
                                'max_stream_bytes': max_length, 'max_stream_bits': max_bits,
                                'fixed_worst_case_coordinate_slot_bytes_per_token': fixed_total_rate,
                                'fixed_slots_bytes_per_block': fixed_slots_per_block,
                                'reachable_max_bits_per_table': reachable,
                                'encoded_stream_sha256': stream_hash,
                                'table_lengths': tables, 'coordinate_bucket_ids': ids.tolist()})
    receipt = {'layer': layer, 'source_sha256': base.sha(HERE), 'parent_source_sha256': base.sha(BASE),
               'capture_sha256': base.sha(base.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': base.sha(image), 'parent_sha256': base.sha(parent),
               'train_windows': 8, 'inspected_held_windows': 4, 'shape': list(held.shape),
               'static_nibble_bytes_per_token': 112, 'results': results,
               'contract': 'exact signed differences; train-only entropy-rank bucket assignments and canonical Huffman tables; 112-byte anchors and 4-byte block offsets; byte-aligned group/coordinate streams; coordinate length bytes charged; static tables and assignments charged once over 1024 tokens'}
    DATA.mkdir(parents=True, exist_ok=True)
    output = DATA / f'layer{layer:02d}.json'
    output.write_text(json.dumps(receipt, indent=2) + '\n')
    for r in results:
        print(layer, r['restart_keys'], r['tables_per_group'], r['layout'], round(r['total_bytes_per_token'], 3), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
