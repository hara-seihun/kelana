#!/usr/bin/env python3
"""Shared activation codes against routed Qwen expert outputs, CPU-only."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe/experts/layer-0-0-16')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bf16(path, shape):
    raw = np.memmap(path, dtype='<u2', mode='r', shape=shape)
    return (np.asarray(raw, dtype=np.uint32) << 16).view(np.float32)


def swiglu(z):
    gate, up = z[:512], z[512:]
    return (gate / (1 + np.exp(-gate))) * up


def quantize(x, bits, clip):
    limit = (1 << (bits - 1)) - 1
    step = float(np.max(np.abs(x))) * clip / limit
    code = np.clip(np.rint(x / step), -limit, limit).astype(np.int8)
    return code.astype(np.float32) * step


def rms(delta, target):
    return float(np.sqrt(np.sum(np.square(delta, dtype=np.float64)) /
                         np.sum(np.square(target, dtype=np.float64))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--base', type=Path, default=BASE)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--samples', type=int, default=24)
    args = ap.parse_args()
    assert args.samples % 2 == 0 and args.samples >= 4
    gate_file = args.base / 'gate_up_proj.bf16'
    down_file = args.base / 'down_proj.bf16'
    gate = bf16(gate_file, (16, 1024, 2048))
    down = bf16(down_file, (16, 2048, 512))
    rng = np.random.default_rng(20260923)
    x = rng.standard_normal((args.samples, 2048), dtype=np.float32)
    # Independent synthetic routes and scores. Real model routing is not available here.
    selected = np.stack([rng.permutation(16)[:8] for _ in x])
    score = rng.standard_normal((args.samples, 8), dtype=np.float32)
    score = np.exp(score - score.max(axis=1, keepdims=True))
    score /= score.sum(axis=1, keepdims=True)
    clips = (1.0, 0.875, 0.75, 0.625)
    half = args.samples // 2
    results = []
    for bits in (4, 8):
        variants = np.stack([np.stack([quantize(v, bits, c) for c in clips]) for v in x])
        exact_pre = np.zeros((args.samples, 8, 1024), np.float32)
        candidate_pre = np.zeros((args.samples, len(clips), 8, 1024), np.float32)
        exact_output = np.zeros((args.samples, 8, 2048), np.float32)
        candidate_output = np.zeros((args.samples, len(clips), 8, 2048), np.float32)
        # Batch candidate vectors per expert to make the fixture affordable on CPU.
        for expert in range(16):
            positions = np.argwhere(selected == expert)
            if not len(positions):
                continue
            samples, slots = positions.T
            z = (gate[expert] @ x[samples].T).T
            zq = (gate[expert] @ variants[samples].reshape(-1, 2048).T).T.reshape(-1, len(clips), 1024)
            exact_pre[samples, slots] = z
            candidate_pre[samples, :, slots] = zq
            exact_output[samples, slots] = (down[expert] @ swiglu(z.T)).T
            candidate_output[samples, :, slots] = (down[expert] @ swiglu(zq.reshape(-1, 1024).T)).T.reshape(-1, len(clips), 2048)
        target = np.einsum('se,sed->sd', score, exact_output, optimize=True)
        mapped = np.einsum('se,sced->scd', score, candidate_output, optimize=True)
        pre_diff = candidate_pre - exact_pre[:, None]
        weighted_pre_sse = np.sum(np.square(pre_diff, dtype=np.float64) * score[:, None, :, None]**2, axis=(2, 3))
        composed_sse = np.sum(np.square(mapped - target[:, None], dtype=np.float64), axis=2)
        train_best = int(np.argmin(composed_sse[:half].sum(axis=0)))
        held = slice(half, None)
        best_linear = np.argmin(weighted_pre_sse[held], axis=1)
        best_composed = np.argmin(composed_sse[held], axis=1)
        def result_for(indices):
            rows = np.arange(half, args.samples)
            return rms(mapped[rows, indices] - target[held], target[held])
        results.append({
            'bits_per_activation_code': bits,
            'clip_factors': clips,
            'train_selected_clip': clips[train_best],
            'held_max_clip_rms': result_for(np.zeros(half, dtype=np.int64)),
            'held_train_selected_rms': result_for(np.full(half, train_best, dtype=np.int64)),
            'held_weighted_preactivation_oracle_rms': result_for(best_linear),
            'held_composed_oracle_rms': result_for(best_composed),
            'held_clip_rms': [result_for(np.full(half, i, dtype=np.int64)) for i in range(len(clips))],
            'held_weighted_preactivation_oracle_counts': np.bincount(best_linear, minlength=len(clips)).tolist(),
            'held_composed_oracle_counts': np.bincount(best_composed, minlength=len(clips)).tolist(),
            'held_relative_preactivation_rms_max_clip': rms(pre_diff[held, 0], exact_pre[held]),
            'held_target_norm': float(np.linalg.norm(target[held])),
            'held_max_clip_sse': float(composed_sse[held, 0].sum()),
            'held_composed_oracle_sse': float(composed_sse[np.arange(half, args.samples), best_composed].sum()),
        })
    receipt = {
        'revision': '995ad96eacd98c81ed38be0c5b274b04031597b0',
        'gate_up_sha256': sha(gate_file), 'down_sha256': sha(down_file),
        'source_sha256': sha(Path(__file__)), 'seed': 20260923, 'samples': args.samples,
        'train_samples': half, 'held_samples': half,
        'inputs': 'shared per-token iid N(0,1) FP32 vectors',
        'routing': 'uniform eight-of-sixteen without replacement, independent Gaussian softmax scores',
        'arithmetic': 'BF16 tensors decoded to FP32, NumPy BLAS dot then FP32 sigmoid/down, FP32 weighted sum; not bit-equivalent to llama.cpp',
        'results': results,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
