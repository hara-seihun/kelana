#!/usr/bin/env python3
"""Spend the unused half-plane slots in paid Q/K's eight padded cache lines."""
import argparse
import hashlib
import importlib.util
import json
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
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


base = imported(ROOT / 'paid-qk-plane-gain/measure.py', 'cache_slack_base')
finite = base.finite


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def add_planes(z, valid, teacher, initial, capacity):
    selected = list(initial)
    score = z[:, :, selected].sum(axis=-1)
    history = []
    for _ in range(capacity - len(selected)):
        masked = np.where(valid, score, -1e9)
        probs = np.exp(masked - masked.max(axis=1, keepdims=True))
        probs /= probs.sum(axis=1, keepdims=True)
        slope = np.einsum('nk,nkj->j', probs - teacher, z, optimize=True) / len(z)
        mean = np.einsum('nk,nkj->nj', probs, z, optimize=True)
        curvature = (np.einsum('nk,nkj->j', probs, z*z, optimize=True)
                     - (mean*mean).sum(axis=0)) / len(z)
        step = np.clip(-slope / np.maximum(curvature, 1e-12), .25, 4.)
        predicted = -(step*slope + .5*step*step*curvature)
        predicted[selected] = -np.inf
        plane = int(np.argmax(predicted))
        selected.append(plane)
        score += step[plane] * z[:, :, plane]
        history.append({'plane': plane, 'gain': float(step[plane]),
                        'predicted_ce_improvement': float(predicted[plane])})
    return sorted(selected), history


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    prior_path = DATA / f'paid-qk-plane-allocation/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    masks = prior['selected_masks']
    original_gamma = torch.tensor(prior['selected_group_affine_bf16'], dtype=torch.bfloat16).float()
    q_path = DATA / f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA / f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        teacher = {name: model.get_tensor(prefix+name+'.weight').float()
                   for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(teacher)
    weights['q_proj'] = base.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = base.helper.binary_weight(k_path).to(torch.bfloat16).float()
    train = finite.load_capture(args.layer, 'train').reshape(8, 256, 1024)
    held = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    tq, tk = base.projected(train, teacher, teacher['k_norm'])
    pq, pk = base.projected(train, weights, original_gamma)
    positions = json.loads((DATA / f'paid-qk-plane-gain/layer{args.layer:02d}.json').read_text())['train_query_positions']
    new_masks, addition, changes, control_changes, train_scores = [], [], [], [], []
    for group, mask in enumerate(masks):
        z, valid, _ = finite.rows_for_group(pq, pk, group, positions)
        _, _, reference = finite.rows_for_group(tq, tk, group, positions)
        z = np.ascontiguousarray(z.astype(np.float64))
        reference = reference.astype(np.float64)
        chosen, history = add_planes(z, valid, reference, mask, 16)
        control = minimize(base.gain_fit.loss_gradient, np.ones(len(mask)),
                           args=(np.ascontiguousarray(z[:, :, mask]), valid, reference, .002),
                           jac=True, method='L-BFGS-B', bounds=[(.25, 4.)]*len(mask),
                           options={'maxiter': 80, 'ftol': 1e-10})
        control_changes.append(np.asarray(control.x, dtype=np.float16).astype(np.float64).tolist())
        zs = np.ascontiguousarray(z[:, :, chosen])
        fit = minimize(base.gain_fit.loss_gradient, np.ones(16),
                       args=(zs, valid, reference, .002), jac=True,
                       method='L-BFGS-B', bounds=[(.25, 4.)]*16,
                       options={'maxiter': 80, 'ftol': 1e-10})
        gain = np.asarray(fit.x, dtype=np.float16).astype(np.float64)
        new_masks.append(chosen)
        addition.append(history)
        changes.append(gain.tolist())
        train_scores.append({'previous_ce': base.gain_fit.loss_gradient(np.ones(len(mask)),
                            np.ascontiguousarray(z[:, :, mask]), valid, reference, 0)[0],
                            'new_ce': base.gain_fit.loss_gradient(gain, zs, valid, reference, 0)[0],
                            'fit_success': bool(fit.success)})
        print('group', group, 'added', [h['plane'] for h in history], 'CE', train_scores[-1], flush=True)
    hq, hk = base.projected(held, teacher, teacher['k_norm'])
    oldq, oldk = base.projected(held, weights, original_gamma)
    baseline = base.per_window(oldq, oldk, hq, hk, masks,
                               {'prior_112': [[1.]*len(m) for m in masks]})['prior_112']
    control_folded = original_gamma.clone()
    for group, mask in enumerate(masks):
        for plane, gain in zip(mask, control_changes[group]):
            for coord in (plane, plane + 64):
                control_folded[group, coord] = (original_gamma[group, coord]*gain).to(torch.bfloat16).float()
    cq, ck = base.projected(held, weights, control_folded)
    control_scores = base.per_window(cq, ck, hq, hk, masks,
                                     {'refit_112_bf16_affine': [[1.]*len(m) for m in masks]})['refit_112_bf16_affine']
    float_scores = base.per_window(oldq, oldk, hq, hk, new_masks,
                                   {'new_128_fp16_gain': changes})['new_128_fp16_gain']
    folded = original_gamma.clone()
    for group, mask in enumerate(new_masks):
        for plane, gain in zip(mask, changes[group]):
            for coord in (plane, plane + 64):
                folded[group, coord] = (original_gamma[group, coord]*gain).to(torch.bfloat16).float()
    newq, newk = base.projected(held, weights, folded)
    folded_scores = base.per_window(newq, newk, hq, hk, new_masks,
                                    {'new_128_bf16_affine': [[1.]*16 for _ in range(8)]})['new_128_bf16_affine']
    scores = {'prior_112': baseline, 'refit_112_bf16_affine': control_scores,
              'new_128_fp16_gain': float_scores, 'new_128_bf16_affine': folded_scores}
    result = {'layer': args.layer, 'domain': 'original-producer Qwen3-0.6B BF16-rounded paid binary Q/K; two causal heads/group; 16 strided train queries/window, all causal held rows',
              'prior_masks': masks, 'new_masks': new_masks, 'greedy_additions': addition,
              'gain_fp16': changes, 'new_group_affine_bf16': folded.tolist(),
              'control_gain_fp16': control_changes, 'control_group_affine_bf16': control_folded.tolist(),
              'train': train_scores, 'held_kl_by_window': scores,
              'held_mean': {name: float(np.mean(s)) for name, s in scores.items()},
              'cost': {'key_cache_padded_bytes_per_token': 512, 'key_cache_logical_bf16_bytes_old_new': [448, 512],
                       'affine_bf16_bytes_old_new': [448, 512],
                       'score_products_per_key_two_heads_old_new': [448, 512],
                       'k_norm_raw_rows_unchanged': 1024, 'paid_qk_factor_images_unchanged': True},
              'source_sha256': digest(Path(__file__)), 'prior_sha256': digest(prior_path),
              'model_sha256': digest(finite.MODEL),
              'capture_sha256': digest(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256': digest(q_path), 'paid_k_sha256': digest(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print('held', result['held_mean'], flush=True)


if __name__ == '__main__':
    main()
