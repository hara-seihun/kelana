#!/usr/bin/env python3
"""Price spectral corrections to the paid binary K factor's isotropic RMS."""
import argparse
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import nnls
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
sys.path.insert(0, str(ROOT / 'value-observer'))


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def modular_rank(matrix, prime=65521):
    a = np.asarray(matrix, dtype=np.int64) % prime
    row = 0
    for col in range(a.shape[1]):
        pivots = np.flatnonzero(a[row:, col])
        if len(pivots) == 0:
            continue
        pivot = row + int(pivots[0])
        a[[row, pivot]] = a[[pivot, row]]
        a[row] = a[row] * pow(int(a[row, col]), -1, prime) % prime
        nonzero = np.flatnonzero(a[row+1:, col]) + row + 1
        a[nonzero] = (a[nonzero] - a[nonzero, col, None]*a[row]) % prime
        row += 1
        if row == a.shape[0]:
            break
    return row


def score(raw, selected, norm, gamma, q, p, logp, c, s, causal):
    n = len(selected) // 2
    k = ((raw[..., selected].float() * torch.rsqrt(norm.clamp_min(0) + 1e-6)).to(torch.bfloat16) * gamma[selected]).float()
    planes = selected[:n]
    rot = torch.cat((k[..., :n]*c[:, planes]-k[..., n:]*s[:, planes],
                     k[..., n:]*c[:, planes]+k[..., :n]*s[:, planes]), -1)
    logits = (q @ rot[:, None].transpose(-1, -2) / math.sqrt(128)).masked_fill(causal, -1e9)
    return (p * (logp - logits.log_softmax(-1)).masked_fill(causal, 0)).sum(-1).mean(dim=(1, 2)).tolist()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    finite = load(ROOT / 'rope-finite-kl/fit.py', 'gram_finite')
    fit = load(ROOT / 'value-observer/fit.py', 'gram_fit')
    prior = DATA / f'key-norm-sketch/layer{args.layer:02d}.json'
    group_path = DATA / f'rope-group-affine/layer{args.layer:02d}.json'
    gain_path = DATA / f'rope-causal-gain/layer{args.layer:02d}.json'
    image_path = DATA / f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    masks = json.loads(gain_path.read_text())['masks']
    gamma = torch.tensor(json.loads(group_path.read_text())['group_affine_bf16'], dtype=torch.bfloat16)
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        wq = model.get_tensor(prefix+'q_proj.weight').float()
        wk = model.get_tensor(prefix+'k_proj.weight').float()
        qgamma = model.get_tensor(prefix+'q_norm.weight').float()
        kgamma = model.get_tensor(prefix+'k_norm.weight').float()
    with np.load(image_path) as image:
        u = fit.unpack(image['U'], 256)
        v = fit.unpack(image['V'], 1024)
        pre = torch.from_numpy(image['scale_pre'].copy()).float()
        post = torch.from_numpy(image['scale_post'].copy()).float()
    input_rank = modular_rank(v.numpy().astype(np.int64))
    paid = (u * post[:, None]) @ (v * pre[None, :])
    held_x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    raw = (held_x @ paid.T).to(torch.bfloat16).reshape(4, 256, 8, 128)
    train_x = finite.load_capture(args.layer, 'train').reshape(8, 256, 1024)
    train_raw = (train_x @ paid.T).to(torch.bfloat16).reshape(8, 256, 8, 128)
    # This changes the order of operations relative to the expanded BF16 evaluator.
    z = ((held_x * pre) @ v.T).reshape(4, 256, 256)
    train_z = (train_x * pre) @ v.T
    z2 = z.square().sum(-1, keepdim=True)
    teacher_q, teacher_k = finite.projections(held_x, dict(q_proj=wq, k_proj=wk, q_norm=qgamma, k_norm=kgamma))
    phase = torch.outer(torch.arange(256).float(), 1 / (1_000_000. ** (torch.arange(64).float()*2/128)))
    c, s = phase.cos().to(torch.bfloat16).float(), phase.sin().to(torch.bfloat16).float()
    causal = torch.ones(256, 256, dtype=torch.bool).triu(1)
    groups = []
    for g, planes in enumerate(masks):
        selected = planes + [r+64 for r in planes]
        key = raw[:, :, g]
        full = key.float().square().mean(-1, keepdim=True)
        # G has an exactly constant diagonal, but its off-diagonal may matter on reachable z.
        a = u[g*128:(g+1)*128] * post[g*128:(g+1)*128, None]
        gram = a.T @ a / 128
        alpha = float(torch.diagonal(gram).mean())
        residual = gram - alpha * torch.eye(256)
        eigen, basis = torch.linalg.eigh(residual.double())
        order = torch.argsort(eigen.abs(), descending=True)
        eigen, basis = eigen[order].float(), basis[:, order].float()
        exact_factor = ((z @ a.T).to(torch.bfloat16).float().square().mean(-1, keepdim=True))
        teacher_logits = (teacher_q[:, 2*g:2*g+2] @ teacher_k[:, g:g+1].transpose(-1, -2) / math.sqrt(128)).masked_fill(causal, -1e9)
        p, logp = teacher_logits.softmax(-1), teacher_logits.log_softmax(-1)
        q = teacher_q[:, 2*g:2*g+2, :, selected]
        norms = {'expanded_full': full, 'factor_full': exact_factor, 'isotropic': alpha*z2}
        corrections = (z @ basis).square() * eigen
        for rank in (8, 16, 32, 64):
            norms[f'spectral_{rank}'] = alpha*z2 + corrections[..., :rank].sum(-1, keepdim=True)
        selected_energy = key[..., selected].float().square().sum(-1, keepdim=True)/128
        train_selected = train_raw[:, :, g, selected].float().square().sum(-1, keepdim=True)/128
        train_full = train_raw[:, :, g].float().square().mean(-1, keepdim=True)
        train_proj = (train_z @ basis[:, :64]).square().reshape(-1, 64)
        held_proj = (z @ basis[:, :64]).square().reshape(-1, 64)
        missing = sorted(set(range(128)) - set(selected))
        missing_a = a[missing]
        missing_rank = modular_rank(u[g*128:(g+1)*128][missing].numpy().astype(np.int64))
        full_rank = modular_rank(u[g*128:(g+1)*128].numpy().astype(np.int64))
        missing_gram = missing_a.T @ missing_a / 128
        missing_eigen, missing_basis = torch.linalg.eigh(missing_gram.double())
        missing_basis = missing_basis[:, -64:].flip(1).float()
        train_missing = (train_full - train_selected).flatten().numpy()
        missing_train_proj = (train_z @ missing_basis).square().reshape(-1, 64).numpy()
        missing_held_proj = (z @ missing_basis).square().reshape(-1, 64).numpy()
        nnls_coefficients = {}
        for rank in (0, 8, 16, 32, 64):
            x_fit = np.column_stack((train_z.square().sum(-1).reshape(-1).numpy(), missing_train_proj[:, :rank]))
            x_pred = np.column_stack((z2.reshape(-1).numpy(), missing_held_proj[:, :rank]))
            scales = np.sqrt(np.mean(x_fit*x_fit, axis=0)).clip(1e-10)
            standardized = x_fit / scales
            penalty = np.sqrt(.01*len(standardized)) * np.eye(standardized.shape[1])
            positive, _ = nnls(np.vstack((standardized, penalty)), np.concatenate((train_missing, np.zeros(len(scales)))))
            nnls_coefficients[str(rank)] = (positive/scales).tolist()
            norms[f'missing_nnls_{rank}'] = selected_energy + torch.from_numpy((x_pred @ (positive/scales)).reshape(full.shape)).float()
            x_train = torch.cat((train_selected.reshape(-1, 1), train_z.square().sum(-1, keepdim=True).reshape(-1, 1),
                                 train_proj[:, :rank], torch.ones(train_z.shape[0]*train_z.shape[1], 1)), 1).double()
            x_held = torch.cat((selected_energy.reshape(-1, 1), z2.reshape(-1, 1),
                                held_proj[:, :rank], torch.ones(z.shape[0]*z.shape[1], 1)), 1).double()
            scales = x_train.square().mean(0).sqrt().clamp_min(1e-12)
            xs = x_train / scales
            target = train_full.reshape(-1, 1).double()
            penalty = .01 * len(xs) * torch.eye(xs.shape[1], dtype=torch.double)
            penalty[-1, -1] = 0
            coefficients = torch.linalg.solve(xs.T @ xs + penalty, xs.T @ target)/scales[:, None]
            norms[f'train_ridge_{rank}'] = (x_held @ coefficients).float().reshape_as(full)
        scores = {name: score(key, selected, norm, gamma[g], q, p, logp, c, s, causal) for name, norm in norms.items()}
        errors = {name: float(torch.sqrt(((norm/full-1).square().mean()))) for name, norm in norms.items()}
        groups.append({'group': g, 'rank_mod_65521_full': full_rank, 'rank_mod_65521_missing': missing_rank,
                       'post_scale_nonzero': bool(torch.all(post[g*128:(g+1)*128] != 0)),
                       'alpha': alpha, 'nnls_coefficients': nnls_coefficients,
                       'min_gram_eigen': float(eigen.min()+alpha),
                       'max_gram_eigen': float(eigen.max()+alpha), 'selected_rows': len(selected),
                       'kl_by_held_window': scores, 'relative_denominator_error': errors})
    arms = groups[0]['kl_by_held_window']
    result = {'layer': args.layer, 'source_sha256': digest(Path(__file__)), 'model_sha256': digest(finite.MODEL),
              'image_sha256': digest(image_path), 'capture_sha256': digest(fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'prior_sha256': digest(prior), 'group_affine_sha256': digest(group_path), 'gain_sha256': digest(gain_path),
              'map': 'original-producer Q and teacher K; expanded BF16 paid K selected numerators; FP32 packed-factor z and real spectral denominator, BF16 normalized selected K, FP32 RoPE/score; four inspected 256-token validation windows',
              'input_rank_mod_65521': input_rank, 'pre_scale_nonzero': bool(torch.all(pre != 0)),
              'groups': groups,
              'mean_held_kl': {name: float(np.mean([group['kl_by_held_window'][name] for group in groups])) for name in arms},
              'mean_relative_denominator_error': {name: float(np.mean([group['relative_denominator_error'][name] for group in groups])) for name in arms},
              'work': {'shared_input_signed_terms': 262144, 'selected_output_signed_terms': 57344,
                       'factor_norm_squared_terms': 256, 'spectral_projection_products_per_rank': 8*256,
                       'full_output_signed_terms': 262144, 'stored_fp16_bytes_per_rank': 8*256*2}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'layer': args.layer, 'mean_held_kl': result['mean_held_kl'],
                      'mean_relative_denominator_error': result['mean_relative_denominator_error']}, indent=2))


if __name__ == '__main__':
    main()
