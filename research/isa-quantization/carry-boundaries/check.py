#!/usr/bin/env python3
"""Exhaustive finite certificate for a one-cell byte-table approximation."""
from itertools import product
import json

Q = (32, 32, 32, 32)
SIGNS = tuple(product((-1, 1), repeat=3))


def half_table(q):
    return tuple(q[0] + sum(s * c for s, c in zip(signs, q[1:])) for signs in SIGNS)


def byte(value):
    return max(-128, min(127, value))


exact = half_table(Q)
approx = tuple(map(byte, exact))
assert exact == (-64, 0, 0, 64, 0, 64, 64, 128)
assert approx == exact[:-1] + (127,)
assert sum((x-y)**2 for x, y in zip(exact, approx)) == 1
shifted = tuple(x-1 for x in exact)
assert all(-128 <= x <= 127 for x in shifted)
assert all(x+1 == target for x, target in zip(shifted, exact))

# Every byte LUT is a product of independent per-cell choices. The nearest
# legal integer to a target cell uniquely minimizes its squared error.
for x, y in zip(exact, approx):
    assert (x-y)**2 == min((x-v)**2 for v in range(-128, 128))

# Signed integer coefficient changes with one-step or larger perturbations.
# For any coefficient vector q', sign-basis orthogonality over all eight
# half-orbit inputs gives sum_t (F_q(t)-F_q'(t))^2 = 8 sum_i(q_i-q'_i)^2.
nearby = []
for delta in product((-1, 0, 1), repeat=4):
    q = tuple(a+b for a, b in zip(Q, delta))
    table = half_table(q)
    if all(-128 <= x <= 127 for x in table):
        error = sum((a-b)**2 for a, b in zip(exact, table))
        nearby.append((error, delta))
assert min(nearby)[0] == 8
assert sum((x-y)**2 for x, y in zip(exact, half_table((31, 32, 32, 32)))) == 8

# Exact two-part response: first term q0 +/- q1, second +/-q2 +/-q3.
left = tuple(Q[0] + t*Q[1] for t in (-1, 1))
right = tuple(s*Q[2] + t*Q[3] for s, t in product((-1, 1), repeat=2))
assert len(left) + len(right) == 6
assert all(-128 <= x <= 127 for x in left + right)
for signs, target, stored in zip(SIGNS, exact, approx):
    pair = left[(-1, 1).index(signs[0])] + right[
        tuple(product((-1, 1), repeat=2)).index(signs[1:])]
    assert pair == target
    assert stored + int(signs == (1, 1, 1)) == target
    for first_sign in (-1, 1):
        assert first_sign*target == sum(c*s for c, s in zip(Q,
            (first_sign,) + tuple(first_sign*t for t in signs)))

print(json.dumps({
    'domain_size': 16,
    'half_table': exact,
    'clipped_table': approx,
    'exact_pair_tables': {'first': left, 'second': right},
    'exact_biased_table': shifted,
    'uniform_half_orbit_mse': 1/8,
    'uniform_full_sign_mse': 1/8,
    'coefficient_change_minimum_mse': min(x[0] for x in nearby)/8,
    'coefficient_change_nearby_solutions': sum(x[0] == 8 for x in nearby),
    'maximum_absolute_error': 1,
}, indent=2))
