#!/usr/bin/env python3
"""Query-only choice of the base head for a shared three-dot packed-key score."""
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
spec = importlib.util.spec_from_file_location('shared_base', ROOT/'shared-query-base/measure.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
paid, cache, finite = base.paid, base.cache, base.finite


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def rounded(a, cap):
    scale = a.abs().amax(-1, keepdim=True).clamp_min(1e-20) / cap
    return (a / scale).round().clamp(-cap, cap) * scale


def row_kl(scores, teacher):
    n = scores.shape[-1]
    mask = torch.arange(n)[None, :] > torch.arange(n)[:, None]
    l = scores.masked_fill(mask, -1e9).log_softmax(-1)
    t = teacher.masked_fill(mask, -1e9).log_softmax(-1)
    return (t.exp() * (t-l)).sum(-1).mean(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    parent_path = DATA/f'shared-query-base/layer{args.layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    key_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    keys = json.loads(key_path.read_text())
    prior_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {name: model.get_tensor(prefix+name+'.weight').float()
                    for name in ('q_proj','k_proj','q_norm','k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    captures = {}
    for split, count in (('train',8), ('validation',4)):
        x = finite.load_capture(args.layer, split).reshape(-1,256,1024)[:count]
        q,k = paid.projected(x, weights, gamma)
        tq,tk = paid.projected(x, original, original['k_norm'])
        captures[split] = (q,k,tq,tk)
    groups = []
    for g, group in enumerate(keys['groups']):
        idx = group['mask'] + [p+64 for p in group['mask']]
        key_arm = keys['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        steps = torch.tensor(group['int4'][key_arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if key_arm.startswith('centered') else [0]*32, dtype=torch.float64)
        def prepared(split):
            q,k,tq,tk = captures[split]
            a = q[:,2*g:2*g+2,:,idx].double()*steps
            codes = ((k[:,g:g+1,:,idx].double()-center)/steps).round().clamp(-7,7)
            teacher = cache.scores(tq[:,2*g:2*g+2], tk[:,g:g+1], list(range(256)))
            return a,codes,teacher
        train_a,train_codes,_ = prepared('train')
        # Shared key-coordinate metric; softmax is invariant to a constant score shift.
        centered = train_codes[:,0].reshape(-1,32)
        centered = centered-centered.mean(0)
        covariance = centered.T @ centered / centered.shape[0]
        report = {'group':g, 'static_base':parent['groups'][g]['selected_shared_base'], 'windows':{}}
        for split in ('train','validation'):
            a,codes,teacher = prepared(split)
            scores = base.arms(a,codes)
            loss = torch.stack([row_kl(scores[f'shared_base_{b}'],teacher) for b in range(2)])
            errors=[]
            for b in range(2):
                recon = [None,None]
                recon[b] = rounded(a[:,b:b+1],119)
                recon[1-b] = recon[b]+rounded(a[:,1-b:2-b] - a[:,b:b+1],7)
                residual = torch.cat(recon,1)-a
                errors.append(torch.einsum('whni,ij,whnj->wn',residual,covariance,residual))
            select = (errors[1] < errors[0])
            chosen = torch.where(select,loss[1],loss[0])
            static = loss[report['static_base']]
            oracle = loss.amin(0)
            report['windows'][split] = {
                'static_kl':static.mean(-1).tolist(),
                'query_covariance_kl':chosen.mean(-1).tolist(),
                'per_query_oracle_kl':oracle.mean(-1).tolist(),
                'dynamic_base_1_fraction':select.double().mean(-1).tolist(),
                'different_from_static_fraction':(select != bool(report['static_base'])).double().mean(-1).tolist(),
                'decision_matches_oracle_fraction':(select == (loss[1]<loss[0])).double().mean(-1).tolist(),
            }
        groups.append(report)
        print('group',g,flush=True)
    fields = ('static_kl','query_covariance_kl','per_query_oracle_kl')
    result = {'layer':args.layer, 'groups':groups,
              'window_kl':{split:{field:[sum(group['windows'][split][field][w] for group in groups)/8
                                         for w in range(count)] for field in fields}
                           for split,count in (('train',8),('validation',4))},
              'cost':{'key_bytes_per_token_layer':128,'signed_nibble_products_per_key_layer':768,
                      'extra_query_only_work_per_layer':'32 quadratic 32x32 forms/token/layer over eight groups, both candidate query quantizations; no teacher or cached-key read in decision',
                      'native_timing':False},
              'sha256':{name:sha(path) for name,path in {
                  'source':__file__,'parent':parent_path,'key_image':key_path,'prior':prior_path,
                  'model':finite.MODEL,'capture':finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz',
                  'paid_q':q_path,'paid_k':k_path}.items()}}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('held', {field:sum(result['window_kl']['validation'][field])/4 for field in fields},flush=True)


if __name__ == '__main__':
    main()
