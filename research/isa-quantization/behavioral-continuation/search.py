#!/usr/bin/env python3
"""Exact rational occupancy and information-projection search for two Mealy machines."""

import itertools
import json
import math
from fractions import Fraction as F
from pathlib import Path

P = ((F(1, 2), F(1, 2)), (F(1, 4), F(3, 4)))
GAMMA = F(1, 2)
PAIRS = tuple(itertools.product(range(2), repeat=2))


def solve(matrix, rhs):
    """Exact Gauss-Jordan elimination, including the pivot rows used by each instance."""
    n = len(rhs)
    aug = [list(matrix[i]) + [rhs[i]] for i in range(n)]
    for col in range(n):
        pivot = next(row for row in range(col, n) if aug[row][col])
        aug[col], aug[pivot] = aug[pivot], aug[col]
        d = aug[col][col]
        aug[col] = [v / d for v in aug[col]]
        for row in range(n):
            if row != col:
                d = aug[row][col]
                aug[row] = [v - d * w for v, w in zip(aug[row], aug[col])]
    return tuple(row[-1] for row in aug)


def occupancy(step, gamma=GAMMA):
    """(1-gamma) sum_t gamma^t Pr_teacher[(s_t,c_t)]; c uses its own step."""
    matrix = []
    for target in PAIRS:
        row = []
        for source in PAIRS:
            s, c = source
            entry = sum(P[s][a] for a in range(2) if (a, step[2 * c + a]) == target)
            row.append(F(source == target) - gamma * entry)
        matrix.append(row)
    w = solve(matrix, [1 - gamma, F(0), F(0), F(0)])
    assert sum(w) == 1 and all(v >= 0 for v in w)
    for target in PAIRS:
        j = PAIRS.index(target)
        assert w[j] == (1 - gamma) * F(target == (0, 0)) + gamma * sum(
            w[i] * sum(P[s][a] for a in range(2) if (a, step[2*c+a]) == target)
            for i, (s, c) in enumerate(PAIRS))
    return w


def centroid(w):
    masses = [[sum(w[PAIRS.index((s, c))] * P[s][a] for s in range(2))
               for a in range(2)] for c in range(2)]
    return tuple(tuple(value / sum(row) for value in row) if sum(row) else None
                 for row in masses)


def kl(p, q):
    return sum(float(x) * math.log(float(x / y)) for x, y in zip(p, q) if x)


def objective(w, q):
    return sum(float(w[PAIRS.index((s, c))]) * kl(P[s], q[c])
               for s, c in PAIRS if w[PAIRS.index((s, c))])


def log_interval(x, terms=24):
    """Rational certificate: atanh series with a geometric absolute tail."""
    z = (x - 1) / (x + 1)
    total = 2 * sum((z ** (2*k + 1) / (2*k + 1) for k in range(terms)), F(0))
    tail = 2 * abs(z) ** (2*terms + 1) / ((2*terms + 1) * (1 - z*z))
    return total - tail, total + tail


def objective_interval(w, q):
    lo = hi = F(0)
    for s, c in PAIRS:
        if not w[PAIRS.index((s, c))]:
            continue
        for a in range(2):
            lower, upper = log_interval(P[s][a] / q[c][a])
            mass = w[PAIRS.index((s, c))] * P[s][a]
            lo += mass * lower
            hi += mass * upper
    return lo, hi


def as_strings(values):
    return [str(v) for v in values]


def record(step):
    w = occupancy(step)
    q = centroid(w)
    floor = objective(w, q)
    return {"transition": list(step), "occupancy_00_01_10_11": as_strings(w),
            "unrestricted_emissions": [as_strings(row) if row else None for row in q],
            "irreducible_floor_nats_per_discounted_step": floor,
            "teacher_state_collision": any(w[PAIRS.index((0, c))] and
                                           w[PAIRS.index((1, c))] for c in range(2))}


def finite_occupancy(step, horizon):
    states = {(0, 0): F(1)}
    result = {pair: F(0) for pair in PAIRS}
    for _ in range(horizon):
        for pair, value in states.items():
            result[pair] += value
        next_states = {pair: F(0) for pair in PAIRS}
        for (s, c), value in states.items():
            for a in range(2):
                next_states[a, step[2*c+a]] += value * P[s][a]
        states = next_states
    return tuple(result[pair] for pair in PAIRS)


def main():
    records = [record(step) for step in itertools.product(range(2), repeat=4)]
    ranked = sorted(records, key=lambda item: (round(item["irreducible_floor_nats_per_discounted_step"], 14), item["transition"]))
    exact = [r["transition"] for r in ranked if not r["teacher_state_collision"]]
    assert exact == [[0, 1, 0, 1]]
    nonzero = [r for r in ranked if r["teacher_state_collision"]]
    winner = nonzero[0]
    winner_interval = objective_interval(occupancy(tuple(winner["transition"])),
                                         centroid(occupancy(tuple(winner["transition"]))))
    rival_lowers = [objective_interval(occupancy(tuple(r["transition"])),
                                       centroid(occupancy(tuple(r["transition"]))))[0]
                    for r in nonzero[1:]]
    assert winner_interval[1] < min(rival_lowers)
    collapsed = next(r for r in records if r["transition"] == [0, 0, 0, 0])
    w = occupancy((0, 0, 0, 0))
    q_opt = centroid(w)
    q_forced = (P[0], P[1])
    floor = objective(w, q_opt)
    penalty = sum(float(sum(w[PAIRS.index((s, c))] for s in range(2))) *
                  kl(q_opt[c], q_forced[c]) for c in range(2) if q_opt[c])
    actual = objective(w, q_forced)
    assert math.isclose(actual, floor + penalty, abs_tol=1e-14)
    finite = finite_occupancy((0, 0, 0, 0), 2)
    finite_actual = objective(finite, q_forced)
    assert math.isclose(finite_actual, .5 * kl(P[1], P[0]), abs_tol=1e-14)
    result = {
        "contract": {"teacher_emissions": [as_strings(row) for row in P],
                     "teacher_transition_s_a": [0, 1, 0, 1],
                     "candidate_initial_state": 0,
                     "candidate_transition_order": "c=0,a=0; c=0,a=1; c=1,a=0; c=1,a=1",
                     "discount": str(GAMMA),
                     "occupancy": "(1-gamma) sum_t gamma^t Pr_P(s_t,c_t), common teacher-drawn tokens, separate state transitions"},
        "number_transitions_exhausted": len(records), "zero_floor_transitions": exact,
        "best_nonzero": winner,
        "strict_best_nonzero_certificate": {
            "method": "24 rational atanh-series terms per logarithm; all other 14 positive-floor transition tables have strictly larger certified lower bounds",
            "winner_upper": float(winner_interval[1]),
            "smallest_rival_lower": float(min(rival_lowers)),
        },
        "collapsed_transition": collapsed,
        "collapsed_teacher_forced_emissions": {
            "q": [as_strings(row) for row in q_forced],
            "local_emission_error_at_aligned_teacher_states": 0,
            "two_token_sequence_KL_nats": finite_actual,
            "normalized_discounted_KL_nats": actual,
            "state_aliasing_floor": floor,
            "emission_quantization_penalty": penalty,
            "decomposition_residual": actual - floor - penalty,
        },
        "full_floor_ranking": [[r["transition"], r["irreducible_floor_nats_per_discounted_step"]] for r in ranked],
    }
    Path(__file__).with_name("results.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"zero_floor_transitions": exact, "best_nonzero": result["best_nonzero"],
                      "collapsed": result["collapsed_teacher_forced_emissions"]}, indent=2))


if __name__ == "__main__":
    main()
