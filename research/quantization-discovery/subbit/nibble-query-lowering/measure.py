#!/usr/bin/env python3
"""Replay the frozen paid nibble key image with a direct integer-dot query coordinate."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit')


def imported(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cache = imported(ROOT/'key-nibble-cache/measure.py', 'nibble_cache')
paid = cache.paid
finite = cache.finite


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def causal_kl(candidate, teacher):
    n = candidate.shape[-1]
    mask = torch.arange(n)[None, :] > torch.arange(n)[:, None]
    a = candidate.masked_fill(mask, -1e9).log_softmax(-1)
    b = teacher.masked_fill(mask, -1e9).log_softmax(-1)
    return ((b.exp() * (b-a)).sum(-1)).mean((-1, -2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    source = Path(__file__)
    parent_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    prior = json.loads((DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json').read_text())
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {name: model.get_tensor(prefix+name+'.weight').float() for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    q, k = paid.projected(x, weights, gamma)
    tq, tk = paid.projected(x, original, original['k_norm'])
    by_group = []
    for g, group in enumerate(parent['groups']):
        mask = group['mask']
        idx = mask + [p+64 for p in mask]
        qg = q[:, 2*g:2*g+2, :, idx].double()
        kg = k[:, g:g+1, :, idx].double()
        arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if arm.startswith('centered') else [0]*len(idx), dtype=torch.float64)
        codes = ((kg-center)/steps).round().clamp(-7, 7)
        prepared = qg*steps
        exact = (prepared @ codes.transpose(-1, -2))/math.sqrt(128)
        teacher = cache.scores(tq[:, 2*g:2*g+2], tk[:, g:g+1], list(range(256)))
        entries = {}
        for bits, cap in [('q4', 7), ('q8', 119)]:
            delta = prepared.abs().amax(-1, keepdim=True).clamp_min(1e-20)/cap
            iq = (prepared/delta).round().clamp(-cap, cap)
            # Every integer product and its sum is exact in float64 here. This is
            # equivalent to a signed integer dot, not a floating-weight decoder.
            reconstructed = (iq @ codes.transpose(-1, -2))*delta/math.sqrt(128)
            err = (reconstructed-exact).abs()
            entries[bits] = {'kl_by_window': causal_kl(reconstructed, teacher).tolist(),
                             'max_score_abs_error_by_window': err.amax((-1,-2,-3)).tolist(),
                             'mean_score_abs_error_by_window': err.mean((-1,-2,-3)).tolist()}
            if bits == 'q8':
                lo = ((iq+8).remainder(16)-8)
                hi = (iq-lo)/16
                assert torch.equal(iq, lo+16*hi)
                assert int(lo.min()) >= -8 and int(lo.max()) <= 7
                assert int(hi.min()) >= -8 and int(hi.max()) <= 7
                assert torch.equal(iq @ codes.transpose(-1,-2),
                                   lo @ codes.transpose(-1,-2) + 16*(hi @ codes.transpose(-1,-2)))
        entries['float_query'] = {'kl_by_window': causal_kl(exact, teacher).tolist()}
        entries['arm'] = arm
        by_group.append(entries)
        print('group', g, 'q4/q8 KL', [sum(entries[b]['kl_by_window'])/4 for b in ('q4','q8')], flush=True)
    result = {'layer': args.layer, 'contract': 'original-producer paid binary Q/K, selected signed nibble K and train-selected FP16 coordinate steps/center; per-query/head/group max-absolute dynamic signed 4- or 8-bit Q after multiplying by steps; real softmax causal scores reconstructed from exact integer dots and FP64 query scale',
              'groups': by_group,
              'aggregate_by_window': {arm: [sum(group[arm]['kl_by_window'][w] for group in by_group)/8 for w in range(4)] for arm in ('float_query','q4','q8')},
              'cost': {'key_bytes_per_token_layer': 128, 'step_bytes_per_layer': 512,
                       'query_step_products_both_heads': 512, 'query_round_clip_both_heads': 512,
                       'query_dynamic_abs_and_max_both_heads': 512,
                       'signed_nibble_products_per_key_q4_both_heads': 512,
                       'signed_nibble_products_per_key_q8_split_both_heads': 1024,
                       'score_scale_multiplies_per_key_both_heads': 16,
                       'key_raw_norm_rows': 1024,
                       'query_scaling_is_activation_dependent_and_not_hidden_outside_timing': True,
                       'native_latency_measured': False},
              'source_sha256': sha(source), 'parent_sha256': sha(parent_path), 'model_sha256': sha(finite.MODEL),
              'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path)}
    result['aggregate_mean'] = {arm: sum(v)/4 for arm,v in result['aggregate_by_window'].items()}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print('aggregate', result['aggregate_mean'], flush=True)


if __name__ == '__main__':
    main()
