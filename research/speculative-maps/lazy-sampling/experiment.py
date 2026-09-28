#!/usr/bin/env python3
"""Exact finite rejection sampler with bytewise, on-demand weight reads."""

import json
from collections import Counter
from fractions import Fraction
from pathlib import Path

BOUNDS = (1024, 64, 64, 64, 64, 64, 64, 64)
CASES = {
    "concentrated_high": (1000, 8, 8, 8, 8, 8, 8, 8),
    "concentrated_low": (125, 1, 1, 1, 1, 1, 1, 1),
    "spread": (128, 56, 56, 56, 56, 56, 56, 56),
    "near_envelope": (1000, 56, 56, 56, 56, 56, 56, 56),
}


def prepare(bounds):
    assert bounds and all(0 < upper <= 65535 for upper in bounds)
    running = 0
    cumulative = []
    for upper in bounds:
        running += upper
        cumulative.append(running)
    return tuple(cumulative)


def attempt(r, source, cumulative):
    """One proposal. Counters are bytes and scalar comparisons, not cache misses."""
    previous = 0
    for i, endpoint in enumerate(cumulative):
        if r < endpoint:
            break
        previous = endpoint
    else:
        raise ValueError("proposal outside the prepared envelope")
    v = r - previous
    high = source[2 * i]
    lower = high << 8
    if v < lower:
        accepted, source_bytes, tests = True, 1, 1
    elif v >= lower + 256:
        accepted, source_bytes, tests = False, 1, 2
    else:
        accepted, source_bytes, tests = v < (lower | source[2 * i + 1]), 2, 3
    scanned = i + 1
    return i, v, accepted, {
        "source_bytes": source_bytes,
        "metadata_bytes": 2 * scanned,
        "proposal_comparisons": scanned,
        "weight_comparisons": tests,
    }


def draw(source, cumulative, uniform):
    """uniform(limit) returns a fresh exact uniform integer in range(limit)."""
    total = cumulative[-1]
    while True:
        i, _, accepted, _ = attempt(uniform(total), source, cumulative)
        if accepted:
            return i


def full_cdf(weights, rank):
    """Reference reads every 16-bit weight before computing the sum and rank."""
    assert 0 <= rank < sum(weights)
    for i, weight in enumerate(weights):
        if rank < weight:
            return i
        rank -= weight
    raise AssertionError("CDF rank escaped")


def evaluate(name, weights, cumulative):
    assert len(weights) == len(cumulative)
    bounds = (cumulative[0],) + tuple(b - a for a, b in zip(cumulative, cumulative[1:]))
    assert all(0 <= weight <= upper for weight, upper in zip(weights, bounds))
    total = cumulative[-1]
    mass = sum(weights)
    assert mass > 0
    source = bytes(byte for weight in weights for byte in (weight >> 8, weight & 255))
    counts = Counter()
    costs = Counter()
    for r in range(total):
        i, v, accepted, bill = attempt(r, source, cumulative)
        costs.update(bill)
        if accepted:
            counts[i] += 1
            # The accepted cells can be ranked in CDF order. This couples
            # every accepted rejection draw to a full-weight inverse CDF draw.
            rank = sum(weights[:i]) + v
            assert full_cdf(weights, rank) == i
    assert tuple(counts[i] for i in range(len(weights))) == weights
    assert sum(counts.values()) == mass
    rejected = next(r for r in range(total) if not attempt(r, source, cumulative)[2])
    for i, weight in enumerate(weights):
        if weight:
            accepted = (0 if i == 0 else cumulative[i - 1])
            stream = iter((rejected, accepted))
            assert draw(source, cumulative, lambda limit: next(stream)) == i
    # Renewal reward: attempts are iid, so cost per accepted draw is the
    # sum over all possible first attempts divided by accepted cell count.
    per_draw = {key: round(value / mass, 6) for key, value in sorted(costs.items())}
    per_draw["random_coordinates"] = round(total / mass, 6)
    per_draw["total_read_bytes"] = round(
        (costs["source_bytes"] + costs["metadata_bytes"]) / mass, 6
    )
    return {
        "weights": list(weights),
        "exact_accepted_counts_per_envelope_cycle": [counts[i] for i in range(len(weights))],
        "target_probabilities": [str(Fraction(w, mass)) for w in weights],
        "envelope_size": total,
        "accepted_cells": mass,
        "acceptance_probability": str(Fraction(mass, total)),
        "expected_per_output": per_draw,
        "full_cdf_dynamic_source_read_bytes_per_output": 2 * len(weights),
        "total_read_bytes_vs_full": round(per_draw["total_read_bytes"] / (2 * len(weights)), 6),
    }


def main():
    cumulative = prepare(BOUNDS)
    results = {
        "contract": "integer weight w_i, 0<=w_i<=static U_i; independent exact uniform proposal coordinate in [0,sum U); repeat until accepted; output P(i)=w_i/sum w",
        "static_bounds": list(BOUNDS),
        "static_preparation_once": {
            "bound_source_read_bytes": 2 * len(BOUNDS),
            "cumulative_write_bytes": 2 * len(BOUNDS),
            "integer_additions": len(BOUNDS),
            "bound_checks": len(BOUNDS),
        },
        "dynamic_full_cdf_per_output": {
            "source_read_bytes": 2 * len(BOUNDS),
            "integer_additions": len(BOUNDS),
            "random_coordinates": 1,
            "cdf_comparisons_max": len(BOUNDS),
            "prepared_dynamic_cdf_write_bytes_if_reused": 2 * len(BOUNDS),
        },
        "cases": {name: evaluate(name, weights, cumulative) for name, weights in CASES.items()},
    }
    assert [Fraction(x) for x in results["cases"]["concentrated_high"]["target_probabilities"]] == [Fraction(x) for x in results["cases"]["concentrated_low"]["target_probabilities"]]
    path = Path(__file__).with_name("results.json")
    path.write_text(json.dumps(results, indent=2) + "\n")
    print(f"{path}: exact accepted-cell and coupled-CDF checks passed")
    for name, row in results["cases"].items():
        bill = row["expected_per_output"]
        print(f"{name}: attempts={bill['random_coordinates']:.3f}, source={bill['source_bytes']:.3f} B, metadata={bill['metadata_bytes']:.3f} B, total={bill['total_read_bytes']:.3f} B vs full 16 B")


if __name__ == "__main__":
    main()
