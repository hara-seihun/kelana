#!/usr/bin/env python3
"""Nonbinary shared-producer quotient screen; BLAS single-thread advised."""
import json
import math
from pathlib import Path
import numpy as np

X = np.arange(32, dtype=np.float64)
CELLS = 8
WIDTH = 48


def silu(a):
    return a / (1 + np.exp(-np.clip(a, -80, 80)))


def teacher(seed, kind='silu'):
    rng = np.random.default_rng(seed)
    gate = np.stack((rng.uniform(.025, .21, WIDTH), rng.uniform(-3.8, .7, WIDTH)), axis=1)
    up = np.stack((rng.uniform(.012, .14, WIDTH), rng.uniform(-.7, 1.2, WIDTH)), axis=1)
    down = rng.normal(0, 1 / np.sqrt(WIDTH), (2, WIDTH))
    if kind == 'linear':
        gate[:, 0] = 0
        gate[:, 1] = 1
    return [gate, up, down]


def respond(params, x):
    gate, up, down = params
    x = np.asarray(x)[:, None]
    z = silu(x * gate[:, 0] + gate[:, 1]) * (x * up[:, 0] + up[:, 1])
    return z @ down.T


def cells():
    affine = {}
    for shift in range(2, 11):
        for a in range(1, 257):
            if (31 * a) >> shift > CELLS - 1:
                break
            for b in range(1 << shift):
                code = tuple(((a * X.astype(int) + b) >> shift).tolist())
                if code[-1] > CELLS - 1:
                    break
                affine.setdefault(code, (a, b, shift))
    return affine


def observations(y):
    return np.column_stack((y, y[:, 0] * y[:, 1]))


def norm(y):
    centered = y - y.mean(axis=0)
    return np.maximum((centered * centered).sum(axis=0), 1e-20)


def loss(y, pred):
    truth = observations(y)
    candidate = observations(pred)
    return float((((truth-candidate)**2).sum(axis=0) / norm(truth)).sum())


def fit_code(code, y):
    code = np.array(code, dtype=int)
    exact = np.zeros((CELLS, 2), dtype=np.float64)
    for i in range(CELLS):
        inside = y[code == i]
        if len(inside):
            exact[i] = inside.mean(axis=0)
    table = exact.astype(np.float16).astype(np.float64)
    pred = table[code]
    truth = observations(y)
    h_projection = np.array([truth[code == i, 2].mean() if np.any(code == i) else 0
                             for i in range(CELLS)])
    covariance = float(sum(np.sum(code == i) * (h_projection[i] - exact[i, 0]*exact[i, 1])**2
                           for i in range(CELLS)) / norm(truth)[2])
    derivative_bound = 0.0
    for i in range(CELLS):
        indices = np.flatnonzero(code == i)
        if len(indices) < 2:
            continue
        assert np.all(np.diff(indices) == 1)
        slopes = np.max(np.abs(np.diff(y[indices], axis=0)), axis=0)
        derivative_bound += len(indices) * (np.prod(slopes) * np.var(X[indices]))**2
    derivative_bound /= norm(truth)[2]
    assert covariance <= derivative_bound * (1 + 1e-9) + 1e-12
    direct_h = h_projection.astype(np.float16).astype(np.float64)[code]
    direct_three = float((((y-pred)**2).sum(axis=0) / norm(truth)[:2]).sum() +
                         ((truth[:, 2]-direct_h)**2).sum() / norm(truth)[2])
    return loss(y, pred), covariance, derivative_bound, direct_three, table


def best_affine(y, partitions):
    return min(((fit_code(code, y)[0], code, spec)
                for code, spec in partitions.items()), key=lambda item: item[0])


def ideal_eight_intervals(y):
    output = observations(y)
    weights = 1 / norm(output)
    prefix = np.vstack((np.zeros(3), np.cumsum(output, axis=0)))
    squares = np.vstack((np.zeros(3), np.cumsum(output * output, axis=0)))
    dp = np.full((CELLS + 1, len(y) + 1), np.inf)
    dp[0, 0] = 0
    for k in range(1, CELLS + 1):
        for right in range(k, len(y) + 1):
            for left in range(k - 1, right):
                total = prefix[right] - prefix[left]
                sq = squares[right] - squares[left]
                cost = np.dot(weights, np.maximum(0, sq - total * total / (right - left)))
                dp[k, right] = min(dp[k, right], dp[k - 1, left] + cost)
    return float(dp[CELLS, len(y)])


def quantize(group, step):
    return np.clip(np.rint(group / step), -7, 7).astype(np.int8).astype(np.float64) * step


def scalar_q4(params, y):
    # The two affine coefficient columns and the two down rows get independent scales.
    orig = [params[0][:, 0], params[0][:, 1], params[1][:, 0],
            params[1][:, 1], params[2][0], params[2][1]]
    scales = [float(max(np.max(np.abs(g))/7, .00001)) for g in orig]

    def build(ss):
        fields = [quantize(v, s) for v, s in zip(orig, ss)]
        return [np.stack((fields[0], fields[1]), axis=1),
                np.stack((fields[2], fields[3]), axis=1),
                np.stack((fields[4], fields[5]))]

    def calibrate(p):
        pred = respond(p, X)
        offset = np.empty(2)
        gain = np.empty(2)
        for j in range(2):
            a = np.stack((pred[:, j], np.ones(len(X))), axis=1)
            gain[j], offset[j] = np.linalg.lstsq(a, y[:, j], rcond=None)[0]
        gain = gain.astype(np.float16).astype(np.float64)
        offset = offset.astype(np.float16).astype(np.float64)
        return pred * gain + offset, gain, offset

    choices = np.geomspace(.55, 1.7, 13)
    for _ in range(2):
        for j in range(6):
            candidates = []
            for factor in choices:
                ss = scales.copy()
                ss[j] = float(max(np.max(np.abs(orig[j])) / 7 * factor, 1e-6))
                ss[j] = float(np.float16(ss[j]))
                pred, gain, offset = calibrate(build(ss))
                candidates.append((loss(y, pred), ss[j]))
            scales[j] = min(candidates)[1]
    model = build(scales)
    pred, gain, offset = calibrate(model)
    return loss(y, pred), model, gain, offset, scales


def experiment():
    partitions = cells()
    square = tuple(((X.astype(int)**2) >> 7).tolist())
    records = []
    for kind in ('silu', 'linear', 'unstructured'):
        for seed in range(12):
            source = teacher(seed, 'linear' if kind == 'linear' else 'silu')
            y = respond(source, X) if kind != 'unstructured' else np.random.default_rng(seed).normal(size=(32, 2))
            sq, cov, upper, third, table = fit_code(square, y)
            aff, _, spec = best_affine(y, partitions)
            direct = y.astype(np.float16).astype(np.float64)
            q4 = scalar_q4(source, y)[0] if kind != 'unstructured' else None
            records.append(dict(kind=kind, seed=seed, square=sq, affine=aff,
                                affine_program=list(spec), covariance=cov,
                                derivative_covariance_bound=upper, square_three_table=third,
                                ideal_eight_intervals=ideal_eight_intervals(y),
                                direct_full=loss(y, direct), scalar_q4=q4))
    return dict(domain='integer 0..31, two branches and live product',
                affine_partitions=len(partitions), square_program='(x*x)>>7',
                payload_bytes_estimate={'square_two_branch_fp16_table': 32,
                                'square_three_output_fp16_table': 48,
                                'optimal_interval_three_output_fp16_table_plus_cuts': 53,
                                'direct_two_branch_fp16_table': 128,
                                'scalar_q4_codes': 144, 'scalar_q4_scales': 12,
                                'scalar_q4_output_gain_origin': 8},
                records=records)


if __name__ == '__main__':
    result = experiment()
    Path(__file__).with_name('results.json').write_text(json.dumps(result, indent=2) + '\n')
    for kind in ('silu', 'linear', 'unstructured'):
        subset = [r for r in result['records'] if r['kind'] == kind]
        print(kind, 'square wins', sum(r['square'] < r['affine'] for r in subset),
              'medians', {k:float(np.median([r[k] for r in subset if r[k] is not None]))
                          for k in ('square','square_three_table','affine','ideal_eight_intervals','covariance','derivative_covariance_bound','direct_full','scalar_q4')
                          if any(r[k] is not None for r in subset)})
