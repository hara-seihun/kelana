#!/usr/bin/env python3
"""Certified incomplete-transition Bellman bounds with globally tied emission codes."""

import itertools
import json
import time
from functools import lru_cache
from fractions import Fraction as F
from pathlib import Path

S = range(3)
C = range(2)
A = range(2)
P = ((F(1, 4), F(3, 4)), (F(1, 2), F(1, 2)), (F(3, 4), F(1, 4)))
T = ((0, 1), (2, 0), (1, 2))
Q = (F(1, 4), F(1, 2), F(3, 4))
H = 7
SLOTS = tuple(itertools.product(C, A))
EMISSIONS = tuple(itertools.product(Q, repeat=2))


def emission_bits(q):
    return 1 if all(v == F(1, 2) for v in q) else 5


def transition_bits(u):
    changed = any(value != c for (c, _), value in zip(SLOTS, u) if value is not None)
    return 5 if changed else 1


def log_interval(x, terms=24):
    z = (x - 1) / (x + 1)
    total = 2 * sum((z ** (2*k + 1) / (2*k + 1) for k in range(terms)), F(0))
    tail = 2 * abs(z) ** (2*terms + 1) / ((2*terms + 1) * (1-z*z))
    return total - tail, total + tail


@lru_cache(None)
def kl_interval(s, probability_one):
    intervals = [log_interval(p / q) for p, q in zip(P[s], (1-probability_one, probability_one))]
    return (max(F(0), sum(P[s][a] * intervals[a][0] for a in A)),
            sum(P[s][a] * intervals[a][1] for a in A))


def dynamic(partial, q, method, side):
    """Each missing edge chooses a destination per source state, token and time."""
    v = [[F(0)] * 2 for _ in S]
    for _ in range(H):
        nxt = [[F(0)] * 2 for _ in S]
        for s in S:
            for c in C:
                val = kl_interval(s, q[c])[side]
                for a in A:
                    successor = T[s][a]
                    slot = partial[2*c+a]
                    if slot is None:
                        assert method != "exact"
                        continuation = min(v[successor]) if method == "oracle" else F(0)
                    else:
                        continuation = v[successor][slot]
                    val += P[s][a] * continuation
                nxt[s][c] = val
        v = nxt
    return v[0][0]


def lower(partial, lagrange, budget, method):
    bits = transition_bits(partial)
    return min((dynamic(partial, q, method, 0) + lagrange * (bits + emission_bits(q))
                for q in EMISSIONS if bits + emission_bits(q) <= budget), default=None)


def full(partial, lagrange, budget, side=1):
    bits = transition_bits(partial)
    return min(((dynamic(partial, q, "exact", side) + lagrange * (bits + emission_bits(q)), q)
                for q in EMISSIONS if bits + emission_bits(q) <= budget), default=(None, None))


def explore(lagrange, budget, method):
    seeds = ((0, 0, 1, 1), (0, 1, 0, 1), (0, 0, 0, 0))
    seeded = [(score, u, q) for u in seeds for score, q in [full(u, lagrange, budget)] if score is not None]
    best = min(seeded)
    initial = best
    counts = {"nodes": 0, "pruned_internal": 0, "leaves_scored": 0,
              "excluded_transition_tables": 0, "strict_oracle_only_prunes": 0}
    strict_witness = []

    def visit(prefix):
        nonlocal best
        counts["nodes"] += 1
        partial = prefix + (None,) * (len(SLOTS)-len(prefix))
        bound = lower(partial, lagrange, budget, method)
        if bound is None or bound > best[0]:
            counts["excluded_transition_tables"] += 2 ** (len(SLOTS)-len(prefix))
            if len(prefix) < len(SLOTS):
                counts["pruned_internal"] += 1
                if method == "oracle":
                    baseline = lower(partial, lagrange, budget, "forced")
                    if baseline is not None and baseline <= best[0]:
                        counts["strict_oracle_only_prunes"] += 1
                        strict_witness.append({"fixed_prefix": prefix, "oracle_lower": float(bound),
                                               "forced_prefix_lower": float(baseline),
                                               "feasible_incumbent_upper": float(best[0])})
            return
        if len(prefix) == len(SLOTS):
            counts["leaves_scored"] += 1
            score, q = full(prefix, lagrange, budget)
            if (score, prefix, q) < best:
                best = (score, prefix, q)
            return
        for x in C:
            visit(prefix + (x,))

    start = time.perf_counter()
    visit(())
    elapsed = time.perf_counter() - start
    # This exhaustive oracle is validation only, strictly after the pruned search.
    candidates = [(score, u, q) for u in itertools.product(C, repeat=len(SLOTS))
                  for score, q in [full(u, lagrange, budget)] if score is not None]
    oracle = min(candidates)
    all_programs = [(dynamic(u, q, "exact", 0) + lagrange * (transition_bits(u) + emission_bits(q)),
                     u, q) for u in itertools.product(C, repeat=len(SLOTS)) for q in EMISSIONS
                    if transition_bits(u) + emission_bits(q) <= budget]
    assert best == oracle and min(entry[0] for entry in all_programs) <= best[0]
    chosen = best[1]
    q = best[2]
    smallest_competitor_lower = min(score for score, u, code in all_programs
                                    if (u, code) != (chosen, q))
    assert best[0] < smallest_competitor_lower
    return {"lambda_nats_per_bit": float(lagrange), "budget_bits": budget, "method": method,
            "optimum": {"certified_global_lower": float(min(entry[0] for entry in all_programs)),
                        "feasible_upper": float(best[0]),
                        "smallest_competitor_lower": float(smallest_competitor_lower),
                        "uniquely_optimal_by_rational_intervals": True,
                        "transition": chosen,
                        "emission_probability_one": [str(v) for v in q],
                        "transition_bits": transition_bits(chosen),
                        "emission_bits": emission_bits(q),
                        "sequence_KL_interval": [float(dynamic(chosen, q, "exact", side))
                                                 for side in (0, 1)]},
            "seed": {"feasible_upper": float(initial[0]), "transition": initial[1]},
            "root_lower": float(lower((None,) * len(SLOTS), lagrange, budget, method)),
            "counts": counts, "first_strict_oracle_prune": strict_witness[0] if strict_witness else None,
            "search_seconds_excluding_exhaustive_validation": elapsed}


def main():
    results = {"teacher": {"p0": [[str(v) for v in row] for row in P],
                           "transition_s_a": T, "initial_state": 0},
               "candidate": {"initial_state": 0, "horizon": H,
                             "transition_order_c_a": SLOTS,
                             "emission_code_probability_one": [str(v) for v in Q],
                             "cost_model": "two independently framed fields: each has one mode bit, zero=hardwired default, one=four-bit payload. Transition default U(c,a)=c, otherwise four table bits. Emission default q_c(1)=1/2 for both c, otherwise two two-bit entries encoding {1/4,1/2,3/4}. Thus each field is exactly 1 or 5 bits (total 2,6,10).", 
                             "log_certificate": "24 atanh-series terms per log with rational geometric tail; lower Bellman and upper feasible score compared as fractions"},
               "experiments": [explore(lam, budget, method) for lam, budget in
                               ((F(0), 10), (F(3, 200), 10), (F(1, 25), 10),
                                (F(3, 200), 6), (F(1, 25), 6))
                               for method in ("forced", "oracle")]}
    Path(__file__).with_name("results.json").write_text(json.dumps(results, indent=2) + "\n")
    for row in results["experiments"]:
        print(row["method"], row["lambda_nats_per_bit"], row["budget_bits"],
              row["optimum"]["feasible_upper"], row["counts"],
              row["search_seconds_excluding_exhaustive_validation"])


if __name__ == "__main__":
    main()
