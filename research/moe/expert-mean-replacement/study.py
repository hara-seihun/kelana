#!/usr/bin/env python3
"""Train-only per-expert output prototypes for actual routed Qwen layer-0 sums."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

EXPERT_IMAGE = 611_516_416 // 8
WHOLE_READ = 2_626_187_904
LIMITS = (.01, .05, .1, .2)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(root, split):
    base = root / split
    names = {'tokens': ('.tokens', np.int32, ()),
             'ids': ('.0.ffn_moe_topk-0.bin', np.int32, (8,)),
             'scores': ('.0.ffn_moe_weights_norm-0.bin', np.float32, (8,)),
             'down': ('.0.ffn_moe_down-0.bin', np.float32, (8, 2048))}
    n = np.fromfile(str(base) + '.tokens', np.int32).size
    paths = {key: Path(str(base) + suffix) for key, (suffix, _, _) in names.items()}
    paths['text'] = Path(str(base) + '.txt')
    data = {key: np.fromfile(paths[key], dtype).reshape((n,) + shape)
            for key, (_, dtype, shape) in names.items()}
    if not np.all((data['ids'] >= 0) & (data['ids'] < 256)):
        raise ValueError('expert ids outside bank')
    if not np.allclose(data['scores'].sum(axis=1), 1, atol=1e-5):
        raise ValueError('unnormalized scores')
    if not np.isfinite(data['down']).all() or not np.isfinite(data['scores']).all():
        raise ValueError('nonfinite data')
    return data, {k: digest(p) for k, p in paths.items()}


def evaluate(data, dictionary, counts):
    ids, scores = data['ids'], data['scores'].astype(np.float64)
    outputs = data['down'].astype(np.float64)
    target = (scores[:, :, None] * outputs).sum(axis=1)
    den = np.sum(target * target, axis=1)
    if np.any(den <= 0):
        raise ValueError('zero routed response')
    covered = counts[ids] > 0
    missing = scores[:, :, None] * outputs
    error = scores[:, :, None] * (outputs - dictionary[ids])
    lost_sq = np.sum(missing**2, axis=2)
    err_sq = np.sum(error**2, axis=2)
    rows = np.arange(len(ids))
    # Actual inference: lowest-score trained expert; no substitution if none was seen.
    pick = np.argmin(np.where(covered, scores, np.inf), axis=1)
    chosen = covered[rows, pick]
    selected = np.where(chosen, err_sq[rows, pick], 0)
    baseline = np.where(chosen, lost_sq[rows, pick], 0)
    # A non-executable comparator sees the omitted output when picking the expert.
    oracle_pick = np.argmin(np.where(covered, err_sq, np.inf), axis=1)
    oracle = np.where(chosen, err_sq[rows, oracle_pick], 0)
    raw_pick = np.argmin(scores, axis=1)
    raw_baseline = lost_sq[rows, raw_pick]
    def statistics(sq, eligible):
        return {'relative_rms': float(np.sqrt(sq.sum() / den.sum())),
                'eligible_tokens': int(eligible.sum()),
                'eligible_under': {str(t): int(np.count_nonzero(eligible & (sq <= t*t*den))) for t in LIMITS},
                'eligible_conditional_whole_read_saving_percent': {
                    str(t): 100 * int(np.count_nonzero(eligible & (sq <= t*t*den))) * EXPERT_IMAGE / (len(ids)*WHOLE_READ)
                    for t in LIMITS}}
    return {'tokens': len(ids), 'tokens_with_trained_candidate': int(chosen.sum()),
            'candidate_slots': int(covered.sum()), 'selected_rank_histogram': np.bincount(pick[chosen], minlength=8).tolist(),
            'train_covered_expert_ids': int(np.count_nonzero(counts)),
            'all_score_lowest_omission': statistics(raw_baseline, np.ones(len(ids), dtype=bool)),
            'trained_candidate_omission': statistics(baseline, chosen),
            'trained_candidate_fp16_mean': statistics(selected, chosen),
            'free_best_trained_candidate_mean': statistics(oracle, chosen),
            'selected_mean_better_than_omission': int(np.count_nonzero(chosen & (selected < baseline)))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    train, th = load(args.capture, 'train')
    held, hh = load(args.capture, 'held')
    counts = np.bincount(train['ids'].ravel(), minlength=256)
    means = np.zeros((256, 2048), np.float64)
    np.add.at(means, train['ids'].ravel(), train['down'].reshape(-1, 2048).astype(np.float64))
    means[counts > 0] /= counts[counts > 0, None]
    # Charge the deployed image, not an unquantized fit or an ideal entropy bound.
    packed = means.astype('<f2')
    args.out.parent.mkdir(parents=True, exist_ok=True)
    image_path = args.out.parent / 'layer-0-means.fp16'
    mask_path = args.out.parent / 'layer-0-coverage.bin'
    image_path.write_bytes(packed.tobytes())
    mask_path.write_bytes(np.packbits(counts > 0, bitorder='little').tobytes())
    means = packed.astype(np.float64)
    result = {'contract': 'Only train-captured FP32 layer-0 per-expert down outputs fit a fixed FP16 mean. Held chooses the lowest-score trained expert, reconstructs its mean, and measures FP64 eight-score weighted local sum against captured FP32 outputs. Zero substitution when no expert is trained. The free best-choice selector uses held missing output and is not executable. Scores and IDs are captured callback values; no native FP32 identity, complete-model language quality or GPU timing.',
              'source_sha256': digest(Path(__file__)), 'inputs_sha256': {'train': th, 'held': hh},
              'image': {'all_expert_fp16_means_bytes_per_layer': image_path.stat().st_size,
                        'coverage_mask_bytes_per_layer': mask_path.stat().st_size,
                        'fp16_means_sha256': digest(image_path),
                        'coverage_mask_sha256': digest(mask_path),
                        'existing_expert_image_bytes_per_assignment': EXPERT_IMAGE,
                        'conditional_whole_model_one_read_bytes_per_token': WHOLE_READ,
                        'online_extra_per_substitution': '2048 FP16 prototype loads, FP32 conversion, 2048 weighted adds; score-min selector among up to 8; native skips a Q4/Q5 expert only if gate/up and down products and dispatch can be suppressed'},
              'counts_train': counts.tolist(), 'train': evaluate(train, means, counts),
              'held': evaluate(held, means, counts)}
    args.out.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('image', 'train', 'held')}, indent=2))


if __name__ == '__main__':
    main()
