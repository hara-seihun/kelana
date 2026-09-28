#!/usr/bin/env python3
"""Fit a one-scalar center rule for the second packed binary A7 consumer."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'binary-rank-gauge'))
import measure as parent

OUT = parent.ROOT / 'binary-second-center-choice/receipt.json'
TRAIN = slice(704, 768)
HELD = slice(832, 960)
ALPHAS = (-1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75, 1.0, 1.5)


def digest(a):
    return hashlib.sha256(np.ascontiguousarray(a).tobytes()).hexdigest()


def centered(signs, h, alpha):
    words = h.astype(np.float64).reshape(len(h), -1, 32)
    lo, hi = words.min(2), words.max(2)
    mid = (lo + hi) / 2
    center = np.floor(mid + alpha * (words.mean(2) - mid)).astype(np.int64)
    radius = np.maximum(hi - center, center - lo)
    maximum, cap = 63, 8
    global_radius = np.maximum(radius.max(1), 1.0)
    exponent = np.clip(np.floor(np.log2(global_radius[:, None] / np.maximum(radius, 1e-30))).astype(np.int32), 0, cap)
    upper = global_radius[:, None] / maximum * np.exp2(-exponent.astype(np.float64))
    use_three = (radius / maximum <= .75 * upper) & (exponent < cap)
    steps = np.where(use_three, .75 * upper, upper)
    weight = np.where(use_three, 3 << (cap - 1 - exponent), 1 << (cap + 1 - exponent)).astype(np.int64)
    base = global_radius / maximum * 2.0 ** -(cap + 1)
    zero = np.rint(center / steps).astype(np.int64)
    codes = np.clip(np.rint(words / steps[:, :, None]).astype(np.int64) - zero[:, :, None], -64, 63)
    integer = np.zeros((len(h), len(signs)), dtype=np.int64)
    for group in range(codes.shape[1]):
        block = signs[:, group * 32:(group + 1) * 32].astype(np.int64)
        integer += (codes[:, group] @ block.T + zero[:, group, None] * block.sum(axis=1)[None, :]) * weight[:, group, None]
    return integer, base, {'held_integer_sha256': digest(integer[64:]),
                           'max_abs_accumulator': int(np.max(np.abs(integer))),
                           'max_abs_zero': int(np.max(np.abs(zero))),
                           'changed_group_centers': int(np.count_nonzero(center))}


def run(layer):
    image_path = parent.IMAGES / f'model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
    fixture = parent.FIXTURES / f'layer{layer:02d}-mlp_up_proj.npz'
    with np.load(image_path) as image:
        n, k, rank = map(int, image['dimensions'])
        v, u = image['V'].copy(), image['U'].copy()
        pre, post = image['scale_pre'].astype(np.float64), image['scale_post'].astype(np.float64)
    with np.load(fixture) as data:
        x = np.concatenate((data['train'][TRAIN], data['validation'][HELD])).astype(np.float64) * pre
    vs = 2 * np.unpackbits(v, axis=1, count=k, bitorder='little').astype(np.int32) - 1
    us = 2 * np.unpackbits(u, axis=1, count=rank, bitorder='little').astype(np.int32) - 1
    h, b1 = parent.stage(vs, x)
    truth = ((x @ vs.T.astype(np.float64)) @ us.T.astype(np.float64)) * post
    baseline, b2 = parent.stage(us, h)
    baseline_response = baseline.astype(np.float64) * (b1 * b2)[:, None] * post
    arms = {}
    for alpha in ALPHAS:
        integer, base, bill = centered(us, h, alpha)
        response = integer.astype(np.float64) * (b1 * base)[:, None] * post
        arms[str(alpha)] = {'train_rms': parent.error(response[:64], truth[:64]),
                            'held_rms': parent.error(response[64:], truth[64:]),
                            'held_per_input': parent.split_errors(response[64:], truth[64:]), **bill}
    choice = min(ALPHAS, key=lambda a: arms[str(a)]['train_rms'])
    return {'layer': layer, 'image_sha256': parent.sha(image_path), 'fixture_sha256': parent.sha(fixture),
            'first_integer_sha256': digest(h), 'train_rows': [TRAIN.start, TRAIN.stop],
            'held_rows': [HELD.start, HELD.stop], 'baseline_train_rms': parent.error(baseline_response[:64], truth[:64]),
            'baseline_held_rms': parent.error(baseline_response[64:], truth[64:]),
            'train_selected_alpha': choice, 'arms': arms}


def main():
    entries = [run(layer) for layer in (0, 7, 14, 27)]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': parent.sha(Path(__file__)),
                               'parent_source_sha256': parent.sha(Path(parent.__file__)),
                               'numpy_version': np.__version__, 'entries': entries}, indent=2) + '\n')
    for e in entries:
        print(e['layer'], 'baseline', round(e['baseline_held_rms'], 7), 'selected', e['train_selected_alpha'],
              [(a, round(v['held_rms'], 7)) for a, v in e['arms'].items()], flush=True)
    print(OUT)


if __name__ == '__main__':
    main()
