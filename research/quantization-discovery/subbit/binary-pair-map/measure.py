#!/usr/bin/env python3
"""Direct sign-quartet response, with packed Qwen factor-image work counts."""
import hashlib
import json
from pathlib import Path

import numpy as np

IMAGES = Path('/path/to/workspace/data/kelana-subbit/binary-factors/fixtures')
OUT = Path('/path/to/workspace/data/kelana-subbit/binary-pair-map')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def quartet(signs, h):
    # A column's first sign and three equality bits identify one of eight sums.
    anchor = signs[0]
    bits = (signs[1:] != anchor).astype(np.int32)
    bucket = bits[0] + 2 * bits[1] + 4 * bits[2]
    sums = np.bincount(bucket, weights=anchor * h, minlength=8)
    parity = np.arange(8)
    output = np.empty(4, dtype=np.float64)
    output[0] = sums.sum()
    for row in range(1, 4):
        output[row] = sums[parity & (1 << (row - 1)) == 0].sum() - sums[parity & (1 << (row - 1)) != 0].sum()
    return output, bucket


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    worst_error = 0.
    for path in sorted(IMAGES.glob('*_0.55.npz')):
        with np.load(path) as image:
            n, k, rank = map(int, image['dimensions'])
            signs = 2 * np.unpackbits(image['U'], axis=1, count=rank, bitorder='little').astype(np.int8) - 1
            v = 2 * np.unpackbits(image['V'], axis=1, count=k, bitorder='little').astype(np.int8) - 1
            pre = image['scale_pre'].astype(np.float64)
            post = image['scale_post'].astype(np.float64)
        assert signs.shape == (n, rank) and v.shape == (rank, k)
        layer = int(path.name.split('_')[2])
        key = path.stem.split('_weight_')[0].split(f'model_layers_{layer}_')[1]
        fixture = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext') / f'layer{layer:02d}-{key}.npz'
        with np.load(fixture) as f:
            x = f['validation'][0].astype(np.float64)
        h = v.astype(np.float64) @ (x * pre)
        occupied = np.zeros(8, dtype=np.int64)
        minimum = 8
        for row in range(0, n, 4):
            reference = signs[row:row + 4].astype(np.float64) @ h
            actual, bucket = quartet(signs[row:row + 4], h)
            worst_error = max(worst_error, float(np.max(np.abs(actual - reference))))
            counts = np.bincount(bucket, minlength=8)
            occupied += (counts > 0)
            minimum = min(minimum, np.count_nonzero(counts))
        groups = n // 4
        # Scalar grammar: one signed add per input coordinate to its chosen bucket;
        # for each group, four 8-way signed sums, each needing at most 7 adds.
        entries.append({
            'image': str(path), 'sha256': digest(path), 'n': n, 'k': k, 'rank': rank,
            'groups': groups, 'min_occupied_buckets': minimum,
            'occupied_bucket_fraction': occupied.tolist(),
            'conventional_signed_adds': n * rank,
            'quartet_signed_adds_upper': groups * (rank + 28),
            'conventional_h_reads': n * rank,
            'quartet_h_reads': groups * rank,
            'quartet_dynamic_routes': groups * rank,
            'quartet_pattern_bits': n * rank,
            'full_factor_signed_adds': rank * (k + n),
            'full_factor_quartet_signed_adds_upper': rank * k + groups * (rank + 28),
            'reference': 'paid first-factor image and first matching validation activation',
            'fixture': str(fixture), 'fixture_sha256': digest(fixture),
        })
    result = {'source_sha256': digest(Path(__file__)), 'max_fp64_absolute_difference': worst_error,
              'entries': entries}
    dest = OUT / 'images.json'
    dest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'images': len(entries),
                      'max_fp64_absolute_difference': worst_error,
                      'signed_add_ratios': [round(e['quartet_signed_adds_upper'] / e['conventional_signed_adds'], 5) for e in entries]}, indent=2))


if __name__ == '__main__':
    main()
