#!/usr/bin/env python3
"""Train-only causal selection of a one-dot signed-nibble query scale."""
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
spec = importlib.util.spec_from_file_location('nibble_query_reference', ROOT/'nibble-query-lowering/measure.py')
nibble = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nibble)
paid, finite = nibble.paid, nibble.finite
RATIOS = (.5, .625, .75, .875, 1., 1.125, 1.25, 1.5)


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def candidate(prepared, codes, ratio):
    delta = prepared.abs().amax(-1, keepdim=True).clamp_min(1e-20) * ratio / 7
    iq = (prepared/delta).round().clamp(-7, 7)
    return (iq @ codes.transpose(-1, -2))*delta/math.sqrt(128), iq


def causal_kl_by_head(candidate, teacher):
    n = candidate.shape[-1]
    mask = torch.arange(n)[None, :] > torch.arange(n)[:, None]
    a = candidate.masked_fill(mask, -1e9).log_softmax(-1)
    b = teacher.masked_fill(mask, -1e9).log_softmax(-1)
    return (b.exp()*(b-a)).sum(-1).mean(-1)


def projected(x, weights, original, gamma):
    q, k = paid.projected(x, weights, gamma)
    tq, tk = paid.projected(x, original, original['k_norm'])
    return q, k, tq, tk


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    parent_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    prior_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    parent = json.loads(parent_path.read_text())
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
    train = projected(finite.load_capture(args.layer, 'train').reshape(8, 256, 1024), weights, original, gamma)
    held = projected(finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024), weights, original, gamma)
    groups = []
    for g, group in enumerate(parent['groups']):
        mask = group['mask']
        idx = mask + [p+64 for p in mask]
        arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if arm.startswith('centered') else [0]*len(idx), dtype=torch.float64)
        splits = []
        for q, k, tq, tk in (train, held):
            prepared = q[:,2*g:2*g+2,:,idx].double()*steps
            codes = ((k[:,g:g+1,:,idx].double()-center)/steps).round().clamp(-7, 7)
            teacher = nibble.cache.scores(tq[:,2*g:2*g+2], tk[:,g:g+1], list(range(256)))
            kl = []
            for ratio in RATIOS:
                scores, iq = candidate(prepared, codes, ratio)
                kl.append(causal_kl_by_head(scores, teacher))
            splits.append(torch.stack(kl))
        train_kl, held_kl = splits  # [ratio, window, head]
        choices = train_kl.mean(1).argmin(0).tolist()
        chosen = torch.stack([held_kl[c,:,h] for h,c in enumerate(choices)], dim=-1)
        baseline = held_kl[RATIOS.index(1.)]
        oracle = held_kl.amin(0)
        groups.append({'group':g, 'arm':arm, 'chosen_ratio_by_head':[RATIOS[c] for c in choices],
                       'train_kl_by_ratio_window_head':train_kl.tolist(),
                       'held_kl_by_ratio_window_head':held_kl.tolist(),
                       'selected_held_by_window_head':chosen.tolist(),
                       'baseline_held_by_window_head':baseline.tolist(),
                       'oracle_held_by_window_head':oracle.tolist()})
        print('group', g, 'ratios', groups[-1]['chosen_ratio_by_head'],
              'held selected / base', chosen.mean().item(), baseline.mean().item(), flush=True)
    summary = {}
    for key in ('selected', 'baseline', 'oracle'):
        field = {'selected':'selected_held_by_window_head','baseline':'baseline_held_by_window_head','oracle':'oracle_held_by_window_head'}[key]
        summary[key] = [sum(sum(group[field][w])/2 for group in groups)/8 for w in range(4)]
    result = {'layer':args.layer, 'ratios':RATIOS, 'groups':groups, 'aggregate_by_window':summary,
              'aggregate_mean':{k:sum(v)/4 for k,v in summary.items()},
              'contract':'static per-head/group ratio trained on finite causal teacher-to-candidate KL, applied to per-query max/7 scale and one signed-nibble key dot; frozen paid Q/K and key image; original-producer captures',
              'cost':{'ratio_fp16_bytes_per_layer':32,'extra_scale_multiply_per_query_head_group':16,
                      'query_step_products_per_token_layer':512,'single_dot_products_per_key_both_heads':512,
                      'key_bytes_per_token_layer':128,'full_raw_k_norm_rows':1024,
                      'native_time_measured':False},
              'source_sha256':digest(Path(__file__)), 'parent_sha256':digest(parent_path),
              'prior_sha256':digest(prior_path), 'model_sha256':digest(finite.MODEL),
              'capture_sha256':digest(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256':digest(q_path), 'paid_k_sha256':digest(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('aggregate', result['aggregate_mean'],flush=True)


if __name__ == '__main__':
    main()
