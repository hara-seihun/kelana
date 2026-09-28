#!/usr/bin/env python3
"""Three signed-nibble dots for two heads observing one frozen paid key group."""
import argparse
import hashlib
import json
import math
import importlib.util
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('shared_query_lowering', ROOT / 'nibble-query-lowering/measure.py')
lowering = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lowering)

cache, paid, finite = lowering.cache, lowering.paid, lowering.finite
DATA = Path('/path/to/workspace/data/kelana-subbit')


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def dots(a, codes, cap):
    scale = a.abs().amax(-1, keepdim=True).clamp_min(1e-20) / cap
    integer = (a / scale).round().clamp(-cap, cap)
    if cap == 119:
        lo = (integer + 8).remainder(16) - 8
        hi = (integer - lo) / 16
        assert int(lo.min()) >= -8 and int(lo.max()) <= 7
        assert int(hi.min()) >= -8 and int(hi.max()) <= 7
        assert torch.equal(integer @ codes.transpose(-1, -2),
                           lo @ codes.transpose(-1, -2) + 16 * (hi @ codes.transpose(-1, -2)))
    return (integer @ codes.transpose(-1, -2)) * scale / math.sqrt(128)


def arms(a, codes):
    base = [dots(a[:,i:i+1], codes, 119) for i in range(2)]
    nibble = [dots(a[:,i:i+1], codes, 7) for i in range(2)]
    output = {'four_dot': torch.cat(base, dim=1),
              'two_dot': torch.cat(nibble, dim=1),
              'independent_base_0': torch.cat([base[0], nibble[1]], dim=1),
              'independent_base_1': torch.cat([nibble[0], base[1]], dim=1)}
    for b in range(2):
        other = 1-b
        correction = dots(a[:,other:other+1] - a[:,b:b+1], codes, 7)
        scores = [None, None]
        scores[b], scores[other] = base[b], base[b] + correction
        output[f'shared_base_{b}'] = torch.cat(scores, dim=1)
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
        q, k = paid.projected(x, weights, gamma)
        tq, tk = paid.projected(x, original, original['k_norm'])
        captures[split] = q, k, tq, tk
    groups = []
    for g, group in enumerate(parent['groups']):
        idx = group['mask'] + [p + 64 for p in group['mask']]
        key_arm = parent['group_arms_selected_by_train']['coordinate'][g] + '_coordinate'
        steps = torch.tensor(group['int4'][key_arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if key_arm.startswith('centered') else [0] * 32,
                              dtype=torch.float64)
        result = {'group': g, 'key_arm': key_arm, 'splits': {}}
        for split in captures:
            q, k, tq, tk = captures[split]
            a = q[:,2*g:2*g+2,:,idx].double() * steps
            codes = ((k[:,g:g+1,:,idx].double() - center) / steps).round().clamp(-7, 7)
            teacher = cache.scores(tq[:,2*g:2*g+2], tk[:,g:g+1], list(range(256)))
            scores = arms(a, codes)
            metrics = {name: lowering.causal_kl(value, teacher).tolist() for name,value in scores.items()}
            # The two heads' score errors can also be assessed against the same-code float map.
            float_score = (a @ codes.transpose(-1, -2)) / math.sqrt(128)
            metrics['float_query'] = lowering.causal_kl(float_score, teacher).tolist()
            result['splits'][split] = metrics
            pair = a[:,1:2] - a[:,0:1]
            result.setdefault('query_geometry', {})[split] = {
                'difference_max_to_second_head_max': (pair.abs().amax(-1) /
                    a[:,1:2].abs().amax(-1).clamp_min(1e-20)).mean().item(),
                'difference_max_to_first_head_max': (pair.abs().amax(-1) /
                    a[:,0:1].abs().amax(-1).clamp_min(1e-20)).mean().item(),
                'difference_nibble_score_mae': (dots(pair, codes, 7) -
                    (pair @ codes.transpose(-1,-2))/math.sqrt(128)).abs().mean().item(),
                'second_head_nibble_score_mae': (dots(a[:,1:2], codes, 7) -
                    float_score[:,1:2]).abs().mean().item()}
        train = result['splits']['train']
        result['selected_independent_base'] = min(range(2), key=lambda b: sum(train[f'independent_base_{b}']))
        result['selected_shared_base'] = min(range(2), key=lambda b: sum(train[f'shared_base_{b}']))
        groups.append(result)
        print(args.layer, g, result['selected_independent_base'], result['selected_shared_base'], flush=True)
    summary = {}
    for split, count in (('train', 8), ('validation', 4)):
        summary[split] = {}
        for arm in groups[0]['splits'][split]:
            summary[split][arm] = [sum(group['splits'][split][arm][w] for group in groups)/8 for w in range(count)]
        for label, selector in (('independent_selected', 'selected_independent_base'),
                                ('shared_selected', 'selected_shared_base')):
            family = label.split('_')[0]
            summary[split][label] = [sum(group['splits'][split][f'{family}_base_{group[selector]}'][w]
                                         for group in groups)/8 for w in range(count)]
    result = {'layer': args.layer, 'contract': 'frozen paid Q/K, signed-nibble key cache and original-producer 256-token captures; three-dot shared-base query uses two signed nibble passes for one head and a single nibble pass for the other-head difference; train-only base-head choice',
              'groups': groups, 'aggregate_by_window': summary,
              'mean': {split: {name: sum(values)/len(values) for name,values in table.items()}
                       for split,table in summary.items()},
              'cost': {'key_bytes_per_token_layer': 128, 'query_step_products': 512,
                       'signed_nibble_products_per_key_layer': {'four_dot': 1024, 'three_dot': 768, 'two_dot': 512},
                       'shared_query_extra_subtractions': 256, 'shared_query_dynamic_maxima': 16,
                       'independent_query_dynamic_maxima': 16, 'shared_score_extra_additions_per_key': 8,
                       'full_raw_k_norm_rows': 1024, 'native_time_measured': False},
              'sha256': {name:digest(path) for name,path in {'source':Path(__file__), 'parent':parent_path,
                         'prior':prior_path, 'model':finite.MODEL,
                         'capture':finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz',
                         'paid_q':q_path, 'paid_k':k_path}.items()}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('held', result['mean']['validation'], flush=True)


if __name__ == '__main__':
    main()
