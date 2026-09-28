#!/usr/bin/env python3
"""Fit a shared key-RMSNorm gain and measure its BF16-folded causal map."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from scipy.optimize import minimize
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('causal_gain', HERE.parent / 'rope-causal-gain/fit.py')
gain_fit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gain_fit)
finite = gain_fit.finite


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def evaluate(q, k, k_fold, masks, group_gains, shared):
    scores = {'unit': [], 'group': [], 'shared_real': [], 'shared_fold_bf16': []}
    for window in range(q.shape[0]):
        totals = {name: 0.0 for name in scores}
        for g, indices in enumerate(masks):
            original, valid, p = gain_fit.rows(q[window:window+1], k[window:window+1], g,
                                               list(range(256)), indices)
            folded, _, _ = gain_fit.rows(q[window:window+1], k_fold[window:window+1], g,
                                         list(range(256)), indices)
            entropy = -(p * np.log(np.maximum(p, 1e-300))).sum(axis=1).mean()
            for name, z, gains in (
                ('unit', original, np.ones(len(indices))),
                ('group', original, group_gains[g]),
                ('shared_real', original, shared[indices]),
                ('shared_fold_bf16', folded, np.ones(len(indices))),
            ):
                ce, _ = gain_fit.loss_gradient(np.asarray(gains), z, valid, p, 0)
                totals[name] += (ce - entropy) / 8
        for name in scores:
            scores[name].append(totals[name])
        print('held window', window, {k: round(v, 6) for k, v in totals.items()}, flush=True)
    return scores


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ridge', type=float, default=0.002)
    args = parser.parse_args()
    torch.set_num_threads(4)
    prior_path = finite.DATA / f'rope-causal-gain/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    masks = [np.asarray(m, dtype=np.intp) for m in prior['masks']]
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        weights = {n: model.get_tensor(f'model.layers.{args.layer}.self_attn.{n}.weight').float()
                   for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    train = finite.projections(finite.load_capture(args.layer, 'train').reshape(8, 256, 1024), weights)
    train_rows = [gain_fit.rows(*train, g, list(range(64, 256, 12)), indices)
                  for g, indices in enumerate(masks)]
    def objective(shared):
        value = args.ridge * np.sum((shared - 1) ** 2)
        gradient = 2 * args.ridge * (shared - 1)
        for indices, (z, valid, p) in zip(masks, train_rows):
            ce, grad = gain_fit.loss_gradient(shared[indices], z, valid, p, 0)
            value += ce / 8
            gradient[indices] += grad / 8
        return value, gradient
    solution = minimize(objective, np.ones(64), method='L-BFGS-B', jac=True,
                        bounds=[(0.25, 2.0)] * 64, options={'maxiter': 80, 'ftol': 1e-10})
    shared = solution.x.astype(np.float16).astype(np.float64)
    gamma = weights['k_norm'].to(torch.bfloat16)
    gain_vector = torch.from_numpy(np.concatenate((shared, shared))).float()
    folded_gamma = (gamma.float() * gain_vector).to(torch.bfloat16)
    folded_weights = dict(weights, k_norm=folded_gamma)
    held_x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    held_q, held_k = finite.projections(held_x, weights)
    _, held_k_fold = finite.projections(held_x, folded_weights)
    scores = evaluate(held_q, held_k, held_k_fold, masks, prior['gains_fp16'], shared)
    result = {'layer': args.layer, 'shared_gain_fp16': shared.tolist(),
              'folded_k_norm_bf16': folded_gamma.float().tolist(),
              'k_norm_bf16': gamma.float().tolist(),
              'held_kl_by_window': scores, 'ridge': args.ridge,
              'train_objective_unit': objective(np.ones(64))[0],
              'train_objective_shared': objective(shared)[0],
              'optimizer': {'iterations': solution.nit, 'success': bool(solution.success)},
              'source_sha256': digest(Path(__file__)), 'prior_sha256': digest(prior_path),
              'model_sha256': digest(finite.MODEL), 'capture_sha256': prior['capture_sha256'],
              'observation': 'original producer; both heads; 16 strided train queries/window; full causal validation; folded BF16 normalization, FP32 rotary and scores'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('held means', {k: np.mean(v) for k, v in scores.items()}, flush=True)

if __name__ == '__main__':
    main()
