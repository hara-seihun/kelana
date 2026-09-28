#!/usr/bin/env python3
"""Exact rational full-box response comparison of executable weight alphabets."""

from fractions import Fraction as Q
from itertools import combinations
from random import Random
import json
import struct


def loss(weights, values):
    return sum((abs(w - v) for w, v in zip(weights, values)), Q(0))


def nearest(weights, alphabet):
    return tuple(min(alphabet, key=lambda v: (abs(w - v), abs(v), v)) for w in weights)


def ladder(weights):
    candidates = []
    for exponent in range(-14, 14):
        base = Q(2) ** exponent
        alphabet = (Q(0),) + tuple(sign * base * (2 ** j) for j in range(3) for sign in (1, -1))
        fitted = nearest(weights, alphabet)
        candidates.append((loss(weights, fitted), exponent, fitted))
    return min(candidates)


def symmetric(weights, amplitude=3):
    # Exact global optimum, even allowing any rational scale rather than FP16.
    # For each fixed code assignment the absolute-error sum is piecewise
    # affine, minimized at zero-error lines s=abs(w_i/k_i) or at s=0.
    # Taking the minimum over assignments preserves this candidate set.
    scales = {Q(0)} | {abs(w) / k for w in weights for k in range(1, amplitude + 1)}
    candidates = []
    for scale in scales:
        alphabet = tuple(k * scale for k in range(-amplitude, amplitude + 1))
        fitted = nearest(weights, alphabet)
        candidates.append((loss(weights, fitted), scale, fitted))
    return min(candidates)


def affine(weights):
    # Stronger than an FP16 affine grid: both offset and step are arbitrary
    # rationals. For each fixed code assignment, absolute errors sum to
    # a convex piecewise affine function. An optimum has a representative
    # at two intersecting zero-error lines a+s*q=w_i or at s=0.
    # Minimizing over codes at those vertices gives the global optimum.
    lines = [(w, Q(q)) for w in weights for q in range(8)]
    parameters = {(w, Q(0)) for w in weights}
    for (w0, t0), (w1, t1) in combinations(lines, 2):
        if t0 == t1:
            continue
        step = (w0 - w1) / (t0 - t1)
        if step >= 0:
            parameters.add((w0 - step * t0, step))
    candidates = []
    for offset, step in parameters:
        fitted = nearest(weights, tuple(offset + q * step for q in range(8)))
        candidates.append((loss(weights, fitted), offset, step, fitted))
    return min(candidates)


def as_json(result):
    return [str(item) if not isinstance(item, tuple) else [str(v) for v in item] for item in result]


def check_operand_bits():
    for exponent in range(-14, 14):
        hi = lambda j, sign: ((exponent + 15 + j) << 2) | (sign << 7)
        table = (0, hi(0, 0), hi(1, 0), hi(2, 0),
                 hi(0, 1), hi(1, 1), hi(2, 1), 0)
        for code, byte in enumerate(table):
            operand = struct.unpack(">e", struct.pack(">H", byte << 8))[0]
            expected = (0, 2**exponent, 2**(exponent + 1), 2**(exponent + 2),
                        -(2**exponent), -(2**(exponent + 1)), -(2**(exponent + 2)), 0)[code]
            assert Q(operand) == Q(expected)


def main():
    check_operand_bits()
    examples = {
        "six_rungs": (Q(-4), Q(-2), Q(-1), Q(1), Q(2), Q(4)),
        "uniform_friendly": (Q(-3), Q(-2), Q(-1), Q(1), Q(2), Q(3)),
    }
    rng = Random(20260924)
    for i in range(48):
        examples[f"unstructured_{i:02d}"] = tuple(Q(rng.choice(tuple(range(-8, 0)) + tuple(range(1, 9))), 2) for _ in range(6))
    results = {}
    for label, weights in examples.items():
        results[label] = {
            "weights": [str(w) for w in weights],
            "ladder": as_json(ladder(weights)),
            "symmetric_3bit": as_json(symmetric(weights)),
            "affine_3bit": as_json(affine(weights)),
            "ternary": as_json(symmetric(weights, 1)),
        }
    random_results = [results[f"unstructured_{i:02d}"] for i in range(48)]
    summary = {}
    for competitor in ("symmetric_3bit", "affine_3bit", "ternary"):
        wins = sum(Q(r["ladder"][0]) < Q(r[competitor][0]) for r in random_results)
        ties = sum(Q(r["ladder"][0]) == Q(r[competitor][0]) for r in random_results)
        summary[competitor] = {"ladder_wins": wins, "ties": ties, "ladder_losses": 48 - wins - ties}
    print(json.dumps({"contract": "max over x in [-1,1]^6 of absolute linear response error", "examples": results, "random_summary": summary}, indent=2))


if __name__ == "__main__":
    main()
