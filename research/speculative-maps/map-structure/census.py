#!/usr/bin/env python3
"""Exact structural census of frozen learned transition CDFs."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

DEFAULT = Path('/path/to/workspace/data/kelana-speculative/learned-transition-tables.npz')


def histogram(values):
    keys, counts = np.unique(values, return_counts=True)
    return {str(int(k)): int(v) for k, v in zip(keys, counts)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--tables', type=Path, default=DEFAULT)
    args = parser.parse_args()
    with np.load(args.tables) as data:
        cdf = data['cdf']
        assert cdf.shape == (32, 6, 16, 16) and cdf.dtype == np.uint16
        assert np.all(cdf[..., -1] == 256) and np.all(np.diff(cdf, axis=-1) >= 0)
        assert np.all(cdf[..., :-1] <= 255)
        mass = np.diff(cdf.astype(np.int16), axis=-1, prepend=0)
        uniforms = np.arange(256, dtype=np.uint16)
        maps = np.sum(uniforms[None, None, :, None, None] >= cdf[:, :, None, :, :], axis=-1).astype(np.uint8)
        distinct_rows = np.array([[np.unique(cdf[c, t], axis=0).shape[0] for t in range(6)] for c in range(32)])
        distinct_maps = np.array([[np.unique(maps[c, t], axis=0).shape[0] for t in range(6)] for c in range(32)])
        image_sizes = np.array([[[np.unique(maps[c, t, u]).size for u in range(256)] for t in range(6)] for c in range(32)])
        paths = np.empty((32, 256, 6), dtype=np.uint8)
        # The common uniforms across positions form a diagonal probe, not an exhaustive path distribution.
        for c in range(32):
            state = np.zeros(256, dtype=np.uint8)
            for t in range(6):
                state = maps[c, t, np.arange(256), state]
                paths[c, :, t] = state
        # For each context and uniform tuple, the complete prefix maps' image sizes bound any
        # subsequent composition. Seeded sampling checks coalescence without 256^6 enumeration.
        rng = np.random.default_rng(76123)
        prefix_images = []
        for c in range(32):
            for draws in rng.integers(0, 256, size=(1024, 6)):
                f = np.arange(16, dtype=np.uint8)
                prefix = []
                for t, u in enumerate(draws):
                    f = maps[c, t, u, f]
                    prefix.append(np.unique(f).size)
                prefix_images.append(prefix)
        prefix_images = np.asarray(prefix_images)
        # Across contexts, each candidate position is local; compare distributions and maps
        # only when predecessor/output labels are meaningful within the same context/position.
        result = {
            'tables_sha256': hashlib.sha256(args.tables.read_bytes()).hexdigest(),
            'cdf_shape': list(cdf.shape),
            'zero_mass_entries': int(np.count_nonzero(mass == 0)),
            'positive_support_per_row': histogram(np.count_nonzero(mass, axis=-1)),
            'distinct_rows_by_position': [histogram(distinct_rows[:, t]) for t in range(6)],
            'distinct_maps_per_context_position': [histogram(distinct_maps[:, t]) for t in range(6)],
            'map_image_size_by_position': [histogram(image_sizes[:, t, :]) for t in range(6)],
            'prefix_image_size_by_position_seeded_32768_streams': [histogram(prefix_images[:, t]) for t in range(6)],
            'context_position_pairs_with_identical_all_rows': int(np.sum(distinct_rows == 1)),
            'unique_cdf_rows_global': int(np.unique(cdf.reshape(-1, 16), axis=0).shape[0]),
            'distinct_diagonal_paths_per_context': histogram([np.unique(paths[c], axis=0).shape[0] for c in range(32)]),
            'cdf_u8_first_15_exact': True,
            'cdf_u8_bytes_per_context': 6 * 16 * 15,
            'cdf_u16_bytes_per_context': 6 * 16 * 16 * 2,
        }
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
