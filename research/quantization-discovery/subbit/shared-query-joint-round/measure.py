#!/usr/bin/env python3
"""Conditional two-head lattice projection for three direct nibble key-score passes."""
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
cache, paid, finite, lowering = base.cache, base.paid, base.finite, base.lowering
DATA = Path('/path/to/workspace/data/kelana-subbit')


def lattice(a0, a1, codes, weight, radius=None):
    """Weighted least squares; radius=None enumerates the entire nibble range."""
    d = a0.abs().amax(-1, keepdim=True).clamp_min(1e-20) / 119
    e = (a1-a0).abs().amax(-1, keepdim=True).clamp_min(1e-20) / 7
    best = torch.full_like(a0, float('inf'))
    best_u = torch.zeros_like(a0)
    best_v = torch.zeros_like(a0)
    center = ((a1-a0)/e).round().clamp(-7,7)
    candidates = (range(-7,8) if radius is None else range(-radius,radius+1))
    for offset in candidates:
        v = offset if radius is None else (center+offset).clamp(-7,7)
        u = ((a0 + weight*(a1-e*v)) / ((1+weight)*d)).round().clamp(-119,119)
        cost = (a0-d*u).square() + weight*(a1-d*u-e*v).square()
        take = cost < best
        best = torch.where(take, cost, best)
        best_u = torch.where(take, u, best_u)
        best_v = torch.where(take, v, best_v)
    lo = (best_u+8).remainder(16)-8
    hi = (best_u-lo)/16
    assert best_v.min() >= -7 and best_v.max() <= 7
    assert lo.min() >= -8 and lo.max() <= 7 and hi.min() >= -8 and hi.max() <= 7
    assert torch.equal(best_u, lo + 16*hi)
    b = (best_u @ codes.transpose(-1,-2))*d/math.sqrt(128)
    delta = (best_v @ codes.transpose(-1,-2))*e/math.sqrt(128)
    return b, b+delta, best.mean().item()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0,14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    parent_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    prior_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    shared_path = DATA/f'shared-query-base/layer{args.layer:02d}.json'
    parent, prior, shared = [json.loads(p.read_text()) for p in (parent_path,prior_path,shared_path)]
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {n:model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj','k_proj','q_norm','k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'],dtype=torch.bfloat16).float()
    captures = {}
    for split,nw in (('train',8),('validation',4)):
        x = finite.load_capture(args.layer,split).reshape(-1,256,1024)[:nw]
        q,k = paid.projected(x,weights,gamma)
        tq,tk = paid.projected(x,original,original['k_norm'])
        captures[split] = q,k,tq,tk
    results = []
    for g, group in enumerate(parent['groups']):
        idx = group['mask'] + [p+64 for p in group['mask']]
        key_arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        steps = torch.tensor(group['int4'][key_arm]['steps'],dtype=torch.float64)
        center = torch.tensor(group['train_center'] if key_arm.startswith('centered') else [0]*32,dtype=torch.float64)
        record = {'group':g,'splits':{}}
        for split,(q,k,tq,tk) in captures.items():
            a = q[:,2*g:2*g+2,:,idx].double()*steps
            codes = ((k[:,g:g+1,:,idx].double()-center)/steps).round().clamp(-7,7)
            teacher = cache.scores(tq[:,2*g:2*g+2],tk[:,g:g+1],list(range(256)))
            baseline = base.arms(a,codes)
            metrics = {name:lowering.causal_kl(value,teacher).tolist() for name,value in baseline.items() if name.startswith('shared_base_')}
            for b in range(2):
                other = 1-b
                for weight in (0.25,1.0,4.0):
                    sb,so,coordinate_error = lattice(a[:,b:b+1],a[:,other:other+1],codes,weight)
                    pair = [None,None]
                    pair[b],pair[other] = sb,so
                    name = f'joint_{b}_{weight:g}'
                    metrics[name] = lowering.causal_kl(torch.cat(pair,dim=1),teacher).tolist()
                    record.setdefault('coordinate_error',{}).setdefault(split,{})[name] = coordinate_error
            for b in range(2):
                other = 1-b
                for radius in (0,1):
                    sb,so,coordinate_error = lattice(a[:,b:b+1],a[:,other:other+1],codes,1.0,radius)
                    pair = [None,None]
                    pair[b],pair[other] = sb,so
                    name = f'near_{b}_{radius}'
                    metrics[name] = lowering.causal_kl(torch.cat(pair,dim=1),teacher).tolist()
                    record.setdefault('coordinate_error',{}).setdefault(split,{})[name] = coordinate_error
            record['splits'][split] = metrics
        record['selected_joint'] = min(((b,w) for b in range(2) for w in (0.25,1.0,4.0)),
                                       key=lambda bw:sum(record['splits']['train'][f'joint_{bw[0]}_{bw[1]:g}']))
        record['selected_shared'] = shared['groups'][g]['selected_shared_base']
        record['selected_near'] = min(((b,r) for b in range(2) for r in (0,1)),
                                      key=lambda br:sum(record['splits']['train'][f'near_{br[0]}_{br[1]}']))
        results.append(record)
        print(args.layer,g,record['selected_joint'],flush=True)
    summary = {}
    for split,nw in (('train',8),('validation',4)):
        summary[split] = {}
        for label,selector in (('joint_selected','selected_joint'),('near_selected','selected_near'),('shared_selected','selected_shared')):
            summary[split][label] = []
            for window in range(nw):
                vals = []
                for group in results:
                    arm = (f'joint_{group[selector][0]}_{group[selector][1]:g}' if label=='joint_selected'
                           else f'near_{group[selector][0]}_{group[selector][1]}' if label=='near_selected'
                           else f'shared_base_{group[selector]}')
                    vals.append(group['splits'][split][arm][window])
                summary[split][label].append(sum(vals)/8)
    output = {'layer':args.layer,'contract':'Frozen paid Q/K and signed-nibble K cache, original-producer causal 256-token captures; train-selected weighted lattice rounding with 15-candidate exact and 1/3-candidate restricted policies, fixed dynamic scales and three dot passes',
              'groups':results,'aggregate_by_window':summary,
              'mean':{split:{arm:sum(v)/len(v) for arm,v in arms.items()} for split,arms in summary.items()},
              'cost':{'key_bytes_per_token_layer':128,'products_per_key_layer':768,'query_coordinate_candidates_per_policy':15*256,
                      'query_scale_products':512,'score_additions_per_key':8,'native_time_measured':False},
              'sha256':{name:base.digest(path) for name,path in {'source':Path(__file__),'shared_source':ROOT/'shared-query-base/measure.py',
                    'parent':parent_path,'prior':prior_path,'shared_receipt':shared_path,'model':finite.MODEL,
                    'capture':finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz','paid_q':q_path,'paid_k':k_path}.items()}}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(output,indent=2)+'\n')
    print('held',output['mean']['validation'],flush=True)

if __name__ == '__main__':
    main()
