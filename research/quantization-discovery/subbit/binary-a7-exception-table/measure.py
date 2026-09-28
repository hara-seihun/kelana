#!/usr/bin/env python3
"""Count exact exceptional byte-table responses for the paid A7 two-factor reader."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'binary-rank-gauge'))
import measure as parent

ROWS = slice(960, 1024)
OUT = parent.ROOT / 'binary-a7-exception-table/receipt.json'


def digest(a):
    return hashlib.sha256(np.ascontiguousarray(a).tobytes()).hexdigest()


def analyze(q, signs):
    blocks = q.reshape(len(q), -1, 2, 4).astype(np.int16)
    coeff = (2 * ((np.arange(8)[:, None] >> np.arange(3)) & 1) - 1).astype(np.int16)
    table = blocks[..., 0, None] + np.einsum('rbci,mi->rbcm', blocks[..., 1:], coeff)
    outside = (table < -128) | (table > 127)
    # The full A7 quartet lies in [-256, 255]. Its wrapped signed byte plus
    # one exception bit determines both the size AND direction of correction:
    # wrapped nonnegative means -256; wrapped negative means +256.
    wrapped = ((table.astype(np.int32) + 128) % 256 - 128).astype(np.int8)
    delta = np.where(outside, np.where(wrapped >= 0, -256, 256), 0).astype(np.int32)
    assert np.array_equal(wrapped.astype(np.int32) + delta, table)
    sb = signs.reshape(signs.shape[0], -1, 2, 4)
    rel = sb[..., 0, None] * sb[..., 1:]
    index = (((rel + 1) // 2) * (1 << np.arange(3))).sum(axis=-1).astype(np.intp)
    counts = np.zeros((index.shape[1], 2, 8), dtype=np.int32)
    b, c = np.indices(index.shape[1:])
    np.add.at(counts, (np.broadcast_to(b, index.shape), np.broadcast_to(c, index.shape), index), 1)
    assert np.array_equal(counts.sum(-1), np.full(counts.shape[:2], signs.shape[0]))
    counts32 = counts.astype(np.int64)
    uses = np.einsum('rbcm,bcm->r', outside.astype(np.int64), counts32)
    total = table.shape[0] * table.shape[1] * table.shape[2] * signs.shape[0]
    e = outside.sum(-1)
    # One eight-bit exception mask is paid for each bad four-sign table.
    # Four two-sign half-orbit tables use eight bytes per eight-sign block.
    bad = e > 0
    compact_bytes = 8 * e.size + int(bad.sum())
    int16_bytes = 16 * e.size
    byte_two_bytes = 4 * e.size
    row_fallback_uses = int(bad.sum() * signs.shape[0])
    # The LUT is exact for every packed output sign, not merely its histogram.
    first = 0
    picked = np.take_along_axis(table[first, ..., :][None, ...], index[..., None], -1)[..., 0]
    picked_wrapped = np.take_along_axis(wrapped[first, ..., :][None, ...], index[..., None], -1)[..., 0]
    picked_delta = np.take_along_axis(delta[first, ..., :][None, ...], index[..., None], -1)[..., 0]
    assert np.array_equal(picked.astype(np.int32), picked_wrapped.astype(np.int32) + picked_delta)
    signed_sum = (picked.astype(np.int32) * sb[..., 0]).sum(axis=(-1, -2))
    direct_sum = (signs * q[first].reshape(1, -1)).sum(axis=-1)
    assert np.array_equal(signed_sum, direct_sum)
    assert int(uses[first]) == int((picked_delta != 0).sum())
    return {
        'tables': int(e.size), 'bad_tables': int(bad.sum()),
        'exception_entries': int(e.sum()), 'entries_per_bad_table': np.bincount(e[bad], minlength=9).tolist(),
        'table_slots': int(table.size), 'exception_uses': int(uses.sum()),
        'total_uses': int(total), 'row_fallback_uses': row_fallback_uses,
        'per_input_exception_uses': uses.tolist(),
        'compact_prepared_bytes': compact_bytes, 'int16_prepared_bytes': int16_bytes,
        'byte_two_prepared_bytes': byte_two_bytes,
        'first_integer_response_sha256': digest(direct_sum.astype('<i4')),
        'table_sha256': digest(table), 'code_sha256': digest(q),
        'paid_sign_sha256': digest(signs.astype(np.int8)), 'histogram_sha256': digest(counts),
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
    vs = 2 * np.unpackbits(v, axis=1, count=k, bitorder='little').astype(np.int32) - 1
    us = 2 * np.unpackbits(u, axis=1, count=rank, bitorder='little').astype(np.int32) - 1
    q1, w1, _ = parent.ladder(x, threshold=.75)
    h = parent.factor(vs, q1, w1)
    q2, w2, _ = parent.ladder(h, threshold=.75)
    y = parent.factor(us, q2, w2)
    return {'layer': layer, 'image_sha256': parent.sha(image), 'fixture_sha256': parent.sha(fixture),
            'validation_rows': [ROWS.start, ROWS.stop], 'first_response_sha256': digest(h),
            'final_response_sha256': digest(y), 'first_ladder_sha256': digest(w1),
            'second_ladder_sha256': digest(w2), 'stages': {'input': analyze(q1, vs), 'rank': analyze(q2, us)}}


def main():
    entries = [run(layer) for layer in (0, 7, 14, 27)]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': parent.sha(Path(__file__)),
                               'parent_source_sha256': parent.sha(Path(parent.__file__)),
                               'numpy_version': np.__version__, 'entries': entries}, indent=2) + '\n')
    for entry in entries:
        print(entry['layer'], [(key, v['exception_entries'], v['exception_uses'], v['total_uses'])
                               for key, v in entry['stages'].items()], flush=True)
    print(OUT)


if __name__ == '__main__':
    main()
