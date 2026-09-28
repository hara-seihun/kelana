#!/usr/bin/env python3
"""Exact finite search for two residual ReLU-gated, ternary-down blocks."""
import itertools
import json
import sys

import numpy as np
from scipy.optimize import differential_evolution

TRITS = np.array(list(itertools.product((-1, 0, 1), repeat=2)), dtype=float)
SCALES = np.array((0.5, 1.0, 1.5))
COEFF = (TRITS[:, None, :] * SCALES[None, :, None]).reshape(-1, 2)
CODES = np.repeat(np.arange(len(TRITS)), len(SCALES))
SCALE_IDS = np.tile(np.arange(len(SCALES)), len(TRITS))
TRAIN = np.array(list(itertools.product((0.5, 1.0, 1.5), (-1., -0.5, 0.5, 1.))), dtype=float)
HELD = np.array(list(itertools.product((0.25, 0.75, 1.25, 1.75), (-0.75, -0.25, 0.25, 0.75))), dtype=float)


def block(x, down):
    return x + np.maximum(x[..., 0], 0)[..., None] * x[..., 1, None] * down


def error(y, target):
    return np.mean(np.square(y - target), axis=(-2, -1))


def candidates(x):
    return block(x[None, ...], COEFF[:, None, :])


def composed(x):
    h = candidates(x)
    return block(h[:, None, :, :], COEFF[None, :, None, :])


def best_index(loss):
    return int(np.flatnonzero(loss <= loss.min() + 1e-13)[0])


def code_refit(composed_outputs, target, first, second):
    ids1 = np.flatnonzero(CODES == CODES[first])
    ids2 = np.flatnonzero(CODES == CODES[second])
    subset = error(composed_outputs[np.ix_(ids1, ids2)], target)
    a, b = np.unravel_index(best_index(subset.ravel()), subset.shape)
    return (int(ids1[a]), int(ids2[b]))


def evaluate(teacher, train_outputs, train_first, include_continuous=True):
    t1 = block(TRAIN, teacher[0])
    t2 = block(t1, teacher[1])
    first = best_index(error(train_first, t1))
    teacher_second = best_index(error(candidates(t1), t2))
    seq_second = best_index(error(candidates(train_first[first]), block(train_first[first], teacher[1])))
    joint_losses = error(train_outputs, t2)
    j1, j2 = np.unravel_index(best_index(joint_losses.ravel()), joint_losses.shape)
    controls = {
        'independent': (first, teacher_second),
        'sequential': (first, seq_second),
        'independent_refit': code_refit(train_outputs, t2, first, teacher_second),
        'sequential_refit': code_refit(train_outputs, t2, first, seq_second),
        'downstream_code_only': (first, j2),
        'upstream_scale_only': (j1, teacher_second),
        'joint': (j1, j2),
    }
    held_target = block(block(HELD, teacher[0]), teacher[1])
    held_outputs = composed(HELD)
    continuous = {}
    for name in (('independent', 'sequential') if include_continuous else ()):
        i, k = controls[name]
        code1, code2 = TRITS[CODES[i]], TRITS[CODES[k]]

        def objective(scales):
            return float(error(block(block(TRAIN, scales[0] * code1), scales[1] * code2), t2))

        fit = differential_evolution(objective, ((0, 3), (0, 3)), seed=1,
                                     tol=1e-11, polish=True)
        y = block(block(HELD, fit.x[0] * code1), fit.x[1] * code2)
        continuous[name] = {'scales': fit.x.tolist(), 'train_mse': float(fit.fun),
                            'held_mse': float(error(y, held_target))}
    return {
        'teacher': [list(a) for a in teacher],
        'first_local_error': float(error(train_first[first], t1)),
        'controls': {name: {
            'indices': [int(i), int(k)],
            'codes': [TRITS[CODES[i]].astype(int).tolist(), TRITS[CODES[k]].astype(int).tolist()],
            'scales': [float(SCALES[SCALE_IDS[i]]), float(SCALES[SCALE_IDS[k]])],
            'train_mse': float(joint_losses[i, k]),
            'held_mse': float(error(held_outputs[i, k], held_target)),
            'first_local_mse': float(error(train_first[i], t1)),
        } for name, (i, k) in controls.items()},
        'teacher_gate_crossings_train': int(np.count_nonzero(t1[:, 0] < 0)),
        'joint_gate_crossings_train': int(np.count_nonzero(train_first[j1, :, 0] < 0)),
        'continuous_scale_refit': continuous,
        'sum_preservation_lower_bound': {
            'train_mse': float(np.mean(np.square(t2.sum(axis=-1) - TRAIN.sum(axis=-1))) / 4),
            'held_mse': float(np.mean(np.square(held_target.sum(axis=-1) - HELD.sum(axis=-1))) / 4),
        },
    }


def discover():
    train_outputs = composed(TRAIN)
    train_first = candidates(TRAIN)
    values = (-1.25, -0.75, -0.25, 0.25, 0.75, 1.25)
    best = None
    for a, b, c, d in itertools.product(values, repeat=4):
        result = evaluate(((a, b), (c, d)), train_outputs, train_first, include_continuous=False)
        q = result['controls']
        baseline = min(q['independent_refit']['train_mse'], q['sequential_refit']['train_mse'])
        gain = baseline - q['joint']['train_mse']
        if q['joint']['first_local_mse'] <= q['independent']['first_local_mse'] + 1e-12:
            continue
        if q['joint']['train_mse'] < 0.7 * baseline and gain > 0.008:
            key = (gain, -q['joint']['train_mse'])
            if best is None or key > best[0]:
                best = (key, result)
    return evaluate(best[1]['teacher'], train_outputs, train_first)


if __name__ == '__main__':
    train_outputs = composed(TRAIN)
    train_first = candidates(TRAIN)
    if len(sys.argv) == 1:
        result = discover()
    else:
        teacher = json.loads(sys.argv[1])
        result = evaluate(teacher, train_outputs, train_first)
    print(json.dumps(result, indent=2))
