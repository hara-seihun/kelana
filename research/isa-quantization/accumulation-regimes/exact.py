#!/usr/bin/env python3
"""Exact finite-domain ternary projection and shared-scale search."""
from fractions import Fraction as Q
from itertools import product
import json
import struct

INPUTS = list(product((-1, 0, 1), repeat=4))
TEACHERS = {
    "two_exact_blocks": (Q(-1), Q(1), Q(-2), Q(2)),
    "perturbed": (Q(-1), Q(5, 4), Q(-7, 4), Q(9, 4)),
}


def dot(a, x):
    return sum((u * v for u, v in zip(a, x)), Q(0))


def metrics(target, weights):
    errors = [dot(target, x) - dot(weights, x) for x in INPUTS]
    return max(map(abs, errors)), sum((e * e for e in errors), Q(0)) / len(errors)


def candidates(target):
    # On each interval between switches s=2|w_i|, nearest ternary codes
    # are fixed; the MSE-minimizing step is the mean active magnitude.
    switches = sorted(set([Q(0)] + [2 * abs(w) for w in target]))
    steps = set([Q(0)] + [abs(w) for w in target] + switches)
    for lo, hi in zip(switches, switches[1:] + [None]):
        probe = (lo + hi) / 2 if hi is not None else lo + 1
        active = [abs(w) for w in target if 2 * abs(w) > probe]
        if active:
            mean = sum(active, Q(0)) / len(active)
            if mean >= lo and (hi is None or mean <= hi):
                steps.add(mean)
    return sorted(steps)


def fit(target, groups):
    # A separate optimally fitted nonnegative step for each declared group.
    steps = [candidates(tuple(target[i] for i in group)) for group in groups]
    best = None
    for selected in product(*steps):
        weights = tuple(min((-s, Q(0), s), key=lambda v: (abs(v - target[i]), v))
                        for group, s in zip(groups, selected) for i in group)
        robust, mse = metrics(target, weights)
        key = (mse, robust, selected, weights)
        if best is None or key < best[0]:
            best = (key, (selected, weights, robust, mse))
    return best[1]


def nearby_half_steps(optimum):
    bits = struct.unpack('<H', struct.pack('<e', float(optimum)))[0]
    return (Q(struct.unpack('<e', struct.pack('<H', b))[0])
            for b in range(max(0, bits - 1), min(0x7bff, bits + 1) + 1))


def fit_codebook(target, codebook):
    # Strong same-width controls: exhaustive assignments, optimal FP16 step.
    best = None
    for codes in product(codebook, repeat=len(target)):
        norm = sum(c * c for c in codes)
        optimum = max(Q(0), sum((w * c for w, c in zip(target, codes)), Q(0)) / norm) if norm else Q(0)
        for step in nearby_half_steps(optimum):
            weights = tuple(step * c for c in codes)
            robust, mse = metrics(target, weights)
            key = (mse, robust, step, codes)
            if best is None or key < best[0]:
                best = (key, (step, codes, robust, mse))
    return best[1]


def ratio(x):
    return str(x)


def main():
    results = {}
    for name, target in TEACHERS.items():
        results[name] = {}
        for label, groups in (("block_scales", ((0, 1), (2, 3))),
                              ("one_scale", ((0, 1, 2, 3),))):
            scales, weights, robust, mse = fit(target, groups)
            assert all(Q(struct.unpack('<e', struct.pack('<e', float(s)))[0]) == s for s in scales)
            results[name][label] = dict(scales=list(map(ratio, scales)),
                                        weights=list(map(ratio, weights)),
                                        max_error=ratio(robust), mse=ratio(mse),
                                        # 2-bit trits, packed into one byte;
                                        # FP16 scale fields counted as 2 bytes each.
                                        static_bytes=1 + 2 * len(groups))
        for label, alphabet in (("signed_2bit", (-2, -1, 0, 1)),
                                ("offset_2bit", (-1, 0, 1, 2)),
                                ("sign_magnitude_2bit", (-2, -1, 1, 2))):
            step, codes, robust, mse = fit_codebook(target, alphabet)
            results[name][label] = dict(scale=ratio(step), codes=codes,
                                        max_error=ratio(robust), mse=ratio(mse),
                                        static_bytes=3)
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
