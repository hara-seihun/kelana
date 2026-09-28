#!/usr/bin/env python3
"""Rational-log replay of a feasible-budget binary-KL spectral floor."""
from fractions import Fraction as Q
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import json

HERE = Path(__file__).resolve().parent
source = HERE.parent / 'causal-state-capacity' / 'certificate.py'
spec = spec_from_file_location('capacity_certificate', source)
capacity = module_from_spec(spec)
spec.loader.exec_module(capacity)
log = capacity.log_interval


def add(a, b):
    return a[0] + b[0], a[1] + b[1]


def scale(q, a):
    return (q*a[0], q*a[1]) if q >= 0 else (q*a[1], q*a[0])


def kl(p, q):
    return add(scale(p, log(p/q)), scale(1-p, log((1-p)/(1-q))))


def display(interval):
    return {'rational': [str(v) for v in interval], 'decimal': [float(v) for v in interval]}


def main():
    teacher = ((Q(2,3), Q(1,2), Q(1,3)), (Q(1,2), Q(2,3), Q(1,3)))
    shared = (Q(7,12), Q(7,12), Q(1,3))
    # The shared-key reader supplies an achieved upper bound; direct table loss is exactly zero.
    total_upper = (Q(0), Q(0))
    for row in teacher:
        for p, q in zip(row, shared):
            total_upper = add(total_upper, kl(p, q))
    U = scale(Q(1,6), total_upper)
    B = total_upper[1]
    assert U[1] < Q(1,100) and U[0] > Q(9,1000)

    # Outward rational probability endpoints. Complements use the same certificate.
    endpoints = {Q(1,3): Q(2,11), Q(1,2): Q(2,3), Q(2,3): Q(9,11)}
    weight = Q(99,1000)
    entries = {}
    for p, q in endpoints.items():
        outward_loss = kl(p,q)
        odds_ratio = (q/(1-q))/(p/(1-p))
        if odds_ratio < 1:
            odds_ratio = 1 / odds_ratio
        radius = log(odds_ratio)
        assert outward_loss[0] > B
        assert outward_loss[0] > weight * radius[1]**2
        entries[str(p)] = {'outward_probability': str(q), 'logit_radius': display(radius),
                           'outward_KL': display(outward_loss),
                           'certified_weight': str(weight)}

    # Gram [[2,1],[1,2]] has eigenvalues 3,1. Rank-one row-centered tail²=log(2)².
    log2 = log(Q(2))
    floor = (weight * log2[0]**2 / 6, weight * log2[1]**2 / 6)
    previous = ((log2[0]-Q(1,2))/27, (log2[1]-Q(1,2))/27)
    assert floor[0] > previous[1] and floor[1] < U[0]
    result = {
        'teacher_probabilities': [[str(p) for p in row] for row in teacher],
        'shared_key_probability_row': [str(q) for q in shared],
        'shared_key_feasible_mean_KL': display(U),
        'direct_table_mean_KL': '0',
        'per_cell_budget_from_shared_key': display(total_upper),
        'outward_certificates': entries,
        'rank_one_tail_squared': 'log(2)^2',
        'certified_mean_KL_floor': display(floor),
        'prior_unconditional_floor': display(previous),
        'proof_basis': 'exact rational atanh log intervals with geometric tail, 24 terms',
        'fit_search_or_native_claim': False,
    }
    (HERE/'results.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'new_floor': float(floor[0]), 'old_floor': float(previous[1]),
                      'shared_key_upper': float(U[1])}, indent=2))


if __name__ == '__main__':
    main()
