#!/usr/bin/env python3
"""Reachable half-orbit table entries on paid binary-factor images."""
import hashlib
import json
from pathlib import Path

import numpy as np

FIXTURES = Path('/path/to/workspace/data/kelana-subbit/binary-factors/fixtures')
DEST = Path('/path/to/workspace/data/kelana-subbit/binary-sign-orbits/receipt.json')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage(packed, width):
    signs = np.unpackbits(packed, axis=1, count=width, bitorder='little')
    blocks = np.packbits(signs.reshape(signs.shape[0], width // 8, 8), axis=2, bitorder='little')[:, :, 0]
    indices = (blocks >> 1) ^ np.where(blocks & 1, 0, 127).astype(np.uint8)
    populations = [np.bincount(indices[:, j], minlength=128) for j in range(indices.shape[1])]
    counts = np.array([np.count_nonzero(p) for p in populations])
    # Reassigning a discarded orbit requires at least one sign edit per block
    # occurrence. Keeping the most frequent labels attains this occurrence bound.
    min_reassigned = {str(cap): int(sum(p.sum() - np.sort(p)[-cap:].sum()
                                         for p in populations)) for cap in (64, 96, 112)}
    # Each used index is a distinct generic linear response. The count is also
    # the minimum live entries for a direct one-read-plus-sign table.
    return {
        'rows': int(signs.shape[0]), 'chunks': int(width // 8),
        'occupied_entries': int(counts.sum()),
        'full_entries': int(128 * len(counts)),
        'min_occupied_per_chunk': int(counts.min()),
        'max_occupied_per_chunk': int(counts.max()),
        'full_chunks': int(np.count_nonzero(counts == 128)),
        'occupancy_histogram': {str(int(v)): int(n) for v, n in zip(*np.unique(counts, return_counts=True))},
        'min_reassigned_occurrences_for_orbit_cap': min_reassigned,
        'max_saved_gray_updates': int((128 - counts).sum()),
        'full_gray_updates': int(127 * len(counts)),
        'mandatory_response_creations': int((counts - 1).sum()),
        'indices_sha256': hashlib.sha256(indices.tobytes()).hexdigest(),
    }


def main():
    records = []
    for path in sorted(FIXTURES.glob('*_0.55.npz')):
        with np.load(path) as image:
            n, k, rank = map(int, image['dimensions'])
            output = stage(image['U'], rank)
            first = stage(image['V'], k)
        records.append({'image': str(path), 'image_sha256': digest(path), 'n': n, 'k': k,
                        'rank': rank, 'first': first, 'output': output})
    assert len(records) == 16
    receipt = {'source_sha256': digest(Path(__file__)), 'images': records}
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text(json.dumps(receipt, indent=2) + '\n')
    for projection in ('mlp_down', 'mlp_up', 'attn_o', 'attn_q'):
        selected = [r for r in records if projection in r['image']]
        for name in ('first', 'output'):
            occupied = sum(r[name]['occupied_entries'] for r in selected)
            full = sum(r[name]['full_entries'] for r in selected)
            chunks = sum(r[name]['chunks'] for r in selected)
            print(projection, name, f'{occupied}/{full}', 'full chunks',
                  sum(r[name]['full_chunks'] for r in selected), '/', chunks,
                  'max Gray update saving', full - occupied, '/', 127 * chunks,
                  'min reassigned to cap96',
                  sum(r[name]['min_reassigned_occurrences_for_orbit_cap']['96'] for r in selected),
                  '/', sum(r[name]['rows'] * r[name]['chunks'] for r in selected))
    print(DEST)


if __name__ == '__main__':
    main()
