#!/usr/bin/env python3
"""Train-softmax-weighted rank-eight correction for the tied Qwen head and embedding."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from scipy.special import logsumexp

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'tied-rare'))
import study as rare

DATA = Path('/path/to/workspace/data/kelana-subbit/tied-softmax')
SOURCE = rare.SOURCE
TOKENS = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz')


def train_inputs():
    with np.load(SOURCE / 'final-head.npz') as z:
        h = z['train_hidden'].copy()
    with np.load(TOKENS) as z:
        tokens = z['train'][:4].copy()
    def take(positions):
        indices = np.concatenate([i * 256 + positions for i in range(4)])
        return h[indices], tokens[:4, positions + 1].reshape(-1)
    return take(np.arange(4, 255, 16)), take(np.arange(0, 255, 32))


def fit():
    DATA.mkdir(parents=True, exist_ok=True)
    image, labels, scales, code, unit, hidden, original, gold, counts, validation, weight, residual = rare.image_and_residual()
    (input_fit, _), _ = train_inputs()
    order = np.lexsort((np.arange(rare.evaluate.ROWS), -counts))
    exact_ids = order[:1280]
    logits = input_fit @ weight.T
    probabilities = np.exp(logits - logsumexp(logits, axis=1)[:, None])
    curvature = np.mean(probabilities * (1.0 - probabilities), axis=0)
    # The diagonal curvature of categorical cross-entropy is p(1-p).
    # Retained exact rows have no residual to approximate.
    importance = 0.1 + 100000.0 * curvature
    importance[exact_ids] = 0
    root = np.sqrt(importance).astype(np.float32)
    weighted = residual * root[:, None]
    rng = np.random.default_rng(20260922)
    omega = rng.standard_normal((1024, 16)).astype(np.float32)
    q, _ = np.linalg.qr(weighted @ omega, mode='reduced')
    q, _ = np.linalg.qr(weighted @ (weighted.T @ q), mode='reduced')
    u, singular, vt = np.linalg.svd(q.T @ weighted, full_matrices=False)
    left = ((q @ u[:, :8]) * singular[:8]).astype(np.float32)
    left /= np.where(root > 0, root, 1)[:, None]
    left[exact_ids] = 0
    out = DATA / 'rank8.npz'
    np.savez_compressed(out, left=left.astype(np.float16), right=vt[:8].astype(np.float16), exact_ids=exact_ids.astype(np.uint32))
    receipt = {'format': 'tied-softmax-rank8/1', 'image_sha256': rare.sha(out),
               'source_sha256': rare.sha(__file__), 'base_sha256': rare.sha(image),
               'train_hidden_sha256': rare.sha(SOURCE / 'final-head.npz'),
               'fit_positions': '4,20,...,244 from each of four train windows; 64 head inputs',
               'rank': 8, 'exact_frequent_rows': 1280,
               'weights': '0.1 + 100000*mean_train_softmax_p(1-p), zero on exact rows',
               'fit': 'one randomized power iteration, 16 sketch columns; FP16 factors',
               'probability_mass_on_exact': float(probabilities[:, exact_ids].sum(axis=1).mean()),
               'payload_bytes': int(json.loads((SOURCE / 'codebook256.json').read_text())['total_payload_bytes'] + 2 * (left.size + vt[:8].size) + 1280 * (4 + 2048) + 8)}
    receipt['bpw'] = 8 * receipt['payload_bytes'] / (rare.evaluate.ROWS * 1024)
    (DATA / 'fit.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


def assess():
    image, labels, scales, code, unit, hidden, original, gold, counts, val_counts, weight, residual = rare.image_and_residual()
    with np.load(DATA / 'rank8.npz') as z:
        left = z['left'].astype(np.float32); right = z['right'].astype(np.float32)
        exact_ids = z['exact_ids'].copy()
    with np.load(rare.DATA / 'rank16.npz') as z:
        plain_left = z['left'][:, :8].astype(np.float32)
        plain_right = z['right'][:8].astype(np.float32)
    _, (tune_h, tune_gold) = train_inputs()
    base = rare.evaluate.respond(hidden, labels, scales, code, unit)
    tune_base = rare.evaluate.respond(tune_h, labels, scales, code, unit)
    common_valid = hidden @ weight[exact_ids].T
    common_tune = tune_h @ weight[exact_ids].T
    mask = np.ones(rare.evaluate.ROWS, bool); mask[exact_ids] = False
    ids = np.flatnonzero(val_counts)
    denominator = np.sum(val_counts[ids] * np.sum(weight[ids] ** 2, axis=1))
    results = {}
    for name, a, b in [('unweighted', plain_left, plain_right), ('softmax_weighted', left, right)]:
        scores = base + (hidden @ b.T) @ a.T
        scores[:, exact_ids] = common_valid
        train_scores = tune_base + (tune_h @ b.T) @ a.T
        train_scores[:, exact_ids] = common_tune
        calibrated, fitted = rare.calibrate(scores, original, train_scores, tune_gold, exact_ids)
        errors = residual[ids] - a[ids] @ b
        errors[~mask[ids]] = 0
        results[name] = {'head': rare.evaluate.quality(original, calibrated, gold),
                         'uncalibrated_head': rare.evaluate.quality(original, scores, gold),
                         'embedding_validation_weighted_relative_rms': float(np.sqrt(np.sum(val_counts[ids] * np.sum(errors ** 2, axis=1)) / denominator)),
                         'calibration': fitted}
    receipt = {'format': 'tied-softmax-rank8-assessment/1', 'fit_sha256': rare.sha(DATA / 'fit.json'),
               'factor_sha256': rare.sha(DATA / 'rank8.npz'),
               'plain_factor_sha256': rare.sha(rare.DATA / 'rank16.npz'),
               'source_sha256': rare.sha(__file__),
               'head_boundary': 'original BF16 model final hidden; 64 held validation logits; no quantized embedding propagation',
               'calibration': '32 disjoint train positions 0,32,...,224 from four windows, two rare-logit scalars per arm',
               'rates_identical': json.loads((DATA / 'fit.json').read_text())['bpw'],
               'results': results}
    (DATA / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    {'fit': fit, 'assess': assess}[sys.argv[1]]()
