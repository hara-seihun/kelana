#!/usr/bin/env python3
"""Finite shared-coordinate search for a two-channel RMSNorm/SwiGLU residual block."""
import json
import math
from pathlib import Path

import numpy as np


PATTERNS = np.array([[a, b, c, d] for a in (-1., 0., 1.)
                     for b in (-1., 0., 1.) for c in (-1., 0., 1.)
                     for d in (-1., 0., 1.) if (a, b, c, d) != (0., 0., 0., 0.)])
NORM2 = np.sum(PATTERNS ** 2, axis=1)


def quantize(w):
    v = w.reshape(-1)
    scales = np.maximum(PATTERNS @ v, 0) / NORM2
    errors = np.sum((scales[:, None] * PATTERNS - v) ** 2, axis=1)
    i = int(np.argmin(errors))
    return (PATTERNS[i].reshape(2, 2) * scales[i],
            PATTERNS[i].astype(int).reshape(2, 2).tolist(), float(scales[i]), float(errors[i]))


def rotation(degrees):
    a = np.deg2rad(degrees)
    return np.array([[np.cos(a), -np.sin(a)], [np.sin(a), np.cos(a)]])


def silu(x):
    return x / (1 + np.exp(-x))


def block(x, g, u, d):
    n = x / np.sqrt(np.mean(x * x, axis=-1, keepdims=True) + 1e-6)
    return x + (silu(n @ g.T) * (n @ u.T)) @ d.T


def candidate(g, u, d, angle, gain):
    q = rotation(angle)
    s = np.diag([gain, 1.])
    gs, us, ds = g @ q.T, s @ u @ q.T, q @ d @ np.linalg.inv(s)
    fits = [quantize(w) for w in (gs, us, ds)]
    return sum(f[3] for f in fits), [f[0] for f in fits], fits


def evaluate(g, u, d, approx, angle, x, depth=1):
    q = rotation(angle)
    y = x.copy()
    xq = x @ q.T
    for _ in range(depth):
        y = block(y, g, u, d)
        xq = block(xq, *approx)
    pred = xq @ q
    error = pred - y
    return float(np.sqrt(np.mean(error ** 2)) / np.sqrt(np.mean(y ** 2)))


def run():
    q0 = rotation(29.)
    gain0 = 2.5
    gstar = np.array([[1., 1.], [0., -1.]])
    ustar = np.array([[1., -1.], [1., 1.]])
    dstar = np.array([[1., 0.], [-1., 1.]])
    g = gstar @ q0
    u = np.diag([1 / gain0, 1.]) @ ustar @ q0
    d = q0.T @ dstar @ np.diag([gain0, 1.])
    rng = np.random.default_rng(210926)
    train = rng.normal(size=(4096, 2)) * np.array([2.0, 0.3]) + [0.5, -0.25]
    held = rng.normal(size=(4096, 2)) * np.array([0.35, 2.0]) + [-0.6, 0.4]
    angles = range(0, 90)
    gains = [round(0.5 + k * 0.1, 10) for k in range(36)]
    families = {
        'fixed': [(0, 1.)],
        'hadamard': [(45, 1.)],
        'rotation_only': [(a, 1.) for a in angles],
        'gain_only': [(0, h) for h in gains],
        'joint': [(a, h) for a in angles for h in gains],
    }
    result = {'seed': 210926, 'teacher': {'angle_degrees': 29, 'hidden_up_gain': 2.5}, 'arms': {}}
    for name, choices in families.items():
        options = [(candidate(g, u, d, a, h), a, h) for a, h in choices]
        (err, matrices, fits), a, h = min(options, key=lambda item: item[0][0])
        result['arms'][name] = {
            'angle_degrees': a, 'hidden_up_gain': h, 'weight_sse': err,
            'train_relative_rmse': evaluate(g, u, d, matrices, a, train),
            'held_relative_rmse': evaluate(g, u, d, matrices, a, held),
            'held_three_blocks_relative_rmse': evaluate(g, u, d, matrices, a, held, depth=3),
            'codes': [f[1] for f in fits], 'scales': [f[2] for f in fits],
        }
        if name != 'joint':
            # Stronger control: select on block output rather than local weight SSE.
            (_, fitted, _), best_a, best_h = min(options, key=lambda item: evaluate(g, u, d, item[0][1], item[1], train))
            result['arms'][name]['train_selected'] = {
                'angle_degrees': best_a, 'hidden_up_gain': best_h,
                'train_relative_rmse': evaluate(g, u, d, fitted, best_a, train),
                'held_relative_rmse': evaluate(g, u, d, fitted, best_a, held),
                'held_three_blocks_relative_rmse': evaluate(g, u, d, fitted, best_a, held, depth=3),
            }
    # A second nonlinear block shares the residual coordinates but has a
    # different gate, up, down and hidden gain. No fitting uses its outputs.
    g2star = np.array([[0., 1.], [-1., 1.]])
    u2star = np.array([[1., 0.], [-1., -1.]])
    d2star = np.array([[1., 1.], [0., -1.]])
    g2 = g2star @ q0
    u2 = np.diag([1 / 1.8, 1.]) @ u2star @ q0
    d2 = q0.T @ d2star @ np.diag([1.8, 1.])
    transfer = {}
    for name, arm in result['arms'].items():
        a = arm['angle_degrees']
        h2 = min(gains, key=lambda h: candidate(g2, u2, d2, a, h)[0])
        second_sse, second, _ = candidate(g2, u2, d2, a, h2)
        first = candidate(g, u, d, a, arm['hidden_up_gain'])[1]
        q = rotation(a)
        y = block(block(held, g, u, d), g2, u2, d2)
        z = block(block(held @ q.T, *first), *second) @ q
        transfer[name] = {'second_gain': h2, 'second_weight_sse': second_sse,
                          'held_two_distinct_blocks_relative_rmse': float(np.sqrt(np.mean((z - y) ** 2)) / np.sqrt(np.mean(y ** 2)))}
    result['transfer'] = transfer
    assert transfer['joint']['held_two_distinct_blocks_relative_rmse'] < 1e-12
    # A local gain cannot pass through SiLU. Evaluate the same weights with an
    # illicit gate gain to quantify the error rather than calling it a gauge.
    n = held / np.sqrt(np.mean(held * held, axis=-1, keepdims=True) + 1e-6)
    gate = n @ g.T
    up = n @ u.T
    altered = held + (silu(2 * gate) * up / 2) @ d.T
    exact = block(held, g, u, d)
    result['gate_gain_2_relative_rmse'] = float(np.sqrt(np.mean((altered - exact) ** 2)) / np.sqrt(np.mean(exact ** 2)))
    assert result['arms']['joint']['weight_sse'] < 1e-24
    assert result['arms']['joint']['held_relative_rmse'] < 1e-12
    assert result['arms']['rotation_only']['weight_sse'] > 1e-3
    assert result['arms']['gain_only']['weight_sse'] > 1e-3
    Path(__file__).with_name('results.json').write_text(json.dumps(result, indent=2) + '\n')
    for name, arm in result['arms'].items():
        print(f"{name:14} a={arm['angle_degrees']:2} h={arm['hidden_up_gain']:3.1f} sse={arm['weight_sse']:.5g} train={arm['train_relative_rmse']:.5g} held={arm['held_relative_rmse']:.5g} depth3={arm['held_three_blocks_relative_rmse']:.5g}")
        if 'train_selected' in arm:
            print('  train-selected', arm['train_selected'])
    print('distinct-block transfer:', result['transfer'])
    print('illicit gate gain held:', result['gate_gain_2_relative_rmse'])


if __name__ == '__main__':
    run()
