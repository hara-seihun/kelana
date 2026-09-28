#!/usr/bin/env python3
"""Paired frozen binary-factor responses with integer group-shift scales."""
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
IMAGES = ROOT / 'binary-factors/fixtures'
FIXTURES = ROOT / 'fixtures/qwen3-0.6b-wikitext'
OUT = ROOT / 'binary-shifted-scales/receipt.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def quant_groups(a, bits, cap, shifts, three=False):
    words = np.asarray(a).reshape(-1, 32)
    maximum = (1 << (bits - 1)) - 1
    max_group = np.max(np.abs(words), axis=1)
    global_max = max(float(max_group.max()), 1e-30)
    if shifts:
        exponent = np.clip(np.floor(np.log2(global_max / np.maximum(max_group, 1e-30))).astype(np.int32), 0, cap)
        upper = (global_max / maximum) * np.exp2(-exponent.astype(np.float64))
        if three:
            lower = upper * .75
            use_three = (max_group / maximum <= lower) & (exponent < cap)
            steps = np.where(use_three, lower, upper)
            weights = np.where(use_three, 3 << (cap - 1 - exponent), 1 << (cap + 1 - exponent))
            base = (global_max / maximum) * 2.0 ** -(cap + 1)
        else:
            steps = upper
            weights = 1 << (cap - exponent)
            base = (global_max / maximum) * 2.0 ** -cap
        q = np.clip(np.rint(words / steps[:, None]), -maximum - 1, maximum).astype(np.int32)
        # The response's only floating scale is common to all groups.
        return q, weights, base, exponent
    steps = np.maximum(max_group / maximum, 1e-30)
    q = np.clip(np.rint(words / steps[:, None]), -maximum - 1, maximum).astype(np.int32)
    return q, steps, None, None


def response(signs, x, bits, cap, shifted, three=False):
    q, weights, base, exponents = quant_groups(x, bits, cap, shifted, three)
    partials = np.einsum('rgk,gk->rg', signs.reshape(signs.shape[0], -1, 32).astype(np.int32), q, optimize=True).astype(np.int64)
    if shifted:
        integer = partials @ weights.astype(np.int64)
        return integer, base, exponents
    return partials.astype(np.float64) @ weights, 1., None


def relative(a, b):
    return float(np.linalg.norm(a - b) / np.linalg.norm(b))


def main():
    entries = []
    for path in sorted(IMAGES.glob('*_0.55.npz')):
        with np.load(path) as image:
            n, k, rank = map(int, image['dimensions'])
            u = image['U'].copy()
            v = image['V'].copy()
            pre = image['scale_pre'].astype(np.float64)
            post = image['scale_post'].astype(np.float64)
        layer = int(path.name.split('_')[2])
        key = path.stem.split('_weight_')[0].split(f'model_layers_{layer}_')[1]
        fixture = FIXTURES / f'layer{layer:02d}-{key}.npz'
        with np.load(fixture) as data:
            inputs = data['validation'][:4].astype(np.float64)
        vs = 2 * np.unpackbits(v, axis=1, count=k, bitorder='little').astype(np.int16) - 1
        us = 2 * np.unpackbits(u, axis=1, count=rank, bitorder='little').astype(np.int16) - 1
        cases = {}
        for bits in (5, 6, 7):
            for cap in (4, 8, 12):
                cases[f'shift{cap}_a{bits}'] = []
            cases[f'group32_a{bits}'] = []
            cases[f'shift3_8_a{bits}'] = []
        cases['global_a8'] = []
        for x in inputs:
            a = x * pre
            h = vs.astype(np.float64) @ a
            truth = (us.astype(np.float64) @ h) * post
            for bits in (5, 6, 7):
                float_h, _, _ = response(vs, a, bits, 0, False)
                float_y, _, _ = response(us, float_h, bits, 0, False)
                cases[f'group32_a{bits}'].append(relative(float_y * post, truth))
                for cap in (4, 8, 12):
                    h_int, first_base, e_first = response(vs, a, bits, cap, True)
                    y_int, second_relative_base, e_second = response(us, h_int, bits, cap, True)
                    y = y_int.astype(np.float64) * (first_base * second_relative_base) * post
                    cases[f'shift{cap}_a{bits}'].append({'rms': relative(y, truth), 'first_exponent_range': [int(e_first.min()), int(e_first.max())], 'second_exponent_range': [int(e_second.min()), int(e_second.max())], 'max_intermediate_integer': int(np.abs(h_int).max()), 'max_final_integer': int(np.abs(y_int).max())})
                h_int, first_base, _ = response(vs, a, bits, 8, True, True)
                y_int, second_base, _ = response(us, h_int, bits, 8, True, True)
                cases[f'shift3_8_a{bits}'].append({'rms': relative(y_int.astype(np.float64) * (first_base * second_base) * post, truth), 'max_intermediate_integer': int(np.abs(h_int).max()), 'max_final_integer': int(np.abs(y_int).max())})
            # cap=0 gives the same dynamic global A8 scale at both stages.
            global_h, first_base, _ = response(vs, a, 8, 0, True)
            global_y, second_base, _ = response(us, global_h, 8, 0, True)
            cases['global_a8'].append(relative(global_y * first_base * second_base * post, truth))
        entries.append({'image': str(path), 'image_sha256': sha(path), 'fixture_sha256': sha(fixture), 'projection': key, 'layer': layer, 'n': n, 'k': k, 'rank': rank, 'cases': cases})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    receipt = {'source_sha256': sha(Path(__file__)), 'contract': 'Frozen .55 Qwen binary factor images and first four inspected validation input rows per image; both factor boundaries dynamically signed A5/A6/A7 with local maxima. Shifted scales use global max divided by 2^min(floor(log2(global max/group max)),cap), cap 4/8/12; integer group shift/reduce and one float scale per output; optional 3/4 step with integer multiply-by-three; independent floating group-32 baseline; original factor FP64 denominator. No GPU or model loss.', 'entries': entries}
    OUT.write_text(json.dumps(receipt, indent=2) + '\n')
    for projection in sorted({e['projection'] for e in entries}):
        group = [e for e in entries if e['projection'] == projection]
        print(projection, {key: round(float(np.mean([v['rms'] if isinstance(v, dict) else v for e in group for v in e['cases'][key]])), 6) for key in group[0]['cases']})
    print(OUT)


if __name__ == '__main__':
    main()
