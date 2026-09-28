#!/usr/bin/env python3
"""Fit a paid binary Q/K image's selected two-head causal score observation."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open
from scipy.optimize import minimize

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')


def imported(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


gain_fit = imported(ROOT/'rope-causal-gain/fit.py', 'paid_qk_gain_fit')
finite = gain_fit.finite
helper = imported(ROOT/'value-observer/measure.py', 'paid_qk_helper')


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def projected(x, weights, k_gamma):
    return finite.projections(x, dict(weights, k_norm=k_gamma))


def observations(q, k, tq, tk, group, positions, mask):
    z, valid, _ = finite.rows_for_group(q, k, group, positions)
    _, _, p = finite.rows_for_group(tq, tk, group, positions)
    return np.ascontiguousarray(z[:, :, mask].astype(np.float64)), valid, p.astype(np.float64)


def per_window(q, k, tq, tk, masks, arms):
    scores = {name: [] for name in arms}
    for w in range(q.shape[0]):
        running = {name: 0. for name in arms}
        for g, planes in enumerate(masks):
            z, valid, p = observations(q[w:w+1], k[w:w+1], tq[w:w+1], tk[w:w+1], g, list(range(256)), planes)
            entropy = -(p * np.log(np.maximum(p, 1e-300))).sum(-1).mean()
            for name, gains in arms.items():
                ce, _ = gain_fit.loss_gradient(np.asarray(gains[g], dtype=np.float64), z, valid, p, 0)
                running[name] += (ce - entropy)/8
        for name in arms:
            scores[name].append(running[name])
    return scores


def full_paid_kl(q, k, tq, tk):
    causal = torch.ones(256, 256, dtype=torch.bool).triu(1)
    by_window = torch.zeros(q.shape[0], dtype=torch.float64)
    for g in range(8):
        logits = (q[:, 2*g:2*g+2] @ k[:, g:g+1].transpose(-1, -2) / math.sqrt(128)).masked_fill(causal, -1e9)
        reference = (tq[:, 2*g:2*g+2] @ tk[:, g:g+1].transpose(-1, -2) / math.sqrt(128)).masked_fill(causal, -1e9)
        logp = reference.log_softmax(-1)
        by_window += (logp.exp() * (logp - logits.log_softmax(-1))).sum(-1).mean(dim=(1, 2)).double()/8
    return by_window.tolist()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ridge', type=float, default=0.002)
    args = parser.parse_args()
    torch.set_num_threads(4)
    selected_path = DATA/f'rope-group-affine/layer{args.layer:02d}.json'
    mask_path = DATA/f'rope-causal-gain/layer{args.layer:02d}.json'
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    masks = json.loads(mask_path.read_text())['masks']
    old_gamma = torch.tensor(json.loads(selected_path.read_text())['group_affine_bf16'], dtype=torch.bfloat16).float()
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        teacher_weights = {name: model.get_tensor(prefix+name+'.weight').float()
                           for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    paid_weights = dict(teacher_weights)
    for name, path in [('q_proj', q_path), ('k_proj', k_path)]:
        paid_weights[name] = helper.binary_weight(path).to(torch.bfloat16).float()
    train_x = finite.load_capture(args.layer, 'train').reshape(8, 256, 1024)
    held_x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    tq, tk = projected(train_x, teacher_weights, teacher_weights['k_norm'])
    hq, hk = projected(held_x, teacher_weights, teacher_weights['k_norm'])
    train_q, train_k = projected(train_x, paid_weights, old_gamma)
    held_q, held_k = projected(held_x, paid_weights, old_gamma)
    fitted, iterations, train_ce = [], [], []
    positions = list(range(64, 256, 12))
    for g, planes in enumerate(masks):
        z, valid, p = observations(train_q, train_k, tq, tk, g, positions, planes)
        seed = np.ones(len(planes))
        result = minimize(gain_fit.loss_gradient, seed, args=(z, valid, p, args.ridge), jac=True,
                          method='L-BFGS-B', bounds=[(.25, 4.)]*len(planes),
                          options={'maxiter': 80, 'ftol': 1e-10})
        fitted.append(np.asarray(result.x, dtype=np.float16).astype(np.float64).tolist())
        iterations.append({'group': g, 'iterations': result.nit, 'success': bool(result.success)})
        train_ce.append([gain_fit.loss_gradient(seed, z, valid, p, 0)[0],
                         gain_fit.loss_gradient(np.asarray(fitted[-1]), z, valid, p, 0)[0]])
        print('group', g, 'train CE', train_ce[-1], flush=True)
    unit = [[1.]*len(m) for m in masks]
    floating = per_window(held_q, held_k, hq, hk, masks, {'prior_group_affine': unit, 'post_gain_fp16': fitted})
    folded = old_gamma.clone()
    for g, planes in enumerate(masks):
        for plane, gain in zip(planes, fitted[g]):
            for coordinate in (plane, plane+64):
                folded[g, coordinate] = (old_gamma[g, coordinate]*gain).to(torch.bfloat16).float()
    fq, fk = projected(held_x, paid_weights, folded)
    folded_scores = per_window(fq, fk, hq, hk, masks, {'folded_bf16': unit})['folded_bf16']
    full_q, full_k = projected(held_x, paid_weights, teacher_weights['k_norm'])
    full_scores = full_paid_kl(full_q, full_k, hq, hk)
    scores = dict(floating, folded_bf16=folded_scores, full_paid_qk=full_scores)
    report = {'layer': args.layer, 'ridge': args.ridge, 'train_query_positions': positions,
              'map': 'Original-producer train/held hidden; paid binary Q and K BF16 output; original BF16 Q/K teacher, paid Q/K BF16 norm and RoPE; all causal held keys, two heads/group; frozen 112-plane masks; FP32 score, float64 finite KL for selected arms, torch FP32 softmax for full-paid control',
              'masks': masks, 'gain_fp16': fitted, 'prior_group_affine_bf16': old_gamma.tolist(),
              'folded_group_affine_bf16': folded.tolist(), 'optimization': iterations,
              'train_cross_entropy': train_ce, 'held_kl_by_window': scores,
              'held_mean': {name: float(np.mean(values)) for name, values in scores.items()},
              'source_sha256': sha(Path(__file__)), 'model_sha256': sha(finite.MODEL),
              'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path),
              'prior_affine_sha256': sha(selected_path), 'mask_sha256': sha(mask_path),
              'cost': {'qk_projection_bytes_unchanged': True, 'key_affine_bytes': 448,
                       'key_affine_multiplies_per_token': 224, 'cached_key_coordinates': 224,
                       'score_products_per_key_both_heads': 448,
                       'full_paid_k_affine_bytes': 256, 'full_paid_key_coordinates': 1024,
                       'full_paid_score_products_per_key_both_heads': 2048,
                       'post_gain_fp16_extra_bytes': 224, 'post_gain_fp16_extra_multiplies_per_key': 224}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print('held', report['held_mean'], flush=True)


if __name__ == '__main__':
    main()
