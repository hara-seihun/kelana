#!/usr/bin/env python3
"""A fixed, paid key gauge: exact rational geometry and finite two-feature output."""
from fractions import Fraction as F
from hashlib import sha256
from pathlib import Path
import json
import math
import struct

HERE = Path(__file__).resolve().parent


def lse(values):
    m = max(values)
    return m + math.log(sum(math.exp(x-m) for x in values))


def probability_of_second(scores):
    return math.exp(scores[1] - lse(scores))


def finite_reader(q, keys, center):
    # Fixed omega=(-1,+1); no fitted or sampled feature choice.
    scores = []
    for k in keys:
        z = float(k)-center
        scores.append(lse((float(q)+z, -float(q)-z)) - .5*(float(q)**2+z*z) - math.log(2))
    return probability_of_second(scores)


def main():
    B = F(8)
    queries = (F(-1, 2), F(1, 2))
    keys = (B-1, B+1)
    image = HERE/'center.f16'
    image.write_bytes(struct.pack('<e', float(B)))
    blob = image.read_bytes()
    assert len(blob) == 2
    center = struct.unpack('<e', blob)[0]
    assert F(center) == B
    before_exp = [[(q+k)**2 for k in keys] for q in queries]
    after_exp = [[(q+k-B)**2 for k in keys] for q in queries]
    mean_before = sum(map(sum, before_exp))/4
    mean_after = sum(map(sum, after_exp))/4
    assert mean_before == B*B+F(5, 4) and mean_after == F(5, 4)
    assert max(map(max, before_exp)) == (B+F(3, 2))**2
    assert max(map(max, after_exp)) == F(9, 4)
    rows = []
    for q in queries:
        original = [q*k for k in keys]
        shifted = [q*(k-B) for k in keys]
        assert original[1]-original[0] == shifted[1]-shifted[0] == 2*q
        exact = probability_of_second(list(map(float, original)))
        exact_shifted = probability_of_second(list(map(float, shifted)))
        assert abs(exact-exact_shifted) < 1e-15
        uncentered = finite_reader(q, keys, 0.)
        centered = finite_reader(q, keys, center)
        rows.append({'query': str(q), 'teacher_value': exact,
                     'teacher_shifted_value': exact_shifted,
                     'fixed_two_feature_uncentered_value': uncentered,
                     'fixed_two_feature_centered_value': centered,
                     'uncentered_abs_error': abs(uncentered-exact),
                     'centered_abs_error': abs(centered-exact)})
    result = {'B': str(B), 'query_values': list(map(str, queries)), 'key_values': list(map(str, keys)),
              'exact_variance_exponents_before': [[str(x) for x in row] for row in before_exp],
              'exact_variance_exponents_after': [[str(x) for x in row] for row in after_exp],
              'mean_exponent_before': str(mean_before), 'mean_exponent_after': str(mean_after),
              'mean_reduction': str(mean_before-mean_after),
              'center_field': {'path': image.name, 'bytes': len(blob), 'sha256': sha256(blob).hexdigest()},
              'finite_reader_rows': rows,
              'strong_control': 'direct sigmoid(2q), no prefix feature program required on this fixed family',
              'proof_scope': 'rational score differences and geometry exact; exp/output evaluated in float64',
              'no_random_draw_seed_sweep_or_native_claim': True}
    (HERE/'results.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
