#!/usr/bin/env python3
"""Event partition and certified-Lipschitz bounds for a dynamic-max RoPE query."""
import hashlib
import json
import math
from pathlib import Path

import numpy as np

TAU = 2 * math.pi


def roots(a, b, target):
    radius = math.hypot(a, b)
    if radius == 0 or abs(target) > radius:
        return []
    offset = math.atan2(b, a)
    delta = math.acos(max(-1., min(1., target / radius)))
    return [(offset + delta) % TAU, (offset - delta) % TAU]


def rotated(x, p):
    c, s = math.cos(p), math.sin(p)
    return np.array([c*x[0]-s*x[1], s*x[0]+c*x[1]])


def codes(v, cap):
    maximum = float(np.max(np.abs(v)))
    if maximum == 0:
        return np.zeros(len(v), dtype=np.int16), 0.
    return np.clip(np.floor(cap*v/maximum + .5), -cap, cap).astype(np.int16), maximum / cap


def query_events(q, cap):
    """Superset of all max-branch and rounded-code transitions on [0,2pi)."""
    x, y = q[:2]
    radius = math.hypot(x, y)
    fixed_max = float(np.max(np.abs(q[2:]))) if len(q) > 2 else 0.
    if radius == 0:
        return []
    u = (x, -y)
    v = (y, x)
    angles = []
    for a, b in (u, v):
        for level in (-fixed_max, fixed_max):
            angles.extend(roots(a, b, level))
    for sign in (-1, 1):
        angles.extend(roots(u[0]-sign*v[0], u[1]-sign*v[1], 0))
    for m in range(-cap, cap):
        t = m + .5
        for a, b in (u, v):
            angles.extend(roots(a, b, t*fixed_max/cap))
        for numerator, denominator in ((u, v), (v, u)):
            for sign in (-1, 1):
                angles.extend(roots(numerator[0]-sign*t*denominator[0]/cap,
                                    numerator[1]-sign*t*denominator[1]/cap, 0))
        for fixed in q[2:]:
            if fixed == 0:
                continue
            level = cap*float(fixed)/t
            if level < fixed_max or level > radius:
                continue
            for a, b in (u, v):
                angles.extend(roots(a, b, level))
                angles.extend(roots(a, b, -level))
    return [p for p in angles if p > 0 and p < TAU]


def key_events(keys, step, cap=7):
    angles = []
    for x, y in keys:
        for m in range(-cap, cap):
            t = step*(m+.5)
            angles.extend(roots(x, -y, t))
            angles.extend(roots(y, x, t))
    return [p for p in angles if p > 0 and p < TAU]


def rounded(v, step, cap=7):
    return np.clip(np.floor(v / step + .5), -cap, cap).astype(np.int16)


def causal_loss(keys, queries, other, phase, key_step, cap):
    rotated_keys = keys.copy()
    rotated_keys[:, :2] = [rotated(k[:2], phase) for k in keys]
    kc = rounded(rotated_keys, key_step)
    total = 0.
    for h in range(2):
        for t in range(len(keys)):
            q = queries[h, t].copy()
            q[:2] = rotated(q[:2], phase)
            qc, step = codes(q, cap)
            approximate = other[h, t, :t+1] + key_step*step * (kc[:t+1].astype(np.int64) @ qc.astype(np.int64))
            teacher = other[h, t, :t+1] + keys[:t+1] @ queries[h, t]
            a = approximate - np.max(approximate)
            b = teacher - np.max(teacher)
            p = np.exp(b); p /= p.sum()
            logz = math.log(np.exp(a).sum())
            total += float(logz - np.dot(p, a) + np.dot(p, np.log(p)))
    return total/(2*len(keys))


def fixed_step_loss(keys, queries, other, phase, key_step, query_step, cap):
    rk = keys.copy()
    rk[:, :2] = [rotated(k[:2], phase) for k in keys]
    kc = rounded(rk, key_step)
    total = 0.
    for h in range(2):
        for t in range(len(keys)):
            q = queries[h, t].copy()
            q[:2] = rotated(q[:2], phase)
            qc = rounded(q, query_step, cap)
            approximate = other[h, t, :t+1] + key_step*query_step*(kc[:t+1].astype(np.int64) @ qc.astype(np.int64))
            teacher = other[h, t, :t+1] + keys[:t+1] @ queries[h, t]
            a = approximate - approximate.max()
            b = teacher - teacher.max()
            p = np.exp(b); p /= p.sum()
            total += float(math.log(np.exp(a).sum()) - np.dot(p, a) + np.dot(p, np.log(p)))
    return total/(2*len(keys))


def bound(keys, queries, phase, key_step, cap):
    """Valid local Lipschitz bound for the loss when all code labels are fixed."""
    rotated_keys = keys.copy()
    rotated_keys[:, :2] = [rotated(k[:2], phase) for k in keys]
    kc = rounded(rotated_keys, key_step)
    total = 0.
    for h in range(2):
        for t in range(len(keys)):
            q = queries[h, t].copy()
            q[:2] = rotated(q[:2], phase)
            qc, _ = codes(q, cap)
            z = kc[:t+1].astype(np.int64) @ qc.astype(np.int64)
            total += key_step * math.hypot(*queries[h, t, :2]) * (int(z.max())-int(z.min())) / cap
    return total/(2*len(keys))


def main():
    rng = np.random.default_rng(7429)
    n = 5
    cap = 119
    keys = rng.normal(size=(n, 8)) * .22
    keys[:, :2] = rng.normal(size=(n, 2)) * [.6, .42] + [.43, .30]
    queries = rng.normal(size=(2, n, 8)) * .22
    queries[..., :2] = rng.normal(size=(2, n, 2)) * [.48, .36] + [.55, .32]
    other = rng.normal(size=(2, n, n))*.35
    key_step = .75
    kcuts = key_events(keys[:, :2], key_step)
    qcuts = sum((query_events(q, cap) for q in queries.reshape(-1, 8)), [])
    cuts = sorted(set([0., TAU] + kcuts + qcuts))
    mids = [(lo+hi)/2 for lo, hi in zip(cuts, cuts[1:])]
    losses = [causal_loss(keys, queries, other, p, key_step, cap) for p in mids]
    best_index = int(np.argmin(losses))
    lo, hi = cuts[best_index:best_index+2]
    # Sample one side of each event as well. Bound is only applied inside an open cell.
    candidates = [(value, p) for value, p in zip(losses, mids)]
    candidates += [(causal_loss(keys, queries, other, p, key_step, cap), p) for p in cuts]
    best = min(candidates)
    static_step = .02
    static_cuts = sorted(set([0., TAU] + kcuts + sum((key_events(q[None, :2], static_step, cap) for q in queries.reshape(-1, 8)), [])))
    static_phases = [(left+right)/2 for left, right in zip(static_cuts, static_cuts[1:])] + static_cuts
    static_best = min((fixed_step_loss(keys, queries, other, p, key_step, static_step, cap), p) for p in static_phases)
    lower = min(value-bound(keys, queries, p, key_step, cap)*(right-left)/2
                for value, p, left, right in zip(losses, mids, cuts, cuts[1:]))
    # Demonstrate why midpoint enumeration is not an exact search when a query max moves.
    quarter = lo + (hi-lo)/4
    quarter_loss = causal_loss(keys, queries, other, quarter, key_step, cap)
    def image(p):
        rk = keys.copy()
        rk[:, :2] = [rotated(k[:2], p) for k in keys]
        rq = queries.copy()
        rq[..., :2] = np.array([rotated(q[:2], p) for q in queries.reshape(-1, 8)]).reshape(2, n, 2)
        return rounded(rk, key_step), np.array([codes(q, cap)[0] for q in rq.reshape(-1, 8)])
    assert all(np.array_equal(a, b) for a, b in zip(image(quarter), image(mids[best_index])))
    assert lower <= best[0] + 1e-12
    result = dict(seed=7429, cap=cap, key_step=key_step, keys=keys.tolist(),
                  queries=queries.tolist(), other=other.tolist(),
                  source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  key_events=len(kcuts), query_events=len(qcuts), cells=len(mids),
                  zero_loss=causal_loss(keys, queries, other, 0., key_step, cap),
                  best_sample_loss=best[0], best_sample_phase=best[1],
                  fixed_step_best_phase=static_best[1], fixed_step_best_loss=static_best[0],
                  dynamic_loss_at_fixed_step_phase=causal_loss(keys, queries, other, static_best[1], key_step, cap),
                  best_mid_cell=[lo, hi], best_mid_loss=losses[best_index],
                  quarter_loss=quarter_loss, global_lipschitz_lower=lower,
                  max_cell_width=max(np.diff(cuts)),
                  query_codes_best=codes(np.r_[rotated(queries[0, -1, :2], best[1]), queries[0, -1, 2:]], cap)[0].tolist(),
                  key_codes_best=rounded(np.column_stack((np.array([rotated(k[:2], best[1]) for k in keys]), keys[:, 2:])), key_step).tolist())
    Path(__file__).with_name('receipt.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ('keys', 'queries', 'other', 'query_codes_best', 'key_codes_best')}, indent=2))


if __name__ == '__main__':
    main()
