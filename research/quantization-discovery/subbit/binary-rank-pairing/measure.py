#!/usr/bin/env python3
"""Fit a zero-rate rank partition against grouped A7 reconstruction."""
import hashlib
import json
import runpy
from pathlib import Path

import numpy as np

PARENT = Path(__file__).resolve().parents[1] / 'binary-rank-gauge/measure.py'
parent = runpy.run_path(str(PARENT))
ROOT = Path('/path/to/workspace/data/kelana-subbit')
OUT = ROOT / 'binary-rank-pairing/receipt.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def group_loss(values, base, global_max, threshold):
    maximum = np.max(np.abs(values), axis=1)
    exponent = np.clip(np.floor(np.log2(global_max / np.maximum(maximum, 1e-30))).astype(np.int32), 0, 8)
    upper = global_max / 63 * np.exp2(-exponent.astype(np.float64))
    use_three = (maximum / 63 <= upper * threshold) & (exponent < 8)
    step = np.where(use_three, upper * .75, upper)
    multiplier = np.where(use_three, 3 << (7 - exponent), 1 << (9 - exponent))
    quant = np.clip(np.rint(values / step[:, None]), -64, 63)
    residual = values - quant * multiplier[:, None] * base[:, None]
    return float(np.sum(residual * residual))


def optimize(h, start, threshold, seed, attempts):
    rng = np.random.default_rng(seed)
    perm = start.copy()
    train = h[:64].astype(np.float64)
    maximum = np.maximum(np.max(np.abs(train), axis=1), 1e-30)
    base = maximum / 63 * (2.0 ** -9)
    losses = np.array([group_loss(train[:, perm[g*32:(g+1)*32]], base, maximum, threshold)
                       for g in range(12)])
    before = float(losses.sum())
    accepted = 0
    for _ in range(attempts):
        a = int(rng.integers(384))
        b = int(rng.integers(384))
        ga, gb = a // 32, b // 32
        if ga == gb:
            continue
        perm[a], perm[b] = perm[b], perm[a]
        la = group_loss(train[:, perm[ga*32:(ga+1)*32]], base, maximum, threshold)
        lb = group_loss(train[:, perm[gb*32:(gb+1)*32]], base, maximum, threshold)
        if la + lb < losses[ga] + losses[gb] - 1e-8:
            losses[ga], losses[gb] = la, lb
            accepted += 1
        else:
            perm[a], perm[b] = perm[b], perm[a]
    return perm, before, float(losses.sum()), accepted


def arm(h, b1, vs, us, post, truth, perm, threshold):
    vp = np.packbits(((vs[perm] + 1) // 2).astype(np.uint8), axis=1, bitorder='little')
    up = np.packbits(((us[:, perm] + 1) // 2).astype(np.uint8), axis=1, bitorder='little')
    assert np.array_equal(2 * np.unpackbits(vp, axis=1, count=1024, bitorder='little').astype(np.int32) - 1, vs[perm])
    assert np.array_equal(2 * np.unpackbits(up, axis=1, count=384, bitorder='little').astype(np.int32) - 1, us[:, perm])
    ints, b2 = parent['stage'](us[:, perm], h[:, perm], threshold)
    y = ints.astype(np.float64) * (b1 * b2)[:, None] * post
    return {'packed_v_sha256': hashlib.sha256(vp.tobytes()).hexdigest(),
            'packed_u_sha256': hashlib.sha256(up.tobytes()).hexdigest(),
            'train_rms': parent['error'](y[:64], truth[:64]),
            'held_rms': parent['error'](y[64:], truth[64:]),
            'held_per_input': parent['split_errors'](y[64:], truth[64:]),
            'held_integer_sha256': hashlib.sha256(np.ascontiguousarray(ints[64:]).tobytes()).hexdigest(),
            'permutation_sha256': hashlib.sha256(perm.astype('<i4').tobytes()).hexdigest()}


def run(layer, attempts):
    image = ROOT / f'binary-factors/fixtures/model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
    fixture = ROOT / f'fixtures/qwen3-0.6b-wikitext/layer{layer:02d}-mlp_up_proj.npz'
    with np.load(image) as data:
        v, u = data['V'], data['U']
        pre, post = data['scale_pre'].astype(np.float64), data['scale_post'].astype(np.float64)
    vs = 2 * np.unpackbits(v, axis=1, count=1024, bitorder='little').astype(np.int32) - 1
    us = 2 * np.unpackbits(u, axis=1, count=384, bitorder='little').astype(np.int32) - 1
    with np.load(fixture) as data:
        x = np.concatenate((data['train'][512:576], data['validation'][512:576])).astype(np.float64) * pre
    h, b1 = parent['stage'](vs, x)
    truth = ((x @ vs.T.astype(np.float64)) @ us.T.astype(np.float64)) * post
    sorted_rank = np.argsort(-np.mean(h[:64].astype(np.float64)**2, axis=0), kind='stable')
    result = {'layer': layer, 'image_sha256': sha(image), 'fixture_sha256': sha(fixture),
              'first_integer_sha256': hashlib.sha256(np.ascontiguousarray(h).tobytes()).hexdigest(),
              'arms': {}}
    for label, threshold in [('safe', .75), ('frozen_pair', .77)]:
        # Only layer 0 uses .77 at both boundaries; layer 14 has .78/.77.
        if label == 'frozen_pair':
            first = .77 if layer == 0 else .78
            hh, bb = parent['stage'](vs, x, first)
        else:
            hh, bb = h, b1
        fitted, before, after, accepted = optimize(hh, sorted_rank, threshold, 191 + layer, attempts)
        result['arms'][label] = {'train_intermediate_squared_error_sorted': before,
                                'train_intermediate_squared_error_fitted': after,
                                'accepted_swaps': accepted,
                                'sorted': arm(hh, bb, vs, us, post, truth, sorted_rank, threshold),
                                'fitted': arm(hh, bb, vs, us, post, truth, fitted, threshold)}
    return result


def main():
    attempts = 6000
    entries = [run(layer, attempts) for layer in (0, 14)]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(PARENT),
        'numpy_version': np.__version__, 'attempts_per_arm': attempts,
        'contract': 'Frozen paid Qwen3-0.6B mlp_up one-bit factors. Train[512:576] rank group reconstruction fit; validation[512:576] held complete two-factor FP64 same-image response. Repack V rows/U columns; no online gather. 32-rank groups, A7 two-choice integer ladder, cap 8. Independent safe and frozen-pair first thresholds; second threshold .75/.77. No GPU or whole-model loss.',
        'entries': entries}, indent=2) + '\n')
    for entry in entries:
        for name, result in entry['arms'].items():
            print(entry['layer'], name, 'accepted', result['accepted_swaps'], 'intermediate', result['train_intermediate_squared_error_sorted'], result['train_intermediate_squared_error_fitted'], 'final held', result['sorted']['held_rms'], result['fitted']['held_rms'])
    print(OUT)


if __name__ == '__main__':
    main()
