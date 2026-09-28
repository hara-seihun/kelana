#!/usr/bin/env python3
"""Exact rational-log certificates for causal state-capacity theorems."""

import json
from fractions import Fraction as F
from pathlib import Path

A = (F(1, 2), F(1, 2))
B = (F(1, 4), F(3, 4))


def log_interval(x, terms=24):
    z = (x - 1) / (x + 1)
    center = 2 * sum((z ** (2*k + 1) / (2*k + 1) for k in range(terms)), F(0))
    tail = 2 * abs(z) ** (2*terms + 1) / ((2*terms + 1) * (1 - z*z))
    return center - tail, center + tail


def js(u, v, p, r):
    if not u or not v:
        return (F(0), F(0)), p
    centroid = tuple((u*x+v*y)/(u+v) for x, y in zip(p, r))
    interval = tuple(sum((weight*prob*log_interval(prob/centroid[a])[side]
                          for weight, law in ((u, p), (v, r))
                          for a, prob in enumerate(law)), F(0))
                     for side in (0, 1))
    return interval, centroid


def printed(interval):
    return [float(x) for x in interval]


def main():
    alpha = A[0]
    c2_single, _ = js(alpha, alpha**2, A, B)
    c2_multi = tuple(2*x for x in c2_single)
    c1_exact, _ = js(F(1), F(1), A, B)
    clock_upper = c1_exact
    assert c2_multi[0] > c2_single[1] > 0
    assert c2_multi[1] < clock_upper[0]
    histories = ('', '0', '1')
    suffix = '0'
    after = ('0', '00', '10')
    weights = (F(1,2), F(1,8), F(1,4))
    laws = ((F(1,4), F(3,4)), (F(1,2), F(1,2)), (F(3,4), F(1,4)))
    pairs = []
    exact_pairs = []
    for i in range(3):
        for j in range(i+1, 3):
            loss, center = js(weights[i], weights[j], laws[i], laws[j])
            exact_pairs.append((loss, i, j))
            pairs.append({"prefixes": [histories[i], histories[j]],
                          "after_suffix": [after[i], after[j]],
                          "weights": [str(weights[i]), str(weights[j])],
                          "KL_interval": printed(loss),
                          "centroid_probability_one": str(center[1])})
    winner = min(exact_pairs, key=lambda item: item[0][1])
    assert winner[0][1] < min(pair[0][0] for pair in exact_pairs if pair != winner)
    minimum = float(winner[0][0])
    assert all(pair[0][0] > 0 for pair in exact_pairs)
    result = {"contract": {
        "teacher": "A for C phases, then B on final phase; deterministic time-driven teacher; horizon C+1",
        "A": [str(x) for x in A], "B": [str(x) for x in B],
        "candidate": "any deterministic C-state token-driven machine with stationary state-only emissions",
        "C": "symbolic integer >= 1; no finite C enumeration",
        "multi_ray_bound": "sum_{a:A(a)>0} J(A(a)^max(1,C-1), A(a)^C; A,B)",
        "J": "inf_q u KL(A||q)+v KL(B||q), centroid q=(u A+v B)/(u+v)"},
        "binary_symmetric_witness": {
            "C_one_exact_interval": printed(c1_exact),
            "C_two_single_ray_interval": printed(c2_single),
            "C_two_all_rays_interval": printed(c2_multi),
            "symbolic_C_at_least_two": "2^(2-C) J(1,1/2;A,B)",
            "C_two_clock_feasible_upper_interval": printed(clock_upper)},
        "branching_suffix_certificate": {
            "histories": list(histories), "common_suffix": suffix,
            "teacher_emission_laws_after_suffix": [[str(x) for x in row] for row in laws],
            "pair_certificates": pairs, "strict_minimizing_pair": [histories[winner[1]], histories[winner[2]]],
            "two_state_universal_KL_lower": minimum,
            "required_horizon": 3},
        "arithmetic": "24 atanh-series terms per logarithm with rational geometric tail; decimals are display only"}
    Path(__file__).with_name('results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({"C_two_all_rays": printed(c2_multi),
                      "branching_two_state_lower": minimum}, indent=2))


if __name__ == '__main__':
    main()
