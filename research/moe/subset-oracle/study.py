#!/usr/bin/env python3
"""Exhaustive hindsight subset floor for actual eight-expert Qwen layer-0 captures."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


EXPERT_BYTES = 611_516_416 // 8
FULL_BYTES = 2_626_187_904
EPS = (.01, .05, .10, .20)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def capture(root, split):
    prefix = root / split
    files = {
        'tokens': ('.tokens', np.int32, None),
        'scores': ('.0.ffn_moe_weights_norm-0.bin', np.float32, (8,)),
        'down': ('.0.ffn_moe_down-0.bin', np.float32, (8, 2048)),
    }
    n = len(np.fromfile(str(prefix) + '.tokens', dtype=np.int32))
    arrays = {}
    hashes = {}
    for key, (suffix, dtype, tail) in files.items():
        path = Path(str(prefix) + suffix)
        hashes[key] = sha(path)
        shape = (n, *tail) if tail else (n,)
        arrays[key] = np.memmap(path, dtype=dtype, shape=shape, mode='r')
    hashes['text'] = sha(Path(str(prefix) + '.txt'))
    if not np.isfinite(arrays['scores']).all() or not np.isfinite(arrays['down']).all():
        raise ValueError('nonfinite capture')
    if not np.allclose(arrays['scores'].sum(axis=1), 1, atol=1e-5):
        raise ValueError('scores are not normalized')
    return arrays, hashes


def analyze(arrays):
    scores = np.asarray(arrays['scores'], dtype=np.float64)
    v = np.asarray(arrays['down'], dtype=np.float64) * scores[:, :, None]
    n = len(v)
    # An omitted subset has residual sum_e v_e. The 256 masks enumerate
    # every selection, including cancellation between omitted contributions.
    masks = np.arange(256, dtype=np.uint16)
    omit = ((masks[:, None] >> np.arange(8)) & 1).astype(np.float64)
    counts = omit.sum(axis=1).astype(np.int64)
    squared = np.empty((n, 256), dtype=np.float64)
    target_sq = np.empty(n, dtype=np.float64)
    for i in range(n):
        gram = v[i] @ v[i].T
        squared[i] = np.einsum('mi,ij,mj->m', omit, gram, omit, optimize=True)
        target_sq[i] = gram.sum()
    if np.any(target_sq <= 0) or np.min(squared) < -1e-12 * np.max(target_sq):
        raise ValueError('invalid Gram square')
    squared = np.maximum(squared, 0)
    by_k = {}
    score_order = np.argsort(-scores, axis=1, kind='stable')
    for k in range(1, 9):
        possible = np.flatnonzero(counts == 8 - k)
        best = possible[np.argmin(squared[:, possible], axis=1)]
        best_sq = squared[np.arange(n), best]
        score_mask = (1 << score_order[:, k:]).sum(axis=1).astype(np.int64)
        score_sq = squared[np.arange(n), score_mask]
        by_k[str(k)] = {
            'best_relative_rms': float(np.sqrt(best_sq.sum() / target_sq.sum())),
            'score_order_relative_rms': float(np.sqrt(score_sq.sum() / target_sq.sum())),
            'best_le_threshold': {str(t): int(np.count_nonzero(best_sq <= (t*t)*target_sq)) for t in EPS},
            'score_order_le_threshold': {str(t): int(np.count_nonzero(score_sq <= (t*t)*target_sq)) for t in EPS},
            'hindsight_best_mask_histogram': {str(m): int(c) for m, c in zip(*np.unique(best, return_counts=True))},
        }
    frontier = {}
    for eps in EPS:
        valid = squared <= eps*eps*target_sq[:, None]
        max_omit = np.max(np.where(valid, counts[None, :], -1), axis=1)
        assert np.all(max_omit >= 0)
        skipped = int(max_omit.sum())
        chosen = np.argmax(np.where(valid, counts[None, :], -1), axis=1)
        chosen_sq = squared[np.arange(n), chosen]
        first_score_k = np.full(n, 8, dtype=np.int64)
        for k in range(1, 8):
            remaining = (1 << score_order[:, k:]).sum(axis=1).astype(np.int64)
            ok = squared[np.arange(n), remaining] <= eps*eps*target_sq
            first_score_k[(first_score_k == 8) & ok] = k
        score_skipped = int((8 - first_score_k).sum())
        frontier[str(eps)] = {
            'hindsight_skipped_expert_assignments': skipped,
            'score_order_skipped_expert_assignments': score_skipped,
            'hindsight_tokens_skipping_any': int((max_omit > 0).sum()),
            'hindsight_tokens_skipping_two_or_more': int((max_omit >= 2).sum()),
            'hindsight_histogram_experts_skipped_0_to_8': np.bincount(max_omit, minlength=9).tolist(),
            'hindsight_relative_rms': float(np.sqrt(chosen_sq.sum() / target_sq.sum())),
            'hindsight_conditional_whole_model_bytes_saved_percent': 100 * skipped * EXPERT_BYTES / (n*FULL_BYTES),
            'score_order_conditional_whole_model_bytes_saved_percent': 100 * score_skipped * EXPERT_BYTES / (n*FULL_BYTES),
        }
    # Two vectors may cancel even when neither can safely be omitted alone.
    single_sq = squared[:, counts == 1].min(axis=1)
    pair_sq = squared[:, counts == 2].min(axis=1)
    return {
        'tokens': n,
        'per_retained_count': by_k,
        'adaptive_frontier': frontier,
        'tokens_best_pair_better_than_best_single': int((pair_sq < single_sq).sum()),
        'expert_bytes_per_assignment': EXPERT_BYTES,
        'whole_model_conditional_bytes_per_token': FULL_BYTES,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    panels = {}
    for split in ('train', 'held'):
        arrays, hashes = capture(args.capture, split)
        panels[split] = {'sha256': hashes, 'results': analyze(arrays)}
    output = {
        'contract': 'FP64 sum and Gram arithmetic over captured FP32 layer-0 GGUF expert outputs and FP32 normalized scores. All 256 omitted subsets enumerated. Hindsight knows every omitted output and is not an executable early-stop policy. Byte projection assumes identical behavior at 40 layers, one image read per selected expert, and zero selection overhead. Not native FP32 identity or whole-model language quality.',
        'source_sha256': sha(Path(__file__)),
        'panels': panels,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2) + '\n')
    for split, panel in panels.items():
        r = panel['results']
        print(split, 'best pair beats best single', r['tokens_best_pair_better_than_best_single'])
        print('retained', json.dumps({k: {m: v for m, v in d.items() if m != 'hindsight_best_mask_histogram'} for k, d in r['per_retained_count'].items()}))
        print('frontier', json.dumps(r['adaptive_frontier'], indent=2))


if __name__ == '__main__':
    main()
