#!/usr/bin/env python3
"""Measure the score-translation quotient on pinned Qwen causal Q/K captures."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
FINITE = ROOT / 'rope-causal-mask/fit.py'
def imported(path):
    spec = importlib.util.spec_from_file_location('gauge_finite', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def phase(length):
    freq = 1 / (1_000_000. ** (torch.arange(0, 128, 2).double() / 128))
    angle = torch.outer(torch.arange(length).double(), freq)
    return angle.cos()[None, None], angle.sin()[None, None]


def rotate(x, cos, sin, reverse=False):
    a, b = x.double()[..., :64], x.double()[..., 64:]
    if reverse:
        return torch.cat((a * cos + b * sin, b * cos - a * sin), dim=-1)
    return torch.cat((a * cos - b * sin, b * cos + a * sin), dim=-1)


def metrics(q, k, offsets):
    mask = torch.ones(k.shape[-2], k.shape[-2], dtype=torch.bool).triu(1)
    outcomes = {key: {'kl': 0., 'score_centered_mse': 0.} for key in offsets}
    for g in range(8):
        query = q[:, 2*g:2*g+2].double()
        base = (query @ k[:, g:g+1].double().transpose(-1, -2)) / math.sqrt(128)
        base = base.masked_fill(mask, -1e100)
        ref = base.log_softmax(-1)
        p = ref.exp()
        for key, shifted in offsets.items():
            score = (query @ shifted[:, g:g+1].double().transpose(-1, -2)) / math.sqrt(128)
            score = score.masked_fill(mask, -1e100)
            logp = score.log_softmax(-1)
            kl = (p * (ref - logp).masked_fill(mask, 0)).sum(-1).mean().item()
            delta = (score - base).masked_fill(mask, 0)
            avg = (p * delta).sum(-1, keepdim=True)
            var = (p * (delta - avg).square()).sum(-1).mean().item()
            outcomes[key]['kl'] += kl / 8
            outcomes[key]['score_centered_mse'] += var / 8
    return outcomes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    finite = imported(FINITE)
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        weights = {name: model.get_tensor(f'model.layers.{args.layer}.self_attn.{name}.weight').float()
                   for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    train = finite.load_capture(args.layer, 'train').reshape(8, 256, 1024)
    held = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    _, kt = finite.projections(train, weights)
    q, k = finite.projections(held, weights)
    cos, sin = phase(256)
    post_mean = kt.double().mean(dim=(0, 2))[None, :, None, :]
    pre_mean = rotate(kt, cos, sin, reverse=True).mean(dim=(0, 2))[None, :, None, :]
    pre_shift = rotate(pre_mean, cos, sin)
    arms = {
        'post_translation_real': k.double() - post_mean,
        'pre_translation_real': k.double() - pre_shift,
        'bf16_raw': k.to(torch.bfloat16).float(),
        'bf16_post_centered': (k.double() - post_mean).to(torch.bfloat16).float(),
        'bf16_pre_centered': (k.double() - pre_shift).to(torch.bfloat16).float(),
    }
    by_window = [metrics(q[w:w+1], k[w:w+1], {name: v[w:w+1] if v.shape[0] == 4 else v for name, v in arms.items()})
                 for w in range(4)]
    pooled = {name: {metric: sum(window[name][metric] for window in by_window)/4
                     for metric in ('kl', 'score_centered_mse')} for name in arms}
    raw_energy = kt.double().square().mean(dim=(0, 2))
    mean_energy = post_mean[0, :, 0].square()
    held_raw_energy = k.double().square().mean(dim=(0, 2))
    held_residual_energy = (k.double() - post_mean).square().mean(dim=(0, 2))
    report = {
        'layer': args.layer, 'contract': '256-key causal original-producer BF16 Q/K normalization and RoPE; train-fitted static center, double score/softmax; BF16 round after optional rotated-key subtraction; validation windows never fit center',
        'train_windows': 8, 'held_windows': 4, 'sequence_length': 256,
        'post_mean_squared_fraction_by_group': (mean_energy.sum(-1)/raw_energy.sum(-1)).tolist(),
        'post_mean_squared_fraction_pooled': float(mean_energy.sum()/raw_energy.sum()),
        'held_residual_energy_fraction_by_group': (held_residual_energy.sum(-1)/held_raw_energy.sum(-1)).tolist(),
        'held_residual_energy_fraction_pooled': float(held_residual_energy.sum()/held_raw_energy.sum()),
        'pre_mean_squared_norm_by_group': pre_mean[0,:,0].square().sum(-1).tolist(),
        'held_by_window': by_window, 'held_mean': pooled,
        'source_sha256': sha(Path(__file__)), 'projection_source_sha256': sha(FINITE),
        'model_sha256': sha(finite.MODEL),
        'capture_sha256': sha(finite.CAPTURES/f'layer{args.layer:02d}.npz'),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'layer': args.layer, 'train_center_fraction': report['post_mean_squared_fraction_pooled'],
                      'held_residual_fraction': report['held_residual_energy_fraction_pooled'], 'held': pooled}, indent=2))


if __name__ == '__main__':
    main()
