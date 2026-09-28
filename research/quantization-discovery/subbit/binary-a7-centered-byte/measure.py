#!/usr/bin/env python3
"""Count optimally centered A7 four-sign tables on frozen paid binary factors."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'binary-rank-gauge'))
import measure as parent

ROWS = slice(960, 1024)
OUT = parent.ROOT / 'binary-a7-centered-byte/receipt.json'


def digest(a):
    return hashlib.sha256(np.ascontiguousarray(a).tobytes()).hexdigest()


def stage(q, signs):
    # For an even quartet, every integer between the two middle order statistics
    # minimizes the L1 radius. Choose the lower median, then clamp to zero if
    # zero lies in the minimizer interval, avoiding needless corrections.
    blocks = q.reshape(len(q), -1, 4).astype(np.int32)
    ordered = np.sort(blocks, axis=-1)
    lower, upper = ordered[..., 1], ordered[..., 2]
    center = np.clip(np.zeros_like(lower), lower, upper)
    minimum_radius = np.abs(blocks - center[..., None]).sum(axis=-1)
    # At radius 128 only the negative end may reach -128. Choose another
    # L1-minimizing center if the initial choice puts +128 in the table.
    edge = (minimum_radius == 128) & (blocks[..., 0] >= center) & (upper > blocks[..., 0])
    center = np.where(edge, np.maximum(lower, blocks[..., 0] + 1), center)
    residual = blocks - center[..., None]
    r = np.abs(residual).sum(axis=-1)
    # Half-orbit fixes the sign of the first factor. The eight responses
    # occupy [-r+2*positive, r-2*negative] in general; enumerate exactly.
    patterns = 2 * ((np.arange(8)[:, None] >> np.arange(3)) & 1) - 1
    table = residual[..., 0, None] + residual[..., 1:] @ patterns.T
    original = blocks[..., 0, None] + blocks[..., 1:] @ patterns.T
    admitted = (table.min(axis=-1) >= -128) & (table.max(axis=-1) <= 127)
    raw = (original.min(axis=-1) >= -128) & (original.max(axis=-1) <= 127)
    assert np.array_equal(raw, (blocks[..., 0] - np.abs(blocks[..., 1:]).sum(-1) >= -128) &
                          (blocks[..., 0] + np.abs(blocks[..., 1:]).sum(-1) <= 127))
    assert np.all(admitted >= raw)
    assert np.array_equal(admitted, (minimum_radius <= 127) |
                          ((minimum_radius == 128) & (upper > blocks[..., 0])))
    # Decode using the actual paid packed signs, then compare the first 4-term
    # response exhaustively on observed codes and on every half-orbit label.
    sums = 1 + patterns.sum(axis=-1)
    assert np.array_equal(original, table + center[..., None] * sums)
    if admitted.any():
        encoded = table[admitted].astype(np.int8)
        assert np.array_equal(encoded.astype(np.int32), table[admitted])
    p = (signs[:, :4] == signs[:, 0, None]).astype(np.uint8)
    assert np.array_equal(p[:, 0], np.ones(len(p), dtype=np.uint8))
    labels = p[:, 1] + 2 * p[:, 2] + 4 * p[:, 3]
    sign = signs[:, 0]
    sampled = sign[None, :] * (table[:, 0, labels] + center[:, 0, None] * sums[labels])
    direct = blocks[:, 0, :] @ signs[:, :4].T
    assert np.array_equal(sampled, direct)
    positions = len(center[0])
    sign_sums = signs.reshape(len(signs), -1, 4).sum(axis=-1)
    nonzero_corrections = int(((center != 0).astype(np.int32) @ (sign_sums != 0).astype(np.int32).T).sum())
    return {
        'input_codes_sha256': digest(q), 'paid_signs_sha256': digest(signs),
        'original_byte_tables': int(raw.sum()), 'centered_byte_tables': int(admitted.sum()),
        'total_tables': int(admitted.size), 'centered_safe_positions_all_64': int(admitted.all(axis=0).sum()),
        'raw_safe_positions_all_64': int(raw.all(axis=0).sum()),
        'nonzero_center_tables': int(np.count_nonzero(center)),
        'centered_safe_but_correction_needed': int((admitted & (center != 0)).sum()),
        'centered_safe_zero_correction': int((admitted & (center == 0)).sum()),
        'centered_still_int16': int((~admitted).sum()),
        'nonzero_center_positions_union': int(np.any(center != 0, axis=0).sum()),
        'table_positions': positions,
        'center_min': int(center.min()), 'center_max': int(center.max()),
        'max_minimum_l1_radius': int(r.max()),
        'table_sha256': digest(table), 'center_sha256': digest(center),
        'first_quartet_response_sha256': digest(sampled),
        'centered_byte_reads': int(admitted.sum() * len(signs)),
        'centered_int16_reads': int((~admitted).sum() * len(signs)),
        'additional_center_correction_slots': int(np.count_nonzero(center) * len(signs)),
        'additional_nonzero_center_corrections': nonzero_corrections,
        'zero_sign_sum_fraction': float(np.mean(sign_sums == 0)),
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
    q1, w1, _ = parent.ladder(x)
    h = parent.factor(vs, q1, w1)
    q2, w2, _ = parent.ladder(h)
    y = parent.factor(us, q2, w2)
    return {'layer': layer, 'image_sha256': parent.sha(image), 'fixture_sha256': parent.sha(fixture),
            'validation_rows': [ROWS.start, ROWS.stop], 'first_integer_sha256': digest(h),
            'final_integer_sha256': digest(y), 'group_weights_sha256': [digest(w1), digest(w2)],
            'stages': {'input': stage(q1, vs), 'rank': stage(q2, us)}}


def main():
    entries = [run(layer) for layer in (0, 7, 14, 27)]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': parent.sha(Path(__file__)),
                               'parent_source_sha256': parent.sha(Path(parent.__file__)),
                               'numpy_version': np.__version__, 'entries': entries}, indent=2) + '\n')
    for e in entries:
        print(e['layer'], [(name, s['original_byte_tables'], s['centered_byte_tables'],
                             s['centered_safe_positions_all_64'], s['additional_nonzero_center_corrections'])
                            for name, s in e['stages'].items()], flush=True)
    print(OUT)


if __name__ == '__main__':
    main()
