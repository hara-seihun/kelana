#!/usr/bin/env python3
"""Exact sparse code witnesses for the trained 27-state FFN perturbation cubes."""
import os
os.environ.setdefault('OPENBLAS_NUM_THREADS', '4')
os.environ.setdefault('OMP_NUM_THREADS', '4')
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
JOINT = HERE.parents[1] / 'discovery' / 'joint-observer'
sys.path.insert(0, str(JOINT))
import trained


def distinct_masks(codes):
    """One bit per unordered input pair; equal masks are interchangeable features."""
    pairs = [(i, j) for i in range(len(codes)) for j in range(i)]
    masks = {}
    for col in range(codes.shape[1]):
        mask = sum(1 << p for p, (i, j) in enumerate(pairs) if codes[i, col] != codes[j, col])
        if mask:
            masks.setdefault(mask, col)
    return pairs, masks


def certificate(codes):
    pairs, masks = distinct_masks(codes)
    universe = (1 << len(pairs)) - 1
    if not masks:
        return {'separable': False, 'collision': [list(p) for p in pairs[:1]]}
    candidates = sorted(masks, key=lambda m: (-m.bit_count(), masks[m]))
    uncovered = universe
    chosen = []
    while uncovered:
        m = max(candidates, key=lambda a: (a & uncovered).bit_count())
        if not (m & uncovered):
            p = next(k for k in range(len(pairs)) if uncovered >> k & 1)
            return {'separable': False, 'collision': list(pairs[p])}
        chosen.append(m)
        uncovered &= ~m
    lower = 1 if universe in masks else 2
    if len(chosen) > 2:
        # All one- and two-coordinate programs are exhausted by the complete
        # set of distinct pair-separation masks. Superset testing is exact.
        two = next(((a, b) for a in candidates for b in candidates
                    if (a | b) == universe), None)
        if two is not None:
            chosen = list(two)
        else:
            lower = 3
    covered = 0
    for m in chosen:
        covered |= m
    assert covered == universe
    columns = [masks[m] for m in chosen]
    assert len({tuple(row) for row in codes[:, columns]}) == len(codes)
    result = {'separable': True, 'lower_bound': lower, 'upper_bound': len(chosen),
              'coordinates': columns, 'values': codes[:, columns].astype(int).tolist(),
              'candidate_distinct_masks': len(masks), 'pair_count': len(pairs),
              'checked_coverage_hex': hex(covered),
              'proof': 'exhaustive distinct one-coordinate masks; two-coordinate unions if needed'}
    if lower == len(chosen):
        result['minimum'] = lower
    return result


def run(layer, anchor):
    path = trained.DATA / f'layer{layer:02d}'
    chunk, row = divmod(anchor, 8)
    x = np.fromfile(path / f'c{chunk:03d}/x_in.f32', np.float32).reshape(-1, trained.D)[row].astype(np.float64)
    norm = np.fromfile(path / 'post_norm_s.f32', np.float32).astype(np.float64)
    rotated = trained.hadamard_1024(x / np.sqrt(np.mean(x*x) + 1e-6) * norm)
    q, scales = trained.quantize(rotated[None, :], 127)
    base = q[0] * np.repeat(scales[0], 128)
    groups = []
    for coords in trained.COORDINATES:
        cols = np.array(coords)
        steps = np.minimum(32, 127 - np.abs(q[0, cols])).astype(int)
        assert np.all(steps > 0)
        groups.append((cols, steps * scales[0, cols//128]))
    gate = trained.scaled_weights(path / 'gate.halo', trained.FF, trained.D)
    ga = gate @ base
    gd = [gate[:, cols] * amps for cols, amps in groups]
    del gate
    up = trained.scaled_weights(path / 'up.halo', trained.FF, trained.D)
    ua = up @ base
    ud = [up[:, cols] * amps for cols, amps in groups]
    del up
    signs = np.fromfile(path / 'signs_ff.f32', np.float32).astype(np.float64)
    cases = []
    for index, (g_delta, u_delta) in enumerate(zip(gd, ud)):
        g = ga[None, :] + trained.ST @ g_delta.T
        u = ua[None, :] + trained.ST @ u_delta.T
        sig = np.where(g >= 0, 1/(1+np.exp(-np.abs(g))), np.exp(-np.abs(g))/(1+np.exp(-np.abs(g))))
        transformed = trained.hadamard_1024(g * sig * u * signs)
        for levels in (127, 7):
            code, scale = trained.quantize(transformed, levels)
            code = code.astype(np.int16)
            result = certificate(code)
            result.update(group=index, input_coordinates=groups[index][0].tolist(), levels=levels,
                          code_sha256=hashlib.sha256(code.tobytes()).hexdigest(),
                          scale_sha256=hashlib.sha256(scale.tobytes()).hexdigest(),
                          changing_scale_blocks=int(np.count_nonzero(np.any(scale != scale[0], axis=0))),
                          distinct_code_signatures=len({r.tobytes() for r in code}),
                          distinct_scale_signatures=len({r.tobytes() for r in scale}),
                          individually_injective_scale_blocks=[i for i in range(scale.shape[1])
                                                               if len(set(scale[:, i])) == len(scale)],
                          individually_injective_rounded_f32_scale_blocks=[i for i in range(scale.shape[1])
                                                               if len(set(scale[:, i].astype(np.float32))) == len(scale)])
            cases.append(result)
    return {'contract': 'CPU float64 trained.py perturbation cube, 27 fixed-scale input codes; hidden Hadamard quantizer codes, excluding scale from the separating test',
            'layer': layer, 'anchor': anchor, 'dataset_manifest_sha256': trained.sha(path/'manifest.json'),
            'source_sha256': trained.sha(__file__), 'trained_source_sha256': trained.sha(trained.__file__),
            'cases': cases}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 10), required=True)
    parser.add_argument('--anchor', type=int, choices=(0, 127), required=True)
    args = parser.parse_args()
    result = run(args.layer, args.anchor)
    dest = HERE / 'results' / f'layer{args.layer:02d}-anchor{args.anchor:03d}.json'
    dest.parent.mkdir(exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + '\n')
    for r in result['cases']:
        print(args.layer, args.anchor, r['group'], r['levels'], r.get('minimum'), r.get('collision'), r['candidate_distinct_masks'], flush=True)
