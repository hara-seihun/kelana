#!/usr/bin/env python3
"""Price an appendable page-chain layout for the frozen narrow-V Huffman codes."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
PARENT = SUBBIT / 'value-coordinate-entropy' / 'measure.py'
spec = importlib.util.spec_from_file_location('value_coordinate_entropy', PARENT)
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
base = parent.base
DATA = Path('/path/to/workspace/data/kelana-subbit/value-paged-entropy')


def mapping(lengths):
    code = previous = 0
    result = {}
    for symbol in sorted(range(31), key=lambda s: (lengths[s], s)):
        length = lengths[symbol]
        code <<= length - previous
        result[symbol] = (code, length)
        code += 1
        previous = length
    return result


def paged_stream(symbols, codes, capacity):
    """Append one codeword at a time, retaining bit cursor, linked pages and their writes."""
    pages = [bytearray(capacity)]
    next_page = [65535]
    page_index = bit_cursor = pointer_writes = total_bits = 0
    digest = hashlib.sha256()
    for symbol in symbols:
        code, width = codes[int(symbol)]
        total_bits += width
        for shift in range(width - 1, -1, -1):
            if bit_cursor == capacity * 8:
                next_page[page_index] = len(pages)
                pointer_writes += 1
                page_index = len(pages)
                pages.append(bytearray(capacity))
                next_page.append(65535)
                bit_cursor = 0
            if (code >> shift) & 1:
                pages[page_index][bit_cursor // 8] |= 1 << (7 - bit_cursor % 8)
            bit_cursor += 1
    # Decode directly through the page links. The known key count ends parsing;
    # neither a byte length nor a codeword terminator is needed.
    reverse = {(code, width): symbol for symbol, (code, width) in codes.items()}
    restored = []
    cursor = page = prefix = length = 0
    while len(restored) < len(symbols):
        if cursor == capacity * 8:
            page = next_page[page]
            assert page != 65535
            cursor = 0
        bit = (pages[page][cursor // 8] >> (7 - cursor % 8)) & 1
        cursor += 1
        prefix = prefix * 2 + bit
        length += 1
        if (prefix, length) in reverse:
            restored.append(reverse[prefix, length])
            prefix = length = 0
    assert restored == list(map(int, symbols))
    assert page == page_index and cursor == bit_cursor
    for block in pages:
        digest.update(block)
    return len(pages), pointer_writes, total_bits, digest.digest()


def run(layer):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('paid_factor_decode', base.SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    image = base.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    factor_parent = base.PARENT / f'layer{layer:02d}-8x4.json'
    selected = json.loads(factor_parent.read_text())['selected']
    with np.load(image) as factor:
        right = [decoder.decode({name: factor[name][group].copy() for name in factor.files}, 'right') for group in range(8)]
    train = base.codes(layer, 'train', right, [s['steps'] for s in selected],
                       [s['lows'] for s in selected], 8)
    held = base.codes(layer, 'validation', right, [s['steps'] for s in selected],
                      [s['lows'] for s in selected], 4)
    results = []
    for width in (32, 256):
        observed_bit_lengths = []
        ids, tables = parent.fit(parent.differences(train, width), 4)
        codes = [[mapping(table) for table in group] for group in tables]
        table_bytes, assignment_bytes = 620, 56
        worst_bits = [[parent.reachable_max_bits(table, width) for table in group]
                      for group in tables]
        for capacity in (4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 128):
            # Pages have P payload bytes and a 16-bit next-page index. Page 0..223
            # are fixed, so no head pointer is needed. A 16-bit tail-page index
            # and a 16-bit tail-bit cursor per coordinate make append O(1).
            bound = sum((worst_bits[g][ids[g, j]] + capacity*8 - 1) // (capacity*8)
                        for g in range(8) for j in range(28))
            assert bound < 65535
            windows = []
            stream_hash = hashlib.sha256()
            for w in range(4):
                bytes_used = pages_used = overflow = 0
                for start in range(0, 256, width):
                    page_count = 0
                    for g in range(8):
                        diff = held[w, start+1:start+width, g].astype(np.int16) - held[w, start:start+width-1, g].astype(np.int16) + 15
                        for j in range(28):
                            count, writes, bits, digest = paged_stream(diff[:, j], codes[g][ids[g, j]], capacity)
                            if capacity == 20:
                                observed_bit_lengths.append(bits)
                            page_count += count
                            overflow += writes
                            stream_hash.update(digest)
                    assert page_count <= bound
                    pages_used += page_count
                    # One 112-byte anchor + 4-byte arena offset + 224*(2+2)
                    # tail entries per restart block. Every page charges pointer
                    # and its full reserved payload, including unused final bytes.
                    bytes_used += 1012 + page_count * (capacity + 2)
                windows.append({'bytes': bytes_used, 'pages': pages_used, 'overflow_pointer_writes': overflow})
            rate = (sum(x['bytes'] for x in windows) + table_bytes + assignment_bytes) / 1024
            results.append({'restart_keys': width, 'page_payload_bytes': capacity,
                            'per_window': windows, 'total_bytes_per_token': rate,
                            'worst_case_pages_per_block': bound,
                            'payload_page_sha256': stream_hash.hexdigest(),
                            'table_lengths': tables, 'bucket_ids': ids.tolist()})
            print(layer, width, capacity, f'{rate:.3f}', flush=True)
        assert len(observed_bit_lengths) == 4 * (256 // width) * 224
        # Exhaust every fixed integer page payload through 255 bytes. This is an
        # optimum only within the declared fixed-page, pointer and tail grammar.
        sweep = []
        for capacity in range(1, 256):
            pages = sum((bits + capacity*8 - 1) // (capacity*8) for bits in observed_bit_lengths)
            rate = (pages * (capacity+2) + 4*(256//width)*1012 + 676) / 1024
            sweep.append({'page_payload_bytes': capacity, 'total_bytes_per_token': rate})
        best = min(sweep, key=lambda r: (r['total_bytes_per_token'], r['page_payload_bytes']))
        results.append({'restart_keys': width, 'exhaustive_fixed_page_sweep': sweep,
                        'best_page': best, 'stream_bit_length_sha256': hashlib.sha256(
                            np.asarray(observed_bit_lengths, dtype='<u2').tobytes()).hexdigest()})
        print(layer, width, 'best', best, flush=True)
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / f'layer{layer:02d}.json').write_text(json.dumps({
        'layer': layer, 'source_sha256': base.sha(HERE), 'parent_source_sha256': base.sha(PARENT),
        'capture_sha256': base.sha(base.CAPTURES / f'layer{layer:02d}.npz'),
        'factor_sha256': base.sha(image), 'factor_fit_sha256': base.sha(factor_parent),
        'train_windows': 8, 'inspected_held_windows': 4, 'static_nibble_bytes_per_token': 112,
        'table_bytes': 620, 'assignment_bytes': 56, 'results': results,
        'contract': 'four train-fitted Huffman tables per GQA group; exact codeword-by-codeword append and linked-page decode; one fixed first page per coordinate; 16-bit next and tail page indices, 16-bit tail bit cursor; full page payload and pointer reserved; 112-byte anchor, 4-byte block arena offset, 896-byte mutable tail metadata per restart; static table and assignment charged once over 1024 tokens; per-stream pages may grow without moving existing pages; CPU original-producer frozen cache only'
    }, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
