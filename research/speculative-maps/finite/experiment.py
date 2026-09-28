#!/usr/bin/env python3
"""Exact finite-state speculative transition maps and prefix-budget coverage."""
import heapq
import itertools
import json
from collections import Counter
from fractions import Fraction
from pathlib import Path

STATES = 16
IDENTITY = sum(s << (4 * s) for s in range(STATES))


def at(packed, state):
    return (packed >> (4 * state)) & 15


def pack(values):
    assert len(values) == STATES and all(0 <= v < STATES for v in values)
    return sum(v << (4 * s) for s, v in enumerate(values))


def compose(left, right):
    """right after left; both maps retain every hypothetical predecessor."""
    return pack([at(right, at(left, s)) for s in range(STATES)])


def scan_serial(maps):
    acc = IDENTITY
    out = []
    for mapping in maps:
        acc = compose(acc, mapping)
        out.append(acc)
    return out


def scan_tree(maps):
    """Balanced upsweep/downsweep: O(n) map work, O(log n) span."""
    if not maps:
        return []
    levels = [list(maps)]
    while len(levels[-1]) > 1:
        row = levels[-1]
        levels.append([compose(row[i], row[i + 1]) if i + 1 < len(row)
                       else row[i] for i in range(0, len(row), 2)])
    prefixes = [IDENTITY]
    for level in range(len(levels) - 2, -1, -1):
        row = levels[level]
        children = []
        for i, prior in enumerate(prefixes):
            children.append(prior)
            if 2 * i + 1 < len(row):
                children.append(compose(prior, row[2 * i]))
        prefixes = children
    return [compose(prefixes[i], maps[i]) for i in range(len(maps))]


def draw(row, uniform, grid):
    cumulative = 0
    for state, mass in enumerate(row):
        cumulative += mass
        if uniform < cumulative:
            return state
    raise ValueError('row does not sum to grid')


def transition(rows, uniform, grid):
    return pack([draw(row, uniform, grid) for row in rows])


def sequence(rows_by_time, uniforms, grid, start):
    state = start
    path = []
    for rows, uniform in zip(rows_by_time, uniforms, strict=True):
        state = draw(rows[state], uniform, grid)
        path.append(state)
    return tuple(path)


def finite_grid_law():
    grid, states, length = 4, 3, 5
    rows_by_time = []
    for t in range(length):
        small = []
        for s in range(states):
            # Include deterministic, branching and state-dependent conditionals.
            weights = [((t + 2 * s + 3 * j) % 4) for j in range(states)]
            total = sum(weights)
            if total == 0:
                weights[s] = grid
            else:
                weights = [w * grid // total for w in weights]
                weights[(s + t) % states] += grid - sum(weights)
            small.append(weights + [0] * (STATES - states))
        rows_by_time.append(small + [[grid if j == s else 0 for j in range(STATES)]
                                     for s in range(states, STATES)])
    assert all(sum(row) == grid for rows in rows_by_time for row in rows)
    # The conditional-law reference enumerates state paths, not shared uniforms.
    reference = Counter({((), 0): Fraction(1)})
    for rows in rows_by_time:
        next_paths = Counter()
        for (path, state), probability in reference.items():
            for successor, mass in enumerate(rows[state]):
                if mass:
                    next_paths[(path + (successor,), successor)] += probability * Fraction(mass, grid)
        reference = next_paths
    observed = Counter()
    streams = 0
    for uniforms in itertools.product(range(grid), repeat=length):
        maps = [transition(rows, u, grid) for rows, u in zip(rows_by_time, uniforms, strict=True)]
        path = sequence(rows_by_time, uniforms, grid, 0)
        assert path == tuple(at(p, 0) for p in scan_serial(maps))
        assert scan_serial(maps) == scan_tree(maps)
        observed[(path, path[-1])] += 1
        streams += 1
    assert {key: Fraction(count, streams) for key, count in observed.items()} == dict(reference)
    return {'grid': grid, 'states': states, 'steps': length, 'streams': streams,
            'distinct_paths': len(reference), 'law': 'exact rational equality'}


def larger_paths():
    # Separate, deterministic pseudo-random fixtures, without inferring a distribution.
    import random
    rng = random.Random(1776)
    cases = 200
    for _ in range(cases):
        length = rng.randrange(1, 34)
        rows_by_time = []
        for _ in range(length):
            rows = []
            for s in range(STATES):
                choices = rng.sample(range(STATES), 3)
                row = [0] * STATES
                for successor, mass in zip(choices, (5, 2, 1), strict=True):
                    row[successor] = mass
                rows.append(row)
            rows_by_time.append(rows)
        uniforms = [rng.randrange(8) for _ in range(length)]
        maps = [transition(rows, u, 8) for rows, u in zip(rows_by_time, uniforms, strict=True)]
        start = rng.randrange(STATES)
        path = sequence(rows_by_time, uniforms, 8, start)
        serial, parallel = scan_serial(maps), scan_tree(maps)
        assert serial == parallel
        assert path == tuple(at(p, start) for p in parallel)
        # Joint carrier: two maps in two packed words, no intermediate unpacking.
        other_uniforms = [rng.randrange(8) for _ in range(length)]
        other = [transition(rows, u, 8) for rows, u in zip(rows_by_time, other_uniforms, strict=True)]
        joint = list(zip(scan_tree(maps), scan_tree(other), strict=True))
        assert joint == list(zip(scan_serial(maps), scan_serial(other), strict=True))
        assert sequence(rows_by_time, other_uniforms, 8, start) == tuple(
            at(second, start) for _, second in joint)
    return {'cases': cases, 'max_states': STATES, 'max_steps': 33,
            'joint_carrier_bits': 128, 'joint_compositions': 'componentwise exact'}


def tree_coverage(rows, start, budget):
    """Take the highest-mass unseen prefix. Every child is no heavier than its parent."""
    frontier = [(-Fraction(mass), (successor,)) for successor, mass in rows[start].items()]
    heapq.heapify(frontier)
    covered = Fraction(0)
    chosen = []
    for _ in range(budget):
        if not frontier:
            break
        negative_probability, path = heapq.heappop(frontier)
        probability = -negative_probability
        covered += probability
        chosen.append((path, probability))
        for successor, mass in rows[path[-1]].items():
            heapq.heappush(frontier, (-probability * mass, path + (successor,)))
    return covered, chosen


def chain_coverage(rows, start, budget):
    """Exact best fixed chain at this budget, including non-greedy choices."""
    from functools import lru_cache

    @lru_cache(None)
    def best(state, remaining):
        if not remaining:
            return Fraction(0)
        return max((mass * (1 + best(successor, remaining - 1))
                    for successor, mass in rows[state].items()), default=Fraction(0))

    return best(start, budget)


def coverage():
    f = Fraction
    scenarios = {
        'sticky_correlated': {0: {0: f(9, 10), 1: f(1, 10)},
                              1: {1: f(9, 10), 0: f(1, 10)}},
        'balanced_branching': {0: {0: f(1, 2), 1: f(1, 2)},
                               1: {0: f(1, 2), 1: f(1, 2)}},
        'asymmetric_branching': {0: {0: f(3, 4), 1: f(1, 4)},
                                 1: {1: f(1, 2), 0: f(1, 2)}},
    }
    output = {}
    for name, rows in scenarios.items():
        output[name] = {}
        for budget in (2, 4, 8, 16):
            tree, nodes = tree_coverage(rows, 0, budget)
            chain = chain_coverage(rows, 0, budget)
            assert tree >= chain
            assert sum((p for _, p in nodes), Fraction(0)) == tree
            assert all(path[:-1] in {p for p, _ in nodes} for path, _ in nodes if len(path) > 1)
            output[name][str(budget)] = {'chain': float(chain), 'tree': float(tree),
                                         'chain_exact': str(chain), 'tree_exact': str(tree)}
    return output


def main():
    result = {'finite_grid': finite_grid_law(), 'larger_paths': larger_paths(),
              'coverage': coverage(),
              'scan_cost': {'serial_compositions': 'n', 'serial_span': 'n',
                            'balanced_compositions': '<3n', 'balanced_span': '<2ceil(log2(n))+2'}}
    destination = Path(__file__).with_name('results.json')
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
