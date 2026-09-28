#!/usr/bin/env python3
"""Exact semantic-envelope certificates for a small instruction-image search."""
import argparse
from fractions import Fraction as Q
from itertools import product
import hashlib
import json
import os
from pathlib import Path
import time

os.environ.setdefault('OPENBLAS_NUM_THREADS', '1')
os.environ.setdefault('OMP_NUM_THREADS', '1')
import numpy as np


def solve(a, b):
    m = [[Q(v) for v in row] + [Q(y)] for row, y in zip(a, b)]
    n = len(b)
    for k in range(n):
        pivot = next(i for i in range(k, n) if m[i][k])
        m[k], m[pivot] = m[pivot], m[k]
        div = m[k][k]
        m[k] = [v / div for v in m[k]]
        for i in range(n):
            if i != k:
                div = m[i][k]
                m[i] = [v - div * u for v, u in zip(m[i], m[k])]
    return [row[-1] for row in m]


def certificate(a, f, weights):
    """Full-column-rank integer envelope. Return a rational projection witness."""
    a, f, w = a.tolist(), f.tolist(), weights.tolist()
    k = len(a[0])
    gram = [[sum(wi * row[i] * row[j] for wi, row in zip(w, a))
             for j in range(k)] for i in range(k)]
    rhs = [sum(wi * row[i] * y for wi, row, y in zip(w, a, f)) for i in range(k)]
    coeff = solve(gram, rhs)
    residual = [Q(y) - sum(v * c for v, c in zip(row, coeff)) for row, y in zip(a, f)]
    # Independent exact orthogonality check, not a floating least-squares status.
    assert all(sum(wi * row[j] * r for wi, row, r in zip(w, a, residual)) == 0
               for j in range(k))
    floor = sum(wi * r * r for wi, r in zip(w, residual))
    return dict(coeff=[str(v) for v in coeff], residual=[str(v) for v in residual],
                floor=str(floor))


def replay(a, f, weights, cert):
    coeff = list(map(Q, cert['coeff']))
    residual = list(map(Q, cert['residual']))
    for row, y, r in zip(a.tolist(), f.tolist(), residual):
        assert sum(v * c for v, c in zip(row, coeff)) + r == y
    for j in range(a.shape[1]):
        assert sum(int(w) * int(row[j]) * r for w, row, r in zip(weights, a, residual)) == 0
    assert sum(int(w) * r * r for w, r in zip(weights, residual)) == Q(cert['floor'])


def fiber_floor(h, f, weights):
    total = Q(0)
    for label in set(h.tolist()):
        indices = np.flatnonzero(h == label)
        mass = sum(int(weights[i]) for i in indices)
        mean = Q(sum(int(weights[i]) * int(f[i]) for i in indices), mass)
        total += sum(int(weights[i]) * (Q(int(f[i])) - mean) ** 2 for i in indices)
    return total


def grid_floor(family, weights, cert):
    """Pay the finite coefficient grid through an exact coordinate dual bound."""
    floor = Q(cert['floor'])
    a = family['envelope']
    if a.shape[1] != 3:
        return floor
    gram = (a.T @ (weights[:, None] * a)).tolist()
    theta = list(map(Q, cert['coeff']))
    penalties = []
    for j in range(3):
        inverse_column = solve(gram, [int(i == j) for i in range(3)])
        distance = min(abs(theta[j] - 4*q) for q in range(-8, 9))
        penalties.append(distance * distance / inverse_column[j])
    # The same response displacement pays all constraints; summing is unsound.
    return floor + max(penalties)


def fit(family, f, weights, codes):
    errors = (4 * family['basis'] @ codes.T).T - f
    scores = np.einsum('ij,j,ij->i', errors, weights, errors, optimize=False)
    best = int(np.argmin(scores))
    return int(scores[best]), best


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, default=Path(__file__).with_name('results.json'))
    args = ap.parse_args()
    started = time.perf_counter()
    inputs = np.array(list(product(range(-1, 2), repeat=2)), dtype=np.int64)
    x, y = inputs.T
    packed = (x + 1) + 3 * (y + 1)
    weights = np.array([1, 2, 1, 2, 3, 2, 1, 2, 1], dtype=np.int64)
    # These coefficients are joint operator constants, not per-weight scales.
    codes = np.array(list(product(range(-8, 9), repeat=3)), dtype=np.int64)
    families = []
    for a, b, shift in product((1, 3, 5, 7, 9, 11, 13), range(-8, 9, 4), (1, 2, 3)):
        raw = ((a * packed + b) >> shift) & 7
        h = np.where(raw >= 4, raw - 8, raw)
        basis = np.stack((np.ones(9, dtype=np.int64), h, h*h), axis=1)
        rank = min(3, len(set(h.tolist())))
        # Signed three-bit h followed by Horner, output unit is 1/4.
        families.append(dict(shape=[a, b, shift], h=h, basis=basis,
                             envelope=basis[:, :rank]))
    # Generic rational nonlinear teachers on the complete nine-state domain.
    teacher_basis = np.stack((np.ones(9, dtype=np.int64), x, y, x*y, x*x, y*y,
                              np.maximum(x-y, 0), np.maximum(x+y, 0)*y), axis=1)
    rng = np.random.default_rng(240926)
    trials = []
    for seed in range(12):
        teacher_coeff = rng.integers(-9, 10, size=8, dtype=np.int64)
        f = teacher_basis @ teacher_coeff  # target units are 1/16
        bounds = []
        for family in families:
            cert = certificate(family['envelope'], f, weights)
            replay(family['envelope'], f, weights, cert)
            lower = Q(cert['floor'])
            fiber = fiber_floor(family['h'], f, weights)
            assert lower >= fiber
            discrete = grid_floor(family, weights, cert)
            assert discrete >= lower
            bounds.append((lower, fiber, cert, discrete))
        # Relaxations order the families. Only unpruned families enter packed fit.
        order = sorted(range(len(families)), key=lambda i: (bounds[i][0], i))
        incumbent = None
        evaluated = []
        for i in order:
            if incumbent is not None and bounds[i][0] > incumbent[0]:
                continue
            evaluated.append(i)
            score, code = fit(families[i], f, weights, codes)
            if incumbent is None or (score, i, code) < incumbent:
                incumbent = (score, i, code)
        # Same ordering with only the weaker arbitrary-decoder collision floor.
        fiber_incumbent = None
        fiber_evaluated = []
        for i in sorted(range(len(families)), key=lambda i: (bounds[i][1], i)):
            if fiber_incumbent is not None and bounds[i][1] > fiber_incumbent[0]:
                continue
            fiber_evaluated.append(i)
            score, code = fit(families[i], f, weights, codes)
            if fiber_incumbent is None or (score, i, code) < fiber_incumbent:
                fiber_incumbent = (score, i, code)
        grid_incumbent = None
        grid_evaluated = []
        for i in sorted(range(len(families)), key=lambda i: (bounds[i][3], i)):
            if grid_incumbent is not None and bounds[i][3] > grid_incumbent[0]:
                continue
            grid_evaluated.append(i)
            score, code = fit(families[i], f, weights, codes)
            if grid_incumbent is None or (score, i, code) < grid_incumbent:
                grid_incumbent = (score, i, code)
        # Independent complete oracle is run AFTER all pruned searches.
        oracle = [fit(family, f, weights, codes) for family in families]
        expected = min((score, i, code) for i, (score, code) in enumerate(oracle))
        assert incumbent == expected and fiber_incumbent == expected and grid_incumbent == expected
        assert all(bounds[i][3] <= score for i, (score, _) in enumerate(oracle))
        score, winner, code = incumbent
        family = families[winner]
        coeff = codes[code]
        # Actual fixed five-byte description: a,b,s plus three signed-offset 5-bit codes.
        codeword = sum((int(c)+8) << (5*j) for j, c in enumerate(coeff))
        payload = bytes([family['shape'][0], family['shape'][1] & 255, family['shape'][2]]) + codeword.to_bytes(2, 'little')
        recovered = [(int.from_bytes(payload[3:], 'little') >> (5*j) & 31)-8 for j in range(3)]
        assert recovered == coeff.tolist() and len(payload) == 5
        trials.append(dict(seed=seed, teacher_coefficients_units16=teacher_coeff.tolist(),
                           target_units16=f.tolist(), oracle_loss_units256=score,
                           weighted_mse=str(Q(score, int(weights.sum())*256)),
                           winner_shape=family['shape'], winner_constants_units4=coeff.tolist(),
                           payload_hex=payload.hex(), winner_projection_certificate=bounds[winner][2],
                           projection_family_fits=len(evaluated), fiber_family_fits=len(fiber_evaluated),
                           grid_family_fits=len(grid_evaluated),
                           full_family_fits=len(families), codes_per_family=len(codes),
                           projection_pruned=len(families)-len(evaluated),
                           certified_family_floors=[str(b[0]) for b in bounds],
                           grid_family_floors=[str(b[3]) for b in bounds],
                           exact_family_optima=[v[0] for v in oracle]))
    # Coordinate lower bounds overlap: this Gram matrix makes summation invalid.
    gram = [[20, 18], [18, 20]]
    inverse_jj = solve(gram, [1, 0])[0]
    coordinate_penalty = Q(1, 4) / inverse_jj
    actual_displacement_cost = Q(1)  # d=(1/2,-1/2)
    assert coordinate_penalty <= actual_displacement_cost < 2*coordinate_penalty
    result = dict(source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  overlapping_penalties=dict(gram=gram, displacement=['1/2','-1/2'],
                                            one_bound=str(coordinate_penalty),
                                            summed_invalid_bound=str(2*coordinate_penalty),
                                            actual=str(actual_displacement_cost)),
                  domain=inputs.tolist(), weights=weights.tolist(), target_unit='1/16',
                  candidate_unit='1/4', families=len(families), codes_per_family=len(codes),
                  payload_bytes=5, online_semantic_core='MAD; signed BFE3; MAD; MAD',
                  timing_scope='Python certificate construction and exhaustive reference; no native inference',
                  trials=trials, seconds=time.perf_counter()-started,
                  total_reference_images=sum(t['full_family_fits']*len(codes) for t in trials),
                  total_projection_images=sum(t['projection_family_fits']*len(codes) for t in trials),
                  total_fiber_images=sum(t['fiber_family_fits']*len(codes) for t in trials),
                  total_grid_images=sum(t['grid_family_fits']*len(codes) for t in trials))
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('trials','domain','weights')}, indent=2))


if __name__ == '__main__':
    main()
