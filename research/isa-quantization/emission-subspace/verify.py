#!/usr/bin/env python3
"""Exact acceptance of a square-root emission-density overlap certificate."""
import hashlib
import importlib.util
import json
from fractions import Fraction as F
from math import isqrt
from pathlib import Path

HERE = Path(__file__).resolve().parent
TREE = HERE.parent / 'categorical-tree'
spec = importlib.util.spec_from_file_location('categorical_intervals', TREE / 'search.py')
intervals = importlib.util.module_from_spec(spec)
spec.loader.exec_module(intervals)
NAMES = ('crossing_label_witness', 'generic_six_law_witness', 'near_disjoint_support_witness')


def source_cases():
    source = json.loads((TREE / 'results.json').read_text())
    cases = {name: {key: source[name][key] for key in ('teacher_laws', 'occupancy', 'candidate_state_budget')}
             for name in NAMES}
    cases['live_context_witness'] = {
        'teacher_laws': [[str(F(a,8)), str(F(4-a,8)), str(F(b,8)), str(F(4-b,8))]
                         for a in (1,3) for b in (1,3)],
        'occupancy': ['1/4']*4, 'candidate_state_budget': 2}
    return cases


def digest(case):
    return hashlib.sha256(json.dumps(case, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def sqrt_interval(x, bits=88):
    assert x >= 0
    scale = 1 << bits
    k = isqrt(x.numerator * scale * scale // x.denominator)
    lo = F(k, scale)
    hi = lo if lo*lo == x else F(k+1, scale)
    assert lo*lo <= x <= hi*hi
    return lo, hi


def density(case):
    p = [[F(x) for x in row] for row in case['teacher_laws']]
    nu = [F(x) for x in case['occupancy']]
    assert all(x >= 0 for row in p for x in row)
    assert all(sum(row) == 1 for row in p)
    assert len(p) == len(nu) and sum(nu) == 1 and all(x >= 0 for x in nu)
    roots = [[sqrt_interval(x) for x in row] for row in p]
    v = len(p[0])
    return [[(sum(nu[s]*roots[s][i][0]*roots[s][j][0] for s in range(len(p))),
              sum(nu[s]*roots[s][i][1]*roots[s][j][1] for s in range(len(p))))
             for j in range(v)] for i in range(v)]


def gram(matrix):
    return [[sum((a*b for a,b in zip(row, col)), F(0)) for col in matrix] for row in matrix]


def verify(case, proposal):
    assert proposal['source_sha256'] == digest(case)
    return {'source_sha256': digest(case),
            **verify_matrix(density(case), case['candidate_state_budget'], proposal)}


def verify_matrix(rho, c, proposal):
    """Accept the same overlap certificate for any enclosed symmetric density."""
    v = len(rho)
    assert 1 <= c <= v
    assert all(len(row) == v for row in rho)
    assert all(rho[i][j] == rho[j][i] for i in range(v) for j in range(v))
    scale = 1 << proposal['scale_bits']
    t = F(proposal['offset'], scale)
    assert t >= 0
    plus = [[F(x, scale) for x in row] for row in proposal['positive_factor']]
    minus = [[F(x, scale) for x in row] for row in proposal['negative_factor']]
    assert len(plus) == len(minus) == v
    assert all(len(row) == v for row in plus+minus)
    gp, gm = gram(plus), gram(minus)
    row_bounds = []
    for i in range(v):
        total = F(0)
        for j in range(v):
            represented = (t if i == j else 0) + gp[i][j] - gm[i][j]
            lo, hi = rho[i][j]
            total += max(abs(lo-represented), abs(hi-represented))
        row_bounds.append(total)
    delta = max(row_bounds)
    upper = c*(t+delta)+sum(gp[i][i] for i in range(v))
    assert upper > 0
    logarithm = intervals.log_interval(upper)
    bound = (max(F(0), -logarithm[1]), max(F(0), -logarithm[0]))
    return {'rank_budget': c,
            'offset': str(t), 'row_error_allowance': str(delta),
            'overlap_upper': str(upper), 'overlap_upper_decimal': float(upper),
            'KL_lower_bound_interval': [str(x) for x in bound],
            'KL_lower_bound_decimal': [float(x) for x in bound],
            'certificate': 'Exact rational Gram reconstruction plus enclosing algebraic density entries; absolute row-sum spectral allowance; no numerical eigenvalues trusted.'}


def main():
    proposals = json.loads((HERE / 'certificates.json').read_text())
    results = {name: verify(case, proposals[name]) for name, case in source_cases().items()}
    tree_results = json.loads((TREE / 'results.json').read_text())
    for name, result in results.items():
        if name in tree_results:
            exact = tree_results[name]['full_categorical_two_state_floor']['interval']
            result['best_tree_floor'] = max(row['independent_nodes']['decimal'][0] for row in tree_results[name]['trees'])
        else:
            study = intervals.Study([[a,4-a,b,4-b] for a in (1,3) for b in (1,3)], [1]*4)
            exact = [str(x) for x in intervals.minimum([
                intervals.add(study.cluster_full(mask), study.cluster_full(study.all ^ mask))
                for mask in study.assignments])]
            result['separate_context_two_label_floors'] = [0, 0]
        assert F(result['KL_lower_bound_interval'][0]) <= F(exact[1])
        result['complete_clustering_interval'] = exact
        print(name, result['KL_lower_bound_decimal'])
    assert results['near_disjoint_support_witness']['KL_lower_bound_decimal'][0] > .69
    (HERE / 'results.json').write_text(json.dumps(results, indent=2)+'\n')


if __name__ == '__main__':
    main()
