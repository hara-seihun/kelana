#!/usr/bin/env python3
"""Replay a frozen causal K norm after deleting low-gain sampled row strata."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
import importlib.util


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


norm = load(ROOT/'causal-key-norm/measure.py', 'support_norm')
paid = norm.paid
finite = norm.finite
sample = norm.sample


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--group', type=int, choices=range(8), required=True)
    parser.add_argument('--threshold', type=float, default=.1)
    parser.add_argument('--refit', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(3)
    source_path = DATA/f'causal-key-norm/layer{args.layer:02d}-group{args.group}.json'
    source = json.loads(source_path.read_text())
    item = source['candidates']['16']
    coeff = np.array(item['arms']['causal_fit']['coeff_fp16'], dtype=np.float32)
    reduced = coeff.copy()
    reduced[1:][reduced[1:] <= args.threshold] = 0
    removed = [i for i in range(4) if reduced[i+1] == 0]
    selected = source['selected_planes'] + [p+64 for p in source['selected_planes']]
    gamma = torch.tensor(json.loads((DATA/f'paid-qk-plane-allocation/layer{args.layer:02d}.json').read_text())['selected_group_affine_bf16'][args.group], dtype=torch.bfloat16)
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {n: model.get_tensor(prefix+n+'.weight').float()
                    for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    x = finite.load_capture(args.layer, 'validation').reshape(-1, 256, 1024)
    raw = (x @ weights['k_proj'].T).to(torch.bfloat16).reshape(-1, 256, 8, 128)[:, :, args.group]
    q, _ = paid.paid.projected(x, weights, original['k_norm'])
    q = q[:, 2*args.group:2*args.group+2, :, selected]
    tq, tk = paid.paid.projected(x, original, original['k_norm'])
    mask = torch.ones(256, 256, dtype=torch.bool).triu(1)
    reference = (tq[:, 2*args.group:2*args.group+2] @ tk[:, args.group:args.group+1].transpose(-1, -2)/math.sqrt(128)).masked_fill(mask, -1e9)
    teacher = reference.softmax(-1)
    phase = torch.outer(torch.arange(256).float(), 1/(1_000_000.**(torch.arange(64).float()*2/128)))
    cos, sin = phase.cos().to(torch.bfloat16).float(), phase.sin().to(torch.bfloat16).float()
    feat = norm.features(raw, selected, item['rows'], item['weights'])
    denominator = (feat*torch.tensor(reduced)).sum(-1, keepdim=True)
    held = sample.score(raw, selected, denominator, gamma, q, teacher,
                        teacher.clamp_min(1e-30).log(), cos, sin, mask)
    training = None
    train_ce = None
    refit_held = None
    refit_coeff = None
    if args.refit and removed:
        xt = finite.load_capture(args.layer, 'train').reshape(-1, 256, 1024)
        rt = (xt @ weights['k_proj'].T).to(torch.bfloat16).reshape(-1, 256, 8, 128)[:, :, args.group]
        qt, _ = paid.paid.projected(xt, weights, original['k_norm'])
        qt = qt[:, 2*args.group:2*args.group+2, :, selected]
        ttq, ttk = paid.paid.projected(xt, original, original['k_norm'])
        target = (ttq[:, 2*args.group:2*args.group+2] @ ttk[:, args.group:args.group+1].transpose(-1, -2)/math.sqrt(128)).masked_fill(mask, -1e9).softmax(-1)
        z = norm.score_base(rt, selected, gamma, qt, cos, sin)
        ft = norm.features(rt, selected, item['rows'], item['weights'])
        keep = [i for i in range(5) if i == 0 or i-1 not in removed]
        fitted, training = norm.fit(z, ft[..., keep], target.numpy().astype(np.float64),
                                    source['train_query_positions'], coeff[keep].astype(np.float64))
        refit_coeff = np.zeros(5, dtype=np.float32)
        refit_coeff[keep] = fitted
        train_feat = ft.numpy().astype(np.float64)
        target_np = target.numpy().astype(np.float64)
        train_positions = np.array(source['train_query_positions'])
        causal_mask = np.arange(256)[None, None, None, :] <= train_positions[None, None, :, None]
        def causal_ce(a):
            d = np.maximum(np.einsum('wkc,c->wk', train_feat, a), 1e-8)
            logits = np.where(causal_mask, z[:, :, train_positions]/np.sqrt(d[:, None, None, :]+1e-6), -1e30)
            top = logits.max(-1, keepdims=True)
            logsum = np.log(np.exp(logits-top).sum(-1)) + top[..., 0]
            return float(np.mean(logsum - (target_np[:, :, train_positions]*logits).sum(-1)))
        train_ce = {'original': causal_ce(coeff), 'deleted': causal_ce(reduced),
                    'refit': causal_ce(refit_coeff)}
        refit_denominator = (feat*torch.tensor(refit_coeff)).sum(-1, keepdim=True)
        refit_held = sample.score(raw, selected, refit_denominator, gamma, q, teacher,
                                  teacher.clamp_min(1e-30).log(), cos, sin, mask)
    report = {
        'layer': args.layer, 'group': args.group, 'threshold': args.threshold,
        'deleted_bins': removed, 'deleted_raw_rows': len(removed)*4,
        'kept_raw_rows': len(selected)+16-len(removed)*4,
        'frozen_coeff_fp16': coeff.tolist(), 'deleted_coeff_fp16': reduced.tolist(),
        'held_kl_by_window_original': item['arms']['causal_fit']['held_kl_by_window'],
        'held_kl_by_window_deleted': held,
        'refit_coeff_fp16': None if refit_coeff is None else refit_coeff.tolist(),
        'refit_training': training,
        'train_ce_without_penalty': train_ce,
        'held_kl_by_window_refit': refit_held,
        'source_sha256': sha(Path(__file__)), 'parent_receipt_sha256': sha(source_path),
        'model_sha256': sha(finite.MODEL),
        'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
        'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path),
        'observation': 'original-producer paid binary Q/K; frozen plane/affine and frozen FP16 norm coefficients; BF16 normalization; both heads full causal teacher KL on four validation windows'
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({'layer': args.layer, 'group': args.group, 'removed': removed,
                      'base': float(np.mean(report['held_kl_by_window_original'])),
                      'deleted': float(np.mean(held)),
                      'refit': None if refit_held is None else float(np.mean(refit_held))}), flush=True)


if __name__ == '__main__':
    main()
