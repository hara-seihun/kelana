#!/usr/bin/env python3
"""Finite certificates for two-head radix score fibers on the full nibble cube."""
import json
from pathlib import Path

N = 32
R = 7
LIMIT = 2 * N * R * R


def reachable(a_count, exceptional):
    """Return attainable positive difference scores and a coefficient witness."""
    result = {}
    for b in range(-14, 15):
        for a in range(-14 * a_count, 14 * a_count + 1):
            score = 7 * a + exceptional * b
            if 0 < score <= LIMIT:
                result[score] = (a, b)
    return result


def split_sum(total, count):
    values = []
    for _ in range(count):
        value = max(-14, min(14, total))
        values.append(value)
        total -= value
    assert total == 0
    return values


def witness(radix):
    if radix <= 448:
        keys = [1] * N
        du = split_sum(-radix, N)
        dv = [1] + [0] * (N - 1)
    else:
        exceptional = 5 if radix == 3093 else 6
        a, b = reachable(31, exceptional)[radix]
        keys = [7] * 31 + [exceptional]
        du = split_sum(-a, 31) + [-b]
        if exceptional == 6:
            dv = [1] + [0] * 30 + [-1]
        else:
            dv = [-2] + [0] * 30 + [3]
    assert all(-14 <= x <= 14 for x in du + dv)
    U = sum(x * y for x, y in zip(keys, du))
    V = sum(x * y for x, y in zip(keys, dv))
    assert (U, V) == (-radix, 1)
    return keys, du, dv


def representable_at_threshold():
    # At |U| >= 3099, at most two of the 32 absolute key magnitudes
    # can be less than seven. These are all partitions of that deficit.
    cases = ([7] * 32, [7] * 31 + [6], [7] * 31 + [5],
             [7] * 30 + [6, 6])
    bounds = []
    for keys in cases:
        sums = {0}
        for c in keys:
            sums = {x + c * d for x in sums for d in range(-14, 15)}
        bounds.append({"keys": {str(c): keys.count(c) for c in set(keys)},
                       "score_3099_attainable": 3099 in sums})
    # All-seven scores are multiples of seven. For the other three cases
    # 3099 is not an attainable U difference at all.
    assert all(not entry["score_3099_attainable"] for entry in bounds)
    return bounds


def main():
    six = reachable(31, 6)
    missing = [i for i in range(449, 3099) if i not in six]
    assert missing == [3093]
    five = reachable(31, 5)
    assert 3093 in five
    for B in range(1, 3099):
        witness(B)
    bounds = representable_at_threshold()
    result = {"dimension": N, "code_min": -7, "code_max": 7,
              "first_collision_free_positive_integer_radix": 3099,
              "collision_radices_checked": 3098,
              "one_six_exception_missing_below_threshold": missing,
              "threshold_cases": bounds,
              "boundary_witness": {"radix": 3098, "key_and_difference_sums":
                                   [sum(x * y for x, y in zip(witness(3098)[0], z))
                                    for z in witness(3098)[1:]]},
              "largest_single_score": 1568,
              "balanced_remainder_radix": 3137,
              "max_packed_query_at_3099": 7 * (3099 + 1)}
    path = Path(__file__).with_name("receipt.json")
    path.write_text(json.dumps(result, indent=2) + "\n")
    print(path)


if __name__ == "__main__":
    main()
