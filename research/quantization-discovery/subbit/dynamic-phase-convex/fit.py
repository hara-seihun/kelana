#!/usr/bin/env python3
"""Convex lower bounds for the dynamic-max phase cells of the pinned toy map."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
PARENT = HERE.parent / "dynamic-phase-cells"
spec = importlib.util.spec_from_file_location("dynamic_phase", PARENT / "fit.py")
phase = importlib.util.module_from_spec(spec)
spec.loader.exec_module(phase)


def extrema(a, b, lo, hi):
    values = [a * math.cos(p) + b * math.sin(p) for p in (lo, hi)]
    stationary = math.atan2(b, a)
    for k in range(-2, 5):
        p = stationary + k * math.pi
        if lo < p < hi:
            values.append(a * math.cos(p) + b * math.sin(p))
    return min(values), max(values)


def loss_and_derivative(m, base, slope, teacher, entropy):
    logits = base + slope * m
    maximum = np.max(logits)
    exponent = np.exp(logits - maximum)
    weights = exponent / exponent.sum()
    loss = float(maximum + math.log(exponent.sum()) - np.dot(teacher, logits) + entropy)
    derivative = float(np.dot(weights - teacher, slope))
    return loss, derivative


def convex_minimum(low, high, base, slope, teacher, entropy):
    left, dl = loss_and_derivative(low, base, slope, teacher, entropy)
    right, dr = loss_and_derivative(high, base, slope, teacher, entropy)
    if dl >= 0:
        return left
    if dr <= 0:
        return right
    for _ in range(36):
        mid = (low + high) / 2
        if loss_and_derivative(mid, base, slope, teacher, entropy)[1] < 0:
            low = mid
        else:
            high = mid
    return loss_and_derivative((low + high) / 2, base, slope, teacher, entropy)[0]


def main():
    parent = json.loads((PARENT / "receipt.json").read_text())
    keys = np.asarray(parent["keys"])
    queries = np.asarray(parent["queries"])
    other = np.asarray(parent["other"])
    cap = parent["cap"]
    step = parent["key_step"]
    n = len(keys)
    cuts = sorted(set([0., phase.TAU] + phase.key_events(keys[:, :2], step)
                      + sum((phase.query_events(q, cap) for q in queries.reshape(-1, keys.shape[1])), [])))
    teachers = []
    for h in range(2):
        for t in range(n):
            logits = other[h, t, :t+1] + keys[:t+1] @ queries[h, t]
            p = np.exp(logits - logits.max())
            p /= p.sum()
            teachers.append((p, float(np.dot(p, np.log(p)))))
    best = parent["best_sample_loss"]
    lower = math.inf
    candidate_cells = 0
    constant_cells = 0
    best_cell = None
    for lo, hi in zip(cuts, cuts[1:]):
        mid = (lo + hi) / 2
        # The preceding midpoint bound is a valid cheap filter on this same partition.
        midpoint_loss = phase.causal_loss(keys, queries, other, mid, step, cap)
        lipschitz_lower = midpoint_loss - phase.bound(keys, queries, mid, step, cap) * (hi-lo)/2
        if lipschitz_lower >= best:
            continue
        candidate_cells += 1
        rk = keys.copy()
        rk[:, :2] = [phase.rotated(k[:2], mid) for k in keys]
        kc = phase.rounded(rk, step)
        cell_lower = 0.
        all_constant = True
        for h in range(2):
            for t in range(n):
                q = queries[h, t]
                rotated = q.copy()
                rotated[:2] = phase.rotated(q[:2], mid)
                labels, _ = phase.codes(rotated, cap)
                dominant = int(np.argmax(np.abs(rotated)))
                fixed = float(np.max(np.abs(q[2:])))
                if dominant >= 2 or np.hypot(*q[:2]) == 0:
                    minimum = maximum = fixed
                else:
                    all_constant = False
                    a, b = (q[0], -q[1]) if dominant == 0 else (q[1], q[0])
                    sign = 1 if rotated[dominant] >= 0 else -1
                    minimum, maximum = extrema(sign*a, sign*b, lo, hi)
                    minimum = max(minimum, fixed)
                    maximum = max(maximum, fixed)
                slope = (step/cap) * (kc[:t+1].astype(np.int64) @ labels.astype(np.int64))
                teacher, entropy = teachers[h*n+t]
                cell_lower += convex_minimum(minimum, maximum, other[h, t, :t+1], slope, teacher, entropy)
        cell_lower /= 2*n
        if all_constant:
            constant_cells += 1
        if cell_lower < lower:
            lower = cell_lower
            best_cell = [lo, hi]
    assert lower <= best + 1e-9
    result = dict(parent_source_sha256=hashlib.sha256((PARENT / "fit.py").read_bytes()).hexdigest(),
                  parent_receipt_sha256=hashlib.sha256((PARENT / "receipt.json").read_bytes()).hexdigest(),
                  source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  cells=len(cuts)-1, candidate_cells=candidate_cells,
                  constant_max_candidate_cells=constant_cells, convex_lower=lower,
                  lipschitz_lower=parent["global_lipschitz_lower"], sampled_upper=best,
                  tightest_cell=best_cell, convex_gap=best-lower,
                  lipschitz_gap=best-parent["global_lipschitz_lower"])
    (HERE / "receipt.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
