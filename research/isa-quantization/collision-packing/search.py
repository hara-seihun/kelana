#!/usr/bin/env python3
"""Fractional (C+1)-collision certificates versus complete categorical oracles.

LP is a proposal only: shares are rounded downward to rational dyadics and
checked by exact arithmetic. All log objectives are rational enclosures.
"""
import itertools
import json
import math
import sys
from fractions import Fraction as F
from pathlib import Path
from time import perf_counter

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'categorical-tree'))
from search import Study, add, minimum, receipt  # exact rational log interval engine


def oracle(study, capacity):
    # Canonical restricted-growth strings: every unlabeled partition, no repeats.
    def assignments(prefix, used):
        if len(prefix) == study.n:
            yield tuple(prefix)
            return
        for label in range(min(used + 1, capacity)):
            yield from assignments(prefix + [label], max(used, label + 1))
    costs = []
    for labels in assignments([0], 1):
        clusters = [sum(1 << i for i, x in enumerate(labels) if x == k)
                    for k in range(max(labels) + 1)]
        costs.append(add(*(study.cluster_full(mask) for mask in clusters)))
    return minimum(costs), len(costs)


def pair_floors(study):
    return {(i, j): study.cluster_full((1 << i) | (1 << j))
            for i in range(study.n) for j in range(i+1, study.n)}


def optimize(study, capacity):
    from scipy.optimize import linprog
    pair = pair_floors(study)
    edges = list(itertools.combinations(range(study.n), capacity + 1))
    floors = [minimum([pair[i, j] for i, j in itertools.combinations(edge, 2)]) for edge in edges]
    incidence = [[int(i in edge) for edge in edges] for i in range(study.n)]
    proposal = linprog([-float(v[0]) for v in floors], A_ub=incidence,
                       b_ub=[1]*study.n, bounds=(0, None), method='highs')
    assert proposal.success, proposal.message
    denominator = 1 << 32
    share = [F(math.floor(max(0, x) * denominator), denominator) for x in proposal.x]
    loads = [sum((share[j] for j, edge in enumerate(edges) if i in edge), F(0))
             for i in range(study.n)]
    # Truncation does not guarantee exact feasibility if solver overshot.
    scale = max(F(1), *loads)
    share = [x / scale for x in share]
    loads = [x / scale for x in loads]
    assert all(0 <= x <= 1 for x in loads)
    assert all(x >= 0 for x in share)
    floor = add(*( (share[j]*v[0], share[j]*v[1])
                   for j,v in enumerate(floors) if share[j]))
    uniform_share = F(1, math.comb(study.n-1, capacity))
    uniform = add(*((uniform_share*v[0], uniform_share*v[1]) for v in floors))
    best = max((uniform, floor), key=lambda interval: interval[0])
    return {'hyperedges': len(edges), 'pairs': len(pair),
            'uniform': receipt(uniform), 'optimized_proposal': receipt(floor),
            'best': receipt(best),
            'loads': [str(x) for x in loads],
            'shares': [{'edge': list(e), 'share': str(share[j])} for j,e in enumerate(edges)
                       if share[j]],
            'all_pair_costs': {f'{i},{j}': receipt(v) for (i,j),v in pair.items()},
            'min_pair_per_hyperedge': [{'edge': list(e), 'cost': receipt(v)}
                                      for e,v in zip(edges, floors)]}


def run_case(name, rows, weights, capacity):
    study = Study(rows, weights)
    packing = optimize(study, capacity)
    exact, count = oracle(study, capacity)
    assert F(packing['best']['interval'][0]) <= exact[1]
    return {'name': name, 'teacher_laws': [[str(x) for x in p] for p in study.p],
            'occupancy': [str(x) for x in study.nu], 'capacity': capacity,
            'complete_unlabeled_assignments': count, 'exact': receipt(exact),
            'packing': packing}


def main():
    start = perf_counter()
    cases = [
        run_case('crossing_product', [[a*b,a*(4-b),(4-a)*b,(4-a)*(4-b)]
                                      for a in (1,3) for b in (1,3)], [1]*4, 2),
        run_case('generic_weighted', [[9,1,4,2],[2,7,1,6],[3,2,9,2],
                                      [1,3,2,10],[5,5,3,3],[4,2,4,6]], [1,2,1,3,2,1], 2),
        run_case('near_disjoint', [[1000000 if i == j else 1 for j in range(4)]
                                    for i in range(4)], [1]*4, 2),
        run_case('Bernoulli_four', [[1,4],[2,3],[3,2],[4,1]], [1,2,3,4], 2),
        run_case('Bernoulli_three', [[1,3],[2,2],[3,1]], [1,1,1], 2),
    ]
    for c in cases:
        p = c['packing']
        print(c['name'], 'assignments', c['complete_unlabeled_assignments'],
              'uniform', p['uniform']['decimal'][0],
              'best', p['best']['decimal'][0], 'exact', c['exact']['decimal'][0])
    out = {'contract': 'Positive finite categorical teacher laws, normalized nonnegative teacher occupancy, at most C stationary candidate emission laws, shared global labels.',
           'arithmetic': 'Rational atanh-series log intervals from categorical-tree/search.py; scipy proposes shares, exact dyadic truncation and rational rescaling verify loads; all objectives are outward rational enclosures.',
           'cases': cases, 'elapsed_seconds': perf_counter()-start}
    Path(__file__).with_name('results.json').write_text(json.dumps(out, indent=2)+'\n')
    print('seconds', out['elapsed_seconds'])


if __name__ == '__main__':
    main()
