"""Exact vector-frontier elimination over installed-program support intervals.

All charges are integer toy-machine costs; no native timing inference is intended.
"""
from dataclasses import dataclass
from itertools import product
import json
import time

A = (0, 1, 0, 1)
C = (0, 1, 0, 2)
L = (0, 1, 2, 3)
ZERO = (0, 0, 0, 0)


@dataclass(frozen=True)
class Asset:
    name: str
    first: int
    last: int
    charge: tuple[int, int, int, int]


@dataclass(frozen=True)
class Option:
    name: str
    need: frozenset[str]
    cost: tuple[int, int, int, int]


def plus(a, b):
    return tuple(x + y for x, y in zip(a, b))


def dominates(a, b):
    return all(x <= y for x, y in zip(a, b))


def prune(vectors):
    """Nondominated distinct vectors, preserving one concrete choice witness."""
    survivors = {}
    for vector, witness in sorted(vectors.items()):
        if any(dominates(other, vector) for other in survivors):
            continue
        for other in tuple(survivors):
            if dominates(vector, other):
                del survivors[other]
        survivors[vector] = witness
    return survivors


def sse(x, y):
    return sum((a - b) ** 2 for a, b in zip(x, y))


def best_scalar(teacher):
    constant = min((sse(teacher, (b,) * 4), b) for b in range(4))
    affine = min((sse(teacher, tuple(s * x + b for x in range(4))), s, b)
                 for s in range(-3, 4) for b in range(-3, 4))
    return constant[0], affine[0]


def instance(n):
    teachers = (A, C, L) * ((n + 2) // 3)
    teachers = teachers[:n]
    assets = [Asset('constant-reader', 0, n-1, (0, 1, 0, 0)),
              Asset('affine-reader', 0, n-1, (0, 2, 0, 0)),
              Asset('direct-reader', 0, n-1, (0, 2, 0, 0)),
              Asset('shared-reader', 0, n-1, (0, 3, 0, 0))]
    # A tile-bank program variant is legal only on its two neighboring regions.
    # Its four signed-byte responses are serialized once and copied into a
    # dedicated four-byte prepared bank resident for the entire image lifetime.
    # Retiring a decision does not evict this prepared bank. Reader code is shared.
    assets += [Asset(f'bank-{j}', j, j+1, (0, 4, 0, 4))
               for j in range(n-1)]
    options = []
    for i, teacher in enumerate(teachers):
        ce, ae = best_scalar(teacher)
        choices = [Option('constant', frozenset({'constant-reader'}), (ce, 1, 1, 0)),
                   Option('affine', frozenset({'affine-reader'}), (ae, 2, 2, 0)),
                   Option('direct', frozenset({'direct-reader'}), (0, 4, 2, 0))]
        for j in (i-1, i):
            if 0 <= j < n-1:
                # Bank j uses the teacher of its first region as its response.
                choices.append(Option(f'bank-{j}',
                                      frozenset({'shared-reader', f'bank-{j}'}),
                                      (sse(teacher, teachers[j]), 1, 2, 0)))
        options.append(choices)
    return assets, options


def eliminate(assets, options):
    n = len(options)
    starts = [[a for a in assets if a.first == i] for i in range(n)]
    ends = [frozenset(a.name for a in assets if a.last == i) for i in range(n)]
    states = {frozenset(): {ZERO: ()}}
    transitions = 0
    max_states = 0
    max_labels = 0
    max_crossing = 0
    for i in range(n):
        next_states = {}
        max_crossing = max(max_crossing, sum(a.first <= i <= a.last for a in assets))
        for active, labels in states.items():
            for bits in product((False, True), repeat=len(starts[i])):
                opened = tuple(a for a, bit in zip(starts[i], bits) if bit)
                installed = active | frozenset(a.name for a in opened)
                setup = tuple(sum(a.charge[k] for a in opened) for k in range(4))
                for option in options[i]:
                    if not option.need <= installed:
                        continue
                    remaining = installed - ends[i]
                    dest = next_states.setdefault(remaining, {})
                    for cost, witness in labels.items():
                        transitions += 1
                        result = plus(plus(cost, setup), option.cost)
                        dest.setdefault(result, witness + (option.name,))
        states = {key: prune(value) for key, value in next_states.items()}
        max_states = max(max_states, len(states))
        max_labels = max(max_labels, sum(len(x) for x in states.values()))
    assert set(states) == {frozenset()}
    return states[frozenset()], {'transitions': transitions,
                                  'peak_states': max_states,
                                  'peak_labels': max_labels,
                                  'peak_crossing_assets': max_crossing}


def exhaustive(assets, options):
    """Independent assignment oracle: setup charged by actual union, not opened sets."""
    asset_by_name = {a.name: a for a in assets}
    vectors = {}
    assignments = 0
    for assignment in product(*options):
        assignments += 1
        installed = set().union(*(opt.need for opt in assignment))
        cost = ZERO
        for opt in assignment:
            cost = plus(cost, opt.cost)
        for name in installed:
            cost = plus(cost, asset_by_name[name].charge)
        vectors.setdefault(cost, tuple(opt.name for opt in assignment))
    return prune(vectors), assignments


def replay(assets, options, witness):
    by_name = {a.name: a for a in assets}
    chosen = [next(x for x in row if x.name == name) for row, name in zip(options, witness)]
    result = ZERO
    for option in chosen:
        result = plus(result, option.cost)
    for asset_name in set().union(*(x.need for x in chosen)):
        result = plus(result, by_name[asset_name].charge)
    return result


def run():
    results = {}
    for n in (7, 48):
        assets, options = instance(n)
        started = time.perf_counter()
        front, stats = eliminate(assets, options)
        elapsed = time.perf_counter() - started
        for vector, witness in front.items():
            assert replay(assets, options, witness) == vector
        if n == 7:
            oracle, assignments = exhaustive(assets, options)
            assert set(front) == set(oracle)
            stats['oracle_assignments'] = assignments
        results[str(n)] = {'assets': len(assets), 'frontier_size': len(front),
                           'shared_frontier_size': sum(any(choice.startswith('bank-')
                                                           for choice in witness)
                                                       for witness in front.values()),
                           'frontier_vectors': sorted(front) if n == 7 else None,
                           'sample_frontier_witness': {'vector': min(front),
                                                       'choices': front[min(front)]},
                           'elapsed_seconds': round(elapsed, 4), **stats}
    print(json.dumps(results, sort_keys=True, separators=(',', ':')))


if __name__ == '__main__':
    run()
