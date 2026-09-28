#!/usr/bin/env python3
"""Measure a query-only error certificate for the frozen signed-nibble key score."""
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


cache = imported(ROOT/'key-nibble-cache/measure.py', 'gate_cache')
paid = cache.paid
finite = cache.finite


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def causal_kl_rows(candidate, reference):
    n = candidate.shape[-1]
    mask = torch.arange(n)[None, :] > torch.arange(n)[:, None]
    p = reference.masked_fill(mask, -1e9).log_softmax(-1)
    q = candidate.masked_fill(mask, -1e9).log_softmax(-1)
    return (p.exp() * (p-q)).sum(-1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    parent_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    prior_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
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
    results = []
    thresholds = (1e-4, 1e-3, 1e-2, 0.1)
    for g, group in enumerate(parent['groups']):
        idx = group['mask'] + [p+64 for p in group['mask']]
        arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if arm.startswith('centered') else [0]*len(idx), dtype=torch.float64)
        codes = ((k[:, g:g+1, :, idx].double()-center)/steps).round().clamp(-7, 7)
        prepared = q[:, 2*g:2*g+2, :, idx].double()*steps
        delta = prepared.abs().amax(-1, keepdim=True).clamp_min(1e-20)/7
        one = (prepared/delta).round().clamp(-7, 7)*delta
        residual = prepared-one
        # All admissible key codes lie in [-7,7]. Thus score error lies in
        # [-eps,eps]; the centered log-partition Hoeffding bound is eps²/2.
        eps = 7*residual.abs().sum(-1)/math.sqrt(128)
        certificate = eps.square()/2
        certificate[:, :, 0] = 0  # A one-key softmax is independent of every score.
        score_one = one @ codes.transpose(-1, -2)/math.sqrt(128)
        score_float = prepared @ codes.transpose(-1, -2)/math.sqrt(128)
        actual = causal_kl_rows(score_one, score_float)
        # An oracle that has already scanned the causal cache supplies tight
        # per-coordinate extrema. This is a diagnostic, not a free gate.
        low = codes.cummin(dim=2).values
        high = codes.cummax(dim=2).values
        width = (residual.abs() * (high-low)/math.sqrt(128)).sum(-1)
        range_certificate = width.square()/8
        score_error = score_one-score_float
        causal_mask = torch.arange(256)[None, :] > torch.arange(256)[:, None]
        prefix_min = score_error.masked_fill(causal_mask, float('inf')).amin(-1)
        prefix_max = score_error.masked_fill(causal_mask, -float('inf')).amax(-1)
        oracle_certificate = (prefix_max-prefix_min).square()/8
        flat = certificate.flatten()
        a = actual.flatten()
        assert (a <= flat+1e-10).all(), (g, (a-flat).max().item())
        assert (a <= range_certificate.flatten()+1e-10).all()
        assert (a <= oracle_certificate.flatten()+1e-10).all()
        results.append({'group': g, 'arm': arm, 'certificate_quantiles': torch.quantile(flat, torch.tensor([0., .5, .9, .99, 1.], dtype=torch.float64)).tolist(),
                        'actual_kl_mean': float(a.mean()), 'actual_kl_max': float(a.max()),
                        'accepted_by_threshold': {str(t): int((flat <= t).sum()) for t in thresholds},
                        'coordinate_range_oracle_accepted': {str(t): int((range_certificate <= t).sum()) for t in thresholds},
                        'score_range_oracle_accepted': {str(t): int((oracle_certificate <= t).sum()) for t in thresholds},
                        'accepted_actual_kl_mean_by_threshold': {str(t): float(a[flat <= t].mean()) if (flat <= t).any() else None for t in thresholds}})
        print('group', g, 'certificate median', results[-1]['certificate_quantiles'][1], flush=True)
    output = {'layer': args.layer, 'domain': 'frozen paid binary Q/K, original-producer validation capture, 32 signed nibble key codes per group in [-7,7], 512 query/head/group rows per window',
              'row_count': 4*2*256*8, 'thresholds': thresholds, 'groups': results,
              'accepted_total': {str(t): {field: sum(r[field][str(t)] for r in results) for field in ('accepted_by_threshold', 'coordinate_range_oracle_accepted', 'score_range_oracle_accepted')} for t in thresholds},
              'cost': {'base_one_dot_products_per_key_layer': 512, 'fallback_second_dot_products_per_key_layer': 512,
                       'query_preparation_products_for_one_dot': 512, 'query_residual_abs_and_sum_for_certificate': 512,
                       'fallback_query_prepare_and_split': 'additional activation-dependent work, native cost unmeasured',
                       'coordinate_range_oracle': 'requires prefix extrema for all 256 key-code coordinates plus 512 query differences and products; its observed bounds are not a free runtime gate',
                       'score_range_oracle': 'requires computing the skipped score difference for every cached key; diagnostic ceiling only',
                       'key_producer_and_cache': 'unchanged from 128-byte paid nibble cache'},
              'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(parent_path), 'prior_sha256': sha(prior_path),
              'model_sha256': sha(finite.MODEL), 'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2)+'\n')
    print('accepted', output['accepted_total'], flush=True)


if __name__ == '__main__':
    main()
