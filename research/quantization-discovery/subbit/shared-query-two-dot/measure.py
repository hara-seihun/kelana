#!/usr/bin/env python3
"""Compare two-dot shared query coordinates against independent nibble queries."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('shared_query_base', ROOT / 'shared-query-base/measure.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
cache, paid, finite = base.cache, base.paid, base.finite
DATA = Path('/path/to/workspace/data/kelana-subbit')


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def scores(a, codes):
    a0, a1 = a[:, :1], a[:, 1:2]
    d = base.dots
    s0, s1 = d(a0, codes, 7), d(a1, codes, 7)
    delta = d(a1 - a0, codes, 7)
    output = {'independent': torch.cat((s0, s1), dim=1)}
    for i in range(9):
        alpha = i / 8
        common = d((1-alpha)*a0 + alpha*a1, codes, 7)
        output[f'alpha_{i}'] = torch.cat((common - alpha*delta,
                                         common + (1-alpha)*delta), dim=1)
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    parent_path = DATA / f'key-nibble-cache/layer{args.layer:02d}.json'
    prior_path = DATA / f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    prior = json.loads(prior_path.read_text())
    q_path = DATA / f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA / f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {name: model.get_tensor(prefix + name + '.weight').float()
                    for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    captures = {}
    for split, nw in (('train', 8), ('validation', 4)):
        x = finite.load_capture(args.layer, split).reshape(-1, 256, 1024)[:nw]
        captures[split] = (*paid.projected(x, weights, gamma),
                           *paid.projected(x, original, original['k_norm']))
    groups = []
    for g, group in enumerate(parent['groups']):
        idx = group['mask'] + [p + 64 for p in group['mask']]
        key_arm = parent['group_arms_selected_by_train']['coordinate'][g] + '_coordinate'
        steps = torch.tensor(group['int4'][key_arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if key_arm.startswith('centered') else [0] * 32,
                              dtype=torch.float64)
        record = {'group': g, 'key_arm': key_arm, 'splits': {}}
        for split, (q, k, tq, tk) in captures.items():
            a = q[:, 2*g:2*g+2, :, idx].double() * steps
            codes = ((k[:, g:g+1, :, idx].double() - center) / steps).round().clamp(-7, 7)
            teacher = cache.scores(tq[:, 2*g:2*g+2], tk[:, g:g+1], list(range(256)))
            record['splits'][split] = {name: base.lowering.causal_kl(score, teacher).tolist()
                                        for name, score in scores(a, codes).items()}
        record['selected'] = min((f'alpha_{i}' for i in range(9)),
                                 key=lambda name: sum(record['splits']['train'][name]))
        groups.append(record)
        print(args.layer, g, record['selected'], flush=True)
    aggregate = {}
    for split, nw in (('train', 8), ('validation', 4)):
        aggregate[split] = {arm: [sum(group['splits'][split][arm][w] for group in groups)/8
                                  for w in range(nw)]
                            for arm in groups[0]['splits'][split]}
        aggregate[split]['selected'] = [sum(group['splits'][split][group['selected']][w]
                                            for group in groups)/8 for w in range(nw)]
    paths = {'source': Path(__file__), 'base_source': ROOT / 'shared-query-base/measure.py',
             'parent': parent_path, 'prior': prior_path, 'model': finite.MODEL,
             'capture': finite.value_fit.CAPTURES / f'layer{args.layer:02d}.npz',
             'paid_q': q_path, 'paid_k': k_path}
    result = {'layer': args.layer,
              'contract': 'frozen paid Q/K and signed-nibble keys on original-producer 256-token captures; train-only shared coordinate choice',
              'groups': groups, 'aggregate_by_window': aggregate,
              'mean': {split: {name: sum(values)/len(values) for name, values in table.items()}
                       for split, table in aggregate.items()},
              'cost': {'key_bytes_per_token_layer': 128,
                       'signed_nibble_products_per_key_layer': 512,
                       'shared_query_subtractions_per_token_layer': 256,
                       'shared_query_weighted_combinations_per_token_layer': 256,
                       'shared_score_scaled_additions_per_key_layer': 16,
                       'dynamic_maxima_per_token_layer': 16,
                       'full_raw_k_norm_rows': 1024,
                       'native_time_measured': False},
              'sha256': {name: digest(path) for name, path in paths.items()}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('held', result['mean']['validation'], flush=True)


if __name__ == '__main__':
    main()
