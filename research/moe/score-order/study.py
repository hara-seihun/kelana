#!/usr/bin/env python3
"""Norm-only certificate for stopping a routed expert sum on captured real inputs."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(root, split):
    prefix = root / split
    n = len(np.fromfile(str(prefix) + '.tokens', dtype=np.int32))
    files = {
        'ids': ('.0.ffn_moe_topk-0.bin', np.int32, (n, 8)),
        'scores': ('.0.ffn_moe_weights_norm-0.bin', np.float32, (n, 8)),
        'down': ('.0.ffn_moe_down-0.bin', np.float32, (n, 8, 2048)),
    }
    arrays = {name: np.memmap(str(prefix) + suffix, dtype=dtype, mode='r', shape=shape)
              for name, (suffix, dtype, shape) in files.items()}
    hashes = {name: digest(Path(str(prefix) + suffix))
              for name, (suffix, _, _) in files.items()}
    hashes['tokens'] = digest(Path(str(prefix) + '.tokens'))
    hashes['text'] = digest(Path(str(prefix) + '.txt'))
    if not np.isfinite(arrays['down']).all() or not np.isfinite(arrays['scores']).all():
        raise ValueError('nonfinite capture')
    if not np.allclose(arrays['scores'].sum(axis=1), 1, atol=1e-5):
        raise ValueError('scores not normalized')
    return arrays, hashes


def panel(arrays):
    v = np.asarray(arrays['down'], dtype=np.float64) * np.asarray(arrays['scores'], dtype=np.float64)[:, :, None]
    target = v.sum(axis=1)
    norm = np.linalg.norm(v, axis=2)
    orders = {
        'router_score': np.argsort(-arrays['scores'], axis=1, kind='stable'),
        'free_contribution_norm': np.argsort(-norm, axis=1, kind='stable'),
    }
    output = {'tokens': len(v), 'mean_target_norm': float(np.linalg.norm(target, axis=1).mean()), 'arms': {}}
    for name, order in orders.items():
        vv = np.take_along_axis(v, order[:, :, None], axis=1)
        nn = np.take_along_axis(norm, order, axis=1)
        first_certified = {eps: np.full(len(v), 8, dtype=np.int32) for eps in (.01, .05, .10)}
        for k in range(1, 8):
            p = vv[:, :k].sum(axis=1)
            b = nn[:, k:].sum(axis=1)
            residual = target - p
            actual_relative = np.linalg.norm(residual, axis=1) / np.linalg.norm(target, axis=1)
            # ||target|| >= ||p|| - B. When positive, B/(||p||-B) is
            # a certificate that does not inspect omitted output directions.
            lower = np.linalg.norm(p, axis=1) - b
            certified = np.where(lower > 0, b / np.maximum(lower, 1e-300), np.inf)
            for eps, earliest in first_certified.items():
                earliest[(earliest == 8) & (certified <= eps)] = k
            output['arms'][f'{name}_{k}'] = {
                'relative_rms': float(np.linalg.norm(residual) / np.linalg.norm(target)),
                'actual_le_0.05': int((actual_relative <= .05).sum()),
                'actual_le_0.10': int((actual_relative <= .10).sum()),
                'norm_certificate_le_0.01': int((certified <= .01).sum()),
                'norm_certificate_le_0.05': int((certified <= .05).sum()),
                'norm_certificate_le_0.10': int((certified <= .10).sum()),
                'positive_target_lower_bound': int((lower > 0).sum()),
                'median_bound_over_true_target_norm': float(np.median(b / np.linalg.norm(target, axis=1))),
                'median_actual_relative': float(np.median(actual_relative)),
            }
        output[f'{name}_adaptive'] = {
            str(eps): {
                'mean_skipped_experts': float(np.mean(8 - earliest)),
                'tokens_skipping_any': int((earliest < 8).sum()),
                'maximum_conditional_whole_model_weight_byte_saving_percent': float(
                    100 * np.mean(8 - earliest) * (611516416 / 8) / 2626187904),
                'first_stop_histogram_k_1_to_8': np.bincount(earliest, minlength=9)[1:].tolist(),
            } for eps, earliest in first_certified.items()
        }
    # Grant hindsight choice of the best omitted SINGLE expert, with the
    # full target available to decide. This is a lower error floor for all
    # seven-survivor ordering rules without replacement directions.
    one_omit = np.linalg.norm(v, axis=2) / np.linalg.norm(target, axis=1)[:, None]
    output['best_seven_hindsight'] = {
        'relative_rms': float(np.sqrt(np.sum(np.min(np.sum(v*v, axis=2), axis=1)) / np.sum(target*target))),
        'actual_le_0.05': int((one_omit.min(axis=1) <= .05).sum()),
        'actual_le_0.10': int((one_omit.min(axis=1) <= .10).sum()),
    }
    return output


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('capture', type=Path)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    splits = {name: load(args.capture, name) for name in ('train', 'held')}
    data = {
        'contract': 'FP64 local layer-0 sum of eight installed GGUF captured FP32 down outputs and FP32 router scores. The norm-only bound grants perfect per-token omitted output norms for free, but cannot read their directions. Not the native FP32 reduction or complete-model quality.',
        'source_sha256': digest(Path(__file__)),
        'inputs': {name: {'sha256': hashes, 'results': panel(arrays)}
                   for name, (arrays, hashes) in splits.items()},
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(data, indent=2) + '\n')
    for name, split in data['inputs'].items():
        print(name, json.dumps({k: v for k, v in split['results']['arms'].items() if k.endswith('_7')}, indent=2))
        print('best seven', split['results']['best_seven_hindsight'])


if __name__ == '__main__':
    main()
