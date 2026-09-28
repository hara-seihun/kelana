#!/usr/bin/env python3
"""Price a cold-table carry pass for the paid two-stage A7 binary reader."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'binary-rank-gauge'))
import measure as parent

ROWS = slice(960, 1024)
OUT = parent.ROOT / 'binary-a7-carry-fold'


def digest(a):
    return hashlib.sha256(np.ascontiguousarray(a).tobytes()).hexdigest()


def analyze(q, signs, weight):
    q = q.reshape(q.shape[0], -1)
    nrows, width = q.shape
    nout = signs.shape[0]
    assert width == signs.shape[1] and width % 8 == 0
    q4 = q.reshape(nrows, width // 4, 4).astype(np.int16)
    relatives = 2 * ((np.arange(8)[:, None] >> np.arange(3)) & 1) - 1
    table = q4[:, :, 0, None] + np.einsum('tci,ji->tcj', q4[:, :, 1:], relatives)
    bad = (table < -128) | (table > 127)
    wrapped = ((table.astype(np.int32) + 128) % 256 - 128).astype(np.int16)
    carry = np.where(bad, np.where(wrapped >= 0, -1, 1), 0)
    assert np.array_equal(table, wrapped + 256 * carry)

    s4 = signs.reshape(nout, width // 4, 4).astype(np.int16)
    rel = s4[:, :, 0, None] * s4[:, :, 1:]
    index = (((rel + 1) // 2) * (1 << np.arange(3))).sum(axis=-1).astype(np.intp)
    output_sign = s4[:, :, 0]
    rows = np.arange(nrows)[:, None, None]
    locations = np.arange(width // 4)[None, None, :]
    selected = carry[rows, locations, index[None, :, :]] * output_sign[None, :, :]
    # Every byte lookup reads only its wrapped response. A second pass visits
    # the static packed sign quartets only at dynamic tables with any carry.
    # This selects precisely the nonzero signed +/-256 updates.
    selective = np.where(bad.any(-1)[:, None, :], selected, 0)
    assert np.array_equal(selected, selective), (selected.shape, selective.shape, int(np.count_nonzero(selected != selective)))
    corrections = selected.sum(axis=2, dtype=np.int32)
    byte_picks = wrapped[rows, locations, index[None, :, :]] * output_sign[None, :, :]
    assert np.array_equal(byte_picks.sum(axis=2, dtype=np.int32) + 256 * corrections,
                          q.astype(np.int32) @ signs.astype(np.int32).T)
    group_picks = byte_picks.reshape(nrows, nout, width // 32, 8).sum(axis=-1, dtype=np.int32)
    group_carries = selected.reshape(nrows, nout, width // 32, 8).sum(axis=-1, dtype=np.int32)
    weighted = ((group_picks + 256 * group_carries) * weight[:, None, :]).sum(axis=-1, dtype=np.int32)
    assert np.array_equal(weighted, parent.factor(signs.astype(np.int32), q.reshape(nrows, -1, 32), weight))
    bad_tables = bad.any(-1)
    bad_scans = int(bad_tables.sum() * nout)
    exception_uses = int(np.count_nonzero(selected))
    return {
        'width': width, 'outputs': nout, 'inputs': nrows,
        'byte_lookups': int(nrows * width // 4 * nout),
        'ordinary_per_lookup_mask_checks': int(nrows * width // 4 * nout),
        'bad_table_sign_quartet_scans': bad_scans,
        'nonzero_carry_updates': exception_uses,
        'active_tables': int(bad_tables.sum()),
        'active_table_positions': int(bad_tables.any(axis=0).sum()),
        'active_entries': int(bad.sum()),
        'per_input_scans': (bad_tables.sum(axis=1) * nout).tolist(),
        'per_input_carry_updates': np.count_nonzero(selected, axis=(1, 2)).tolist(),
        'correction_sha256': digest(corrections.astype('<i4')),
        'integer_response_sha256': digest((q.astype(np.int32) @ signs.astype(np.int32).T).astype('<i4')),
        'weighted_response_sha256': digest(weighted.astype('<i4')),
        'code_sha256': digest(q), 'sign_sha256': digest(signs.astype(np.int8)),
    }


def run(layer):
    image = parent.IMAGES / f'model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
    fixture = parent.FIXTURES / f'layer{layer:02d}-mlp_up_proj.npz'
    with np.load(image) as d:
        n, k, rank = map(int, d['dimensions'])
        v, u = d['V'].copy(), d['U'].copy()
        pre = d['scale_pre'].astype(np.float64)
    with np.load(fixture) as d:
        x = d['validation'][ROWS].astype(np.float64) * pre
    vs = 2 * np.unpackbits(v, axis=1, count=k, bitorder='little').astype(np.int16) - 1
    us = 2 * np.unpackbits(u, axis=1, count=rank, bitorder='little').astype(np.int16) - 1
    q1, w1, _ = parent.ladder(x, threshold=.75)
    h = parent.factor(vs.astype(np.int32), q1, w1)
    q2, w2, _ = parent.ladder(h, threshold=.75)
    return {'layer': layer, 'image_sha256': parent.sha(image), 'fixture_sha256': parent.sha(fixture),
            'rows': [ROWS.start, ROWS.stop], 'stages': {'input': analyze(q1, vs, w1), 'rank': analyze(q2, us, w2)}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 7, 14, 27), required=True)
    args = parser.parse_args()
    entry = run(args.layer)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f'layer{args.layer:02d}.json'
    path.write_text(json.dumps({'source_sha256': parent.sha(Path(__file__)),
                                'parent_source_sha256': parent.sha(Path(parent.__file__)),
                                'numpy_version': np.__version__, 'entry': entry}, indent=2) + '\n')
    print(entry['layer'], [(name, s['bad_table_sign_quartet_scans'], s['nonzero_carry_updates'])
                           for name, s in entry['stages'].items()], flush=True)
    print(path)


if __name__ == '__main__':
    main()
