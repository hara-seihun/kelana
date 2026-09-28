#!/usr/bin/env python3
"""One paid rank-eight factor fitted to both tied-matrix consumers."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from scipy.special import logsumexp

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'tied-rare'))
import study as rare

DATA = Path('/path/to/workspace/data/kelana-subbit/joint-spectrum')
GOLD = Path('/path/to/workspace/data/kelana-subbit/gold-row')
SOURCE = rare.SOURCE
SOFTMAX = Path('/path/to/workspace/data/kelana-subbit/tied-softmax')
TOKENS = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz')
RANK = 8
EXACT = 1280
SEED = 20260923


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def fit_image():
    DATA.mkdir(exist_ok=True, parents=True)
    image, labels, scales, code, unit, hidden, original, gold, counts, val_counts, w, residual = rare.image_and_residual()
    exact = np.lexsort((np.arange(rare.evaluate.ROWS), -counts))[:EXACT]
    logits = np.load(GOLD / 'fit-exact.npy', mmap_mode='r')
    probabilities = np.exp(logits - logsumexp(logits.astype(np.float64), axis=1)[:, None]).astype(np.float32)
    curvature = np.mean(probabilities * (1 - probabilities), axis=0)
    del probabilities
    active = np.ones(len(counts), bool)
    active[exact] = False
    occurrence = counts.astype(np.float64)
    occurrence /= occurrence[active].mean()
    # The head metric matches the previous curvature fit; train token occurrence
    # adds the input-embedding consumer in units of its average rare-row mass.
    importance = 0.1 + 100000 * curvature + 4 * occurrence
    importance[exact] = 0
    root = np.sqrt(importance).astype(np.float32)
    weighted = residual * root[:, None]
    rng = np.random.default_rng(SEED)
    q, _ = np.linalg.qr(weighted @ rng.standard_normal((1024, 16)).astype(np.float32), mode='reduced')
    q, _ = np.linalg.qr(weighted @ (weighted.T @ q), mode='reduced')
    u, s, vt = np.linalg.svd(q.T @ weighted, full_matrices=False)
    left = ((q @ u[:, :RANK]) * s[:RANK]).astype(np.float32)
    left /= np.where(root > 0, root, 1)[:, None]
    left[exact] = 0
    path = DATA / 'rank8.npz'
    np.savez_compressed(path, left=left.astype(np.float16), right=vt[:RANK].astype(np.float16), exact_ids=exact.astype('<u4'))
    payload = (json.loads((SOURCE / 'codebook256.json').read_text())['total_payload_bytes']
               + 2 * (left.size + RANK * 1024) + EXACT * (4 + 2048) + 8)
    receipt = {'format': 'joint-tied-rank8/1', 'source_sha256': sha(__file__), 'base_sha256': sha(image),
               'input_sha256': sha(GOLD / 'fit-exact.npy'), 'frequency_sha256': sha(SOURCE / 'frequency.npz'),
               'factor_sha256': sha(path), 'rank': RANK, 'seed': SEED, 'exact_frequent_rows': EXACT,
               'objective_row_weight': '0.1 + 100000*mean_train_softmax_p(1-p) + 4*train_count/mean_rare_train_count; exact rows zero',
               'objective_positions': '4,12,...,252 in four train windows, 128 positions',
               'fit': '16-column randomized range sketch, one power iteration, truncated SVD; stored FP16',
               'paid_bytes': int(payload), 'bpw': 8 * payload / (rare.evaluate.ROWS * 1024)}
    (DATA / 'fit.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


def calibration_inputs():
    with np.load(SOURCE / 'final-head.npz') as z:
        h = z['train_hidden'].copy()
    positions = np.arange(0, 255, 32)
    indices = np.concatenate([i * 256 + positions for i in range(4)])
    with np.load(TOKENS) as z:
        gold = z['train'][:4, positions + 1].reshape(-1)
    return h[indices], gold


def assess():
    image, labels, scales, code, unit, hidden, original, gold, counts, val_counts, w, residual = rare.image_and_residual()
    with np.load(DATA / 'rank8.npz') as z:
        left, right, exact = z['left'].astype(np.float32), z['right'].astype(np.float32), z['exact_ids'].copy()
    with np.load(SOFTMAX / 'rank8.npz') as z:
        previous_left, previous_right = z['left'].astype(np.float32), z['right'].astype(np.float32)
        assert np.array_equal(exact, z['exact_ids'])
    tune_h, tune_gold = calibration_inputs()
    base = rare.evaluate.respond(hidden, labels, scales, code, unit)
    tune_base = rare.evaluate.respond(tune_h, labels, scales, code, unit)
    valid_exact = hidden @ w[exact].T
    tune_exact = tune_h @ w[exact].T
    ids = np.flatnonzero(val_counts)
    denom = np.sum(val_counts[ids] * np.sum(w[ids] ** 2, axis=1))
    results = {}
    for name, a, b in [('curvature_only', previous_left, previous_right), ('joint_occurrence', left, right)]:
        score = base + (hidden @ b.T) @ a.T
        score[:, exact] = valid_exact
        tune = tune_base + (tune_h @ b.T) @ a.T
        tune[:, exact] = tune_exact
        corrected, calibration = rare.calibrate(score, original, tune, tune_gold, exact)
        error = residual[ids] - a[ids] @ b
        error[np.isin(ids, exact)] = 0
        results[name] = {'head': rare.evaluate.quality(original, corrected, gold),
                         'uncalibrated_head': rare.evaluate.quality(original, score, gold),
                         'embedding_validation_weighted_relative_rms': float(np.sqrt(np.sum(val_counts[ids] * np.sum(error ** 2, axis=1)) / denom)),
                         'calibration': calibration}
    receipt = {'format': 'joint-tied-rank8-assessment/1', 'source_sha256': sha(__file__),
               'fit_sha256': sha(DATA / 'fit.json'), 'prior_factor_sha256': sha(SOFTMAX / 'rank8.npz'),
               'capture_sha256': sha(SOURCE / 'final-head.npz'),
               'boundary': 'fixed original BF16 final hidden, 64 held validation positions, held corpus embedding counts; no embedding propagation',
               'calibration': '32 disjoint train positions 0,32,...,224 in four windows; two rare-logit scalars per arm',
               'paid_bpw_both': json.loads((DATA / 'fit.json').read_text())['bpw'], 'results': results}
    (DATA / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    {'fit': fit_image, 'assess': assess}[sys.argv[1]]()
