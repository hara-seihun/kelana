#!/usr/bin/env python3
"""Fit a fixed-rate shared RoPE-plane mask to finite causal attention KL."""
import argparse
import importlib.util
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'value-observer'))
import fit as value_fit
sys.path.insert(0, str(HERE.parent / 'rope-plane-rate-allocation'))
spec = importlib.util.spec_from_file_location('causal_fit', HERE.parent / 'rope-causal-mask/fit.py')
causal_fit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(causal_fit)
MODEL, DATA = causal_fit.MODEL, causal_fit.DATA
projections, evaluate, sha = causal_fit.projections, causal_fit.evaluate, causal_fit.sha
load_capture = value_fit.load_capture


def rows_for_group(q, k, group, positions):
    """A row is one head/window/query; padded keys have zero teacher probability."""
    heads = q[:, 2*group:2*group+2, positions].reshape(-1, 128)
    keys = k[:, group, :, :].repeat_interleave(2, dim=0)
    keys = keys[:, None, :, :].expand(-1, len(positions), -1, -1).reshape(-1, 256, 128)
    pieces = (heads[:, None, :64] * keys[:, :, :64] +
              heads[:, None, 64:] * keys[:, :, 64:]) / math.sqrt(128)
    pieces = pieces.numpy().astype(np.float32, copy=False)
    valid = np.arange(256)[None, :] <= np.tile(positions, q.shape[0]*2)[:, None]
    teacher_logits = np.where(valid, pieces.sum(-1), -1e9)
    teacher_p = softmax(teacher_logits)
    return pieces, valid, teacher_p


def softmax(logits):
    exp = np.exp(logits - logits.max(-1, keepdims=True))
    return exp / exp.sum(-1, keepdims=True)


def objective(z, valid, p, selected):
    s = np.where(valid, z[:, :, selected].sum(-1), -1e9)
    top = s.max(-1, keepdims=True)
    return float(np.mean(top[:, 0] + np.log(np.exp(s-top).sum(-1)) - (p*s).sum(-1)))


def optimize(z, valid, p, initial, steps, shortlist):
    chosen = sorted(initial)
    s = z[:, :, chosen].sum(-1)
    history = []
    for _ in range(steps):
        scores = np.where(valid, s, -1e9)
        predicted = softmax(scores)
        grad = np.einsum('nk,nkj->j', predicted-p, z, optimize=True) / z.shape[0]
        excluded = [i for i in range(64) if i not in chosen]
        candidate_pairs = sorted(((float(grad[j]-grad[i]), i, j)
                                  for i in chosen for j in excluded))[:shortlist]
        before = objective(z, valid, p, chosen)
        best = (before, None, None)
        for _, i, j in candidate_pairs:
            trial = sorted((set(chosen) - {i}) | {j})
            value = objective(z, valid, p, trial)
            if value < best[0] - 1e-8:
                best = (value, i, j)
        if best[1] is None:
            break
        value, i, j = best
        chosen = sorted((set(chosen) - {i}) | {j})
        s += z[:, :, j] - z[:, :, i]
        history.append({'remove': i, 'add': j, 'train_cross_entropy': value,
                        'improvement': before-value})
    return chosen, history


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--steps', type=int, default=6)
    parser.add_argument('--shortlist', type=int, default=12)
    args = parser.parse_args()
    torch.set_num_threads(4)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        weights = {n: model.get_tensor(f'model.layers.{args.layer}.self_attn.{n}.weight').float()
                   for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    train = projections(load_capture(args.layer, 'train').reshape(8, 256, 1024), weights)
    prior_path = DATA / f'rope-causal-mask/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    # A deterministic, strided selection of causal queries. Every key up to that position is retained.
    positions = list(range(64, 256, 12))
    selected = {}
    changes = {}
    train_metrics = {}
    for name in ('uniform_causal', 'weight_counts_causal', 'allocated_causal'):
        selected[name] = []
        changes[name] = []
        train_metrics[name] = []
    for g in range(8):
        z, valid, p = rows_for_group(*train, g, positions)
        for name in selected:
            start = prior['masks'][name][g]
            mask, history = optimize(z, valid, p, start, args.steps, args.shortlist)
            selected[name].append(mask)
            changes[name].append(history)
            train_metrics[name].append({'before_cross_entropy': objective(z, valid, p, start),
                                        'after_cross_entropy': objective(z, valid, p, mask)})
        print('group', g, 'exchanges', [len(changes[name][-1]) for name in selected], flush=True)
    validation = projections(load_capture(args.layer, 'validation').reshape(4, 256, 1024), weights)
    arms = {name: prior['masks'][name] for name in selected}
    arms.update({name+'_finite': mask for name, mask in selected.items()})
    scores = evaluate(*validation, arms)
    report = {'layer': args.layer, 'map': 'original-producer BF16 projections/norm and FP32 RoPE/score; whole shared Q/K planes',
              'train_windows': 8, 'validation_windows': 4, 'train_query_positions': positions,
              'all_causal_keys_for_selected_queries': True, 'steps_per_group': args.steps,
              'gradient_shortlist': args.shortlist,
              'objective': 'exact finite teacher-to-selected attention KL for sampled train queries; rowwise teacher entropy is mask-independent',
              'source_sha256': sha(Path(__file__)), 'prior_receipt_sha256': sha(prior_path),
              'model_sha256': sha(MODEL), 'capture_sha256': prior['capture_sha256'],
              'initial_masks': {name: prior['masks'][name] for name in selected},
              'final_masks': selected, 'exchanges': changes, 'train': train_metrics,
              'validation': scores}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    for name, windows in scores.items():
        print(name, np.mean([w['kl'] for w in windows]), [round(w['kl'], 5) for w in windows], flush=True)


if __name__ == '__main__':
    main()
