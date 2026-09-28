#!/usr/bin/env python3
"""Finite instruction-cell search with paid producer, table and observer."""
import argparse
import json
import math
import numpy as np

X = np.arange(32, dtype=np.int64)
K = 8


def silu(x):
    return x / (1.0 + np.exp(-x))


def teacher(seed):
    rng = np.random.default_rng(seed)
    g = rng.uniform(.065, .24, size=3)
    b = rng.uniform(-2.8, .7, size=3)
    u = rng.uniform(.025, .16, size=3)
    c = rng.uniform(.05, .9, size=3)
    y = silu(X[:, None] * g + b) * (X[:, None] * u + c)
    return y, dict(g=g.tolist(), b=b.tolist(), u=u.tolist(), c=c.tolist())


def affine_partitions():
    # One integer MAD followed by one logical shift, with no clamp or table lookup
    # in the producer. Reject programs that generate an out-of-table address.
    seen = {}
    for shift in range(2, 11):
        for a in range(1, 257):
            if (a * 31) >> shift > 7:
                break
            for b in range(1 << shift):
                q = (a * X + b) >> shift
                if q[-1] > 7:
                    break
                key = tuple(q.tolist())
                spec = (a, b, shift)
                previous = seen.get(key)
                rank = lambda p: (p[1] != 0, p[0] > 64, p[1] > 64, p[2], p[0], p[1])
                if previous is None or rank(spec) < rank(previous):
                    seen[key] = spec
    return seen


def polynomial_partitions():
    # MUL x,x; logical SHR by a literal. No per-teacher fit or implicit clipping.
    return {tuple(((X * X) >> shift).tolist()): shift
            for shift in range(1, 11) if (31 * 31) >> shift == 7}


def fitted_sse(q, y):
    q = np.asarray(q)
    means = np.zeros((K, y.shape[1]))
    counts = np.bincount(q, minlength=K)
    sums = np.stack([np.bincount(q, weights=y[:, j], minlength=K)
                     for j in range(y.shape[1])], axis=1)
    np.divide(sums, counts[:, None], out=means, where=counts[:, None] != 0)
    means = means.astype(np.float16).astype(np.float64)
    return float(np.sum((y - means[q]) ** 2)), means


def interval_bound(y):
    # Exact DP for optimal 8 contiguous cells with unrestricted vector labels.
    # The emitted FP16 label fit can only have higher error.
    n = len(y)
    prefix = np.vstack((np.zeros(y.shape[1]), np.cumsum(y, axis=0)))
    squares = np.r_[0.0, np.cumsum(np.sum(y*y, axis=1))]
    dp = np.full((K + 1, n + 1), np.inf)
    dp[0, 0] = 0
    cuts = np.zeros((K + 1, n + 1), dtype=int)
    for k in range(1, K + 1):
        for right in range(k, n + 1):
            for left in range(k - 1, right):
                total = prefix[right] - prefix[left]
                sse = squares[right] - squares[left] - total @ total / (right - left)
                v = dp[k - 1, left] + max(0.0, sse)
                if v < dp[k, right]:
                    dp[k, right] = v
                    cuts[k, right] = left
    boundaries = []
    right = n
    for k in range(K, 0, -1):
        right = int(cuts[k, right])
        boundaries.append(right)
    return float(dp[K, n]), sorted(boundaries)[1:]


def run():
    affine = affine_partitions()
    polynomial = polynomial_partitions()
    assert polynomial and all(max(q) <= 7 for q in polynomial)
    records = []
    for kind in ('silu_gate', 'linear', 'unstructured'):
        for seed in range(32):
            if kind == 'silu_gate':
                y, params = teacher(seed)
            elif kind == 'linear':
                rng = np.random.default_rng(seed)
                slope = rng.uniform(.05, 1, size=3)
                intercept = rng.uniform(-2, 2, size=3)
                y = X[:, None] * slope + intercept
                params = dict(slope=slope.tolist(), intercept=intercept.tolist())
            else:
                y = np.random.default_rng(seed).normal(size=(32, 3))
                params = {'random_seed': seed}
            norm = float(np.sum((y - y.mean(axis=0)) ** 2))
            best_affine = min(((fitted_sse(q, y)[0], q, spec)
                               for q, spec in affine.items()), key=lambda p: p[0])
            best_poly = min(((fitted_sse(q, y)[0], q, shift)
                             for q, shift in polynomial.items()), key=lambda p: p[0])
            ideal, cuts = interval_bound(y)
            records.append(dict(kind=kind, seed=seed, teacher=params, centered_energy=norm,
                                affine=dict(relative_rms=math.sqrt(best_affine[0]/norm),
                                            program=list(best_affine[2])),
                                square=dict(relative_rms=math.sqrt(best_poly[0]/norm),
                                            shift=best_poly[2]),
                                optimal_intervals=dict(relative_rms=math.sqrt(ideal/norm), cuts=cuts)))
    return dict(domain='x=0..31, 8 codebook entries, 3 output coordinates',
                affine_unique_partitions=len(affine), polynomial_partitions=len(polynomial),
                records=records)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='results.json')
    args = parser.parse_args()
    result = run()
    with open(args.output, 'w') as f:
        json.dump(result, f, indent=2)
        f.write('\n')
    print('affine partitions', result['affine_unique_partitions'], 'square partitions', result['polynomial_partitions'])
    for kind in ('silu_gate', 'linear', 'unstructured'):
        subset = [r for r in result['records'] if r['kind'] == kind]
        wins = [r['seed'] for r in subset if r['square']['relative_rms'] < r['affine']['relative_rms']]
        print(kind, 'square wins', wins)
    for r in result['records'][:5]:
        print(r['seed'], *(round(r[name]['relative_rms'], 5) for name in ('square', 'affine', 'optimal_intervals')))
