#!/usr/bin/env python3
"""Actual-route seven-output linear-reuse oracle and fitted coefficient control."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

EXPERT_BYTES = 611_516_416 // 8
FULL_BYTES = 2_626_187_904
THRESHOLDS = (.01, .05, .1)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(root, split):
    base = root / split
    suffixes = {'tokens': ('.tokens', np.int32, ()),
                'scores': ('.0.ffn_moe_weights_norm-0.bin', np.float32, (8,)),
                'down': ('.0.ffn_moe_down-0.bin', np.float32, (8, 2048))}
    n = np.fromfile(str(base) + '.tokens', np.int32).size
    files = {key: Path(str(base) + suffix) for key, (suffix, _, _) in suffixes.items()}
    files['text'] = Path(str(base) + '.txt')
    arrays = {key: np.fromfile(files[key], dtype).reshape((n,) + shape)
              for key, (_, dtype, shape) in suffixes.items()}
    if not np.isfinite(arrays['scores']).all() or not np.isfinite(arrays['down']).all():
        raise ValueError('nonfinite capture')
    if not np.allclose(arrays['scores'].sum(1), 1, atol=1e-5):
        raise ValueError('unnormalized scores')
    return arrays['down'].astype(np.float64) * arrays['scores'][:, :, None], {k: digest(p) for k, p in files.items()}


def oracle(v):
    """Squared projection residual of y onto surviving weighted outputs, per row/omission."""
    n = len(v)
    original = np.sum(v, axis=1)
    target_sq = np.einsum('ni,ni->n', original, original)
    errors = np.zeros((n, 8), np.float64)
    coeffs = np.empty((n, 8, 7), np.float64)
    for t in range(n):
        for missing in range(8):
            keep = np.delete(v[t], missing, axis=0).T
            # QR/SVD least squares, not a normal-equation inverse; projected
            # target lies in span(keep), and each solve is a free hindsight fit.
            b = np.linalg.lstsq(keep, original[t], rcond=None)[0]
            coeffs[t, missing] = b
            residual = original[t] - keep @ b
            errors[t, missing] = residual @ residual
    if np.any(target_sq <= 0):
        raise ValueError('zero target')
    best = np.argmin(errors, axis=1)
    rows = np.arange(n)
    return {'target_sq': target_sq, 'errors': errors, 'best': best,
            'coeffs': coeffs, 'best_sq': errors[rows, best],
            'prefix_sq': errors[:, 7]}


def report(oracle_result):
    q = oracle_result
    denom = np.sum(q['target_sq'])
    d = {'best_any_seven_rms': float(np.sqrt(np.sum(q['best_sq']) / denom)),
         'top_seven_rms': float(np.sqrt(np.sum(q['prefix_sq']) / denom)),
         'hindsight_best_omitted_rank_counts': np.bincount(q['best'], minlength=8).tolist()}
    for name, e in [('best_any_seven', q['best_sq']), ('top_seven', q['prefix_sq'])]:
        d[name + '_tokens_below_limit'] = {str(lim): int(np.count_nonzero(e <= lim**2 * q['target_sq'])) for lim in THRESHOLDS}
        d[name + '_conditional_bytes_saved_percent_if_every_layer_matches'] = {
            str(lim): float(100 * np.count_nonzero(e <= lim**2 * q['target_sq']) * EXPERT_BYTES / (len(e)*FULL_BYTES))
            for lim in THRESHOLDS}
    return d


def learned_directions(train, held):
    # Train directions on residuals orthogonal to the seven retained outputs.
    # Evaluation grants free per-token coefficients of both the seven vectors
    # and the new directions. This is more powerful than a runnable encoder.
    def residuals(v):
        out = np.empty((len(v), 2048), np.float64)
        for t, row in enumerate(v):
            a = row[:7].T
            q, _ = np.linalg.qr(a, mode='reduced')
            out[t] = row[7] - q @ (q.T @ row[7])
        return out

    train_res = residuals(train)
    held_res = residuals(held)
    _, _, vh = np.linalg.svd(train_res, full_matrices=False)
    result = {}
    for name, v, residual in [('train', train, train_res), ('held', held, held_res)]:
        target_sq = np.sum(np.sum(v, axis=1)**2, axis=1)
        result[name] = {}
        for rank in (1, 8, 32):
            remaining_sq = np.empty(len(v), np.float64)
            for t, row in enumerate(v):
                q, _ = np.linalg.qr(row[:7].T, mode='reduced')
                c = vh[:rank].T
                c = c - q @ (q.T @ c)
                b = np.linalg.lstsq(c, residual[t], rcond=None)[0]
                r = residual[t] - c @ b
                remaining_sq[t] = r @ r
            result[name][str(rank)] = {
                'rms': float(np.sqrt(remaining_sq.sum() / target_sq.sum())),
                'tokens_below_limit': {str(x): int(np.count_nonzero(remaining_sq <= x*x*target_sq)) for x in THRESHOLDS},
                'fp16_direction_bytes_per_layer': 2048 * rank * 2,
            }
    return result


def fit_prefix(train, held):
    # One coefficient per retained router rank, trained on full train outputs.
    # These seven constants need no per-token oracle or extra model image beyond 28 bytes.
    a = np.transpose(train, (0, 2, 1))[:, :, :7].reshape(-1, 7)
    y = np.sum(train, axis=1).ravel()
    b = np.linalg.lstsq(a, y, rcond=None)[0]
    out = {'coefficients': b.tolist()}
    for split, v in [('train', train), ('held', held)]:
        target = v.sum(axis=1)
        pred = np.einsum('nkd,k->nd', v[:, :7, :], b)
        err = np.sum((target-pred)**2, axis=1)
        denominator = np.sum(target**2, axis=1)
        out[split] = {'rms': float(np.sqrt(err.sum()/denominator.sum())),
                      'tokens_below_limit': {str(x): int(np.count_nonzero(err <= x*x*denominator)) for x in THRESHOLDS}}
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    train, ht = load(args.capture, 'train')
    held, hh = load(args.capture, 'held')
    result = {'contract': 'FP64 linear span over the eight captured score-weighted GGUF layer-0 outputs. Per-token least squares uses missing output and is a non-executable optimistic oracle. Global seven coefficients and residual SVD directions use only train text, then held text; direction coefficients are free per-token oracle choices. Local Euclidean error; one-read conditional model bytes assume all 40 layers match and free control. Not complete-model quality or native FP32 map.',
              'source_sha256': digest(Path(__file__)),
              'inputs_sha256': {'train': ht, 'held': hh},
              'train': report(oracle(train)), 'held': report(oracle(held)),
              'trained_top_seven': fit_prefix(train, held),
              'learned_directions_oracle': learned_directions(train, held)}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('train', 'held', 'trained_top_seven', 'learned_directions_oracle')}, indent=2))


if __name__ == '__main__':
    main()
