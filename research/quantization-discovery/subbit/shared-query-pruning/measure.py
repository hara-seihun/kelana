#!/usr/bin/env python3
"""Count certified candidates for the frozen shared-query weighted lattice fit."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('shared_query_base', ROOT / 'shared-query-base/measure.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def count_candidates(a0, a1, weight):
    d = a0.abs().amax(-1, keepdim=True).clamp_min(1e-20) / 119
    delta = a1 - a0
    e = delta.abs().amax(-1, keepdim=True).clamp_min(1e-20) / 7
    v0 = (delta / e).round().clamp(-7, 7)
    def score(v):
        u = ((a0 + weight * (a1 - e*v)) / ((1+weight)*d)).round().clamp(-119, 119)
        return (a0-d*u).square() + weight*(a1-d*u-e*v).square()
    incumbent = score(v0)
    floor_scale = weight / (1+weight)
    # The quadratic floor gives an interval, so the actual selector need not inspect 15 labels.
    radius = ((incumbent + 1e-12) / floor_scale).sqrt()
    lo = ((delta-radius)/e).ceil().clamp(-7, 7).int()
    hi = ((delta+radius)/e).floor().clamp(-7, 7).int()
    assert torch.all(lo <= v0.int()) and torch.all(hi >= v0.int())
    active = hi-lo+1
    pruned_optimal = incumbent.clone()
    for offset in range(15):
        v = lo + offset
        eligible = v <= hi
        if not bool(eligible.any()):
            break
        pruned_optimal = torch.minimum(pruned_optimal, torch.where(eligible, score(v.double()), float('inf')))
    # Diagnostic full enumeration on these measured queries, not part of the online selector.
    optimal = torch.full_like(a0, float('inf'))
    for integer in range(-7, 8):
        optimal = torch.minimum(optimal, score(torch.full_like(a0, integer)))
    assert torch.allclose(optimal, pruned_optimal, atol=1e-11, rtol=0)
    return torch.bincount(active.flatten().long(), minlength=16).tolist(), int(active.numel())


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--layer', type=int, choices=(0, 14), required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    torch.set_num_threads(4)
    layer = args.layer
    parent_path = DATA/f'key-nibble-cache/layer{layer:02d}.json'
    prior_path = DATA/f'paid-qk-cache-slack/layer{layer:02d}.json'
    joint_path = DATA/f'shared-query-joint-round/layer{layer:02d}.json'
    parent, prior, joint = [json.loads(p.read_text()) for p in (parent_path, prior_path, joint_path)]
    q_path = DATA/f'full-model/image-binary055-refined/layer{layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{layer:02d}-self_attn_k_proj.npz'
    finite, paid = base.finite, base.paid
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        original = {name:model.get_tensor(f'model.layers.{layer}.self_attn.{name}.weight').float()
                    for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    records = {}
    for split, windows in (('train', 8), ('validation', 4)):
        x = finite.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        q, _ = paid.projected(x, weights, gamma)
        hist = [0]*16
        selected = []
        for g, group in enumerate(parent['groups']):
            idx = group['mask'] + [i+64 for i in group['mask']]
            arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
            steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
            a = q[:,2*g:2*g+2,:,idx].double()*steps
            head, weight = joint['groups'][g]['selected_joint']
            counts, n = count_candidates(a[:,head:head+1], a[:,1-head:2-head], weight)
            hist = [u+v for u,v in zip(hist, counts)]
            selected.append({'group':g,'base_head':head,'weight':weight,'coordinate_count':n,
                             'candidate_histogram':counts})
        total = sum(hist)
        records[split] = {'coordinate_count':total,'candidate_histogram':hist,
                          'mean_candidates':sum(i*v for i,v in enumerate(hist))/total,
                          'fraction_one_candidate':hist[1]/total,
                          'candidate_evaluations':sum(i*v for i,v in enumerate(hist)),
                          'groups':selected}
        print(layer, split, total, records[split]['mean_candidates'], flush=True)
    sources = {'source':Path(__file__), 'parent':parent_path,'prior':prior_path,'joint':joint_path,
               'model':finite.MODEL,'capture':finite.value_fit.CAPTURES/f'layer{layer:02d}.npz',
               'paid_q':q_path,'paid_k':k_path}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'layer':layer,'method':'nearest-nibble incumbent; real quadratic projection floor; inclusive FP64 1e-12 tolerance',
                                      'splits':records,'sha256':{k:sha(v) for k,v in sources.items()}}, indent=2)+'\n')

if __name__ == '__main__':
    main()
