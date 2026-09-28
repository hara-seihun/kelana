#!/usr/bin/env python3
"""Price append-only V-difference rows with bounded, independent Huffman parsers."""
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
DATA = Path('/path/to/workspace/data/kelana-subbit/value-row-entropy')
SPEC = importlib.util.spec_from_file_location('value_coordinate_parent', SUBBIT / 'value-coordinate-entropy' / 'measure.py')
coord = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(coord)
base = coord.base


def mappings(ids, tables):
    result = []
    for g in range(8):
        for j in range(28):
            lengths = tables[g][int(ids[g, j])]
            code = previous = 0
            mapping = {}
            for symbol in sorted(range(31), key=lambda s: (lengths[s], s)):
                length = lengths[symbol]
                code <<= length - previous
                mapping[symbol] = (code, length)
                code += 1
                previous = length
            result.append(mapping)
    return result


def pack_decode(symbols, maps, reverse):
    bits = ''.join(format(m[int(s)][0], f'0{m[int(s)][1]}b') for s, m in zip(symbols, maps))
    raw = int(bits + '0' * (-len(bits) % 8), 2).to_bytes((len(bits)+7)//8, 'big')
    decoded = []
    prefix = length = 0
    for byte in raw:
        for shift in range(7, -1, -1):
            if len(decoded) == len(symbols):
                break
            prefix = (prefix << 1) | ((byte >> shift) & 1)
            length += 1
            symbol = reverse[len(decoded)].get((prefix, length))
            if symbol is not None:
                decoded.append(symbol)
                prefix = length = 0
    assert decoded == list(map(int, symbols))
    return raw


def run(layer):
    torch.set_num_threads(8)
    decoder_spec = importlib.util.spec_from_file_location('paid_factor_decode', base.SOURCE)
    decoder = importlib.util.module_from_spec(decoder_spec)
    decoder_spec.loader.exec_module(decoder)
    image = base.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    parent = base.PARENT / f'layer{layer:02d}-8x4.json'
    selected = json.loads(parent.read_text())['selected']
    with np.load(image) as factor:
        right = [decoder.decode({name: factor[name][g].copy() for name in factor.files}, 'right') for g in range(8)]
    train = base.codes(layer, 'train', right, [s['steps'] for s in selected], [s['lows'] for s in selected], 8)
    held = base.codes(layer, 'validation', right, [s['steps'] for s in selected], [s['lows'] for s in selected], 4)
    results = []
    mass = (np.arange(256, dtype=np.int64)*17 + 3) % 16
    direct = int((held[0, :, 0].astype(np.int64)*mass[:, None]).sum())
    delta = np.diff(held[0, :, 0].astype(np.int64), axis=0)
    suffix = np.cumsum(mass[:0:-1])[::-1]
    from_differences = int(held[0, 0, 0].astype(np.int64).sum()*mass.sum() +
                           (delta*suffix[:, None]).sum())
    assert direct == from_differences
    for width in (32, 256):
        ids, tables = coord.fit(coord.differences(train, width), 2 if layer == 0 else 4)
        maps = mappings(ids, tables)
        reverse = [{(code, length): symbol for symbol, (code, length) in m.items()} for m in maps]
        static_bytes = (8 * len(tables[0]) * 31 * 5 + 7)//8 + (8*28*(1 if layer == 0 else 2)+7)//8
        for streams in (1, 2, 4, 8):
            per_window = []
            payload_sha = hashlib.sha256()
            longest = 0
            max_block_offset = 0
            for window in range(4):
                total = 0
                for start in range(0, 256, width):
                    anchor = held[window, start].reshape(224).astype(np.int16) & 15
                    packed_anchor = (anchor[::2] | (anchor[1::2] << 4)).astype(np.uint8).tobytes()
                    assert np.array_equal(np.stack([np.frombuffer(packed_anchor, dtype=np.uint8) & 15,
                                                    np.frombuffer(packed_anchor, dtype=np.uint8) >> 4], axis=1).reshape(224), anchor)
                    block = bytearray(packed_anchor + bytes(2*(width-1)))
                    for t in range(start+1, start+width):
                        row_start = len(block)
                        struct.pack_into('<H', block, 112 + 2*(t-start-1), row_start)
                        diff = (held[window, t].astype(np.int16) - held[window, t-1].astype(np.int16)).reshape(224) + 15
                        chunks = []
                        for part in range(streams):
                            lo, hi = part*224//streams, (part+1)*224//streams
                            raw = pack_decode(diff[lo:hi], maps[lo:hi], reverse[lo:hi])
                            assert len(raw) <= 255
                            chunks.append(raw)
                            longest = max(longest, hi-lo)
                            payload_sha.update(raw)
                        # Stream lengths precede the concatenated stream bodies. The last
                        # length follows from the next row start or the block end.
                        block.extend(bytes(len(raw) for raw in chunks[:-1]))
                        for raw in chunks:
                            block.extend(raw)
                        assert struct.unpack_from('<H', block, 112 + 2*(t-start-1))[0] == row_start
                        assert sum(block[row_start:row_start+streams-1]) + len(chunks[-1]) == len(block)-row_start-(streams-1)
                    max_block_offset = max(max_block_offset, len(block))
                    assert len(block) < 65536
                    total += 4 + len(block)  # Four-byte global block address.
                per_window.append(total)
            total_bytes = sum(per_window) + static_bytes
            results.append({'restart_keys': width, 'streams_per_row': streams,
                            'max_serial_symbols_per_stream': longest,
                            'max_block_bytes': max_block_offset, 'static_table_and_assignment_bytes': static_bytes,
                            'held_bytes_per_window': per_window, 'held_bytes_per_token': total_bytes/1024,
                            'held_total_bytes': total_bytes, 'encoded_payload_sha256': payload_sha.hexdigest(),
                            'table_lengths': tables, 'bucket_ids': ids.tolist()})
            print(layer, width, streams, round(total_bytes/1024, 3), flush=True)
    receipt = {'layer': layer, 'source_sha256': base.sha(HERE), 'parent_source_sha256': base.sha(coord.HERE),
               'capture_sha256': base.sha(base.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': base.sha(image), 'parent_sha256': base.sha(parent),
               'shape': list(held.shape), 'train_windows': 8, 'inspected_held_windows': 4,
               'integer_direct_response_witness': direct, 'integer_suffix_response_witness': from_differences,
               'contract': '256-token frozen narrow-V signed-nibble codes; train-only coordinate entropy rank and canonical Huffman lengths; independently appended rows, 2-byte relative row starts, streams-1 one-byte stream lengths, byte-aligned streams, 112-byte block anchor, four-byte block start, static table metadata counted once across 1024 held tokens',
               'results': results}
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / f'layer{layer:02d}.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
