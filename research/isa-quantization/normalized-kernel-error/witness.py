#!/usr/bin/env python3
"""Two fixed witnesses: exact normalized ratios, rational Gaussian-risk intervals."""
from dataclasses import dataclass
from fractions import Fraction as F
from hashlib import sha256
import json
from math import factorial
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent


@dataclass(frozen=True)
class Interval:
    lo: F
    hi: F

    def __post_init__(self):
        assert self.lo <= self.hi

    def __add__(self, other):
        if not isinstance(other, Interval):
            other = Interval(F(other), F(other))
        return Interval(self.lo + other.lo, self.hi + other.hi)

    __radd__ = __add__

    def __neg__(self):
        return Interval(-self.hi, -self.lo)

    def __sub__(self, other):
        if not isinstance(other, Interval):
            other = Interval(F(other), F(other))
        return self + (-other)

    def __mul__(self, other):
        if not isinstance(other, Interval):
            other = Interval(F(other), F(other))
        products = [a * b for a in (self.lo, self.hi) for b in (other.lo, other.hi)]
        return Interval(min(products), max(products))

    __rmul__ = __mul__

    def inverse(self):
        assert self.lo > 0
        return Interval(1 / self.hi, 1 / self.lo)

    def __truediv__(self, other):
        if not isinstance(other, Interval):
            other = Interval(F(other), F(other))
        return self * other.inverse()

    def positive_power(self, n):
        assert self.lo >= 0 and n >= 0
        return Interval(self.lo ** n, self.hi ** n)

    def receipt(self):
        return {'lower_rational': str(self.lo), 'upper_rational': str(self.hi),
                'lower_display': float(self.lo), 'upper_display': float(self.hi),
                'width_display': float(self.hi - self.lo)}


def exp_interval(x):
    x = F(x)
    if x < 0:
        return exp_interval(-x).inverse()
    # All x in this witness are <=16. Positive Taylor terms bound exp from below;
    # the next term and decreasing ratio bound its entire remaining tail above.
    n = 128
    assert x <= 16
    partial = sum((x ** k / factorial(k) for k in range(n + 1)), F(0))
    next_term = x ** (n + 1) / factorial(n + 1)
    ratio = x / (n + 2)
    assert ratio < 1
    return Interval(partial, partial + next_term / (1 - ratio))


def image(name, data):
    path = HERE / name
    path.write_bytes(data)
    return {'file': name, 'bytes': len(data), 'sha256': sha256(data).hexdigest()}


def exact_ratio_witness():
    assets = [image('source.bin', bytes([1, 3, 0, 1])),
              image('common-ratios.bin', bytes([1, 1, 3, 3])),
              image('opposed-ratios.bin', bytes([3, 1, 1, 3]))]
    a, b, v0, v1 = (HERE / 'source.bin').read_bytes()
    p, values = [F(a, a + b), F(b, a + b)], [F(v0), F(v1)]
    y = sum(x * v for x, v in zip(p, values))
    out = {}
    laws = {}
    for name in ['common', 'opposed']:
        raw = (HERE / f'{name}-ratios.bin').read_bytes()
        rows = [[F(raw[2 * j], 2), F(raw[2 * j + 1], 2)] for j in range(2)]
        records = []
        for ratios in rows:
            mean = sum(x * r for x, r in zip(p, ratios))
            output = sum(x * r * v for x, r, v in zip(p, ratios, values)) / mean
            covariance = sum(x * (r - mean) * (v - y)
                             for x, r, v in zip(p, ratios, values))
            centered_variance = sum(x * (r - mean) ** 2 for x, r in zip(p, ratios))
            value_variance = sum(x * (v - y) ** 2 for x, v in zip(p, values))
            bound = centered_variance * value_variance / mean ** 2
            assert output - y == covariance / mean
            assert (output - y) ** 2 <= bound
            records.append({'ratios': list(map(str, ratios)), 'denominator': str(mean),
                            'output': str(output), 'squared_error': str((output - y) ** 2),
                            'cauchy_bound': str(bound)})
        laws[name] = [sorted(row[i] for row in rows) for i in range(2)]
        mse = sum(F(row['squared_error']) for row in records) / 2
        out[name] = {'outcomes': records, 'mean_squared_error': str(mse)}
    assert laws['common'] == laws['opposed'] == [[F(1, 2), F(3, 2)]] * 2
    assert out['common']['mean_squared_error'] == '0'
    assert out['opposed']['mean_squared_error'] == '17/400'
    return {'images': assets, 'teacher': str(y), 'per_key_marginal_mean': '1',
            'per_key_marginal_variance': '1/4', 'same_entire_marginal_laws': True,
            'readers': out}


def risk(q, center):
    odds = exp_interval(2 * q)
    pq_squared = odds.positive_power(2) / (1 + odds).positive_power(4)
    u = F(q) - center
    difference = exp_interval((u - 1) ** 2) + exp_interval((u + 1) ** 2) \
                 - 2 * exp_interval(u ** 2 - 1)
    assert difference.lo > 0
    return pq_squared * difference


def gaussian_witness():
    queries, keys = [F(0), F(4)], [F(-1), F(1)]
    records, risks = [], {}
    for c in [2, 1]:
        asset = image(f'center-{c}.f16', struct.pack('<e', c))
        center = F(struct.unpack('<e', (HERE / asset['file']).read_bytes())[0])
        assert center == c
        # Every score row changes by precisely -q*c, not a changed teacher law.
        for q in queries:
            for k in keys:
                assert q * (k - center) == q * k - q * center
        exponent = sum((q + k - center) ** 2 for q in queries for k in keys) / 4
        assert exponent == 5 + (center - 2) ** 2
        rows = [risk(q, center) for q in queries]
        mean = (rows[0] + rows[1]) / 2
        risks[c] = mean
        records.append({'center': str(center), 'image': asset,
                        'mean_pair_exponent': str(exponent),
                        'per_query_risk': [row.receipt() for row in rows],
                        'mean_leading_output_risk': mean.receipt()})
    assert risks[1].hi < risks[2].lo
    return {'query_law': ['0', '4'], 'keys': ['-1', '1'], 'values': ['0', '1'],
            'law': 'uniform queries and uniform pairs for the exponent objective',
            'records': records,
            'centroid_has_larger_output_risk_certified': True,
            'centroid_to_alternative_risk_ratio': (risks[2] / risks[1]).receipt(),
            'scope': 'Exact analytic iid-Gaussian large-r coefficient, not a finite-r reader measurement.',
            'strong_control': 'Direct sigmoid(2q) is exact on this declared two-key source.'}


def importance_witness():
    cases = 0
    for q in (F(0), F(4)):
        for k in (F(-1), F(1)):
            for c in (F(1), F(2)):
                for w in (F(-1), F(1)):
                    z, t = q + k, w + c
                    log_centered = w * (z - c) - (z - c) ** 2 / 2
                    log_original = t * z - z ** 2 / 2
                    log_weight = -c * t + c ** 2 / 2
                    assert log_centered == log_original + log_weight
                    assert -w ** 2 / 2 + log_centered == -t ** 2 / 2 + log_original
                    cases += 1
    pi, influence, rho = [F(1, 3)] * 3, [F(1, 8), F(1, 8), F(-1, 4)], [F(1, 4), F(1, 4), F(1, 2)]
    assert sum(pi) == sum(rho) == 1 and sum(p * g for p, g in zip(pi, influence)) == 0
    standard = sum(p * g ** 2 for p, g in zip(pi, influence))
    proposal = sum(p ** 2 * g ** 2 / r for p, g, r in zip(pi, influence, rho))
    floor = sum(p * abs(g) for p, g in zip(pi, influence)) ** 2
    assert standard == F(1, 32) and proposal == floor == F(1, 36)
    return {'rational_exponent_checks': cases,
            'finite_proposal_example': {'source_mass': list(map(str, pi)),
                                       'influence': list(map(str, influence)),
                                       'proposal_mass': list(map(str, rho)),
                                       'standard_leading_risk': str(standard),
                                       'optimal_leading_risk': str(proposal)},
            'scope': 'Exact finite identities; no source proposal sampler or finite-r image win.'}


def main():
    result = {'exact_ratios': exact_ratio_witness(), 'gaussian_centers': gaussian_witness(),
              'importance': importance_witness(),
              'certificate': 'Fraction arithmetic; exp Taylor0..128 with positive geometric-tail bound.'}
    (HERE / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'marginal_counterexample_mse': '0 versus17/400',
                      'gaussian_risks': [(r['center'], r['mean_leading_output_risk']['lower_display'])
                                         for r in result['gaussian_centers']['records']],
                      'risk_ratio': result['gaussian_centers']['centroid_to_alternative_risk_ratio']['lower_display']},
                     indent=2))


if __name__ == '__main__':
    main()
