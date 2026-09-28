"""Finite two-key attention toy: producer reachability and shared exact observations."""

from __future__ import annotations

import itertools
import json
import math
from collections import defaultdict
from pathlib import Path

X = list(itertools.product((-1, 0, 1), repeat=3))
TEACHER = ((2, 1, 2), (1, 2, 2))
STATES = tuple(itertools.product((-1, 0, 1), repeat=6))


def rows(codes):
    return codes[:3], codes[3:]


def producer(weights, x):
    return tuple(sum(a * b for a, b in zip(row, x)) for row in weights)


def sigmoid(t):
    return 1 / (1 + math.exp(-t))


def continuation(d, h):
    first = sigmoid(d)
    h1 = h + first
    query = 1 + (h1 > 0.5)
    second = sigmoid(query * d)
    return (first, h1 + second, query)


def weight(x):
    a, b, _ = x
    # 60% of the calibration mass has correlated producer coordinates.
    return 0.6 * (a == b) / 9 + 0.4 / 27


def coefficient_fit(codes):
    flat = sum((tuple(row) for row in TEACHER), ())
    dot = sum(a * b for a, b in zip(flat, codes))
    norm = sum(c * c for c in codes)
    scale = max(0.0, dot / norm) if norm else 0.0
    loss = sum((a - scale * c) ** 2 for a, c in zip(flat, codes))
    return (loss, scale)


def score(codes, scale):
    w = rows(codes)
    weighted_first = weighted_final = weighted_query = weighted_teacher_linear = 0.0
    exact = 0
    collisions = defaultdict(set)
    for x in X:
        a, b = producer(TEACHER, x)
        u, v = producer(w, x)
        p, end, query = continuation(a - b, x[2])
        pc, endc, queryc = continuation(scale * (u - v), x[2])
        mass = weight(x)
        weighted_first += mass * abs(p - pc)
        weighted_final += mass * abs(end - endc)
        weighted_query += mass * (query != queryc)
        weighted_teacher_linear += mass * ((a - scale * u) ** 2 + (b - scale * v) ** 2)
        exact += abs(p - pc) < 1e-12 and abs(end - endc) < 1e-12
        collisions[(u, v)].add((a - b, x[2]))
    witness = None
    for x, y in itertools.combinations(X, 2):
        if producer(w, x) == producer(w, y) and x[2] == y[2] and x[0] - x[1] != y[0] - y[1]:
            witness = (x, y)
            break
    return {
        "scale": scale,
        "codes": [list(r) for r in w],
        "coefficient_squared_error": sum((a - scale * b) ** 2 for a, b in zip(sum(TEACHER, ()), codes)),
        "calibration_linear_squared_error": weighted_teacher_linear,
        "first_attention_weighted_mae": weighted_first,
        "final_residual_weighted_mae": weighted_final,
        "changed_query_probability": weighted_query,
        "exact_inputs_out_of_27": exact,
        "quantized_producer_image_size": len(collisions),
        "uncorrectable_collision": witness,
    }


def main():
    # The scale of the coefficient oracle is optimized over the entire real line.
    fitted = min(STATES, key=lambda codes: (coefficient_fit(codes)[0], codes))
    fit_loss, fit_scale = coefficient_fit(fitted)
    assert fit_loss == 4 / 3
    # Exact difference requires shared scale 1 or 1/2: its x0 coefficient is 1
    # and the difference of two trits has magnitude at most 2. Search both.
    exact_codes = ((sum((a - s * b) ** 2 for a, b in zip(sum(TEACHER, ()), codes)), s, codes)
                    for s in (0.5, 1.0) for codes in STATES
                    if all(producer(TEACHER, x)[0] - producer(TEACHER, x)[1] ==
                           s * (producer(rows(codes), x)[0] - producer(rows(codes), x)[1]) for x in X))
    exact_loss, exact_scale, joint = min(exact_codes)
    assert exact_loss == 6 and exact_scale == 1
    independent = (1, 0, 1, 0, 1, 1)  # Scale two; round halves toward zero.
    observations = defaultdict(list)
    for x in X:
        observations[(x[0] - x[1], x[2])].append(x)
    assert len(observations) == 15
    # Both normalized attention outputs and the post-attention residual are
    # functions of (d,h). Each distinct (d,h) has a distinct (p1,h1).
    assert len({(continuation(d,h)[0], h+continuation(d,h)[0]) for d,h in observations}) == 15
    weights_sum = sum(weight(x) for x in X)
    assert abs(weights_sum - 1) < 1e-12
    ordinary = score(independent, 2)
    corrected = score(independent, 1)
    corrected.update(scale=2, effective_query_multiplier=0.5,
                     coefficient_squared_error=ordinary["coefficient_squared_error"],
                     calibration_linear_squared_error=ordinary["calibration_linear_squared_error"])
    result = {
        "domain": "27 triples in {-1,0,1}^3; 60% correlated x0=x1, 40% uniform",
        "teacher_weights": TEACHER,
        "teacher_image_size": len({producer(TEACHER,x) for x in X}),
        "shared_quotient": "(d=x0-x1,h=x2)",
        "shared_quotient_states": len(observations),
        "coefficient_oracle": score(fitted, fit_scale),
        "ordinary_scale_two_rounding": ordinary,
        "rounding_with_half_temperature_query": corrected,
        "minimum_distortion_exact_attention": score(joint, exact_scale),
        "broken_extension": {
            "same_quotient_inputs": [[0,0,0],[1,1,0]],
            "teacher_common_logit_sum": [0,6],
            "meaning": "a residual branch that consumes the logit sum cannot use the 15-state quotient",
        },
        "storage": "all three candidates have six ternary codes and one shared scale; residual x2 is already live",
    }
    path = Path(__file__).with_name("results.json")
    path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
