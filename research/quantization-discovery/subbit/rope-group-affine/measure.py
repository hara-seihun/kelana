#!/usr/bin/env python3
"""Replay group-indexed BF16 key RMS affine on frozen Q/K causal captures."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('gain_fit', HERE.parent / 'rope-causal-gain/fit.py')
gain_fit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gain_fit)
finite = gain_fit.finite
from measure import rms, rotary  # imported by finite's value-observer path


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    prior_path = finite.DATA / f'rope-causal-gain/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    folded_path = finite.DATA / f'rope-gain-fold/layer{args.layer:02d}.json'
    folded = json.loads(folded_path.read_text())
    masks = prior['masks']
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        weights = {name: model.get_tensor(f'model.layers.{args.layer}.self_attn.{name}.weight').float()
                   for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    gamma = weights['k_norm'].to(torch.bfloat16).float()
    expanded = gamma.expand(8, -1).clone()
    for g, indices in enumerate(masks):
        for plane, gain in zip(indices, prior['gains_fp16'][g]):
            for coordinate in (plane, plane + 64):
                expanded[g, coordinate] = float((gamma[coordinate] * gain).to(torch.bfloat16))
    shared_gamma = torch.tensor(folded['folded_k_norm_bf16']).to(torch.bfloat16).float()
    capture = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    q, k = finite.projections(capture, weights)
    _, k_shared = finite.projections(capture, dict(weights, k_norm=shared_gamma))
    raw = (capture @ weights['k_proj'].T).to(torch.bfloat16).float().reshape(4, 256, 8, 128)
    k_group = rotary(q, rms(raw, expanded).permute(0, 2, 1, 3))[1]
    scores = gain_fit.held(q, k, masks, {
        'unit': [[1.] * len(m) for m in masks],
        'separate_gain_score': prior['gains_fp16'],
    })
    for name, candidate in (('shared_bf16_affine', k_shared), ('group_bf16_affine', k_group)):
        windows = []
        for w in range(4):
            total = 0.0
            for g, indices in enumerate(masks):
                z, valid, p = gain_fit.rows(q[w:w+1], k[w:w+1], g, list(range(256)), indices)
                altered, _, _ = gain_fit.rows(q[w:w+1], candidate[w:w+1], g, list(range(256)), indices)
                entropy = -(p * np.log(np.maximum(p, 1e-300))).sum(axis=1).mean()
                ce, _ = gain_fit.loss_gradient(np.ones(len(indices)), altered, valid, p, 0)
                total += (ce - entropy) / 8
            windows.append(total)
        scores[name] = windows
    result = {
        'layer': args.layer, 'kl_by_window': scores,
        'means': {name: float(np.mean(values)) for name, values in scores.items()},
        'group_affine_bf16': expanded.tolist(),
        'source_sha256': digest(Path(__file__)), 'model_sha256': digest(finite.MODEL),
        'prior_sha256': digest(prior_path), 'folded_prior_sha256': digest(folded_path),
        'capture_sha256': prior['capture_sha256'],
        'observation': 'original-producer BF16 K RMSNorm with group-indexed BF16 affine, FP32 RoPE/score and float64 causal softmax; four previously examined held windows',
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result['means'], indent=2), flush=True)


if __name__ == '__main__':
    main()
