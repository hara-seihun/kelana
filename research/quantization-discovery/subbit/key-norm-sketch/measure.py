#!/usr/bin/env python3
"""Evaluate a sparse raw-row RMSNorm sketch on paid K and causal scores."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def draw(missing, energy, count, seed, stratified):
    rng = np.random.default_rng(seed)
    if stratified:
        order = sorted(missing, key=lambda r: float(energy[r]))
        bins = np.array_split(order, 4)
    else:
        bins = [np.array(missing)]
    rows, weights = [], []
    for bucket in bins:
        n = count // len(bins)
        picked = rng.choice(bucket, n, replace=False)
        rows.extend(int(row) for row in picked)
        weights.extend([len(bucket) / n] * n)
    return rows, weights


def score(raw, selected, norm, gamma, q, p, logp, c, s, causal):
    n = len(selected)//2
    k = ((raw[..., selected].float()*torch.rsqrt(norm + 1e-6)).to(torch.bfloat16)*gamma[selected]).float()
    planes = selected[:n]
    rot = torch.cat((k[..., :n]*c[:, planes]-k[..., n:]*s[:, planes],
                     k[..., n:]*c[:, planes]+k[..., :n]*s[:, planes]), -1)
    logits = (q @ rot[:, None].transpose(-1, -2) / math.sqrt(128)).masked_fill(causal, -1e9)
    return (p*(logp-logits.log_softmax(-1)).masked_fill(causal, 0)).sum(-1).mean(dim=(1, 2)).tolist()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    finite = module(ROOT/'rope-finite-kl/fit.py', 'sketch_finite')
    helper = module(ROOT/'value-observer/measure.py', 'sketch_helper')
    prior = DATA/f'key-rms-factor/layer{args.layer:02d}.json'
    group_path = DATA/f'rope-group-affine/layer{args.layer:02d}.json'
    gain_path = DATA/f'rope-causal-gain/layer{args.layer:02d}.json'
    image_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    masks = json.loads(gain_path.read_text())['masks']
    gamma = torch.tensor(json.loads(group_path.read_text())['group_affine_bf16'], dtype=torch.bfloat16)
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        wq = model.get_tensor(prefix+'q_proj.weight').float()
        wk = model.get_tensor(prefix+'k_proj.weight').float()
        qgamma = model.get_tensor(prefix+'q_norm.weight').float()
        kgamma = model.get_tensor(prefix+'k_norm.weight').float()
    paid = helper.binary_weight(image_path).to(torch.bfloat16).float()
    train_x = finite.load_capture(args.layer, 'train').reshape(8, 256, 1024)
    held_x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    train_raw = (train_x @ paid.T).to(torch.bfloat16).reshape(8, 256, 8, 128)
    held_raw = (held_x @ paid.T).to(torch.bfloat16).reshape(4, 256, 8, 128)
    teacher_q, teacher_k = finite.projections(held_x, dict(q_proj=wq, k_proj=wk, q_norm=qgamma, k_norm=kgamma))
    phase = torch.outer(torch.arange(256).float(), 1 / (1_000_000. ** (torch.arange(64).float()*2/128)))
    c, s = phase.cos().to(torch.bfloat16).float(), phase.sin().to(torch.bfloat16).float()
    causal = torch.ones(256, 256, dtype=torch.bool).triu(1)
    groups = []
    for g, planes in enumerate(masks):
        selected = planes + [r+64 for r in planes]
        missing = sorted(set(range(128)) - set(selected))
        raw = held_raw[:, :, g]
        energy = train_raw[:, :, g].float().square().mean((0, 1))
        full = raw.float().square().mean(-1, keepdim=True)
        base = raw[..., selected].float().square().sum(-1, keepdim=True)
        q = teacher_q[:, 2*g:2*g+2, :, selected]
        teacher_logits = (teacher_q[:, 2*g:2*g+2] @ teacher_k[:, g:g+1].transpose(-1, -2) / math.sqrt(128)).masked_fill(causal, -1e9)
        p, logp = teacher_logits.softmax(-1), teacher_logits.log_softmax(-1)
        arms = {'full': {'denominator_relative_rms_error': 0.,
                         'kl_by_held_window': score(raw, selected, full, gamma[g], q, p, logp, c, s, causal)}}
        for count in (8, 16, 32, 48):
            for stratified in (False, True):
                name = f'{"stratified" if stratified else "uniform"}_{count}'
                trials = []
                for trial in range(8):
                    rows, weights = draw(missing, energy, count, 20260923 + g*1009 + args.layer + trial*100003, stratified)
                    estimate = (base + (raw[..., rows].float().square() * torch.tensor(weights)).sum(-1, keepdim=True)) / 128
                    trials.append({'rows': rows, 'weights': weights,
                                   'denominator_relative_rms_error': float(torch.sqrt(((estimate/full-1)**2).mean())),
                                   'kl_by_held_window': score(raw, selected, estimate, gamma[g], q, p, logp, c, s, causal)})
                arms[name] = trials
        groups.append({'group': g, 'selected_rows': len(selected), 'missing_rows': len(missing), 'arms': arms})
    names = groups[0]['arms']
    receipt = {'layer': args.layer, 'train_windows': 8, 'held_windows': 4,
               'map': 'paid BF16 K output, original Q and teacher K, fixed selected group affine and masks, original-producer captures; BF16 selected normalization, FP32 RoPE/score causal KL; raw-row energy sketches evaluated from BF16 raw K',
               'source_sha256': sha(Path(__file__)), 'model_sha256': sha(finite.MODEL), 'image_sha256': sha(image_path),
               'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
               'group_receipt_sha256': sha(group_path), 'gain_receipt_sha256': sha(gain_path), 'prior_receipt_sha256': sha(prior),
               'groups': groups,
               'mean_held_kl': {name: [float(np.mean([group['arms'][name][trial]['kl_by_held_window'] for group in groups])) for trial in range(8)]
                                if name != 'full' else float(np.mean([group['arms'][name]['kl_by_held_window'] for group in groups])) for name in names},
               'mean_relative_denominator_error': {name: [float(np.mean([group['arms'][name][trial]['denominator_relative_rms_error'] for group in groups])) for trial in range(8)]
                                                   if name != 'full' else 0. for name in names},
               'work': {'rank': 256, 'input_signed_terms': 262144, 'full_output_signed_terms': 262144,
                        'selected_output_signed_terms': 224*256, 'extra_signed_terms_per_row': 256}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'layer': args.layer, 'mean_held_kl': receipt['mean_held_kl'], 'mean_relative_denominator_error': receipt['mean_relative_denominator_error']}, indent=2))


if __name__ == '__main__':
    main()
