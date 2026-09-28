#!/usr/bin/env python3
"""Exact six-bit Walsh experiment; only standard-library integer arithmetic."""
import itertools
import json
import random
from pathlib import Path

N = 6
SIZE = 1 << N
RANK = 3
PLANTED = (60, 43, 29)


def span(generators):
    return frozenset(
        a ^ b ^ c for a in (0, generators[0])
        for b in (0, generators[1]) for c in (0, generators[2])
    )


def subspaces():
    return sorted({span(g) for g in itertools.combinations(range(1, SIZE), RANK)
                   if len(span(g)) == 1 << RANK}, key=lambda u: tuple(sorted(u)))


def product(a, b):
    return [sum(a[t] * b[s ^ t] for t in range(SIZE)) for s in range(SIZE)]


def energy(coeff, allowed):
    return sum(v * v for i, v in enumerate(coeff) if i not in allowed)


def measure(coeff, allowed):
    return energy(coeff, allowed) / sum(v * v for v in coeff)


def joint(maps, allowed):
    return sum(measure(m, allowed) for m in maps)


def witness(seed, structured):
    rng = random.Random(seed)
    support = span(PLANTED)
    f, g = ([0] * SIZE for _ in range(2))
    for mask in range(SIZE):
        if structured:
            amplitude = 8 if mask in support else 1
        else:
            amplitude = 8
        f[mask] = amplitude * rng.choice((-3, -2, -1, 1, 2, 3))
        g[mask] = amplitude * rng.choice((-3, -2, -1, 1, 2, 3))
    return f, g


def composed_score(f, g, h, support):
    branches = measure(f, support) + measure(g, support)
    product_norm = sum(v * v for v in h)
    continuation_error = 0
    for i in range(SIZE):
        candidate = sum(f[t] * g[i ^ t] for t in support if i ^ t in support)
        continuation_error += (h[i] - candidate) ** 2
    return branches + continuation_error / product_norm


def report(seed, structured, spaces):
    f, g = witness(seed, structured)
    h = product(f, g)
    maps = (f, g, h)
    best = min(spaces, key=lambda u: (joint(maps, u), tuple(sorted(u))))
    best_composed = min(spaces, key=lambda u: (composed_score(f, g, h, u), tuple(sorted(u))))
    branch = min(spaces, key=lambda u: (joint((f, g), u), tuple(sorted(u))))
    cubic = frozenset(i for i in range(SIZE) if i.bit_count() <= 3)
    weights = sorted(range(SIZE), key=lambda i: (-sum(m[i] ** 2 / sum(v * v for v in m)
                                                       for m in maps), i))
    unrestricted_eight = frozenset(weights[:8])
    projected = ([v if i in best else 0 for i, v in enumerate(m)] for m in (f, g))
    fp, gp = projected
    composed = product(fp, gp)
    residual_product = product([f[i] - fp[i] for i in range(SIZE)],
                               [g[i] - gp[i] for i in range(SIZE)])
    assert not any(composed[i] for i in range(SIZE) if i not in best)
    assert all(h[i] - composed[i] == residual_product[i] for i in best)
    assert sum((h[i] - composed[i]) ** 2 for i in range(SIZE)) == (
        energy(h, best) + sum(residual_product[i] ** 2 for i in best))
    return {
        'seed': seed, 'structured': structured,
        'best_rank3_support': sorted(best), 'best_composed_rank3_support': sorted(best_composed),
        'branch_rank3_support': sorted(branch),
        'planted_support': sorted(span(PLANTED)),
        'joint_relative_squared_error': {
            'rank3_direct_three_tables': joint(maps, best),
            'rank3_project_branches_then_multiply': composed_score(f, g, h, best_composed),
            'rank3_direct_optimum_support_then_multiply': composed_score(f, g, h, best),
            'best_eight_independent_characters_three_tables': joint(maps, unrestricted_eight),
            'degree_at_most_three_three_tables': joint(maps, cubic),
        },
        'per_branch_error': [measure(f, best), measure(g, best)],
        'product_extra_error_over_direct_projection':
            sum((h[i] - composed[i]) ** 2 for i in best) / sum(v * v for v in h),
    }


def main():
    spaces = subspaces()
    assert len(spaces) == 1395
    assert len(span(PLANTED)) == 8
    out = {'domain': SIZE, 'rank3_subspaces': len(spaces),
           'cases': [report(seed, structured, spaces)
                     for structured in (True, False) for seed in (5, 17, 29)]}
    path = Path(__file__).with_name('results.json')
    path.write_text(json.dumps(out, indent=2) + '\n')
    print(json.dumps(out, indent=2))


if __name__ == '__main__':
    main()
