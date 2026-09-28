#!/usr/bin/env python3
"""Replay frozen direct key consumers on a captured quantized layer-14 producer."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit')
spec = importlib.util.spec_from_file_location('shared_query_base_transfer', ROOT / 'shared-query-base/measure.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    layer = 14
    capture_path = DATA / 'value-observer/layer14-quantized-upstream.npz'
    capture_receipt = DATA / 'value-observer/layer14-quantized-upstream-capture.json'
    parent_path = DATA / 'shared-query-base/layer14.json'
    key_path = DATA / 'key-nibble-cache/layer14.json'
    affine_path = DATA / 'paid-qk-cache-slack/layer14.json'
    q_path = DATA / 'full-model/image-binary055-refined/layer14-self_attn_q_proj.npz'
    k_path = DATA / 'full-model/image-binary055-refined/layer14-self_attn_k_proj.npz'
    parent = json.loads(parent_path.read_text())
    key = json.loads(key_path.read_text())
    affine = json.loads(affine_path.read_text())
    assert sha(capture_path) == json.loads(capture_receipt.read_text())['capture_sha256']
    with safe_open(base.finite.MODEL, framework='pt', device='cpu') as model:
        prefix = 'model.layers.14.self_attn.'
        original = {name: model.get_tensor(prefix + name + '.weight').float()
                    for name in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    paid = dict(original)
    paid['q_proj'] = base.paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    paid['k_proj'] = base.paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(affine['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    with np.load(capture_path) as data:
        captures = {split: torch.from_numpy(data[split].view(np.int16).copy()).view(torch.bfloat16).float()
                    for split in ('train', 'validation')}
    results = {'contract': 'Frozen original-producer paid binary Q/K, group affine, signed-nibble K steps and centers, and train-selected three-dot base heads; layer-14 input after quantized layers 0..13 body and norms, original tied embedding; original layer-14 Q/K teacher on the SAME input; four disjoint 256-token train and validation windows; all causal keys; real-valued score reconstruction from exact integer inner products; CPU only',
               'groups': [], 'per_window': {}, 'cost': parent['cost'],
               'sha256': {name: sha(path) for name, path in {
                   'source': Path(__file__), 'base_source': Path(base.__file__),
                   'capture': capture_path, 'capture_receipt': capture_receipt,
                   'parent': parent_path, 'key_image_receipt': key_path, 'affine_receipt': affine_path,
                   'paid_q': q_path, 'paid_k': k_path, 'model': base.finite.MODEL}.items()}}
    observations = {}
    value = {}
    for split, x in captures.items():
        assert x.shape == (4, 256, 1024), (split, x.shape)
        q, k = base.paid.projected(x, paid, gamma)
        tq, tk = base.paid.projected(x, original, original['k_norm'])
        observations[split] = q, k, tq, tk
        value[split] = (x @ original['v_proj'].T).to(torch.bfloat16).float().reshape(4,256,8,128).double()
    names = ('float_query', 'four_dot', 'two_dot', 'independent_frozen', 'shared_frozen')
    output_names = names + ('teacher',)
    output = {split: {name: torch.zeros(4,256,1024,dtype=torch.float64) for name in output_names}
              for split in observations}
    output_weight = original['o_proj'].double().reshape(1024,16,128)
    mask = torch.ones(256,256,dtype=torch.bool).triu(1)
    for g, group in enumerate(key['groups']):
        indices = group['mask'] + [p + 64 for p in group['mask']]
        arm = key['group_arms_selected_by_train']['coordinate'][g] + '_coordinate'
        steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if arm.startswith('centered') else [0]*32, dtype=torch.float64)
        fixed = parent['groups'][g]
        independent = fixed['selected_independent_base']
        shared = fixed['selected_shared_base']
        entry = {'group': g, 'key_arm': arm, 'frozen_independent_base': independent,
                 'frozen_shared_base': shared, 'splits': {}}
        for split, (q, k, tq, tk) in observations.items():
            prepared = q[:,2*g:2*g+2,:,indices].double() * steps
            codes = ((k[:,g:g+1,:,indices].double() - center)/steps).round().clamp(-7,7)
            teacher = base.cache.scores(tq[:,2*g:2*g+2], tk[:,g:g+1], list(range(256)))
            scores = base.arms(prepared, codes)
            scores['float_query'] = (prepared @ codes.transpose(-1,-2)) / math.sqrt(128)
            scores['independent_frozen'] = scores[f'independent_base_{independent}']
            scores['shared_frozen'] = scores[f'shared_base_{shared}']
            entry['splits'][split] = {name: base.lowering.causal_kl(scores[name], teacher).tolist()
                                      for name in names + ('shared_base_0', 'shared_base_1',
                                                         'independent_base_0', 'independent_base_1')}
            group_value = value[split][:,:,g,:]
            for name in output_names:
                group_scores = teacher if name == 'teacher' else scores[name]
                probability = group_scores.masked_fill(mask, -1e9).softmax(-1)
                context = probability @ group_value[:,None,:,:]
                output[split][name] += torch.einsum('bhtd,ohd->bto',
                    context, output_weight[:,2*g:2*g+2,:])
            # Query quantization is isolated by a second KL against the identical cached codes.
            if split == 'validation':
                entry['held_kl_from_float_key'] = {name: base.lowering.causal_kl(
                    scores[name], scores['float_query']).tolist() for name in names[1:]}
        results['groups'].append(entry)
        print('group', g, 'held shared/four', [round(sum(entry['splits']['validation'][n])/4, 6)
                                          for n in ('shared_frozen','four_dot')], flush=True)
    for split in ('train','validation'):
        results['per_window'][split] = {name: [sum(group['splits'][split][name][w]
                                                  for group in results['groups'])/8
                                           for w in range(4)] for name in names}
    results['mean'] = {split: {name: sum(values)/len(values) for name, values in table.items()}
                       for split, table in results['per_window'].items()}
    for family in ('shared', 'independent'):
        chosen = [min((0,1), key=lambda b: sum(group['splits']['train'][f'{family}_base_{b}']))
                  for group in results['groups']]
        results[f'{family}_quantized_producer_train_choice'] = chosen
        results['per_window']['validation'][f'{family}_reselected'] = [
            sum(group['splits']['validation'][f'{family}_base_{chosen[g]}'][w]
                for g, group in enumerate(results['groups']))/8 for w in range(4)]
        results['mean']['validation'][f'{family}_reselected'] = sum(
            results['per_window']['validation'][f'{family}_reselected'])/4
    results['post_o_relative_squared_error'] = {}
    results['post_o_by_window'] = {}
    for split, by_name in output.items():
        teacher = by_name['teacher']
        denominator = teacher.square().sum((1,2))
        results['post_o_by_window'][split] = {
            name: ((prediction-teacher).square().sum((1,2))/denominator).tolist()
            for name, prediction in by_name.items() if name != 'teacher'}
        results['post_o_relative_squared_error'][split] = {
            name: ((prediction-teacher).square().sum()/denominator.sum()).item()
            for name, prediction in by_name.items() if name != 'teacher'}
    results['prior_original_producer_mean'] = {name: parent['mean']['validation'][{
        'shared_frozen':'shared_selected', 'independent_frozen':'independent_selected'}.get(name,name)]
        for name in names}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(results, indent=2) + '\n')
    print('mean', results['mean'], flush=True)


if __name__ == '__main__':
    main()
