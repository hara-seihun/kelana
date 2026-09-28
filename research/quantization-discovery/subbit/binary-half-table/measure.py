#!/usr/bin/env python3
"""Half-orbit response tables for both packed binary-factor planes."""
import hashlib
import json
from pathlib import Path

import numpy as np

IMAGES = Path('/path/to/workspace/data/kelana-subbit/binary-factors/fixtures')
OUT = Path('/path/to/workspace/data/kelana-subbit/binary-half-table')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def table(eight):
    base = int(eight[0]) - sum(map(int, eight[1:]))
    twice = 2 * eight[1:].astype(np.int64)
    response = np.empty(128, dtype=np.int64)
    response[0] = base
    previous = 0
    for j in range(1, 128):
        gray = j ^ (j >> 1)
        bit = (j & -j).bit_length() - 1
        response[gray] = response[previous] + (twice[bit] if gray & (1 << bit) else -twice[bit])
        previous = gray
    return response


def consume(sign_bits, activation):
    rows, width = sign_bits.shape
    assert width % 8 == 0
    chunks = width // 8
    codes = sign_bits.reshape(rows, chunks, 8).astype(np.int64)
    anchor = codes[:, :, 0]
    relative = (codes[:, :, 1:] == anchor[:, :, None]).astype(np.int64)
    index = (relative * (1 << np.arange(7, dtype=np.int64))).sum(axis=2)
    tables = np.stack([table(activation[8*i:8*i+8]) for i in range(chunks)])
    selected = tables[np.arange(chunks)[None, :], index]
    return ((2 * anchor - 1) * selected).sum(axis=1)


def costs(n, k, rank):
    table_count = (k + rank) // 8
    reads = rank * k // 8 + n * rank // 8
    routed = rank * k + n // 4 * (rank + 28)
    return {
        'half_tables': table_count,
        'half_table_entries': 128 * table_count,
        'half_table_construction_adds_upper': 141 * table_count,
        'half_table_lookup_reads': reads,
        'half_table_lookup_signs': reads,
        'half_table_row_reduction_adds': rank * (k // 8 - 1) + n * (rank // 8 - 1),
        'half_table_peak_bytes_int32_one_table': 512,
        'full_256_table_construction_adds_upper': 255 * table_count,
        'full_256_table_entries': 256 * table_count,
        'routed_quartet_signed_adds_upper_including_first_factor': routed,
        'routed_quartet_dynamic_routes': n * rank // 4,
        'conventional_signed_adds': rank * (k + n),
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for path in sorted(IMAGES.glob('*_0.55.npz')):
        with np.load(path) as image:
            n, k, rank = map(int, image['dimensions'])
            u = np.unpackbits(image['U'], axis=1, count=rank, bitorder='little')
            v = np.unpackbits(image['V'], axis=1, count=k, bitorder='little')
        x = ((np.arange(k, dtype=np.int64) * 37) % 257) - 128
        h = consume(v, x)
        y = consume(u, h)
        direct_h = (2 * v.astype(np.int64) - 1) @ x
        direct_y = (2 * u.astype(np.int64) - 1) @ direct_h
        assert np.array_equal(h, direct_h)
        assert np.array_equal(y, direct_y)
        entries.append({'image': str(path), 'sha256': sha(path), 'n': n, 'k': k,
                        'rank': rank, 'input_sha256': hashlib.sha256(x.tobytes()).hexdigest(),
                        'first_stage_sha256': hashlib.sha256(h.tobytes()).hexdigest(),
                        'output_sha256': hashlib.sha256(y.tobytes()).hexdigest(),
                        'all_integer_outputs_equal': True, **costs(n, k, rank)})
    result = {'source_sha256': sha(Path(__file__)), 'images': entries}
    dest = OUT / 'images.json'
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'count': len(entries),
                      'shapes': {f"{e['n']}x{e['k']}x{e['rank']}": costs(e['n'], e['k'], e['rank']) for e in entries}}, indent=2))


if __name__ == '__main__':
    main()
