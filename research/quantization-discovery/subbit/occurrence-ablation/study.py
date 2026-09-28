#!/usr/bin/env python3
"""Hold the head sample and factor sketch fixed while removing occurrence weight."""
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

DATA = Path('/path/to/workspace/data/kelana-subbit/occurrence-ablation')


def fit():
    DATA.mkdir(parents=True, exist_ok=True)
    image, labels, scales, code, unit, hidden, original, gold, counts, val_counts, w, residual = joint.rare.image_and_residual()
    exact = np.lexsort((np.arange(joint.rare.evaluate.ROWS), -counts))[:joint.EXACT]
    logits = np.load(joint.GOLD / 'fit-exact.npy', mmap_mode='r')
    probabilities = np.exp(logits - logsumexp(logits.astype(np.float64), axis=1)[:, None]).astype(np.float32)
    curvature = np.mean(probabilities * (1 - probabilities), axis=0)
    del probabilities
    importance = 0.1 + 100000 * curvature
    importance[exact] = 0
    root = np.sqrt(importance).astype(np.float32)
    weighted = residual * root[:, None]
    rng = np.random.default_rng(joint.SEED)
    q, _ = np.linalg.qr(weighted @ rng.standard_normal((1024, 16)).astype(np.float32), mode='reduced')
    q, _ = np.linalg.qr(weighted @ (weighted.T @ q), mode='reduced')
    u, s, vt = np.linalg.svd(q.T @ weighted, full_matrices=False)
    left = ((q @ u[:, :joint.RANK]) * s[:joint.RANK]).astype(np.float32)
    left /= np.where(root > 0, root, 1)[:, None]
    left[exact] = 0
    path = DATA / 'rank8-head-only.npz'
    np.savez_compressed(path, left=left.astype(np.float16), right=vt[:joint.RANK].astype(np.float16), exact_ids=exact.astype('<u4'))
    prior = json.loads((joint.DATA / 'fit.json').read_text())
    receipt = {'format': 'occurrence-ablation-fit/1', 'factor_sha256': joint.sha(path),
               'source_sha256': joint.sha(__file__), 'base_sha256': joint.sha(image),
               'head_sample_sha256': joint.sha(joint.GOLD / 'fit-exact.npy'),
               'comparison_factor_sha256': joint.sha(joint.DATA / 'rank8.npz'),
               'objective': '0.1 + 100000*mean_train_softmax_p(1-p); exact rows zero',
               'head_positions': prior['objective_positions'], 'seed': joint.SEED,
               'sketch': prior['fit'], 'rank': joint.RANK, 'exact_rows': joint.EXACT,
               'paid_bytes': prior['paid_bytes'], 'bpw': prior['bpw']}
    (DATA / 'fit.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


def assess():
    image, labels, scales, code, unit, hidden, original, gold, counts, val_counts, w, residual = joint.rare.image_and_residual()
    with np.load(DATA / 'rank8-head-only.npz') as z:
        control = (z['left'].astype(np.float32), z['right'].astype(np.float32), z['exact_ids'].copy())
    with np.load(joint.DATA / 'rank8.npz') as z:
        occurrence = (z['left'].astype(np.float32), z['right'].astype(np.float32), z['exact_ids'].copy())
    assert np.array_equal(control[2], occurrence[2])
    exact = control[2]
    tune_h, tune_gold = joint.calibration_inputs()
    base = joint.rare.evaluate.respond(hidden, labels, scales, code, unit)
    tune_base = joint.rare.evaluate.respond(tune_h, labels, scales, code, unit)
    valid_exact = hidden @ w[exact].T
    tune_exact = tune_h @ w[exact].T
    ids = np.flatnonzero(val_counts)
    denom = np.sum(val_counts[ids] * np.sum(w[ids] ** 2, axis=1))
    results = {}
    per_position = {}
    with np.load(joint.SOURCE / 'final-head.npz') as z:
        positions = z['selected_positions'].copy()
    for name, (left, right, _) in [('head_only', control), ('head_plus_occurrence', occurrence)]:
        score = base + (hidden @ right.T) @ left.T
        score[:, exact] = valid_exact
        tune = tune_base + (tune_h @ right.T) @ left.T
        tune[:, exact] = tune_exact
        corrected, calibration = joint.rare.calibrate(score, original, tune, tune_gold, exact)
        per_position[name] = logsumexp(corrected.astype(np.float64), axis=1) - corrected[np.arange(len(gold)), gold]
        error = residual[ids] - left[ids] @ right
        error[np.isin(ids, exact)] = 0
        results[name] = {'head': joint.rare.evaluate.quality(original, corrected, gold),
                         'uncalibrated_head': joint.rare.evaluate.quality(original, score, gold),
                         'embedding_validation_weighted_relative_rms': float(np.sqrt(np.sum(val_counts[ids] * np.sum(error ** 2, axis=1)) / denom)),
                         'calibration': calibration}
    gain = per_position['head_only'] - per_position['head_plus_occurrence']
    paired = {'occurrence_lower_nll_positions': int(np.sum(gain > 0)),
              'occurrence_higher_nll_positions': int(np.sum(gain < 0)),
              'mean_gain_by_validation_window': {str(window): float(np.mean(gain[positions[:, 0] == window])) for window in np.unique(positions[:, 0])},
              'largest_gain': float(np.max(gain)), 'largest_loss': float(-np.min(gain)),
              'mean_gain_without_largest': float((np.sum(gain) - np.max(gain)) / (len(gain) - 1))}
    receipt = {'format': 'occurrence-ablation-assessment/1', 'source_sha256': joint.sha(__file__),
               'fit_sha256': joint.sha(DATA / 'fit.json'), 'capture_sha256': joint.sha(joint.SOURCE / 'final-head.npz'),
               'boundary': 'same 128 train head inputs, 32 disjoint train calibration inputs, 64 held validation head inputs, fixed original-model hidden; no embedding propagation',
               'paid_bpw_both': json.loads((DATA / 'fit.json').read_text())['bpw'], 'results': results, 'paired_head': paired}
    (DATA / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    {'fit': fit, 'assess': assess}[sys.argv[1]]()
