#!/usr/bin/env python3
"""Fit the paid sparse K denominator to the two-head finite causal observer."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from scipy.optimize import minimize
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')


def imported(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


paid = imported(ROOT/'paid-qk-plane-allocation/measure.py', 'causal_norm_paid')
finite = paid.finite
sample = imported(ROOT/'key-norm-sketch/measure.py', 'causal_norm_sample')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def features(raw, selected, rows, weights):
    base = raw[..., selected].float().square().sum(-1)
    if not rows:
        return torch.stack([base/128], -1)
    parts = [base/128]
    bin_width = len(rows)//4
    for start in range(0, len(rows), bin_width):
        ix = rows[start:start+bin_width]
        parts.append((raw[..., ix].float().square() * torch.tensor(weights[start:start+bin_width])).sum(-1)/128)
    return torch.stack(parts, -1)


def score_base(raw, selected, gamma, q, cos, sin):
    n = len(selected)//2
    planes = selected[:n]
    k = raw[..., selected].float()*gamma[selected].float()
    rot = torch.cat((k[..., :n]*cos[:, planes]-k[..., n:]*sin[:, planes],
                     k[..., n:]*cos[:, planes]+k[..., :n]*sin[:, planes]), -1)
    return (q @ rot[:, None].transpose(-1, -2) / math.sqrt(128)).numpy().astype(np.float64)


def fit(base, f, target, positions, initial, ridge=0.001):
    # Causal masked keys have zero probability; this exact finite CE is smooth in
    # the positive denominator, unlike a BF16-rounded normalization.
    base = base[:, :, positions]
    target = target[:, :, positions]
    feat = f.numpy().astype(np.float64)
    nk = np.arange(base.shape[-1]) <= np.asarray(positions)[:, None]
    mask = nk[None, None, :, :]
    n = base.shape[0]*base.shape[1]*base.shape[2]

    def objective(a):
        d = np.maximum(np.einsum('wkc,c->wk', feat, a), 1e-8)
        z = base / np.sqrt(d[:, None, None, :] + 1e-6)
        z = np.where(mask, z, -1e30)
        top = z.max(-1, keepdims=True)
        exp = np.exp(z-top)*mask
        logsum = np.log(exp.sum(-1, keepdims=True)) + top
        p = exp/exp.sum(-1, keepdims=True)
        loss = (logsum[..., 0] - (target*z).sum(-1)).sum()/n
        grad_z = (p-target)/n
        grad_d = (grad_z * (-0.5*z/(d[:, None, None, :]+1e-6))).sum((1, 2))
        gradient = np.einsum('wk,wkc->c', grad_d, feat)
        loss += ridge*np.square(a-initial).sum()
        gradient += 2*ridge*(a-initial)
        return loss, gradient

    result = minimize(objective, initial, jac=True, bounds=[(0.05, 4.)]*len(initial),
                      method='L-BFGS-B', options={'maxiter': 60, 'ftol': 1e-9})
    return np.asarray(result.x, dtype=np.float16).astype(np.float64), {
        'iterations': int(result.nit), 'success': bool(result.success),
        'train_ce_initial': float(objective(initial)[0]),
        'train_ce_fitted': float(objective(result.x)[0]),
        'train_ce_fp16': float(objective(np.asarray(result.x, dtype=np.float16).astype(np.float64))[0])}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--group', type=int, choices=range(8), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    previous_path = DATA/f'paid-qk-plane-allocation/layer{args.layer:02d}.json'
    previous = json.loads(previous_path.read_text())
    g = args.group
    planes = previous['selected_masks'][g]
    selected = planes + [r+64 for r in planes]
    missing = sorted(set(range(128))-set(selected))
    gamma = torch.tensor(previous['selected_group_affine_bf16'][g], dtype=torch.bfloat16)
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {n: model.get_tensor(prefix+n+'.weight').float()
                    for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    paid_weights = dict(original)
    paid_weights['q_proj'] = paid.paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    paid_weights['k_proj'] = paid.paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    xs = [finite.load_capture(args.layer, split).reshape(-1, 256, 1024)
          for split in ('train', 'validation')]
    raw, queries, teacher = [], [], []
    for x in xs:
        raw.append((x @ paid_weights['k_proj'].T).to(torch.bfloat16).reshape(-1, 256, 8, 128)[:, :, g])
        q, _ = paid.paid.projected(x, paid_weights, original['k_norm'])
        queries.append(q[:, 2*g:2*g+2, :, selected])
        tq, tk = paid.paid.projected(x, original, original['k_norm'])
        causal = torch.ones(256, 256, dtype=torch.bool).triu(1)
        reference = (tq[:, 2*g:2*g+2] @ tk[:, g:g+1].transpose(-1, -2)/math.sqrt(128)).masked_fill(causal, -1e9)
        teacher.append(reference.softmax(-1))
    phase = torch.outer(torch.arange(256).float(), 1/(1_000_000.**(torch.arange(64).float()*2/128)))
    cos, sin = phase.cos().to(torch.bfloat16).float(), phase.sin().to(torch.bfloat16).float()
    z = score_base(raw[0], selected, gamma, queries[0], cos, sin)
    positions = json.loads((DATA/f'paid-qk-plane-gain/layer{args.layer:02d}.json').read_text())['train_query_positions']
    train_energy = raw[0].float().square().mean((0,1)).numpy()
    denominator = raw[1].float().square().mean(-1, keepdim=True)
    scores = {'full': sample.score(raw[1], selected, denominator, gamma, queries[1], teacher[1],
                                    teacher[1].clamp_min(1e-30).log(), cos, sin, causal)}
    candidates = {}
    for count in (0, 16, 32):
        rows, weights = (sample.draw(missing, train_energy, count, 20260923+g*1009+args.layer, True)
                         if count else ([], []))
        tf = features(raw[0], selected, rows, weights)
        hf = features(raw[1], selected, rows, weights)
        initial = np.ones(tf.shape[-1], dtype=np.float64)
        fitted, training = fit(z, tf, teacher[0].numpy().astype(np.float64), positions, initial)
        arms = {'untrained': initial, 'causal_fit': fitted}
        if count == 0:
            ref = raw[0].float().square().mean(-1).reshape(-1)
            part = tf[..., 0].reshape(-1)
            arms['energy_fit'] = np.array([float((ref@part)/(part@part))])
        values = {}
        for name, coeff in arms.items():
            denom = (hf*torch.tensor(coeff, dtype=torch.float32)).sum(-1, keepdim=True)
            values[name] = {'coeff_fp16': np.asarray(coeff, dtype=np.float16).astype(np.float64).tolist(),
                            'held_kl_by_window': sample.score(raw[1], selected, denom, gamma, queries[1], teacher[1],
                                                              teacher[1].clamp_min(1e-30).log(), cos, sin, causal),
                            'held_relative_denominator_rms': float(torch.sqrt(((denom/denominator-1)**2).mean()))}
        candidates[str(count)] = {'rows': rows, 'weights': weights, 'train': training, 'arms': values}
    report = {'layer': args.layer, 'group': g, 'selected_planes': planes, 'train_query_positions': positions,
              'train_windows': raw[0].shape[0], 'held_windows': raw[1].shape[0],
              'map': 'original-producer hidden; paid binary Q/K BF16 raw projection; latest paid selected planes and BF16 affine; two paid Q heads; original teacher; FP32 smooth finite causal CE fit, FP16 denominator coefficients and BF16 key normalization for held full-causal KL',
              'full_held_kl_by_window': scores['full'], 'candidates': candidates,
              'cost': {'rank': 256, 'selected_rows': len(selected), 'missing_rows': len(missing),
                       'extra_signed_terms_per_row': 256, 'factor_signed_terms_common': 262144,
                       'fp16_coeff_bytes': 10, 'cached_key_coordinates': len(selected),
                       'score_products_per_key_both_heads': 2*len(selected)},
              'source_sha256': sha(Path(__file__)), 'previous_receipt_sha256': sha(previous_path),
              'model_sha256': sha(finite.MODEL),
              'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({'layer': args.layer, 'group': g, 'full': scores['full'],
                      'arms': {count: {name: np.mean(v['held_kl_by_window']) for name,v in item['arms'].items()}
                               for count,item in candidates.items()}}, indent=2), flush=True)


if __name__ == '__main__':
    main()
