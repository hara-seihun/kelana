#!/usr/bin/env python3
"""Price a precomputed real-score anchor against a different captured proxy input."""
import hashlib
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
CACHE = Path('/path/to/workspace/data/bonsai2/PTQ1_0.gguf.halo')
BASE = HERE / 'build'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    q0 = np.fromfile(BASE / 'query.i8', dtype=np.int8)
    q1 = np.fromfile(BASE / 'query1.i8', dtype=np.int8)
    delta = np.abs(q1.astype(np.int16) - q0.astype(np.int16)).reshape(40, 128).sum(axis=1)
    raw = np.memmap(CACHE, dtype=np.uint8, mode='r', offset=24576, shape=(7760, 40, 896))
    scale_bits = np.ascontiguousarray(raw[:, :, 768:].reshape(7760, 40, 32, 4)[:, :, :, 2:4]).view('<f2').reshape(7760, 40, 32)
    scale = scale_bits.astype(np.float64).transpose(0, 2, 1).reshape(248320, 40)
    anchor = np.fromfile(BASE / 'score0.f64', dtype='<f8')
    exact1 = np.fromfile(BASE / 'score1.f64', dtype='<f8')
    assert anchor.size == exact1.size == scale.shape[0]
    scale_units = np.rint(scale * (1 << 24)).astype(np.int64)
    anchor_units = np.rint(anchor * (1 << 24)).astype(np.int64)
    target_units = np.rint(exact1 * (1 << 24)).astype(np.int64)
    bound_units = anchor_units + scale_units @ delta.astype(np.int64)
    winner = int(np.argmax(target_units))
    # This optimistic oracle threshold does not pay to find the candidate.
    oracle = int(target_units[winner])
    survivors = np.flatnonzero(bound_units >= oracle)
    assert winner in survivors and np.all(target_units <= bound_units)
    summary = {
        'anchor_query_sha256': sha(BASE / 'query.i8'),
        'target_query_sha256': sha(BASE / 'query1.i8'),
        'anchor_rows': 248320,
        'winner': winner,
        'oracle_scaled_integer_score': oracle,
        'survivors_with_free_oracle': int(survivors.size),
        'query_delta_l1': int(delta.sum()),
        'anchor_score_storage_bytes_f64': int(anchor.nbytes),
        'scale_storage_bytes_f16': int(scale.size * 2),
        'online_scalar_scale_terms': int(scale.size),
        'online_scale_bytes_read': int(scale.size * 2),
        'online_score_bytes_read': int(anchor.nbytes),
    }
    print(json.dumps(summary, indent=2))
    (HERE / 'anchor-result.json').write_text(json.dumps(summary, indent=2) + '\n')


if __name__ == '__main__':
    main()
