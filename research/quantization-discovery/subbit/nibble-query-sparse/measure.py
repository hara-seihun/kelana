#!/usr/bin/env python3
"""Train-only coordinate selection for a partial second nibble score dot."""
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


lower = imported(ROOT/'nibble-query-lowering/measure.py', 'lower')
cache = lower.cache
paid = lower.paid
finite = lower.finite


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def evaluate(q, k, teacher, steps, center, selected):
    # Shapes: q [W,2,T,32], k [W,1,T,32]. Only one group at a time.
    codes = ((k-center)/steps).round().clamp(-7, 7)
    a = q*steps
    d = a.abs().amax(-1, keepdim=True).clamp_min(1e-20)/7
    coarse = (a/d).round().clamp(-7, 7)
    fine = ((a/d-coarse)*16).round().clamp(-8, 7)
    base = (coarse @ codes.transpose(-1, -2))*d/math.sqrt(128)
    full = base + (fine @ codes.transpose(-1, -2))*d/(16*math.sqrt(128))
    output = {'one_dot': lower.causal_kl(base, teacher).tolist(),
              'full_second_dot': lower.causal_kl(full, teacher).tolist(),
              'float_query': lower.causal_kl(a @ codes.transpose(-1, -2)/math.sqrt(128), teacher).tolist()}
    for m in (4, 8, 16, 24):
        idx = selected[:m]
        partial = base + (fine[..., idx] @ codes[..., idx].transpose(-1, -2))*d/(16*math.sqrt(128))
        output[f'partial_{m}'] = lower.causal_kl(partial, teacher).tolist()
    # A second quantization scheme: dynamic signed-8 split from the prior study.
    d8 = a.abs().amax(-1, keepdim=True).clamp_min(1e-20)/119
    iq8 = (a/d8).round().clamp(-119, 119)
    output['prior_two_dot'] = lower.causal_kl((iq8 @ codes.transpose(-1,-2))*d8/math.sqrt(128), teacher).tolist()
    return output, a, d, coarse, fine, codes


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
    captures = {}
    for split, nw in (('train', 8), ('validation', 4)):
        x = finite.load_capture(args.layer, split).reshape(-1, 256, 1024)[:nw]
        q, k = paid.projected(x, weights, gamma)
        tq, tk = paid.projected(x, original, original['k_norm'])
        captures[split] = (q, k, tq, tk)
    results = []
    for g, group in enumerate(parent['groups']):
        idx = group['mask']+[p+64 for p in group['mask']]
        arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if arm.startswith('centered') else [0]*32, dtype=torch.float64)
        q,k,tq,tk = captures['train']
        qt = q[:,2*g:2*g+2,:,idx].double()
        kt = k[:,g:g+1,:,idx].double()
        a = qt*steps
        d = a.abs().amax(-1, keepdim=True).clamp_min(1e-20)/7
        coarse = (a/d).round().clamp(-7,7)
        fine = ((a/d-coarse)*16).round().clamp(-8,7)
        codes = ((kt-center)/steps).round().clamp(-7,7)
        # Train-only query residual energy weighted by key-code second moment.
        # No held labels or statistics enter the coordinate choice.
        importance = ((fine*d/16)**2).mean((0,1,2))*codes.square().mean((0,1,2))
        selected = torch.argsort(importance, descending=True).tolist()
        row = {'group': g, 'key_arm': arm, 'selected_coordinate_order': selected,
               'train_importance': importance.tolist()}
        for split in ('train','validation'):
            q,k,tq,tk = captures[split]
            teacher = cache.scores(tq[:,2*g:2*g+2], tk[:,g:g+1], list(range(256)))
            observed,*_ = evaluate(q[:,2*g:2*g+2,:,idx].double(), k[:,g:g+1,:,idx].double(),
                                    teacher, steps, center, selected)
            row[split] = observed
        results.append(row)
        print(args.layer, g, 'held', {key: round(sum(v)/4,6) for key,v in row['validation'].items()}, flush=True)
    arms = list(results[0]['validation'])
    summary = {split: {key: [sum(row[split][key][w] for row in results)/8 for w in range(n)]
                       for key in arms} for split,n in (('train',8),('validation',4))}
    output = {'layer': args.layer, 'contract': 'frozen paid Q/K and signed-nibble K; train-only fixed selected correction coordinates; one full signed-nibble dot plus partial nibble residual dot; exact integer inner sums, real-valued query scales and causal CPU softmax',
              'groups': results, 'aggregate_by_window': summary,
              'aggregate_mean': {split:{key:sum(values)/len(values) for key,values in summary[split].items()} for split in summary},
              'cost': {'key_bytes_per_token_layer':128, 'key_full_raw_norm_rows':1024,
                       'query_step_products_per_token_layer':512,
                       'base_nibble_products_per_key_layer':512,
                       'extra_nibble_products_per_key_layer': {str(m):16*m for m in (4,8,16,24,32)},
                       'extra_query_rounds_per_token_layer': {str(m):16*m for m in (4,8,16,24,32)},
                       'fixed_coordinate_selection_bytes_per_layer_at_5_bits_index':{str(m):math.ceil(8*m*5/8) for m in (4,8,16,24,32)},
                       'native_time_measured':False},
              'source_sha256':digest(Path(__file__)), 'parent_sha256':digest(parent_path),
              'prior_sha256':digest(prior_path), 'model_sha256':digest(finite.MODEL),
              'capture_sha256':digest(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256':digest(q_path), 'paid_k_sha256':digest(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2)+'\n')
    print('mean', output['aggregate_mean']['validation'], flush=True)


if __name__ == '__main__':
    main()
