#!/usr/bin/env python3
"""Price per-activation signed-byte four-sign tables at both paid A7 factor stages."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'binary-rank-gauge'))
import measure as parent

OUT = parent.ROOT / 'binary-a7-byte-admission/receipt.json'
ROWS = slice(960, 1024)  # disjoint from preceding four-layer center and rank panels


def digest(a):
    return hashlib.sha256(np.ascontiguousarray(a).tobytes()).hexdigest()


def admission(q):
    # Group the input in eight-sign blocks, then the two four-sign tables.
    blocks = q.reshape(q.shape[0], -1, 2, 4).astype(np.int64)
    anchor = blocks[..., 0]
    spread = np.abs(blocks[..., 1:]).sum(axis=-1)
    lo, hi = anchor - spread, anchor + spread
    admitted = (lo >= -128) & (hi <= 127)
    # Explicitly enumerate each reachable relative sign for every activation table.
    table = anchor[..., None] + sum(
        ((2 * ((np.arange(8) >> i) & 1) - 1) * blocks[..., i + 1, None])
        for i in range(3)
    )
    assert np.array_equal(table.min(axis=-1), lo)
    assert np.array_equal(table.max(axis=-1), hi)
    assert np.array_equal((table >= -128).all(-1) & (table <= 127).all(-1), admitted)
    # The four-sign output sign is applied after widening to int32.
    values = table.astype(np.int32)
    if admitted.any():
        encoded = table[admitted].astype(np.int8)
        assert np.array_equal(encoded.astype(np.int32), values[admitted])
        assert np.array_equal(-encoded.astype(np.int32), -values[admitted])
    return admitted, lo, hi, digest(table)


def run(layer):
    image = parent.IMAGES / f'model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
    fixture = parent.FIXTURES / f'layer{layer:02d}-mlp_up_proj.npz'
    with np.load(image) as d:
        n, k, rank = map(int, d['dimensions'])
        v, u = d['V'].copy(), d['U'].copy()
        pre = d['scale_pre'].astype(np.float64)
    with np.load(fixture) as d:
        x = d['validation'][ROWS].astype(np.float64) * pre
        train_x = d['train'][896:960].astype(np.float64) * pre
    vs = 2 * np.unpackbits(v, axis=1, count=k, bitorder='little').astype(np.int32) - 1
    us = 2 * np.unpackbits(u, axis=1, count=rank, bitorder='little').astype(np.int32) - 1
    q1, w1, base1 = parent.ladder(x, threshold=.75)
    h = parent.factor(vs, q1, w1)
    q2, w2, base2 = parent.ladder(h, threshold=.75)
    y = parent.factor(us, q2, w2)
    tq1, tw1, _ = parent.ladder(train_x, threshold=.75)
    th = parent.factor(vs, tq1, tw1)
    tq2, _, _ = parent.ladder(th, threshold=.75)
    # Sort ranks *within each 32-coordinate ladder group*. This preserves
    # group extrema, quantizer steps and the entire two-factor integer map.
    score = np.abs(tq2).mean(axis=0).reshape(-1, 32)
    within = np.argsort(score, axis=1, kind='stable') + 32 * np.arange(rank // 32)[:, None]
    perm = within.ravel()
    sorted_q = q2.reshape(len(q2), rank)[:, perm].reshape(q2.shape)
    sorted_train_q = tq2.reshape(len(tq2), rank)[:, perm].reshape(tq2.shape)
    sorted_us = us[:, perm]
    sorted_y = parent.factor(sorted_us, sorted_q, w2)
    assert np.array_equal(y, sorted_y)
    orig_train_admit, _, _, _ = admission(tq2)
    orig_held_admit, _, _, _ = admission(q2)
    sorted_train_admit, _, _, _ = admission(sorted_train_q)
    sorted_held_admit, _, _, _ = admission(sorted_q)
    gauges = {}
    for name, tg, hg in (('identity', orig_train_admit, orig_held_admit),
                         ('train_magnitude_sorted', sorted_train_admit, sorted_held_admit)):
        designated = tg.all(axis=0)
        gauges[name] = {
            'train_admitted_four_tables': int(tg.sum()),
            'held_admitted_four_tables': int(hg.sum()),
            'train_static_safe_positions': int(designated.sum()),
            'held_static_safe_positions_oracle': int(hg.all(axis=0).sum()),
            'train_designated_byte_failures_on_held': int((~hg[:, designated]).sum()),
            'train_designated_byte_uses_on_held': int(hg[:, designated].size),
        }
    stages = []
    for name, q, signs in (('input', q1, vs), ('rank', q2, us)):
        good, low, high, table_hash = admission(q)
        full = good.all(axis=-1)
        # An eight-sign block can use two byte reads iff both its subtables fit.
        nrows, nblocks, _ = good.shape
        # A mixed-width (4,4) reader always makes two reads per eight signs.
        # Rejects need an int16 subtable; a uniform byte-only A7 map makes four
        # (2,2) reads instead, with no width-dependent control flow.
        stages.append({
            'stage': name, 'rows': nrows, 'input_codes': int(q.shape[-1] * q.shape[1]),
            'output_rows': int(signs.shape[0]), 'eight_blocks_per_row': nblocks,
            'admitted_four_tables': int(good.sum()), 'total_four_tables': int(good.size),
            'fully_admitted_eight_blocks': int(full.sum()), 'total_eight_blocks': int(full.size),
            'static_byte_four_tables_all_64': int(good.all(axis=0).sum()),
            'static_byte_four_tables_per_32': [int(g.all(axis=0).sum()) for g in np.split(good, 2)],
            'byte_four_tables_per_row': [int(row.sum()) for row in good],
            'admitted_uses': int(good.sum() * signs.shape[0]),
            'total_uses': int(good.size * signs.shape[0]),
            'mixed_width_reads': int(good.size * signs.shape[0]),
            'mixed_width_int16_reads': int((~good).sum() * signs.shape[0]),
            'mixed_width_table_bytes': int(8 * (good.sum() + 2 * (~good).sum())),
            'all_pair_byte_reads': int(4 * nrows * nblocks * signs.shape[0]),
            'all_half_int16_reads': int(nrows * nblocks * signs.shape[0]),
            'observed_table_min': int(low.min()), 'observed_table_max': int(high.max()),
            'table_sha256': table_hash, 'codes_sha256': digest(q),
            'group_weights_sha256': digest(w1 if name == 'input' else w2),
        })
    return {'layer': layer, 'image_sha256': parent.sha(image), 'fixture_sha256': parent.sha(fixture),
            'validation_rows': [ROWS.start, ROWS.stop], 'first_integer_sha256': digest(h),
            'final_integer_sha256': digest(y), 'first_base_sha256': digest(base1),
            'second_base_sha256': digest(base2), 'stages': stages,
            'rank_gauge': {'train_rows': [896, 960], 'permutation_sha256': digest(perm.astype('<i4')),
                           'sorted_final_integer_sha256': digest(sorted_y), 'arms': gauges}}


def main():
    entries = [run(layer) for layer in (0, 7, 14, 27)]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': parent.sha(Path(__file__)),
                               'parent_source_sha256': parent.sha(Path(parent.__file__)),
                               'numpy_version': np.__version__, 'entries': entries}, indent=2) + '\n')
    for entry in entries:
        print(entry['layer'], [(s['stage'], s['admitted_four_tables'], s['total_four_tables'],
                                s['fully_admitted_eight_blocks'], s['total_eight_blocks'])
                               for s in entry['stages']], flush=True)
    print(OUT)


if __name__ == '__main__':
    main()
