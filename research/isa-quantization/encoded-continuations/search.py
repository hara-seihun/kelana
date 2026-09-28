#!/usr/bin/env python3
"""Exhaust every shared 3-bit labeling for two native XOR consumers."""

import json
from itertools import permutations
from pathlib import Path

N = 8
F = tuple(x ^ 1 for x in range(N))
swap = list(range(N))
swap[0], swap[4] = swap[4], swap[0]
G = tuple(swap[swap[x] ^ 2] for x in range(N))


def compose(left, right):
    return tuple(left[right[x]] for x in range(N))


def error(candidate, target):
    return sum(a != b for a, b in zip(candidate, target))


def squared(candidate, target):
    return sum((a - b) ** 2 for a, b in zip(candidate, target))


def score(f, g):
    return (
        error(f, F) + error(g, G),
        squared(f, F) + squared(g, G),
        error(compose(f, g), compose(F, G))
        + error(compose(g, f), compose(G, F)),
        squared(compose(f, g), compose(F, G))
        + squared(compose(g, f), compose(G, F)),
    )


def search():
    best = {}
    squared_pairs = {}
    explored = 0
    for encoded in permutations(range(N)):
        inverse = [0] * N
        for x, code in enumerate(encoded):
            inverse[code] = x
        f = tuple(inverse[code ^ 1] for code in encoded)
        g = tuple(inverse[code ^ 2] for code in encoded)
        for name, candidate_g in (("independent-masks", g), ("same-mask", f)):
            values = score(f, candidate_g)
            if name == "independent-masks":
                pair = (values[1], values[3])
                candidate = (encoded, f, candidate_g)
                if pair not in squared_pairs or candidate < squared_pairs[pair]:
                    squared_pairs[pair] = candidate
            for criterion, indices in (("one-step-Hamming", (0, 1, 2, 3)),
                                       ("one-step-squared", (1, 0, 3, 2)),
                                       ("full-Hamming", (0, 2, 1, 3)),
                                       ("full-squared", (1, 3, 0, 2))):
                key = (name, criterion)
                record = (tuple(values[i] for i in indices), encoded, f, candidate_g)
                if key not in best or record < best[key]:
                    best[key] = record
        explored += 1
    return {
        "source": {"F": F, "G": G, "FG": compose(F, G), "GF": compose(G, F),
                   "noncommuting_input": next(x for x in range(N) if F[G[x]] != G[F[x]]),
                   "separate_G_label": swap},
        "search": {"encoders": explored, "native_masks": [1, 2],
                   "ordered_distinct_masks_covered_by_label_symmetry": 42},
        "minima": {f"{name}/{criterion}": {"scores": dict(zip(
            ("one_step_hamming", "one_step_squared", "path_hamming", "path_squared"),
            score(f, g))), "encoded": encoded, "F_approx": f, "G_approx": g}
                   for (name, criterion), (_, encoded, f, g) in sorted(best.items())},
        "squared_pareto": [
            {"one_step_squared": a, "path_squared": b, "encoded": squared_pairs[a, b][0],
             "one_step_hamming": score(*squared_pairs[a, b][1:])[0],
             "path_hamming": score(*squared_pairs[a, b][1:])[2]}
            for a, b in sorted(squared_pairs)
            if not any(c <= a and d <= b and (c < a or d < b)
                       for c, d in squared_pairs)
        ],
    }


if __name__ == "__main__":
    path = Path(__file__).with_name("results.json")
    path.write_text(json.dumps(search(), indent=2) + "\n")
    print(path)
