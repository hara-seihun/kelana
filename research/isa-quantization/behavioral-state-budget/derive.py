#!/usr/bin/env python3
"""Emission-state budget DP and noncausal-versus-own-state witness."""

import json
import math
from fractions import Fraction as F
from pathlib import Path

A = F(1, 2)
B = F(3, 4)


def log_interval(value, terms=24):
    z = (value - 1) / (value + 1)
    total = 2 * sum((z ** (2*j+1) / (2*j+1) for j in range(terms)), F(0))
    error = 2 * abs(z) ** (2*terms+1) / ((2*terms+1) * (1-z*z))
    return total-error, total+error


def bernoulli_kl_interval(p, q):
    terms = ((p, p/q), (1-p, (1-p)/(1-q)))
    return tuple(sum(mass * log_interval(ratio)[side] for mass, ratio in terms)
                 for side in (0, 1))


def js_interval(items):
    weight = sum((mass for mass, _ in items), F(0))
    q = sum((mass*p for mass, p in items), F(0))/weight
    return q, tuple(sum((mass*bernoulli_kl_interval(p, q)[side] for mass, p in items), F(0))
                    for side in (0, 1))


def sorted_dp(items, labels):
    """Exact combinatorial DP; each comparison of KL costs uses certified rational intervals."""
    ordered = sorted(items, key=lambda item: item[1])
    n = len(ordered)
    interval = {(i, j): js_interval(ordered[i:j])[1] for i in range(n) for j in range(i+1, n+1)}
    dp = {(0, 0): (F(0), F(0), ())}
    for k in range(1, labels+1):
        for j in range(k, n+1):
            choices = []
            for i in range(k-1, j):
                if (i, k-1) not in dp:
                    continue
                lo, hi, cuts = dp[i, k-1]
                delta_lo, delta_hi = interval[i, j]
                choices.append((lo+delta_lo, hi+delta_hi, cuts + ((i, j),)))
            winner = min(choices, key=lambda candidate: candidate[1])
            dp[j, k] = (min(candidate[0] for candidate in choices), winner[1], winner[2])
    return {"minimum_interval": [float(v) for v in dp[n, labels][:2]],
            "sorted_weight_probability": [[str(x) for x in row] for row in ordered],
            "optimal_intervals_half_open": dp[n, labels][2]}


def main():
    causal_q, causal = js_interval(((F(1,2), A), (F(1,4), B)))
    one_q, one = js_interval(((F(2), A), (F(1), B)))
    default = bernoulli_kl_interval(B, A)
    grid_constant = {str(q): tuple(2*bernoulli_kl_interval(A,q)[side] +
                                    bernoulli_kl_interval(B,q)[side] for side in (0,1))
                     for q in (F(1,4), F(1,2), F(3,4))}
    assert all(default[1] < other[0] for code, other in grid_constant.items() if code != str(A))
    assert one[0] > causal[1] > 0
    assert default[0] > one[1]
    assert one[1] + F(2,100) < causal[0] + F(10,100)
    assert causal[1] + F(10,1000) < one[0] + F(2,1000)
    generic = sorted_dp(((F(1), F(1,4)), (F(1), F(1,2)), (F(1), F(3,4))), 2)
    generic_single = sorted_dp(((F(1), F(1,4)), (F(1), F(1,2)), (F(1), F(3,4))), 1)
    result = {"contract": {"teacher_cycle": [0, 1, 2, 0], "emission_probability_one": [str(A), str(A), str(B)],
                           "initial_teacher_candidate_state": [0, 0], "horizon": 3,
                           "candidate_states": 2, "candidate_transition": "any deterministic token-conditioned two-state table",
                           "candidate_emissions": "arbitrary stationary probabilities for the state budget; paid grid {1/4,1/2,3/4} for cost examples"},
              "source_only": {"teacher_occupancy": [1, 1, 1], "one_label_centroid_probability_one": str(one_q),
                              "one_label_KL_interval": [float(x) for x in one],
                              "two_label_KL_interval": [0, 0]},
              "causal_collision": {"repeated_token": 0, "first_repeat_probability": str(F(1,2)),
                                   "second_repeat_probability": str(F(1,4)),
                                   "forced_center_probability_one_if_second_candidate_state_reused": str(causal_q),
                                   "universal_sequence_KL_lower_interval": [float(x) for x in causal]},
              "paid_grammar": {"transition_default": "self-loop one bit, else four-bit table plus one-bit header",
                               "emission_default": "both probabilities 1/2 one bit, else two two-bit codes plus one-bit header",
                               "total_bits": [2, 6, 10],
                               "grid_constant_KL_intervals": {code: [float(x) for x in value]
                                                               for code, value in grid_constant.items()},
                               "below_ten_bits_exact_best_KL_interval": [float(x) for x in default],
                               "ten_bits_necessary_for_any_improvement_over_default": True,
                               "example_lower_at_lambda_1_over_100": {
                                   "budget_6": [float(v+F(2,100)) for v in default],
                                   "budget_10_two_class_relaxation": [float(min(default[side]+F(2,100), causal[side]+F(10,100))) for side in (0,1)]}},
              "generic_three_distinct_emissions": {"two_labels": generic, "one_label": generic_single},
              "certificate": "All displayed log intervals are rational 24-term atanh-series sums with geometric tail; interval comparisons are asserted before float conversion."}
    Path(__file__).with_name("results.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"one_label_floor": result["source_only"]["one_label_KL_interval"],
                      "two_label_floor": [0,0], "causal_floor": result["causal_collision"]["universal_sequence_KL_lower_interval"],
                      "generic_two_label": generic}, indent=2))


if __name__ == "__main__":
    main()
