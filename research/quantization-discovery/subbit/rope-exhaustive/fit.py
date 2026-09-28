#!/usr/bin/env python3
"""Exhaust all one-for-one RoPE-plane exchanges at fixed group counts."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('finite_fit', HERE.parent / 'rope-finite-kl/fit.py')
finite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(finite)


def cross_entropy_batch(scores, valid, teacher):
    scores = np.where(valid[:, :, None], scores, -1e9)
    maximum = scores.max(axis=1)
    partition = maximum + np.log(np.exp(scores - maximum[:, None, :]).sum(axis=1))
    expectation = np.einsum('nk,nkc->nc', teacher, scores, optimize=True)
    return (partition - expectation).mean(axis=0)


def descent(z, valid, teacher, start, max_steps):
    chosen = sorted(start)
    score = z[:, :, chosen].sum(axis=-1)
    history = []
    for step in range(max_steps):
        excluded = [j for j in range(64) if j not in chosen]
        before = float(cross_entropy_batch(score[:, :, None], valid, teacher)[0])
        best = (before, None, None)
        for i in chosen:
            candidates = score[:, :, None] - z[:, :, i, None] + z[:, :, excluded]
            losses = cross_entropy_batch(candidates, valid, teacher)
            index = int(losses.argmin())
            if losses[index] < best[0] - 1e-7:
                best = (float(losses[index]), i, excluded[index])
        if best[1] is None:
            return chosen, history, before, True
        loss, removed, added = best
        chosen = sorted((set(chosen) - {removed}) | {added})
        score += z[:, :, added] - z[:, :, removed]
        history.append({'remove': removed, 'add': added, 'train_cross_entropy': loss,
                        'improvement': before - loss})
    # The cap does not imply local optimality. Check all pairs at the new point.
    excluded = [j for j in range(64) if j not in chosen]
    before = float(cross_entropy_batch(score[:, :, None], valid, teacher)[0])
    minimum = min(float(cross_entropy_batch(score[:, :, None] - z[:, :, i, None] +
                                             z[:, :, excluded], valid, teacher).min()) for i in chosen)
    return chosen, history, before, minimum >= before - 1e-7


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--max-steps', type=int, default=12)
    args = parser.parse_args()
    torch.set_num_threads(4)
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        weights = {n: model.get_tensor(f'model.layers.{args.layer}.self_attn.{n}.weight').float()
                   for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    prior_path = finite.DATA / f'rope-finite-kl/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    name = 'allocated_causal' if args.layer == 0 else 'weight_counts_causal'
    initial = prior['final_masks'][name]
    train = finite.projections(finite.load_capture(args.layer, 'train').reshape(8, 256, 1024), weights)
    selected, histories, final_losses, optimal = [], [], [], []
    for group in range(8):
        z, valid, teacher = finite.rows_for_group(*train, group, prior['train_query_positions'])
        mask, history, loss, local = descent(z, valid, teacher, initial[group], args.max_steps)
        selected.append(mask)
        histories.append(history)
        final_losses.append(loss)
        optimal.append(local)
        print('group', group, 'exchanges', len(history), 'local', local, flush=True)
    validation = finite.projections(finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024), weights)
    scores = finite.evaluate(*validation, {'finite_shortlist': initial, 'exhaustive_exchange': selected})
    report = {'layer': args.layer, 'start': name, 'objective': 'finite teacher-to-mask causal attention KL, 16 train queries per window; exhaustive one-plane exchanges in each fixed-size group',
              'train_windows': 8, 'validation_windows': 4, 'positions': prior['train_query_positions'],
              'max_steps': args.max_steps, 'locally_optimal_by_group': optimal,
              'source_sha256': finite.sha(Path(__file__)), 'prior_receipt_sha256': finite.sha(prior_path),
              'model_sha256': finite.sha(finite.MODEL), 'capture_sha256': prior['capture_sha256'],
              'initial_masks': initial, 'final_masks': selected, 'exchanges': histories,
              'final_train_cross_entropy': final_losses, 'validation': scores}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    for name, windows in scores.items():
        print(name, np.mean([w['kl'] for w in windows]), [round(w['kl'], 6) for w in windows], flush=True)


if __name__ == '__main__':
    main()
