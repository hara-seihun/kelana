#!/usr/bin/env python3
"""Exact finite two-lane code search; no external dependencies."""

from itertools import combinations, product
import json
import math
import random

LEVELS = (-2, -1, 0, 1, 2)
N = 5
PERMS = ((0, 1, 2, 3, 4), (4, 3, 2, 1, 0))


def score(target, rows):
    # E_x sum_o ((target_o - rows_o) dot x)^2 for independent uniform trits.
    # Cross terms vanish and E[x_i^2] = 2/3.
    return 2 * sum((a - b) ** 2 for t, r in zip(target, rows)
                   for a, b in zip(t, r))  # numerator, denominator 3


def endpoint_score(target, rows):
    total = 0
    for x in product((-1, 0, 1), repeat=N):
        for t, r in zip(target, rows):
            total += (sum((a - b) * v for a, b, v in zip(t, r, x))) ** 2
    return total * 3 // 3 ** N


def collective(target):
    best = None
    for choice, p in enumerate(PERMS):
        q = tuple(min(LEVELS, key=lambda v: ((target[0][i] - v) ** 2
                                            + (target[1][p[i]] - v) ** 2, v))
                  for i in range(N))
        rows = (q, tuple(q[p[i]] for i in range(N)))
        candidate = (score(target, rows), choice, q, rows)
        if best is None or candidate < best:
            best = candidate
    return best


def scalar(target, levels):
    best = None
    for alphabet in combinations(LEVELS, levels):
        rows = tuple(tuple(min(alphabet, key=lambda v: ((a - v) ** 2, v))
                           for a in row) for row in target)
        candidate = (score(target, rows), alphabet, rows)
        if best is None or candidate < best:
            best = candidate
    return best


def brute_collective(target):
    return min((score(target, (q, tuple(q[p[i]] for i in range(N)))), choice, q)
               for choice, p in enumerate(PERMS)
               for q in product(LEVELS, repeat=N))


def example(name, target):
    joint = collective(target)
    assert joint[:3] == brute_collective(target)
    s3, s4 = scalar(target, 3), scalar(target, 4)
    for numerator, rows in ((joint[0], joint[3]), (s3[0], s3[2]), (s4[0], s4[2])):
        assert numerator == endpoint_score(target, rows)
    return {
        "name": name, "teacher": target,
        "collective": {"error_numerator_over_3": joint[0], "placement": joint[1],
                       "q": joint[2], "rows": joint[3], "payload_bytes": 2},
        "scalar3_oracle": {"error_numerator_over_3": s3[0], "alphabet": s3[1],
                           "rows": s3[2], "payload_bytes": 2},
        "scalar4_oracle": {"error_numerator_over_3": s4[0], "alphabet": s4[1],
                           "rows": s4[2], "payload_bytes": 3},
    }


def main():
    q = LEVELS
    planted = (q, q[::-1])
    perturbed = (q, (2, 1, 1, -1, -2))  # one row-1 coordinate changes 0 -> 1
    rng = random.Random(20260924)
    unstructured = (tuple(rng.choice(LEVELS) for _ in range(N)),
                    tuple(rng.choice(LEVELS) for _ in range(N)))
    result = {
        "contract": "x is uniform over {-1,0,1}^5; squared error sums two outputs; tabulated error is numerator/3",
        "format": "two 5x3-bit code rows compressed into five 3-bit q codes and one placement bit, stored in two bytes",
        "examples": [example("planted reversal", planted),
                     example("one-coordinate perturbation", perturbed),
                     example("seeded unstructured", unstructured)],
        "family": {"collective_states": 2 * 5 ** N - 5 ** 3,
                   "minimum_fixed_bits": math.ceil(math.log2(2 * 5 ** N - 5 ** 3)),
                   "direct_fixed_bits": 3 * N + 1,
                   "independent_five_level_minimum_bits": math.ceil(math.log2(5 ** (2 * N))),
                   "scalar3_fixed_bits": math.ceil(math.log2(3 ** (2 * N))),
                   "scalar4_fixed_bits": 2 * (2 * N)},
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
