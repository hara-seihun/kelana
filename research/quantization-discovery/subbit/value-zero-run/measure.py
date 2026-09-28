#!/usr/bin/env python3
"""Price appendable sparse V difference rows with exact direct suffix-mass response."""
import argparse
import hashlib
import importlib.util
import heapq
import json
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit/value-zero-run')
spec = importlib.util.spec_from_file_location('value_row_parent', SUBBIT / 'value-row-entropy' / 'measure.py')
row = importlib.util.module_from_spec(spec)
spec.loader.exec_module(row)
base = row.base


def inputs(layer):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('paid_factor_decode', base.SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    image = base.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    parent = base.PARENT / f'layer{layer:02d}-8x4.json'
    selected = json.loads(parent.read_text())['selected']
    with np.load(image) as factor:
        right = [decoder.decode({name: factor[name][g].copy() for name in factor.files}, 'right') for g in range(8)]
    steps = [s['steps'] for s in selected]
    lows = [s['lows'] for s in selected]
    return (base.codes(layer, 'train', right, steps, lows, 8),
            base.codes(layer, 'validation', right, steps, lows, 4), image, parent)


def canonical(hist):
    heap = [(int(n)+1, i, (i,)) for i, n in enumerate(hist)]
    heapq.heapify(heap)
    lengths = [0]*len(hist)
    serial = len(hist)
    while len(heap) > 1:
        a, b = heapq.heappop(heap), heapq.heappop(heap)
        for symbol in a[2]+b[2]:
            lengths[symbol] += 1
        heapq.heappush(heap, (a[0]+b[0], serial, a[2]+b[2]))
        serial += 1
    mapping = {}
    code = previous = 0
    for symbol in sorted(range(len(hist)), key=lambda i: (lengths[i], i)):
        length = lengths[symbol]
        code <<= length-previous
        mapping[symbol] = (code, length)
        code += 1
        previous = length
    return lengths, mapping


def bits_to_bytes(bits):
    return int(bits + '0' * (-len(bits) % 8), 2).to_bytes((len(bits)+7)//8, 'big') if bits else b''


def encode_group(delta, mode, mapping=None):
    """Independent 28-coordinate group; zero mask or zero-run Huffman."""
    nonzero = np.flatnonzero(delta)
    if mode == 'mask':
        bits = ''.join(str(int(v != 0)) for v in delta)
        bits += ''.join(format(int(delta[j]) + 15, '05b') for j in nonzero)
    elif mode == 'indexed':
        bits = format(len(nonzero), '05b')
        bits += ''.join(format(int(j), '05b') + format(int(delta[j]) + 15, '05b') for j in nonzero)
    elif mode == 'run':
        bits = ''
        before = -1
        for j in nonzero:
            run = int(j) - before - 1
            for symbol in (run, int(delta[j]) + 44):
                code, length = mapping[symbol]
                bits += format(code, f'0{length}b')
            before = int(j)
        code, length = mapping[28 - before - 1]  # terminal zero run + no value
        bits += format(code, f'0{length}b')
    else:
        raise ValueError(mode)
    raw = bits_to_bytes(bits)
    if mode == 'mask':
        read = np.array([int(b) for b in bits[:28]], dtype=bool)
        payload = [int(bits[p:p+5], 2) - 15 for p in range(28, len(bits), 5)]
        restored = np.zeros(28, dtype=np.int16)
        restored[read] = payload
    elif mode == 'indexed':
        restored = np.zeros(28, dtype=np.int16)
        count = int(bits[:5], 2)
        for i in range(count):
            p = 5 + 10*i
            restored[int(bits[p:p+5], 2)] = int(bits[p+5:p+10], 2) - 15
    else:
        reverse = {(v, n): s for s, (v, n) in mapping.items()}
        restored = np.zeros(28, dtype=np.int16)
        pos = 0
        pending = None
        prefix = length = 0
        done = False
        for byte in raw:
            for shift in range(7, -1, -1):
                prefix = (prefix << 1) | ((byte >> shift) & 1)
                length += 1
                symbol = reverse.get((prefix, length))
                if symbol is None:
                    continue
                prefix = length = 0
                if pending is None:
                    pos += symbol
                    if pos == 28:
                        done = True
                        break
                    assert pos < 28
                    pending = pos
                else:
                    assert 29 <= symbol <= 59
                    restored[pending] = symbol - 44
                    pos += 1
                    pending = None
            if done:
                break
        assert done and pending is None
    assert np.array_equal(restored, delta)
    return raw, len(nonzero), len(bits)


def run(layer):
    train, held, image, parent = inputs(layer)
    mass = ((np.arange(256, dtype=np.int64)*17 + 3) % 31).reshape(256, 1, 1)
    direct = np.sum(held[0].astype(np.int64)*mass, axis=0)
    delta = np.diff(held[0].astype(np.int64), axis=0)
    suffix = np.cumsum(mass[:0:-1], axis=0)[::-1]
    carried = held[0, 0].astype(np.int64)*mass.sum() + np.sum(delta*suffix, axis=0)
    assert np.array_equal(direct, carried)
    receipt = {'layer': layer, 'source_sha256': base.sha(HERE), 'parent_source_sha256': base.sha(row.HERE), 'capture_sha256': base.sha(base.CAPTURES / f'layer{layer:02d}.npz'), 'factor_sha256': base.sha(image), 'parent_sha256': base.sha(parent), 'train_windows': 8, 'inspected_held_windows': 4, 'suffix_integer_response_sha256': hashlib.sha256(carried.tobytes()).hexdigest(), 'results': []}
    for width in (32, 256):
        td = row.coord.differences(train, width).astype(np.int16) - 15
        counts = np.zeros((8, 60), dtype=np.int64)
        for group in range(8):
            for d in td[:, :, group]:
                for v in d:
                    last = -1
                    for j in np.flatnonzero(v):
                        counts[group, j-last-1] += 1
                        counts[group, 44 + int(v[j])] += 1
                        last = int(j)
                    counts[group, 28-last-1] += 1
        # Zero-run symbols 0..28; signed nonzero delta symbols 29..59 (delta -15..15, except zero).
        # The terminal run ends at coordinate 28; the decoder stops before byte padding.
        tables = [canonical(counts[g]) for g in range(8)]
        assert max(max(lengths) for lengths, _ in tables) <= 31
        maps = [mapping for _, mapping in tables]
        for mode in ('mask', 'indexed', 'run'):
            per_window = []
            nonzero = max_row = max_block = max_bits = 0
            digest = hashlib.sha256()
            for w in range(4):
                total = 0
                for start in range(0, 256, width):
                    block = bytearray(112 + 2*(width-1))
                    anchor = held[w, start].reshape(224).astype(np.int16) & 15
                    block[:112] = (anchor[::2] | (anchor[1::2] << 4)).astype(np.uint8).tobytes()
                    for t in range(start+1, start+width):
                        row_start = len(block)
                        block[112+2*(t-start-1):114+2*(t-start-1)] = row_start.to_bytes(2, 'little')
                        parts = []
                        for g in range(8):
                            d = held[w, t, g].astype(np.int16) - held[w, t-1, g].astype(np.int16)
                            raw, nnz, nbits = encode_group(d, mode, maps[g] if mode == 'run' else None)
                            nonzero += nnz
                            max_bits = max(max_bits, nbits)
                            parts.append(raw)
                            digest.update(raw)
                        assert all(len(part) <= 255 for part in parts)
                        max_row = max(max_row, sum(map(len, parts)) + 7)
                        block.extend(bytes(len(part) for part in parts[:-1]))
                        for part in parts:
                            block.extend(part)
                    assert len(block) < 65536
                    max_block = max(max_block, len(block))
                    total += len(block) + 4
                per_window.append(total)
            static = (8*60*5 + 7)//8 if mode == 'run' else 0
            total = sum(per_window) + static
            baseline_bytes = 112*1024
            anchor_address_bytes = 4*(256//width)*(112+4)
            directory_bytes = 4*(256-256//width)*2
            fixed_value_floor_bytes = anchor_address_bytes + directory_bytes + (nonzero*5+7)//8
            max_nonzero_for_fixed_values = (8*(baseline_bytes-anchor_address_bytes-directory_bytes)-1)//5
            result = {'restart_keys': width, 'mode': mode, 'held_bytes_per_window': per_window, 'static_bytes': static, 'charged_bytes_per_token': total/1024, 'nonzero_count': nonzero, 'nonzero_fraction': nonzero/(224*4*(256-256//width)), 'five_bit_values_free_positions_byte_floor': fixed_value_floor_bytes, 'five_bit_values_rate_threshold_nonzero': max_nonzero_for_fixed_values, 'max_group_bits': max_bits, 'max_row_bytes': max_row, 'max_block_bytes': max_block, 'payload_sha256': digest.hexdigest()}
            receipt['results'].append(result)
            print(layer, width, mode, total/1024, result['nonzero_fraction'], flush=True)
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / f'layer{layer:02d}.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
