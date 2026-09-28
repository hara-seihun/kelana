#!/usr/bin/env python3
"""Exact integer checks for complementary-route contrast coding."""
from fractions import Fraction
from itertools import product
from random import Random


def nearest(value, labels):
    return min(labels, key=lambda label: (abs(value - label), abs(label), label))


def fit_contrast(differences):
    # Three-bit affine code, signed 16-bit origin and positive 16-bit step.
    return min(
        ((sum(abs(d - nearest(d, [a + s * c for c in range(8)])) for d in differences), a, s)
         for s in range(1, 33) for a in range(-128, 129)),
        key=lambda result: result,
    )


def fit_independent(differences, bits):
    # Both independently coded weights have the same affine grid. Optimize the
    # observed differences and fold the unobserved common mode into the bias.
    k = (1 << bits) - 1
    return min(
        ((sum(abs(d - nearest(d, [s * c for c in range(-k, k + 1)])) for d in differences), s)
         for s in range(1, 33)),
        key=lambda result: result,
    )


def max_error_over_cube(errors, bound):
    low = bound * sum(min(0, e) for e in errors)
    high = bound * sum(max(0, e) for e in errors)
    return (high - low + 1) // 2  # optimally recenter an integer bias


def check_endpoint():
    # Four independently selected, complementary two-route integer gates.
    w0 = (101, 98, 103, 96)
    w1 = (99, 102, 97, 104)
    bias = -11
    differences = tuple(a - b for a, b in zip(w0, w1))
    folded_bias = bias + 127 * sum(w1)
    for qs in product(range(4), repeat=4):
        source = bias + sum(a * q + b * (127 - q) for q, a, b in zip(qs, w0, w1))
        folded = folded_bias + sum(d * q for d, q in zip(differences, qs))
        assert source == folded
    assert differences == (2, -4, 6, -8)
    for errors in product(range(-2, 3), repeat=3):
        values = [sum(e * q for e, q in zip(errors, qs))
                  for qs in product(range(4), repeat=3)]
        assert max_error_over_cube(errors, 3) == (max(values) - min(values) + 1) // 2


def check_rounding_tie():
    # Independent ties-to-even rounding does not preserve a sum of 127.
    for numerator in range(1, 255, 2):
        p = Fraction(numerator, 254)
        assert round(127 * p) + round(127 * (1 - p)) in (126, 128)
    p = Fraction(1, 254)
    assert round(127 * p) + round(127 * (1 - p)) == 126


def report(name, differences):
    contrast = fit_contrast(differences)
    independent2 = fit_independent(differences, 2)
    independent4 = fit_independent(differences, 4)
    return {
        "case": name,
        "count": len(differences),
        "contrast_3bit_L1": contrast[0],
        "contrast_origin_step": contrast[1:],
        "independent_2bit_L1": independent2[0],
        "independent_4bit_L1": independent4[0],
        "contrast_3bit_model_bits": 3 * len(differences) + 64,
        "independent_2bit_model_bits": 4 * len(differences) + 48,
        "independent_4bit_model_bits": 8 * len(differences) + 48,
        "contrast_optimal_cube_error": (127 * contrast[0] + 1) // 2,
        "independent_2bit_optimal_cube_error": (127 * independent2[0] + 1) // 2,
        "independent_4bit_optimal_cube_error": (127 * independent4[0] + 1) // 2,
    }


if __name__ == "__main__":
    import json

    check_endpoint()
    check_rounding_tie()
    rng = Random(2409)
    planted = tuple(2 * (i % 7 - 3) for i in range(32))
    unstructured = tuple(rng.randint(-60, 60) for _ in range(32))
    print(json.dumps([report("common-mode paired weights", planted),
                      report("unstructured contrasts", unstructured)], indent=2))
