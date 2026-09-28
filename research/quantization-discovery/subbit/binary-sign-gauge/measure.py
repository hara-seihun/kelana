#!/usr/bin/env python3
"""Fit the rank sign gauge of paid binary factors through the complete A7 response."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'binary-rank-gauge'))
from measure import IMAGES, FIXTURES, error, factor, ladder, sha, stage  # noqa: E402

OUT = Path('/path/to/workspace/data/kelana-subbit/binary-sign-gauge/receipt.json')


def digest(array):
    return hashlib.sha256(np.ascontiguousarray(array).tobytes()).hexdigest()


def fit(image_path, order, first_threshold, second_threshold):
    with np.load(image_path) as image:
        n, k, rank = map(int, image['dimensions'])
        v, u = image['V'].copy(), image['U'].copy()
        pre = image['scale_pre'].astype(np.float64)
        post = image['scale_post'].astype(np.float64)
    layer = int(image_path.name.split('_')[2])
    fixture = FIXTURES / f'layer{layer:02d}-mlp_up_proj.npz'
    with np.load(fixture) as data:
        x = np.concatenate((data['train'][512:576], data['validation'][576:704])).astype(np.float64) * pre
    vs = 2 * np.unpackbits(v, axis=1, count=k, bitorder='little').astype(np.int32) - 1
    us = 2 * np.unpackbits(u, axis=1, count=rank, bitorder='little').astype(np.int32) - 1
    h, b1 = stage(vs, x, first_threshold)
    perm = np.argsort(-np.mean(h[:64].astype(np.float64) ** 2, axis=0), kind='stable') if order == 'energy_sorted' else np.arange(rank)
    hp, up = h[:, perm], us[:, perm]
    q, w, b2 = ladder(hp, threshold=second_threshold)
    opposite, ow, ob = ladder(-hp, threshold=second_threshold)
    assert np.array_equal(ow, w) and np.array_equal(ob, b2)
    correction = (-opposite - q).reshape(len(x), rank) * np.repeat(w, 32, axis=1)
    active = np.flatnonzero(np.any(correction, axis=0))
    base_int = factor(up, q, w)
    scale = b1 * b2
    base = base_int.astype(np.float64) * scale[:, None] * post
    truth = (x @ vs.T.astype(np.float64) @ us.T.astype(np.float64)) * post
    # Each sign flip contributes a rank-one output response. Its coefficient is
    # determined by the signed quantizer's asymmetric -64/+63 saturation cell.
    d = correction[:, active].astype(np.float64) * scale[:, None]
    weighted_u = up[:, active].astype(np.float64) * post[:, None]
    response = truth - base
    held_correction_bound = float(np.sum(np.linalg.norm(d[64:], axis=0) * np.linalg.norm(weighted_u, axis=0)) / np.linalg.norm(truth[64:]))
    linear = np.einsum('ra,ro,oa->a', d[:64], response[:64], weighted_u, optimize=True)
    gram = (d[:64].T @ d[:64]) * (weighted_u.T @ weighted_u)
    selected = np.zeros(len(active), dtype=np.int8)
    residual_gradient = linear.copy()
    for _ in range(len(active)):
        improvement = 2 * residual_gradient - np.diag(gram)
        improvement[selected.astype(bool)] = -np.inf
        idx = int(np.argmax(improvement)) if len(active) else -1
        if idx < 0 or improvement[idx] <= 0:
            break
        selected[idx] = 1
        residual_gradient -= gram[:, idx]
    orientation = np.ones(rank, dtype=np.int32)
    orientation[active[selected.astype(bool)]] = -1
    # Replay the actual packed gauge through both factor stages rather than
    # trusting the quadratic surrogate alone.
    vp = np.packbits(((vs[perm] * orientation[:, None] + 1) // 2).astype(np.uint8), axis=1, bitorder='little')
    upacked = np.packbits(((up * orientation[None, :] + 1) // 2).astype(np.uint8), axis=1, bitorder='little')
    vcheck = 2 * np.unpackbits(vp, axis=1, count=k, bitorder='little').astype(np.int32) - 1
    ucheck = 2 * np.unpackbits(upacked, axis=1, count=rank, bitorder='little').astype(np.int32) - 1
    assert np.array_equal(vcheck, vs[perm] * orientation[:, None])
    assert np.array_equal(ucheck, up * orientation[None, :])
    first_replay, first_scale = stage(vcheck, x, first_threshold)
    assert np.array_equal(first_replay, hp * orientation) and np.array_equal(first_scale, b1)
    fitted_int, fitted_scale = stage(ucheck, first_replay, second_threshold)
    assert np.array_equal(fitted_scale, b2)
    predicted_int = base_int + ((correction * (orientation == -1)).astype(np.int32) @ up.T)
    assert np.array_equal(fitted_int, predicted_int)
    fitted = fitted_int.astype(np.float64) * scale[:, None] * post
    max_real_difference = float(np.max(np.abs((x @ vcheck.T.astype(np.float64) @ ucheck.T.astype(np.float64)) * post - truth)))
    return {'layer': layer, 'order': order, 'thresholds': [first_threshold, second_threshold],
            'image_sha256': sha(image_path), 'fixture_sha256': sha(fixture),
            'train_rows': [512, 576], 'held_rows': [576, 704],
            'active_train_coordinates': int(np.count_nonzero(np.any(correction[:64], axis=0))),
            'active_held_coordinates': int(np.count_nonzero(np.any(correction[64:], axis=0))),
            'selected_flips': active[selected.astype(bool)].tolist(),
            'train_saturation_events': int(np.count_nonzero(correction[:64])),
            'held_saturation_events': int(np.count_nonzero(correction[64:])),
            'base_train_rms': error(base[:64], truth[:64]), 'fit_train_rms': error(fitted[:64], truth[:64]),
            'base_held_rms': error(base[64:], truth[64:]), 'fit_held_rms': error(fitted[64:], truth[64:]),
            'held_per_input_base': [error(a, b) for a, b in zip(base[64:], truth[64:])],
            'held_per_input_fit': [error(a, b) for a, b in zip(fitted[64:], truth[64:])],
            'max_real_difference': max_real_difference,
            'held_rms_possible_change_bound': held_correction_bound,
            'permutation_sha256': digest(perm.astype('<i4')),
            'packed_v_sha256': digest(vp), 'packed_u_sha256': digest(upacked),
            'held_integer_sha256': digest(fitted_int[64:])}


def main():
    entries = []
    for layer in (0, 7, 14, 27):
        image = IMAGES / f'model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
        for order in ('identity', 'energy_sorted'):
            entries.append(fit(image, order, .77 if layer == 0 else .78 if layer == 14 else .75,
                               .77 if layer in (0, 14) else .75))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(HERE.parent / 'binary-rank-gauge/measure.py'),
                               'numpy_version': np.__version__, 'entries': entries}, indent=2) + '\n')
    for e in entries:
        print(e['layer'], e['order'], e['active_train_coordinates'], len(e['selected_flips']),
              f"{e['base_train_rms']:.8f}->{e['fit_train_rms']:.8f}",
              f"{e['base_held_rms']:.8f}->{e['fit_held_rms']:.8f}",
              f"ceiling={e['held_rms_possible_change_bound']:.8f}")
    print(OUT)


if __name__ == '__main__':
    main()
