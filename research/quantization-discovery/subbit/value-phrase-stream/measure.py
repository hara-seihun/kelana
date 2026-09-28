#!/usr/bin/env python3
"""Append-only fixed-byte Tunstall phrases for the frozen narrow-V difference image."""
import argparse
import hashlib
import heapq
import importlib.util
import json
import struct
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit/value-phrase-stream')
spec = importlib.util.spec_from_file_location('value_coordinate_parent', SUBBIT / 'value-coordinate-entropy' / 'measure.py')
coord = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coord)
base = coord.base
ALPHABET = 31
BITS = (8, 10, 12)


def tree(counts, bits):
    p = (np.asarray(counts, dtype=np.float64) + 1)
    p /= p.sum()
    leaves = {(): 1.0}
    heap = [(-1.0, ())]
    expansions = []
    for _ in range(((1 << bits) - 1) // (ALPHABET - 1)):
        neg_probability, word = heapq.heappop(heap)
        del leaves[word]
        expansions.append(word)
        for symbol in range(ALPHABET):
            child = word + (symbol,)
            probability = -neg_probability * p[symbol]
            leaves[child] = probability
            heapq.heappush(heap, (-probability, child))
    words = sorted(leaves)
    code = {word: i for i, word in enumerate(words)}
    trie = {}
    for word, i in code.items():
        node = trie
        for symbol in word:
            node = node.setdefault(symbol, {})
        node[None] = i
    return words, trie, expansions


def code_group(symbols, words, trie):
    # Each group has a known 28-symbol output count. Padding with zero
    # differences completes the last phrase, discarded by that count.
    symbols = list(map(int, symbols))
    result = []
    pos = 0
    while pos < len(symbols):
        node = trie
        while None not in node:
            symbol = symbols[pos] if pos < len(symbols) else 15
            node = node[symbol]
            pos += 1
        result.append(node[None])
    assert [s for code in result for s in words[code]][:len(symbols)] == symbols
    return result


def pack(codes, bits):
    value = 0
    for code in codes:
        value = (value << bits) | code
    count = bits * len(codes)
    return (value << (-count % 8)).to_bytes((count + 7)//8, 'big')


def unpack(raw, bits, groups, dictionaries):
    value = int.from_bytes(raw, 'big')
    total = len(raw) * 8
    cursor = 0
    decoded = []
    for group in groups:
        produced = []
        words = dictionaries[group][0]
        while len(produced) < 28:
            code = (value >> (total - cursor - bits)) & ((1 << bits) - 1)
            assert code < len(words)
            produced.extend(words[code])
            cursor += bits
        decoded.extend(produced[:28])
    assert total - cursor < 8
    return decoded


def table_bytes(dictionaries):
    encoded = bytearray()
    for words, trie, expansions in dictionaries:
        for i, word in enumerate(expansions):
            encoded.extend((255 if not word else expansions.index(word[:-1]),
                            0 if not word else word[-1]))
        leaves = {()}
        reconstructed = []
        raw = encoded[-2*len(expansions):]
        for i in range(len(expansions)):
            parent, edge = raw[2*i:2*i+2]
            node = () if parent == 255 else reconstructed[parent] + (edge,)
            assert node in leaves
            leaves.remove(node)
            leaves.update(node + (s,) for s in range(ALPHABET))
            reconstructed.append(node)
        assert sorted(leaves) == words
    return bytes(encoded)


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
    hist = np.ones((8, ALPHABET), dtype=np.int64)
    for window in train:
        diffs = np.diff(window.astype(np.int16), axis=0) + 15
        for group in range(8):
            hist[group] += np.bincount(diffs[:, group].ravel(), minlength=ALPHABET)
    results = []
    dictionaries_by_bits = {}
    for bits in BITS:
        dictionaries = [tree(counts, bits) for counts in hist]
        dictionaries_by_bits[bits] = dictionaries
        # Expansion history stores parent internal-node index and edge symbol.
        # The 12-bit tree has 136 internals, so each expansion uses two bytes.
        encoded_table = table_bytes(dictionaries)
        static_bytes = len(encoded_table)
        coded = []
        for window in range(4):
            window_codes = []
            for t in range(1, 256):
                diff = held[window, t].astype(np.int16) - held[window, t-1].astype(np.int16) + 15
                window_codes.append([code_group(diff[g], *dictionaries[g][:2]) for g in range(8)])
            coded.append(window_codes)
        for width in (32, 256):
          for streams in (1, 2, 4, 8):
            window_bytes = []
            sha = hashlib.sha256()
            max_row_length = 0
            max_block_length = 0
            codewords = 0
            for window in range(4):
                total = 0
                for start in range(0, 256, width):
                    anchor = held[window, start].reshape(224).astype(np.int16) & 15
                    packed = (anchor[::2] | (anchor[1::2] << 4)).astype(np.uint8).tobytes()
                    block = bytearray(packed + bytes(2*(width-1)))
                    for t in range(start+1, start+width):
                        row_start = len(block)
                        struct.pack_into('<H', block, 112 + 2*(t-start-1), row_start)
                        group_codes = coded[window][t-1]
                        diff = held[window, t].astype(np.int16) - held[window, t-1].astype(np.int16) + 15
                        chunks = [pack([code for group in group_codes[part*8//streams:(part+1)*8//streams] for code in group], bits) for part in range(streams)]
                        for part, chunk in enumerate(chunks):
                            groups = range(part*8//streams, (part+1)*8//streams)
                            assert unpack(chunk, bits, groups, dictionaries) == diff[part*8//streams:(part+1)*8//streams].ravel().tolist()
                        assert all(len(chunk) < 256 for chunk in chunks)
                        codewords += sum(len(group) for group in group_codes)
                        max_row_length = max(max_row_length, max(map(len, chunks)))
                        block.extend(bytes(map(len, chunks[:-1])))
                        for chunk in chunks:
                            sha.update(chunk)
                            block.extend(chunk)
                    assert len(block) < 65536
                    max_block_length = max(max_block_length, len(block))
                    total += 4 + len(block)
                window_bytes.append(total)
            charged = sum(window_bytes) + static_bytes
            results.append({'phrase_bits': bits, 'restart_keys': width, 'streams_per_row': streams,
                            'serial_phrases_per_group_mean': codewords/(1024*8*(1-1/width)),
                            'max_stream_bytes_per_row': max_row_length,
                            'held_bytes_per_window': window_bytes, 'held_bytes_per_token': charged/1024,
                            'held_total_bytes': charged, 'static_table_bytes': static_bytes,
                            'max_block_bytes': max_block_length, 'payload_sha256': sha.hexdigest(),
                            'table_sha256': hashlib.sha256(encoded_table).hexdigest()})
            print(layer, bits, width, streams, round(charged/1024, 3), flush=True)
    receipt = {'layer': layer, 'source_sha256': base.sha(HERE), 'parent_source_sha256': base.sha(coord.HERE),
               'capture_sha256': base.sha(base.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': base.sha(image), 'parent_sha256': base.sha(parent),
               'train_windows': 8, 'inspected_held_windows': 4, 'held_shape': list(held.shape),
               'histograms': hist.tolist(), 'expansion_words': {str(bits): [[list(w) for w in d[2]] for d in dictionaries_by_bits[bits]] for bits in BITS},
               'contract': '31-symbol group Tunstall dictionaries, 8/10/12-bit fixed codewords, two-byte expansion descriptor/internal node; 28-symbol group boundaries, zero-difference end padding, 112-byte anchor and 4-byte block address/restart, two-byte row starts, one-byte stream lengths except last; append-only rows; offline dictionary materialization',
               'results': results}
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / f'layer{layer:02d}.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
