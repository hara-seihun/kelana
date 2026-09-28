#!/usr/bin/env python3
"""Fit a shared tied-matrix factor in the actual head-input covariance geometry."""
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
from scipy.special import logsumexp

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('joint_study', HERE.parent / 'joint-spectrum' / 'study.py')
joint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(joint)
DATA = Path('/path/to/workspace/data/kelana-subbit/covariance-factor')
SEED = joint.SEED


def geometry():
    with np.load(joint.SOURCE / 'final-head.npz') as z:
        h = z['train_hidden'].copy()
    indices = np.concatenate([i * 256 + np.arange(4, 256, 8) for i in range(4)])
    h = h[indices].astype(np.float64)
    u, singular, vt = np.linalg.svd(h, full_matrices=False)
    eigen = (singular[:32] ** 2 * 1024 / np.sum(singular ** 2)).astype(np.float32)
    return vt[:32].T.astype(np.float32), eigen, float(np.sum(singular[:32] ** 2) / np.sum(singular ** 2))


def transform(a, v, multiplier):
    return a + ((a @ v) * multiplier) @ v.T


def fit(alpha):
    DATA.mkdir(exist_ok=True, parents=True)
    image, labels, scales, code, unit, hidden, original, gold, counts, val_counts, w, residual = joint.rare.image_and_residual()
    exact = np.lexsort((np.arange(joint.rare.evaluate.ROWS), -counts))[:joint.EXACT]
    logits = np.load(joint.GOLD / 'fit-exact.npy', mmap_mode='r')
    probabilities = np.exp(logits - logsumexp(logits.astype(np.float64), axis=1)[:, None]).astype(np.float32)
    curvature = np.mean(probabilities * (1 - probabilities), axis=0)
    del probabilities
    active = np.ones(len(counts), bool)
    active[exact] = False
    occurrence = counts.astype(np.float64) / counts[active].mean()
    importance = 0.1 + 100000 * curvature + 4 * occurrence
    importance[exact] = 0
    root = np.sqrt(importance).astype(np.float32)
    v, eigen, captured = geometry()
    forward = np.sqrt(1 + alpha * eigen) - 1
    inverse = 1 / np.sqrt(1 + alpha * eigen) - 1
    a = residual * root[:, None]
    if alpha:
        a = transform(a, v, forward)
    rng = np.random.default_rng(SEED)
    q, _ = np.linalg.qr(a @ rng.standard_normal((1024, 16)).astype(np.float32), mode='reduced')
    q, _ = np.linalg.qr(a @ (a.T @ q), mode='reduced')
    u, s, vt = np.linalg.svd(q.T @ a, full_matrices=False)
    left = ((q @ u[:, :joint.RANK]) * s[:joint.RANK]).astype(np.float32)
    left /= np.where(root > 0, root, 1)[:, None]
    left[exact] = 0
    right = vt[:joint.RANK].astype(np.float32)
    if alpha:
        right = transform(right, v, inverse)
    name = f'alpha-{alpha:g}'
    path = DATA / f'{name}.npz'
    np.savez_compressed(path, left=left.astype(np.float16), right=right.astype(np.float16), exact_ids=exact.astype('<u4'))
    reference = json.loads((joint.DATA / 'fit.json').read_text())
    receipt = {'format': 'covariance-factor-fit/1', 'alpha': alpha, 'factor_sha256': joint.sha(path),
               'source_sha256': joint.sha(__file__), 'base_sha256': joint.sha(image),
               'train_head_sha256': joint.sha(joint.SOURCE / 'final-head.npz'),
               'head_sample_sha256': joint.sha(joint.GOLD / 'fit-exact.npy'),
               'head_positions': reference['objective_positions'], 'seed': SEED,
               'metric': 'row_d * (I + alpha * 1024 H32.T H32 / ||H||_F^2); H32 is the top 32 train-head singular directions',
               'row_d': reference['objective_row_weight'], 'covariance_energy_fraction': captured,
               'sketch': reference['fit'], 'exact_rows': joint.EXACT, 'rank': joint.RANK,
               'paid_bytes': reference['paid_bytes'], 'bpw': reference['bpw']}
    (DATA / f'{name}.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


def assess():
    image, labels, scales, code, unit, hidden, original, gold, counts, val_counts, w, residual = joint.rare.image_and_residual()
    tune_h, tune_gold = joint.calibration_inputs()
    base = joint.rare.evaluate.respond(hidden, labels, scales, code, unit)
    tune_base = joint.rare.evaluate.respond(tune_h, labels, scales, code, unit)
    with np.load(joint.DATA / 'rank8.npz') as z:
        exact = z['exact_ids'].copy()
        arms = {'row_diagonal': (z['left'].astype(np.float32), z['right'].astype(np.float32))}
    for alpha in [0, 0.1, 1]:
        with np.load(DATA / f'alpha-{alpha:g}.npz') as z:
            assert np.array_equal(exact, z['exact_ids'])
            arms[f'covariance_{alpha:g}'] = (z['left'].astype(np.float32), z['right'].astype(np.float32))
    valid_exact = hidden @ w[exact].T
    tune_exact = tune_h @ w[exact].T
    ids = np.flatnonzero(val_counts)
    denom = np.sum(val_counts[ids] * np.sum(w[ids] ** 2, axis=1))
    results, losses = {}, {}
    with np.load(joint.SOURCE / 'final-head.npz') as z:
        positions = z['selected_positions'].copy()
    for name, (left, right) in arms.items():
        score = base + (hidden @ right.T) @ left.T
        score[:, exact] = valid_exact
        tune = tune_base + (tune_h @ right.T) @ left.T
        tune[:, exact] = tune_exact
        corrected, calibration = joint.rare.calibrate(score, original, tune, tune_gold, exact)
        losses[name] = logsumexp(corrected.astype(np.float64), axis=1) - corrected[np.arange(len(gold)), gold]
        error = residual[ids] - left[ids] @ right
        error[np.isin(ids, exact)] = 0
        results[name] = {'head': joint.rare.evaluate.quality(original, corrected, gold),
                         'uncalibrated_head': joint.rare.evaluate.quality(original, score, gold),
                         'embedding_validation_weighted_relative_rms': float(np.sqrt(np.sum(val_counts[ids] * np.sum(error ** 2, axis=1)) / denom)),
                         'calibration': calibration}
    paired = {}
    for name in arms:
        if name == 'row_diagonal':
            continue
        gain = losses['row_diagonal'] - losses[name]
        paired[name] = {'lower_nll_positions': int(np.sum(gain > 0)),
                        'mean_gain_by_window': {str(window): float(np.mean(gain[positions[:, 0] == window])) for window in np.unique(positions[:, 0])},
                        'largest_gain': float(np.max(gain)), 'largest_loss': float(-np.min(gain))}
    receipt = {'format': 'covariance-factor-assessment/1', 'source_sha256': joint.sha(__file__),
               'fits': {f'alpha-{alpha:g}': joint.sha(DATA / f'alpha-{alpha:g}.npz') for alpha in [0, .1, 1]},
               'comparison_factor_sha256': joint.sha(joint.DATA / 'rank8.npz'),
               'capture_sha256': joint.sha(joint.SOURCE / 'final-head.npz'),
               'boundary': '128 train-head fit, 32 disjoint train calibration, 64 held original-model validation hidden; no embedding propagation',
               'paid_bpw_all': json.loads((joint.DATA / 'fit.json').read_text())['bpw'],
               'results': results, 'paired': paired}
    (DATA / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    if sys.argv[1] == 'fit':
        fit(float(sys.argv[2]))
    else:
        assess()
