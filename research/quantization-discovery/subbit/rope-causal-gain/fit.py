#!/usr/bin/env python3
"""Fit shared post-normalization key-plane gains to finite causal attention loss."""
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
spec = importlib.util.spec_from_file_location('finite_fit', HERE.parent / 'rope-finite-kl/fit.py')
finite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(finite)


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def rows(q, k, group, positions, selected):
    z, valid, p = finite.rows_for_group(q, k, group, positions)
    return np.ascontiguousarray(z[:, :, selected].astype(np.float64)), valid, p.astype(np.float64)


def loss_gradient(gain, z, valid, p, ridge):
    scores = np.einsum('nkr,r->nk', z, gain, optimize=True)
    scores = np.where(valid, scores, -1e9)
    peak = scores.max(axis=1, keepdims=True)
    weights = np.exp(scores - peak)
    weights /= weights.sum(axis=1, keepdims=True)
    loss = (peak[:, 0] + np.log(np.exp(scores - peak).sum(axis=1)) -
            (p * scores).sum(axis=1)).mean()
    grad = np.einsum('nk,nkr->r', weights-p, z, optimize=True) / z.shape[0]
    delta = gain - 1
    return float(loss + ridge * (delta @ delta)), grad + 2 * ridge * delta


def held(q, k, masks, gains):
    results = {name: [] for name in gains}
    for window in range(q.shape[0]):
        totals = {name: 0.0 for name in gains}
        for g in range(8):
            z, valid, p = rows(q[window:window+1], k[window:window+1], g,
                               list(range(256)), masks[g])
            teacher_entropy = -(np.where(p > 0, p * np.log(np.maximum(p, 1e-300)), 0)).sum(axis=1).mean()
            for name, image in gains.items():
                ce, _ = loss_gradient(np.asarray(image[g], dtype=np.float64), z, valid, p, 0)
                totals[name] += (ce - teacher_entropy) / 8
        for name in gains:
            results[name].append(totals[name])
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--ridge', type=float, default=0.002)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    prior_path = finite.DATA / f'rope-exhaustive/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    masks = prior['final_masks']
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        weights = {n: model.get_tensor(f'model.layers.{args.layer}.self_attn.{n}.weight').float()
                   for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    train = finite.projections(finite.load_capture(args.layer, 'train').reshape(8, 256, 1024), weights)
    gains = []
    train_losses = []
    for g in range(8):
        z, valid, p = rows(*train, g, prior['positions'], masks[g])
        base = loss_gradient(np.ones(len(masks[g])), z, valid, p, 0)[0]
        result = minimize(loss_gradient, np.ones(len(masks[g])),
                          args=(z, valid, p, args.ridge), jac=True,
                          method='L-BFGS-B', bounds=[(0.25, 2.0)]*len(masks[g]),
                          options={'maxiter': 80, 'ftol': 1e-10})
        rounded = np.asarray(result.x, dtype=np.float16).astype(np.float64)
        gains.append(rounded.tolist())
        train_losses.append({'base_ce': base, 'fitted_ce': loss_gradient(rounded, z, valid, p, 0)[0],
                             'iterations': result.nit, 'success': bool(result.success)})
        print('group', g, 'train', base, train_losses[-1]['fitted_ce'], flush=True)
    validation = finite.projections(finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024), weights)
    scores = held(*validation, masks, {'base': [[1.]*len(m) for m in masks], 'gained': gains})
    result = {'layer': args.layer, 'ridge': args.ridge, 'gains_fp16': gains,
              'masks': masks, 'train': train_losses, 'held_kl_by_window': scores,
              'source_sha256': digest(Path(__file__)), 'model_sha256': digest(finite.MODEL),
              'prior_sha256': digest(prior_path), 'capture_sha256': prior['capture_sha256'],
              'observation': 'original-producer finite causal attention KL; 16 strided train queries/window; full held rows',
              'online': 'shared key post-normalization per-plane gain, two multiplies/plane/key token; unchanged key cache and per-key score products'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print('held', {name: float(np.mean(values)) for name, values in scores.items()}, flush=True)

if __name__ == '__main__':
    main()
