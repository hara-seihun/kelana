#!/usr/bin/env python3
"""Test a cost-free rank-coordinate permutation across paid binary factors."""
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
IMAGES = ROOT / 'binary-factors/fixtures'
FIXTURES = ROOT / 'fixtures/qwen3-0.6b-wikitext'
OUT = ROOT / 'binary-rank-gauge/receipt.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ladder(a, bits=7, cap=8, threshold=.75):
    words = np.asarray(a, dtype=np.float64).reshape(a.shape[0], -1, 32)
    maximum = (1 << (bits - 1)) - 1
    group_max = np.max(np.abs(words), axis=2)
    global_max = np.maximum(group_max.max(axis=1), 1e-30)
    exponent = np.clip(np.floor(np.log2(global_max[:, None] / np.maximum(group_max, 1e-30))).astype(np.int32), 0, cap)
    upper = global_max[:, None] / maximum * np.exp2(-exponent.astype(np.float64))
    lower = upper * .75
    use_three = (group_max / maximum <= upper * threshold) & (exponent < cap)
    steps = np.where(use_three, lower, upper)
    weight = np.where(use_three, 3 << (cap - 1 - exponent), 1 << (cap + 1 - exponent)).astype(np.int32)
    q = np.clip(np.rint(words / steps[:, :, None]), -maximum - 1, maximum).astype(np.int32)
    base = global_max / maximum * 2.0 ** -(cap + 1)
    return q, weight, base


def factor(signs, q, weight):
    result = np.zeros((q.shape[0], signs.shape[0]), dtype=np.int32)
    for group in range(q.shape[1]):
        result += (q[:, group] @ signs[:, group * 32:(group + 1) * 32].T) * weight[:, group, None]
    return result


def stage(signs, x, threshold=.75):
    q, w, b = ladder(x, threshold=threshold)
    return factor(signs, q, w), b


def error(y, truth):
    return float(np.linalg.norm(y - truth) / np.linalg.norm(truth))


def split_errors(y, truth):
    return [error(y[i], truth[i]) for i in range(y.shape[0])]


def run(path):
    with np.load(path) as image:
        n, k, rank = map(int, image['dimensions'])
        v, u = image['V'].copy(), image['U'].copy()
        pre, post = image['scale_pre'].astype(np.float64), image['scale_post'].astype(np.float64)
    layer = int(path.name.split('_')[2])
    fixture = FIXTURES / f'layer{layer:02d}-mlp_up_proj.npz'
    with np.load(fixture) as data:
        train = data['train'][512:576].astype(np.float64)
        held = data['validation'][512:576].astype(np.float64)
    vs = 2 * np.unpackbits(v, axis=1, count=k, bitorder='little').astype(np.int32) - 1
    us = 2 * np.unpackbits(u, axis=1, count=rank, bitorder='little').astype(np.int32) - 1
    x = np.concatenate((train, held)) * pre
    h, b1 = stage(vs, x)
    # No target labels: sort by the first stage's *training* rank-code energy.
    power = np.mean(h[:64].astype(np.float64) ** 2, axis=0)
    sorted_rank = np.argsort(-power, kind='stable')
    # An opposite control distributes the strongest coordinates round-robin over the groups.
    spread_rank = sorted_rank.reshape(32, rank // 32).T.reshape(-1)
    identity = np.arange(rank)
    truth_h = x @ vs.T.astype(np.float64)
    truth = (truth_h @ us.T.astype(np.float64)) * post
    arms = {}
    for name, perm in [('identity', identity), ('energy_sorted', sorted_rank), ('energy_spread', spread_rank)]:
        # Repack the two paid sign planes. V row order and U column order
        # change together, so runtime receives h in the chosen order already.
        vp = np.packbits(((vs[perm] + 1) // 2).astype(np.uint8), axis=1, bitorder='little')
        up = np.packbits(((us[:, perm] + 1) // 2).astype(np.uint8), axis=1, bitorder='little')
        assert vp.shape == v.shape and up.shape == u.shape
        vs_p = 2 * np.unpackbits(vp, axis=1, count=k, bitorder='little').astype(np.int32) - 1
        us_p = 2 * np.unpackbits(up, axis=1, count=rank, bitorder='little').astype(np.int32) - 1
        assert np.array_equal(vs_p, vs[perm]) and np.array_equal(us_p, us[:, perm])
        y_int, b2 = stage(us_p, h[:, perm])
        real_gauge = (truth_h[:, perm] @ us_p.T.astype(np.float64)) * post
        y = y_int.astype(np.float64) * (b1 * b2)[:, None] * post
        arms[name] = {
            'real_max_absolute_difference': float(np.max(np.abs(real_gauge - truth))),
            'packed_v_sha256': hashlib.sha256(vp.tobytes()).hexdigest(),
            'packed_u_sha256': hashlib.sha256(up.tobytes()).hexdigest(),
            'train_rms': error(y[:64], truth[:64]),
            'held_rms': error(y[64:], truth[64:]),
            'held_per_input': split_errors(y[64:], truth[64:]),
            'held_output_sha256': hashlib.sha256(np.ascontiguousarray(y_int[64:]).tobytes()).hexdigest(),
            'max_final_integer': int(np.abs(y_int).max()),
        }
    if layer in (0, 14):
        first_threshold, second_threshold = ((.77, .77) if layer == 0 else (.78, .77))
        pair_h, pair_b1 = stage(vs, x, first_threshold)
        for name, perm in [('frozen_pair_identity', identity), ('frozen_pair_sorted', sorted_rank)]:
            pair_int, pair_b2 = stage(us[:, perm], pair_h[:, perm], second_threshold)
            pair_y = pair_int.astype(np.float64) * (pair_b1 * pair_b2)[:, None] * post
            arms[name] = {'train_rms': error(pair_y[:64], truth[:64]),
                          'held_rms': error(pair_y[64:], truth[64:]),
                          'held_per_input': split_errors(pair_y[64:], truth[64:]),
                          'held_output_sha256': hashlib.sha256(np.ascontiguousarray(pair_int[64:]).tobytes()).hexdigest()}
    return {'image': str(path), 'image_sha256': sha(path), 'fixture_sha256': sha(fixture),
            'first_integer_sha256': hashlib.sha256(np.ascontiguousarray(h).tobytes()).hexdigest(),
            'train_rows': [512, 576], 'held_rows': [512, 576], 'layer': layer,
            'dimension': [n, k, rank], 'permutations_sha256': {
                'sorted': hashlib.sha256(sorted_rank.astype('<i4').tobytes()).hexdigest(),
                'spread': hashlib.sha256(spread_rank.astype('<i4').tobytes()).hexdigest(),
            }, 'arms': arms}


def main():
    paths = [IMAGES / f'model_layers_{layer}_mlp_up_proj_weight_0.55.npz' for layer in (0, 7, 14, 27)]
    entries = [run(path) for path in paths]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': sha(Path(__file__)), 'numpy_version': np.__version__,
        'contract': 'Frozen paid .55 binary factor image; 64 train[512:576] inputs choose rank permutation by safe first-stage A7 energy only; 64 validation[512:576] inputs held. Both factors use two-choice A7 C8 ladder, integer group reduction, one final float product. Layers 0/14 also compare independently trained published pair thresholds .77/.77 and .78/.77 on these same windows with/without the safe-fitted permutation. FP64 same-image unquantized two-stage response is denominator. No GPU, composed model loss or native latency.',
        'entries': entries}, indent=2) + '\n')
    for item in entries:
        print(item['layer'], [(k, v['train_rms'], v['held_rms']) for k, v in item['arms'].items()])
    print(OUT)


if __name__ == '__main__':
    main()
