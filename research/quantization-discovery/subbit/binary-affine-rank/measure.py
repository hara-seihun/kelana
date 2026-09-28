#!/usr/bin/env python3
"""Price a signed A7 group zero-point for the frozen paid binary MLP-up reader."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'binary-rank-gauge'))
import measure as parent

ROOT = Path('/path/to/workspace/data/kelana-subbit')
OUT = ROOT / 'binary-affine-rank/receipt.json'


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def affine_ladder(h, bits=7, cap=8, threshold=.75):
    words = np.asarray(h, dtype=np.float64).reshape(h.shape[0], -1, 32)
    lo, hi = words.min(axis=2), words.max(axis=2)
    center = np.floor((lo + hi) / 2).astype(np.int64)
    radius = np.maximum(hi - center, center - lo)
    maximum = (1 << (bits - 1)) - 1
    global_radius = np.maximum(radius.max(axis=1), 1.0)
    exponent = np.clip(np.floor(np.log2(global_radius[:, None] / np.maximum(radius, 1e-30))).astype(np.int32), 0, cap)
    upper = global_radius[:, None] / maximum * np.exp2(-exponent.astype(np.float64))
    lower = .75 * upper
    use_three = (radius / maximum <= upper * threshold) & (exponent < cap)
    steps = np.where(use_three, lower, upper)
    weight = np.where(use_three, 3 << (cap - 1 - exponent), 1 << (cap + 1 - exponent)).astype(np.int64)
    base = global_radius / maximum * 2.0 ** -(cap + 1)
    zero = np.rint(center / steps).astype(np.int64)
    codes = np.clip(np.rint(words / steps[:, :, None]).astype(np.int64) - zero[:, :, None], -maximum - 1, maximum)
    return codes, weight, base, zero, center, radius, steps


def centered_stage(signs, h):
    _, weight, base, _, center, _, steps = affine_ladder(h)
    words = np.asarray(h, dtype=np.float64).reshape(h.shape[0], -1, 32)
    codes = np.clip(np.rint((words - center[:, :, None]) / steps[:, :, None]), -64, 63).astype(np.int64)
    out = np.zeros((len(h), len(signs)), dtype=np.int64)
    correction = np.zeros_like(out)
    for g in range(codes.shape[1]):
        block = signs[:, 32*g:32*(g+1)].astype(np.int64)
        out += (codes[:, g] @ block.T) * weight[:, g, None]
        correction += center[:, g, None] * block.sum(axis=1)[None, :]
    return out, base, correction, {'max_abs_integer_dot': int(np.abs(out).max()),
                                  'max_abs_center_correction': int(np.abs(correction).max()),
                                  'center_sha256': sha_bytes(np.ascontiguousarray(center).tobytes())}


def affine_stage(signs, h):
    q, w, base, z, center, radius, _ = affine_ladder(h)
    out = np.zeros((len(h), len(signs)), dtype=np.int64)
    corrections = np.zeros_like(out)
    for g in range(q.shape[1]):
        block = signs[:, 32*g:32*(g+1)].astype(np.int64)
        sums = block.sum(axis=1)
        out += (q[:, g] @ block.T) * w[:, g, None]
        corrections += (z[:, g] * w[:, g])[:, None] * sums[None, :]
    return out + corrections, base, {
        'nonzero_zero_points': int(np.count_nonzero(z)),
        'total_groups': int(z.size),
        'max_abs_zero_point': int(np.abs(z).max()),
        'max_abs_accumulator': int(np.abs(out + corrections).max()),
        'clipped_codes': int(np.count_nonzero((q == 63) | (q == -64))),
        'zero_points_sha256': sha_bytes(np.ascontiguousarray(z).tobytes()),
    }


def run(layer):
    path = parent.IMAGES / f'model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
    fixture = parent.FIXTURES / f'layer{layer:02d}-mlp_up_proj.npz'
    with np.load(path) as image:
        n, k, rank = map(int, image['dimensions'])
        v, u = image['V'].copy(), image['U'].copy()
        pre, post = image['scale_pre'].astype(np.float64), image['scale_post'].astype(np.float64)
    with np.load(fixture) as data:
        x = np.concatenate((data['train'][512:576], data['validation'][576:704])).astype(np.float64) * pre
    vs = 2 * np.unpackbits(v, axis=1, count=k, bitorder='little').astype(np.int32) - 1
    us = 2 * np.unpackbits(u, axis=1, count=rank, bitorder='little').astype(np.int32) - 1
    h, b1 = parent.stage(vs, x)
    power = np.mean(h[:64].astype(np.float64) ** 2, axis=0)
    permutations = {'identity': np.arange(rank), 'energy_sorted': np.argsort(-power, kind='stable')}
    truth = ((x @ vs.T.astype(np.float64)) @ us.T.astype(np.float64)) * post
    arms = {}
    for name, perm in permutations.items():
        signs = us[:, perm]
        rank_values = h[:, perm]
        plain, b2 = parent.stage(signs, rank_values)
        affine, ab2, detail = affine_stage(signs, rank_values)
        centered, cb2, correction, centered_detail = centered_stage(signs, rank_values)
        arms[name] = {}
        for label, integer, base, extra in [('symmetric', plain, b2, 0), ('affine', affine, ab2, 0),
                                            ('centered', centered, cb2, correction)]:
            response = (integer.astype(np.float64) * base[:, None] + extra) * b1[:, None] * post
            arms[name][label] = {
                'train_rms': parent.error(response[:64], truth[:64]),
                'held_rms': parent.error(response[64:], truth[64:]),
                'held_per_input': parent.split_errors(response[64:], truth[64:]),
                'held_integer_sha256': sha_bytes(np.ascontiguousarray(integer[64:]).tobytes()),
            }
        arms[name]['affine'].update(detail)
        arms[name]['centered'].update(centered_detail)
    return {'layer': layer, 'paid_image': str(path), 'paid_image_sha256': parent.sha(path),
            'fixture_sha256': parent.sha(fixture), 'train_rows': [512, 576], 'held_rows': [576, 704], 'first_stage_sha256': sha_bytes(np.ascontiguousarray(h).tobytes()),
            'arms': arms}


def main():
    entries = [run(layer) for layer in (0, 7, 14, 27)]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': parent.sha(Path(__file__)),
        'parent_source_sha256': parent.sha(Path(parent.__file__)),
        'numpy_version': np.__version__, 'entries': entries}, indent=2) + '\n')
    for item in entries:
        print(item['layer'], [(k, {a: round(v['held_rms'], 7) for a, v in pair.items()}) for k, pair in item['arms'].items()])
    print(OUT)


if __name__ == '__main__':
    main()
