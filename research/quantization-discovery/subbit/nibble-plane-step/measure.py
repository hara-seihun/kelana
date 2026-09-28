#!/usr/bin/env python3
"""Train-select plane-tied key steps and replay causal attention on frozen paid Q/K."""
import argparse
import hashlib
import json
from pathlib import Path

import torch
from safetensors import safe_open

from importlib.util import module_from_spec, spec_from_file_location

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')


def load(path, name):
    spec = spec_from_file_location(name, path)
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


base = load(ROOT/'key-nibble-cache/measure.py', 'key_nibble_base')
paid = base.paid
finite = base.finite


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def mean(values):
    return sum(values)/len(values)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    prior_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    planes_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    planes = json.loads(planes_path.read_text())
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {name: model.get_tensor(prefix+name+'.weight').float()
                    for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(planes['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    train_x = finite.load_capture(args.layer, 'train').reshape(8, 256, 1024)
    held_x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    train = paid.projected(train_x, weights, gamma)
    held = paid.projected(held_x, weights, gamma)
    teacher_train = paid.projected(train_x, original, original['k_norm'])
    teacher_held = paid.projected(held_x, original, original['k_norm'])
    train_positions = list(range(64, 256, 12))
    held_positions = list(range(256))
    groups = []
    for g, mask in enumerate(planes['new_masks']):
        idx = mask + [p+64 for p in mask]
        n = len(mask)
        q, k = train[0][:, 2*g:2*g+2, :, idx], train[1][:, g:g+1, :, idx]
        qh, kh = held[0][:, 2*g:2*g+2, :, idx], held[1][:, g:g+1, :, idx]
        arm = prior['group_arms_selected_by_train']['coordinate'][g]
        center = torch.tensor(prior['groups'][g]['train_center']).reshape(1,1,1,-1) if arm == 'centered' else torch.zeros((1,1,1,2*n))
        prior_steps = torch.tensor(prior['groups'][g]['int4'][arm+'_coordinate']['steps']).reshape(1,1,1,-1)
        score_train = base.scores(teacher_train[0][:, 2*g:2*g+2], teacher_train[1][:, g:g+1], train_positions)
        score_held = base.scores(teacher_held[0][:, 2*g:2*g+2], teacher_held[1][:, g:g+1], held_positions)
        residual = (k-center).abs()
        candidates = []
        for quantile in (.99, .995, .999, 1.):
            # The RoPE paired coordinates have indices p and p+64 in this selected layout.
            paired = torch.stack((residual[..., :n], residual[..., n:]), dim=-1)
            step = (torch.quantile(paired.reshape(-1,n,2).permute(1,0,2).reshape(n,-1), quantile, dim=1).clamp_min(1e-8)/7).half().float()
            steps = torch.cat((step, step)).reshape(1,1,1,-1)
            loss = base.kl(q, base.quantize(k, center, steps), score_train, train_positions)
            candidates.append((loss, quantile, steps))
        first, second = prior_steps.flatten()[:n], prior_steps.flatten()[n:]
        for label, step in [('paid_max', torch.maximum(first,second)),
                            ('paid_min', torch.minimum(first,second)),
                            ('paid_geometric', (first*second).sqrt()),
                            ('paid_arithmetic', (first+second)/2)]:
            steps = torch.cat((step,step)).half().float().reshape(1,1,1,-1)
            loss = base.kl(q, base.quantize(k, center, steps), score_train, train_positions)
            candidates.append((loss,label,steps))
        selected = min(candidates, key=lambda x: x[0])
        def replay(step):
            rounded = base.quantize(kh, center, step)
            return [base.kl(qh[w:w+1], rounded[w:w+1], score_held[w:w+1], held_positions) for w in range(4)]
        groups.append({'group':g, 'arm':arm, 'selected_quantile': selected[1], 'train_candidates':
                       [{'candidate': str(candidate), 'kl': loss} for loss, candidate, _ in candidates],
                       'plane_steps':selected[2].flatten()[:n].tolist(),
                       'coordinate_steps':prior_steps.flatten().tolist(),
                       'held_plane':replay(selected[2]), 'held_coordinate':replay(prior_steps)})
        print('group', g, 'selected', selected[1], 'held plane/coordinate', mean(groups[-1]['held_plane']), mean(groups[-1]['held_coordinate']), flush=True)
    result = {'layer':args.layer, 'domain':'frozen paid binary Q/K and key-nibble image; original-producer 8 train and 4 inspected validation windows; 128 selected RoPE planes; FP64 scores and causal softmax',
              'groups':groups, 'held_by_window':{name:[mean([group['held_'+name][w] for group in groups]) for w in range(4)] for name in ('plane','coordinate')},
              'cost':{'key_cache_bytes_per_token_layer':128, 'coordinate_step_bytes_layer':512,
                      'plane_step_bytes_layer':256, 'query_step_multiplies_token_layer':512,
                      'key_quantizations_token_layer':256, 'raw_key_norm_rows':1024},
              'hashes':{name:sha(path) for name,path in [('source',Path(__file__)),('prior',prior_path),('planes',planes_path),('model',finite.MODEL),('capture',finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),('q_image',q_path),('k_image',k_path)]}}
    result['held_mean'] = {name:mean(scores) for name,scores in result['held_by_window'].items()}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('held mean', result['held_mean'])

if __name__ == '__main__':
    main()
