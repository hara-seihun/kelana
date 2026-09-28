#!/usr/bin/env python3
"""Exact scale-page codec and paired native integer-dot reader on the pinned Bonsai block."""
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import tempfile

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
FIXTURE = ROOT / "instances/bonsai-layer00-down-block0.npz"
PAGE = 64


def pack_bits(values, width):
    acc = 0
    bits = 0
    out = bytearray()
    for value in values:
        assert 0 <= value < (1 << width)
        acc |= int(value) << bits
        bits += width
        while bits >= 8:
            out.append(acc & 255)
            acc >>= 8
            bits -= 8
    if bits:
        out.append(acc)
    return out


def encode_pages(scales, page=PAGE):
    assert len(scales) % page == 0
    starts = []
    stream = bytearray()
    widths = []
    for group in scales.reshape(-1, page):
        base = int(group.min())
        width = int(int(group.max()) - base).bit_length()
        starts.append(len(stream))
        widths.append(width)
        stream += struct.pack('<HB', base, width)
        stream += pack_bits([int(s) - base for s in group], width)
    offsets = struct.pack('<' + 'I' * (len(starts) + 1), *starts, len(stream))
    return offsets + stream, widths


def decode_scale(image, row, pages, page=PAGE):
    offset = struct.unpack_from('<I', image, (row // page) * 4)[0]
    begin = (pages + 1) * 4 + offset
    base, width = struct.unpack_from('<HB', image, begin)
    bit = (row % page) * width
    nbytes = (bit % 8 + width + 7) // 8
    part = int.from_bytes(image[begin + 3 + bit // 8:begin + 3 + bit // 8 + nbytes], 'little')
    return base + ((part >> (bit % 8)) & ((1 << width) - 1))


def trit_code(trits):
    out = bytearray()
    for row in trits:
        for start in range(0, 128, 5):
            chunk = row[start:start + 5]
            out.append(sum((int(v) + 1) * 3 ** j for j, v in enumerate(chunk)))
    return out


def held_joint_census(trits, scale_bits):
    # Each two-trit label is charged against the scale's top byte; odd rows train,
    # even rows held. Laplace smoothing keeps all nine symbols executable.
    group = np.where(scale_bits >> 8 == 33, 0, np.where(scale_bits >> 8 == 34, 1, 2))
    pair = (trits[:, ::2].astype('int32') + 1) + 3 * (trits[:, 1::2].astype('int32') + 1)
    train = np.arange(len(trits)) % 2 == 1
    counts = np.bincount(pair[train].ravel(), minlength=9) + 1
    global_prob = counts / sum(counts)
    conditional = np.zeros((3, 9), dtype=np.int64)
    for g in range(3):
        conditional[g] = np.bincount(pair[train & (group == g)].ravel(), minlength=9) + 1
    conditional_prob = conditional / conditional.sum(axis=1)[:, None]
    test = ~train
    labels = pair[test].ravel()
    groups = np.repeat(group[test], pair.shape[1])
    global_bits = float(-np.log2(global_prob[labels]).sum())
    conditioned_bits = float(-np.log2(conditional_prob[groups, labels]).sum())
    return {'train_rows': int(train.sum()), 'held_pairs': len(labels),
            'unconditional_bits_per_pair': global_bits / len(labels),
            'scale_high_byte_conditioned_bits_per_pair': conditioned_bits / len(labels),
            'held_bit_difference': global_bits - conditioned_bits}


def main():
    fixture = np.load(FIXTURE)
    trits, scales, query = (fixture[k] for k in ('trits', 'scale_bits', 'queries'))
    assert trits.shape == (5120, 128) and scales.shape == (5120,)
    codes = trit_code(trits)
    for r, row in enumerate(trits):
        for chunk in range(26):
            value = codes[r * 26 + chunk]
            for j in range(min(5, 128 - chunk * 5)):
                assert value % 3 - 1 == int(row[chunk * 5 + j])
                value //= 3
    pages, widths = encode_pages(scales)
    assert all(decode_scale(pages, r, len(scales) // PAGE) == int(s) for r, s in enumerate(scales))
    raw = bytearray()
    for r, scale in enumerate(scales):
        raw += codes[r * 26:(r + 1) * 26] + struct.pack('<H', int(scale))
    global_min = int(scales.min())
    global_width = int(int(scales.max()) - global_min).bit_length()
    global_size = 3 + len(pack_bits([int(x) - global_min for x in scales], global_width))
    dictionary_size = len(set(scales)) * 2 + math.ceil(len(scales) * math.ceil(math.log2(len(set(scales)))) / 8)
    with tempfile.TemporaryDirectory(prefix='kelana-scale-page-') as tmp:
        tmp = Path(tmp)
        (tmp / 'aos.bin').write_bytes(raw)
        (tmp / 'codes.bin').write_bytes(codes)
        (tmp / 'scales.bin').write_bytes(scales.astype('<u2').tobytes())
        (tmp / 'pages.bin').write_bytes(pages)
        (tmp / 'query.bin').write_bytes(query[0].tobytes())
        program = tmp / 'reader'
        subprocess.run(['g++', '-O3', '-march=native', '-std=c++20', str(HERE / 'reader.cpp'), '-o', str(program)], check=True)
        proc = subprocess.run([str(program), str(tmp)], check=True, text=True, capture_output=True,
                              env={**os.environ, 'OMP_NUM_THREADS': '1', 'OPENBLAS_NUM_THREADS': '1'})
        native = json.loads(proc.stdout)
    result = {
        'fixture': str(FIXTURE.relative_to(ROOT)), 'fixture_sha256': hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
        'rows': len(scales), 'row_width': 128, 'page_rows': PAGE,
        'trit_code_bytes': len(codes), 'baseline_aos_bytes': len(raw),
        'raw_soa_bytes': len(codes) + scales.nbytes, 'paged_bytes': len(codes) + len(pages),
        'page_offset_bytes': (len(scales) // PAGE + 1) * 4,
        'page_stream_bytes': len(pages) - (len(scales) // PAGE + 1) * 4,
        'scale_page_size_sweep': {str(p): len(encode_pages(scales, p)[0]) for p in (8, 16, 32, 64, 128, 256, 512, 1024, 5120)},
        'page_width_histogram': {str(w): widths.count(w) for w in sorted(set(widths))},
        'global_range_scale_bytes': global_size,
        'global_unique_scale_dictionary_bytes': dictionary_size,
        'scale_unique': len(set(scales)), 'joint_census': held_joint_census(trits, scales),
        'native': native,
    }
    (HERE / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
