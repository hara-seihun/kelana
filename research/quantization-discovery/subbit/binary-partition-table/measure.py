#!/usr/bin/env python3
"""Direct partitioned half-orbit consumption of both frozen binary factors."""
import hashlib
import json
from pathlib import Path

import numpy as np

IMAGES = Path('/path/to/workspace/data/kelana-subbit/binary-factors/fixtures')
OUT = Path('/path/to/workspace/data/kelana-subbit/binary-partition-table')
PARTITIONS = ((8,), (4, 4), (3, 3, 2), (2, 2, 2, 2))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def half_table(block):
    width = len(block)
    table = np.empty(1 << (width - 1), dtype=np.int64)
    table[0] = int(block[0]) - sum(map(int, block[1:]))
    twice = 2 * block[1:].astype(np.int64)
    previous = 0
    for j in range(1, len(table)):
        gray = j ^ (j >> 1)
        bit = (j & -j).bit_length() - 1
        table[gray] = table[previous] + (twice[bit] if gray & (1 << bit) else -twice[bit])
        previous = gray
    return table


def consume(signs, activation, partition):
    rows, width = signs.shape
    assert width == len(activation) and width % 8 == 0
    result = np.zeros(rows, dtype=np.int64)
    # Keep one table live at a time. A gather operates on the original packed sign bits.
    for base in range(0, width, 8):
        pos = 0
        for size in partition:
            bits = signs[:, base + pos:base + pos + size]
            anchor = bits[:, 0]
            relative = (bits[:, 1:] == anchor[:, None]).astype(np.int64)
            indexes = (relative * (1 << np.arange(size - 1, dtype=np.int64))).sum(axis=1)
            table = half_table(activation[base + pos:base + pos + size])
            result += (2 * anchor.astype(np.int64) - 1) * table[indexes]
            pos += size
    return result


def costs(n, k, rank, partition):
    m = len(partition)
    per_eight_tables = sum(1 for _ in partition)
    per_eight_entries = sum(1 << (size - 1) for size in partition)
    per_eight_build = sum(2 * (size - 1) + (1 << (size - 1)) - 1 for size in partition)
    blocks = (k + rank) // 8
    reads = (rank * k // 8 + n * rank // 8) * m
    reductions = rank * (k // 8 * m - 1) + n * (rank // 8 * m - 1)
    return dict(partition=list(partition), tables=blocks * per_eight_tables,
                live_entries_per_eight=per_eight_entries,
                peak_one_table_int32_bytes=4 * max(1 << (size - 1) for size in partition),
                prep_adds_upper=blocks * per_eight_build, indexed_reads=reads,
                lookup_signs=reads, row_reduction_adds=reductions,
                index_relative_sign_bits=(rank * k // 8 + n * rank // 8) * (8 - m))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for path in sorted(IMAGES.glob('*_0.55.npz')):
        with np.load(path) as image:
            n, k, rank = map(int, image['dimensions'])
            u = np.unpackbits(image['U'], axis=1, count=rank, bitorder='little')
            v = np.unpackbits(image['V'], axis=1, count=k, bitorder='little')
        x = ((np.arange(k, dtype=np.int64) * 37) % 257) - 128
        direct_h = (2 * v.astype(np.int64) - 1) @ x
        direct_y = (2 * u.astype(np.int64) - 1) @ direct_h
        for partition in PARTITIONS:
            h = consume(v, x, partition)
            y = consume(u, h, partition)
            assert np.array_equal(h, direct_h) and np.array_equal(y, direct_y)
        entries.append(dict(image=str(path), sha256=digest(path.read_bytes()),
                            n=n, k=k, rank=rank, input_sha256=digest(x.tobytes()),
                            first_stage_sha256=digest(direct_h.tobytes()),
                            output_sha256=digest(direct_y.tobytes()),
                            checked_partitions=[list(part) for part in PARTITIONS]))
    result = dict(source_sha256=digest(Path(__file__).read_bytes()), images=entries,
                  shapes={f'{n}x{k}x{r}': [costs(n, k, r, p) for p in PARTITIONS]
                          for n, k, r in sorted({(e['n'], e['k'], e['rank']) for e in entries})})
    dest = OUT / 'images.json'
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(receipt=str(dest), count=len(entries), shapes=result['shapes']), indent=2))


if __name__ == '__main__':
    main()
