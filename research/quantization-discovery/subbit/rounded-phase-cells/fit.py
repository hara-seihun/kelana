#!/usr/bin/env python3
"""Finite exact cell fit for a shared RoPE phase with rounded key AND query labels."""
import hashlib
import json
import math
from pathlib import Path

import numpy as np

PERIOD = 2*math.pi
QUARTER = math.pi/2


def rotate(x, phase):
    c, s = math.cos(phase), math.sin(phase)
    return np.stack((c*x[..., 0]-s*x[..., 1], s*x[..., 0]+c*x[..., 1]), axis=-1)


def label(x, phase, step, cap=7):
    return np.clip(np.floor(rotate(x, phase)/step + .5), -cap, cap).astype(np.int16)


def transitions(vectors, step, cap=7):
    angles = []
    for x, y in vectors.reshape(-1, 2):
        radius = math.hypot(x, y)
        if radius == 0:
            continue
        offset = math.atan2(y, x)
        for m in range(-cap, cap):
            ratio = step*(m+.5)/radius
            if abs(ratio) >= 1:
                continue
            a = math.acos(ratio)
            angles.extend(((-offset+a) % (2*math.pi), (-offset-a) % (2*math.pi),
                           (QUARTER-offset+a) % PERIOD,
                           (QUARTER-offset-a) % PERIOD))
    return [p for p in angles if 0 < p < PERIOD]


def loss(keys, queries, phase, key_step, query_step, other=None):
    """Sum of two-head causal KLs; all other planes may enter as fixed scores."""
    n = len(keys)
    if other is None:
        other = np.zeros((2, n, n))
    k = label(keys, phase, key_step)
    q = label(queries, phase, query_step)
    approximate = other + key_step*query_step*np.einsum('htd,kd->htk', q.astype(np.int64), k.astype(np.int64))
    teacher = other + np.einsum('htd,kd->htk', queries, keys)
    total = 0.
    for h in range(2):
        for t in range(n):
            a, b = approximate[h, t, :t+1], teacher[h, t, :t+1]
            ap = np.exp(a-a.max()); ap /= ap.sum()
            bp = np.exp(b-b.max()); bp /= bp.sum()
            total += float(np.dot(bp, np.log(bp)-np.log(ap)))
    return total/(2*n)


def fit(keys, queries, key_step, query_step, other=None):
    cuts = sorted(set([0., PERIOD] + transitions(keys, key_step)
                      + transitions(queries, query_step)))
    interiors = [(loss(keys, queries, (lo+hi)/2, key_step, query_step, other),
                  (lo+hi)/2, lo, hi) for lo, hi in zip(cuts, cuts[1:]) if hi > lo]
    endpoints = [(loss(keys, queries, p, key_step, query_step, other), p, p, p)
                 for p in cuts]
    return min(interiors + endpoints), len(interiors), len(transitions(keys, key_step)), len(transitions(queries, query_step))


def main():
    rng = np.random.default_rng(7421)
    n = 12
    keys = rng.normal(size=(n, 2))*[.60, .42]+[.43, .30]
    queries = rng.normal(size=(2, n, 2))*[.42, .3]+[1., .85]
    other = rng.normal(size=(2, n, n))*.35
    key_step, query_step = .75, .34
    optimum, cells, k_events, q_events = fit(keys, queries, key_step, query_step, other)
    zero = loss(keys, queries, 0., key_step, query_step, other)
    grid = min((loss(keys, queries, p, key_step, query_step, other), p)
               for p in np.linspace(0, PERIOD, 4096, endpoint=False))
    assert optimum[0] <= min(zero, grid[0]) + 1e-12
    assert optimum[2] <= optimum[1] <= optimum[3]
    result = dict(source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  seed=7421, keys=keys.tolist(), queries=queries.tolist(),
                  fixed_other_scores=other.tolist(), key_step=key_step, query_step=query_step,
                  baseline_kl=zero, best_kl=optimum[0], best_phase=optimum[1],
                  best_cell=list(optimum[2:]), cells=cells, key_events=k_events,
                  query_events=q_events,
                  right_neighbor_kl=loss(keys, queries, optimum[1]+1e-7, key_step, query_step, other),
                  left_neighbor_kl=loss(keys, queries, optimum[1]-1e-7, key_step, query_step, other),
                  grid_4096_kl=grid[0], grid_4096_phase=grid[1],
                  key_codes_zero=label(keys, 0., key_step).tolist(),
                  key_codes_best=label(keys, optimum[1], key_step).tolist())
    Path(__file__).with_name('receipt.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('keys','queries','fixed_other_scores','key_codes_zero','key_codes_best')}, indent=2))


if __name__ == '__main__':
    main()
