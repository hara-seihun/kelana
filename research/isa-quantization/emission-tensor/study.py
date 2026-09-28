#!/usr/bin/env python3
"""An all-power fidelity hierarchy, with one analytically selected power."""
import argparse
import json
import sys
from fractions import Fraction as F
from pathlib import Path

HERE = Path(__file__).resolve().parent
OWNER = HERE.parent / 'emission-subspace'
sys.path.insert(0, str(OWNER))
import verify as certificate


def cases():
    out = certificate.source_cases()
    out['three_bernoulli_laws'] = {
        'teacher_laws': [['1/4', '3/4'], ['1/2', '1/2'], ['3/4', '1/4']],
        'occupancy': ['1/3']*3, 'candidate_state_budget': 2}
    out['duplicate_law_control'] = {
        'teacher_laws': [['1/4', '3/4'], ['3/4', '1/4']]*2,
        'occupancy': ['1/4']*4, 'candidate_state_budget': 2}
    return out


def collapse(case):
    merged = {}
    for row, mass in zip(case['teacher_laws'], case['occupancy']):
        key, weight = tuple(F(x) for x in row), F(mass)
        assert weight >= 0 and all(x >= 0 for x in key) and sum(key) == 1
        if weight:
            merged[key] = merged.get(key, F(0))+weight
    assert sum(merged.values()) == 1
    return tuple(merged), tuple(merged.values())


def outward(lo, hi):
    return certificate.intervals.outward(lo, hi)


def multiply(x, y):
    assert x[0] >= 0 and y[0] >= 0
    return outward(x[0]*y[0], x[1]*y[1])


def power(interval, k):
    assert k >= 0
    value = (F(1), F(1))
    while k:
        if k & 1:
            value = multiply(value, interval)
        interval = multiply(interval, interval)
        k >>= 1
    return value


def fidelities(p):
    roots = [[certificate.sqrt_interval(x) for x in row] for row in p]
    n = len(p)
    out = [[None]*n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            if i == j:
                out[i][j] = (F(1), F(1))
            else:
                lo = sum(a[0]*b[0] for a,b in zip(roots[i], roots[j]))
                hi = min(F(1), sum(a[1]*b[1] for a,b in zip(roots[i], roots[j])))
                out[i][j] = outward(lo, hi)
    return out


def source_gram(p, nu, k):
    fidelity = fidelities(p)
    n = len(p)
    gram = [[None]*n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            if i == j:
                gram[i][j] = (nu[i], nu[i])
            else:
                gram[i][j] = multiply(certificate.sqrt_interval(nu[i]*nu[j]), power(fidelity[i][j], k))
    return gram


def selected_power(p, nu, c):
    fidelity = fidelities(p)
    n = len(p)
    kappa = max(fidelity[i][j][1] for i in range(n) for j in range(n) if i != j)
    assert kappa < 1, 'These exact fixtures need separated distinct fidelity intervals.'
    radius = max(sum(certificate.sqrt_interval(nu[i]*nu[j])[1] for j in range(n) if i != j) for i in range(n))
    top_weight = sum(sorted(nu, reverse=True)[:c])
    threshold = (1-top_weight)/(2*c*radius)
    if kappa == 0 or threshold >= 1:
        k = 1
    else:
        log_threshold = certificate.intervals.log_interval(threshold)[0]
        log_kappa = certificate.intervals.log_interval(kappa)[1]
        assert log_kappa < 0
        ratio = log_threshold/log_kappa
        k = -((-ratio.numerator)//ratio.denominator)+1
    power_upper = power((kappa,kappa), k)[1]
    assert power_upper <= threshold
    overlap = top_weight+c*radius*power_upper
    assert overlap < 1
    bound = certificate.intervals.scaled(F(-1,k), certificate.intervals.log_interval(overlap))
    return k, {'maximum_fidelity_upper': str(kappa), 'off_diagonal_row_factor': str(radius),
               'top_C_occupancy': str(top_weight), 'coherence_threshold': str(threshold),
               'Gershgorin_overlap_upper': str(overlap),
               'Gershgorin_KL_lower_interval': [str(x) for x in bound]}


def propose():
    import numpy as np
    from propose import factor_density
    output = {}
    for name, case in cases().items():
        p, nu = collapse(case)
        c = case['candidate_state_budget']
        record = {'source_sha256': certificate.digest(case), 'distinct_laws': len(p)}
        if len(p) <= c:
            record['exact_label_assignment_exists'] = True
        else:
            k, choice = selected_power(p,nu,c)
            record.update({'selected_power': k, 'selection': choice, 'certificates': {}})
            for degree in (1,k):
                gram = source_gram(p,nu,degree)
                mid = np.array([[float((lo+hi)/2) for lo,hi in row] for row in gram])
                record['certificates'][str(degree)] = factor_density(mid,c)
        output[name] = record
    (HERE/'certificates.json').write_text(json.dumps(output,indent=2)+'\n')


def check():
    proposals = json.loads((HERE/'certificates.json').read_text())
    output = {}
    for name, case in cases().items():
        p,nu = collapse(case)
        c = case['candidate_state_budget']
        record = proposals[name]
        assert record['source_sha256'] == certificate.digest(case)
        result = {'source_sha256': record['source_sha256'], 'distinct_laws': len(p), 'capacity': c,
                  'vocabulary': len(p[0])}
        if len(p) <= c:
            assert record['exact_label_assignment_exists']
            result['exact_marginal_KL'] = 0
        else:
            k, choice = selected_power(p,nu,c)
            assert record['selected_power'] == k and record['selection'] == choice
            result.update({'selected_power': k, 'selection': choice, 'bounds': {}})
            for degree in (1,k):
                receipt = certificate.verify_matrix(source_gram(p,nu,degree), c, record['certificates'][str(degree)])
                interval = [F(x)/degree for x in receipt['KL_lower_bound_interval']]
                receipt['per_original_emission_KL_interval'] = [str(x) for x in interval]
                receipt['per_original_emission_KL_decimal'] = [float(x) for x in interval]
                receipt['virtual_vocabulary_dimension'] = f'{len(p[0])}^{degree}'
                receipt['actual_Gram_dimension'] = len(p)
                result['bounds'][str(degree)] = receipt
            assert F(result['bounds'][str(k)]['per_original_emission_KL_interval'][0]) > 0
        oracle = certificate.intervals.Study([list(row) for row in p], list(nu))
        exact = certificate.intervals.minimum([
            certificate.intervals.add(oracle.cluster_full(mask), oracle.cluster_full(oracle.all ^ mask))
            for mask in oracle.assignments])
        result['complete_two_label_clustering_interval'] = [str(x) for x in exact]
        result['complete_two_label_clustering_decimal'] = [float(x) for x in exact]
        for row in result.get('bounds', {}).values():
            assert F(row['per_original_emission_KL_interval'][0]) <= exact[1]
        output[name] = result
        print(name, 'laws',len(p), 'power',result.get('selected_power'),
              {key: row['per_original_emission_KL_decimal'][0] for key,row in result.get('bounds',{}).items()})
    b = output['three_bernoulli_laws']
    assert b['bounds']['1']['per_original_emission_KL_decimal'][0] < 1e-9
    (HERE/'results.json').write_text(json.dumps(output,indent=2)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action',choices=('propose','check'))
    args = parser.parse_args()
    (propose if args.action == 'propose' else check)()
