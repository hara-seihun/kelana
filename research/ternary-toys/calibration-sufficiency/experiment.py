#!/usr/bin/env python3
"""Exact finite-support calibration of a ternary gated residual branch."""

import json
from itertools import product

from scipy.stats import binom


STATES = ((1, -1), (-1, -1), (1, 1))
PROBABILITIES = (.899, .100, .001)
TEACHER = (1.49, -.60)
CODES = tuple(product((-1, 0, 1), repeat=2))


def branch(state, weights):
    a, b = state
    gate = max(0., weights[0] * a + weights[1] * b - .5)
    up = 50.5 + 49.5 * b
    return gate * up


def losses(code):
    return tuple((branch(state, code) - branch(state, TEACHER)) ** 2
                 for state in STATES)


def exact_risk(code):
    return sum(p * loss for p, loss in zip(PROBABILITIES, losses(code)))


def iid_failure_probability(n):
    """Probability empirical ERM does not choose the exact-risk winner.

    On this support, (1,-1) and (1,0) dominate the other seven codes
    coordinatewise. The pair has identical loss on state B. Conditional
    on rare-state count C, the common A count is binomial.
    """
    p_a, _, p_c = PROBABILITIES
    upper = int(binom.ppf(1 - 1e-13, n, p_c))
    error_a = losses((1, 0))[0] - losses((1, -1))[0]
    benefit_c = losses((1, -1))[2] - losses((1, 0))[2]
    probability = 0.
    for count_c in range(upper + 1):
        # Exact comparison: 1.18 * count_A >= 1400 * count_C.
        assert round(error_a, 8) == 1.18 and round(benefit_c, 8) == 1400
        count_a_threshold = (70000 * count_c + 58) // 59
        probability += (binom.pmf(count_c, n, p_c) *
                        binom.sf(count_a_threshold - 1, n - count_c,
                                 p_a / (1 - p_c)))
    return probability


def main():
    ranked = sorted(CODES, key=lambda code: (exact_risk(code), code))
    nearest = min(CODES, key=lambda code: (sum((a - b) ** 2
                                             for a, b in zip(code, TEACHER)), code))
    assert ranked[0] == (1, 0) and nearest == (1, -1)
    winner, runner_up = ranked[:2]
    for code in CODES:
        if code in (winner, runner_up):
            continue
        assert any(all(a <= b for a, b in zip(losses(leader), losses(code)))
                   for leader in (winner, runner_up))
    assert losses(winner)[1] == losses(runner_up)[1] == 0
    trials = []
    for n in (100, 1000, 10000, 100000):
        p_failure = iid_failure_probability(n)
        trials.append(dict(sample_size=n, failure_probability=p_failure,
                           expected_selected_risk=exact_risk(winner) + p_failure *
                           (exact_risk(runner_up) - exact_risk(winner)),
                           no_rare_probability=(1 - PROBABILITIES[2]) ** n))
    result = dict(states=STATES, probabilities=PROBABILITIES, teacher_weights=TEACHER,
                  teacher_outputs=[branch(s, TEACHER) for s in STATES],
                  candidates=[dict(code=code, squared_errors=losses(code),
                                   exact_risk=exact_risk(code)) for code in ranked],
                  nearest_weight_code=nearest,
                  weighted_cover_queries=3,
                  cover_chosen_code=winner,
                  iid=trials)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
