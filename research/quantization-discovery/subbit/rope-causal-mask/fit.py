#!/usr/bin/env python3
"""Fit RoPE-commuting Q/K plane masks to the causal attention Fisher metric."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'rope-plane-rate-allocation'))
sys.path.insert(0, str(HERE.parent / 'value-observer'))
from allocate import curves, allocate
from fit import CAPTURES, MODEL, load_capture
from measure import rms, rotary

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def projections(x, weights):
    q = rms((x @ weights['q_proj'].T).to(torch.bfloat16).float().reshape(-1, 256, 16, 128), weights['q_norm'])
    k = rms((x @ weights['k_proj'].T).to(torch.bfloat16).float().reshape(-1, 256, 8, 128), weights['k_norm'])
    return rotary(q.permute(0, 2, 1, 3), k.permute(0, 2, 1, 3))


def score(q, k, selected=None):
    if selected is not None:
        indices = selected + [i + 64 for i in selected]
        q, k = q[..., indices], k[..., indices]
    return (q @ k.transpose(-1, -2)) / math.sqrt(128)


def moments(q, k, draws, seed):
    """Unbiased sample covariance of plane contributions under each causal teacher row."""
    rng = torch.Generator().manual_seed(seed)
    mask = torch.ones(256, 256, dtype=torch.bool).triu(1)
    gram = np.zeros((8, 64, 64), dtype=np.float64)
    for w in range(q.shape[0]):
        for g in range(8):
            for head in (2*g, 2*g+1):
                a, b = q[w, head], k[w, g]
                probs = score(a, b).masked_fill(mask, -1e9).softmax(-1)
                keys = torch.multinomial(probs, draws, replacement=True, generator=rng)
                pieces = ((a[:, None, :64] * b[keys, :64]) +
                          (a[:, None, 64:] * b[keys, 64:])) / math.sqrt(128)
                centered = pieces - pieces.mean(dim=1, keepdim=True)
                z = centered.reshape(-1, 64).double()
                # Sample covariance corrects the finite-draw downward bias.
                gram[g] += (z.T @ z).numpy() / (draws - 1)
    return gram / (q.shape[0] * 2 * 256)


def evaluate(q, k, masks):
    mask = torch.ones(256, 256, dtype=torch.bool).triu(1)
    results = {name: [] for name in masks}
    for w in range(q.shape[0]):
        per_arm = {name: {'kl': 0., 'weighted_score_variance': 0.} for name in masks}
        for g in range(8):
            for head in (2*g, 2*g+1):
                a, b = q[w, head], k[w, g]
                logits = score(a, b).masked_fill(mask, -1e9)
                p = logits.softmax(-1)
                logp = logits.log_softmax(-1)
                for name, sets in masks.items():
                    partial = score(a, b, sets[g]).masked_fill(mask, -1e9)
                    delta = (partial - logits).masked_fill(mask, 0)
                    dmean = (p * delta).sum(-1, keepdim=True)
                    variance = (p * (delta-dmean).square()).sum(-1).mean()
                    logpartial = partial.log_softmax(-1)
                    kl = (p * (logp - logpartial).masked_fill(mask, 0)).sum(-1).mean()
                    per_arm[name]['kl'] += kl.item() / 16
                    per_arm[name]['weighted_score_variance'] += variance.item() / 16
        for name in masks:
            results[name].append(per_arm[name])
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--draws', type=int, default=16)
    parser.add_argument('--threads', type=int, default=4)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(args.threads)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        weights = {n: model.get_tensor(f'model.layers.{args.layer}.self_attn.{n}.weight').float()
                   for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    capture = CAPTURES / f'layer{args.layer:02d}.npz'
    train = projections(load_capture(args.layer, 'train').reshape(8, 256, 1024), weights)
    gram = moments(*train, args.draws, 20260922 + args.layer)
    family = [curves(item, low=4, high=16) for item in gram]
    fitted = allocate(family, total=112, low=4, high=16)
    receipt_path = DATA / 'rope-plane-rate-allocation/receipt.json'
    receipt = json.loads(receipt_path.read_text())['layers'][str(args.layer)]['weighted']['choices']
    masks = {'uniform_weight': receipt['uniform']['masks'],
             'allocated_weight': receipt['capped16']['masks'],
             'uniform_causal': [family[g][14]['planes'] for g in range(8)],
             'weight_counts_causal': [family[g][c]['planes'] for g, c in enumerate(receipt['capped16']['counts'])],
             'allocated_causal': fitted['masks']}
    validation = projections(load_capture(args.layer, 'validation').reshape(4, 256, 1024), weights)
    report = {'layer': args.layer, 'draws_per_query': args.draws, 'seed': 20260922 + args.layer,
              'train_windows': 8, 'validation_windows': 4, 'window_tokens': 256,
              'capture_sha256': sha(capture), 'model_sha256': sha(MODEL),
              'source_sha256': sha(Path(__file__)), 'weight_receipt_sha256': sha(receipt_path),
              'map': 'BF16 Q/K projections and norm; FP32 RoPE and score; original producer, shared whole-plane masks for two heads',
              'train_gram': gram.tolist(), 'masks': masks,
              'counts': {name: list(map(len, sets)) for name, sets in masks.items()},
              'train_curvature': {name: float(sum((np.ones(64) - np.eye(64)[sets].sum(0)) @ g @
                                                    (np.ones(64) - np.eye(64)[sets].sum(0))
                                                    for sets, g in zip(groups, gram))) for name, groups in masks.items()},
              'validation': evaluate(*validation, masks)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    for name, windows in report['validation'].items():
        print(args.layer, name, 'counts', report['counts'][name], 'train', round(report['train_curvature'][name], 6),
              'held_kl', round(np.mean([w['kl'] for w in windows]), 6),
              'held_fisher', round(np.mean([w['weighted_score_variance'] for w in windows]), 6), flush=True)


if __name__ == '__main__':
    main()
