#!/usr/bin/env python3
"""Price a translated one-byte key cache on the frozen paid Q/K score map."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')


def imported(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


paid = imported(ROOT/'paid-qk-plane-gain/measure.py', 'center_paid')
finite = paid.finite


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def scores(q, k, positions):
    return (q[:, :, positions].double() @ k.double().transpose(-1, -2)) / math.sqrt(128)


def kl(q, k, teacher, positions):
    candidate = scores(q, k, positions)
    causal = torch.arange(256)[None, :] > torch.tensor(positions)[:, None]
    candidate = candidate.masked_fill(causal, -1e9)
    reference = teacher.masked_fill(causal, -1e9)
    logp = reference.log_softmax(-1)
    return float((logp.exp() * (logp - candidate.log_softmax(-1))).sum(-1).mean())


def quantize(k, center, scales):
    return (torch.round((k - center) / scales).clamp(-127, 127) * scales).float()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    prior_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        p = f'model.layers.{args.layer}.self_attn.'
        original = {n: model.get_tensor(p+n+'.weight').float() for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    positions = list(range(64, 256, 12))
    train_x = finite.load_capture(args.layer, 'train').reshape(8, 256, 1024)
    held_x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    results = []
    for x in (train_x, held_x):
        q, k = paid.projected(x, weights, gamma)
        tq, tk = paid.projected(x, original, original['k_norm'])
        results.append((q, k, tq, tk))
    train, held = results
    quantiles = (.99, .995, .999, 1.)
    groups = []
    for g, mask in enumerate(prior['new_masks']):
        idx = mask + [p+64 for p in mask]
        qt = train[0][:, 2*g:2*g+2, :, idx]
        kt = train[1][:, g:g+1, :, idx]
        qh, kh = held[0][:, 2*g:2*g+2, :, idx], held[1][:, g:g+1, :, idx]
        tq_h, tk_h = held[2][:, 2*g:2*g+2], held[3][:, g:g+1]
        teacher_train = scores(train[2][:, 2*g:2*g+2], train[3][:, g:g+1], positions)
        teacher_held = scores(tq_h, tk_h, list(range(256)))
        center = kt.double().mean((0, 2), keepdim=True).half().float()
        arms = {}
        for name, origin in [('raw', torch.zeros_like(center)), ('centered', center)]:
            candidates = []
            for quantile in quantiles:
                scale = (torch.quantile((kt-origin).abs().reshape(-1), quantile).clamp_min(1e-8)/127).half().float()
                kq = quantize(kt, origin, scale)
                candidates.append((kl(qt, kq, teacher_train, positions), quantile, float(scale)))
            selected = min(candidates)
            scale = torch.tensor(selected[2], dtype=torch.float16).float()
            arms[name] = {'train_candidates': [{'kl': v, 'quantile': p, 'step': s} for v,p,s in candidates],
                          'selected_train_kl': selected[0], 'selected_quantile': selected[1],
                          'step': selected[2],
                          'held_by_window': [kl(qh[w:w+1], quantize(kh[w:w+1], origin, scale),
                                                teacher_held[w:w+1], list(range(256))) for w in range(4)]}
        baseline = {}
        for name, key in [('real', kh), ('bf16_raw', kh.bfloat16().float()),
                          ('bf16_centered', (kh-center).bfloat16().float())]:
            baseline[name] = [kl(qh[w:w+1], key[w:w+1], teacher_held[w:w+1], list(range(256))) for w in range(4)]
        groups.append({'group': g, 'mask': mask, 'train_center': center.flatten().tolist(),
                       'int8': arms, 'baseline': baseline})
        print('group', g, 'held int8', {k: sum(v['held_by_window'])/4 for k,v in arms.items()}, flush=True)
    aggregate = {}
    for name in ('real', 'bf16_raw', 'bf16_centered', 'int8_raw', 'int8_centered'):
        aggregate[name] = [sum((v['baseline'][name] if name in v['baseline'] else
                                 v['int8'][name[5:]]['held_by_window'])[w] for v in groups)/8 for w in range(4)]
    selected = ['centered' if v['int8']['centered']['selected_train_kl'] <
                v['int8']['raw']['selected_train_kl'] else 'raw' for v in groups]
    aggregate['int8_train_selected'] = [sum(v['int8'][selected[g]]['held_by_window'][w]
                                           for g, v in enumerate(groups))/8 for w in range(4)]
    report = {'layer': args.layer, 'map': 'original-producer Qwen3-0.6B, paid binary Q/K, BF16 producer and norm, FP32 RoPE; full raw K denominator, fixed 128 selected planes; one train-chosen scalar int8 step per group; original Q/K teacher; double causal scores and softmax',
              'train_windows': 8, 'held_windows': 4, 'positions_train': positions,
              'int8_quantile_candidates': quantiles, 'groups': groups,
              'group_arms_selected_by_train': selected, 'held_by_window': aggregate,
              'held_mean': {k: sum(v)/4 for k,v in aggregate.items()},
              'cost': {'baseline_padded_bf16_key_bytes_per_token': 512,
                       'int8_padded_key_bytes_per_token': 256,
                       'center_fp16_bytes_per_layer': 512,
                       'int8_step_fp16_bytes_per_layer': 16,
                       'post_rope_subtracts_per_token': 256,
                       'quantize_multiplies_and_rounds_per_token': 256,
                       'query_scale_multiplies_per_query': 512,
                       'query_score_products_per_key_both_heads': 512,
                       'k_raw_norm_rows': 1024,
                       'consumer_requires_int8_to_float_scale_per_score_coordinate': True},
              'source_sha256': sha(Path(__file__)), 'prior_sha256': sha(prior_path),
              'model_sha256': sha(finite.MODEL), 'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print('held', report['held_mean'], flush=True)


if __name__ == '__main__':
    main()
