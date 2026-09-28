#!/usr/bin/env python3
"""Train-only plane exchanges on frozen paid Q/K, followed by a paid affine refit."""
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
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


paid = imported(ROOT/'paid-qk-plane-gain/measure.py', 'paid_allocation_base')
finite = paid.finite
exchange = imported(ROOT/'rope-finite-kl/fit.py', 'paid_allocation_exchange')
gain_fit = paid.gain_fit


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def optimize_mask(z, valid, teacher, initial, steps):
    # The shortlist ranks the local slope, but accepts only exact finite CE improvements.
    mask, history = exchange.optimize(z, valid, teacher, initial, steps, 16)
    return mask, history


def fit_gain(z, valid, teacher, count):
    solution = minimize(gain_fit.loss_gradient, np.ones(count),
                        args=(z, valid, teacher, .002), jac=True,
                        method='L-BFGS-B', bounds=[(.25, 4.)]*count,
                        options={'maxiter': 80, 'ftol': 1e-10})
    return np.asarray(solution.x, dtype=np.float16).astype(np.float64), bool(solution.success)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--steps', type=int, default=5)
    args = parser.parse_args()
    torch.set_num_threads(4)
    previous_path = DATA/f'paid-qk-plane-gain/layer{args.layer:02d}.json'
    previous = json.loads(previous_path.read_text())
    masks = previous['masks']
    old_gamma = torch.tensor(previous['prior_group_affine_bf16'], dtype=torch.bfloat16).float()
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        teacher_weights = {n: model.get_tensor(prefix+n+'.weight').float()
                           for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(teacher_weights)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    train_x = finite.load_capture(args.layer, 'train').reshape(8, 256, 1024)
    held_x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    tq, tk = paid.projected(train_x, teacher_weights, teacher_weights['k_norm'])
    q, k = paid.projected(train_x, weights, old_gamma)
    positions = previous['train_query_positions']
    selected, gains, histories, objectives, converged = [], [], [], [], []
    for group, initial in enumerate(masks):
        z, valid, _ = finite.rows_for_group(q, k, group, positions)
        _, _, teacher = finite.rows_for_group(tq, tk, group, positions)
        mask, history = optimize_mask(z, valid, teacher, initial, args.steps)
        zs = np.ascontiguousarray(z[:, :, mask].astype(np.float64))
        gain, success = fit_gain(zs, valid, teacher.astype(np.float64), len(mask))
        selected.append(mask)
        gains.append(gain.tolist())
        histories.append(history)
        converged.append(success)
        objectives.append({'prior_unit': exchange.objective(z, valid, teacher, initial),
                           'selected_unit': exchange.objective(z, valid, teacher, mask),
                           'selected_refit': gain_fit.loss_gradient(gain, zs, valid, teacher, 0)[0]})
        print('group', group, 'exchanges', len(history), 'CE', objectives[-1], flush=True)
    hq, hk = paid.projected(held_x, teacher_weights, teacher_weights['k_norm'])
    pq, pk = paid.projected(held_x, weights, old_gamma)
    unit = [[1.] * len(m) for m in selected]
    prior_gains = [previous['gain_fp16'][g] for g in range(8)]
    old = paid.per_window(pq, pk, hq, hk, masks, {'prior_unit': [[1.]*len(m) for m in masks],
                                                    'prior_refit': prior_gains})
    new = paid.per_window(pq, pk, hq, hk, selected,
                          {'selected_unit': unit, 'selected_post_gain': gains})
    folded = old_gamma.clone()
    for g, mask in enumerate(selected):
        for plane, a in zip(mask, gains[g]):
            for coordinate in (plane, plane+64):
                folded[g, coordinate] = (old_gamma[g, coordinate] * a).to(torch.bfloat16).float()
    fq, fk = paid.projected(held_x, weights, folded)
    new['selected_folded'] = paid.per_window(fq, fk, hq, hk, selected,
                                              {'selected_folded': unit})['selected_folded']
    scores = dict(old, **new)
    report = {'layer': args.layer, 'map': 'original-producer captures; paid binary Q/K BF16 projections and RMSNorm; original teacher; both causal heads per group',
              'train_positions': positions, 'train_windows': 8, 'held_windows': 4,
              'selection': 'up to five finite-KL downhill single-plane exchanges per group, slope-shortlisted to 16; fixed group ranks; refit selected affine on same train rows',
              'initial_masks': masks, 'selected_masks': selected, 'exchanges': histories,
              'train_cross_entropy': objectives, 'gain_fp16': gains, 'optimizer_success': converged,
              'selected_group_affine_bf16': folded.tolist(),
              'held_kl_by_window': scores, 'held_mean': {name: float(np.mean(values)) for name, values in scores.items()},
              'cost': {'key_affine_bytes': 448, 'cached_key_coordinates': 224,
                       'score_products_per_key_both_heads': 448,
                       'binary_qk_images_unchanged': True, 'full_raw_key_norm_unchanged': True},
              'source_sha256': sha(Path(__file__)), 'previous_receipt_sha256': sha(previous_path),
              'model_sha256': sha(finite.MODEL),
              'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print('held', report['held_mean'], flush=True)


if __name__ == '__main__':
    main()
