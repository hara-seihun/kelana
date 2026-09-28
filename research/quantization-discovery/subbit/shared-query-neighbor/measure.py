#!/usr/bin/env python3
"""Square-root-free certified neighbor search on frozen paid two-head Q/K queries."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('pruning', ROOT / 'shared-query-pruning/measure.py')
pruning = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pruning)
base = pruning.base
DATA = pruning.DATA


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def search(a0, a1, weight):
    d = a0.abs().amax(-1, keepdim=True).clamp_min(1e-20) / 119
    delta = a1 - a0
    e = delta.abs().amax(-1, keepdim=True).clamp_min(1e-20) / 7
    v0 = (delta/e).round().clamp(-7, 7)
    floor_scale = weight/(1+weight)

    def score(v):
        u = ((a0 + weight*(a1-e*v))/((1+weight)*d)).round().clamp(-119,119)
        return (a0-d*u).square() + weight*(a1-d*u-e*v).square()

    best = score(v0)
    scored = torch.ones_like(best, dtype=torch.int64)
    tested = torch.zeros_like(scored)
    # Every side is visited from the nearest outside integer outward. Once its
    # quadratic lower bound exceeds a feasible cost, farther labels cannot win.
    alive = [torch.ones_like(best, dtype=torch.bool) for _ in range(2)]
    for distance in range(1, 15):
        for side, sign in enumerate((-1, 1)):
            v = v0 + sign*distance
            in_range = (v >= -7) & (v <= 7)
            inspect = alive[side] & in_range
            if not bool(inspect.any()):
                alive[side] = inspect
                continue
            lower = floor_scale*(delta-e*v).square()
            tested += inspect.long()
            eligible = inspect & (lower <= best + 1e-12)
            if bool(eligible.any()):
                best = torch.minimum(best, torch.where(eligible, score(v), float('inf')))
                scored += eligible.long()
            alive[side] = eligible
        if not any(bool(mask.any()) for mask in alive):
            break

    exhaustive = torch.full_like(best, float('inf'))
    for v in range(-7,8):
        exhaustive = torch.minimum(exhaustive, score(torch.full_like(v0, v)))
    assert torch.allclose(best, exhaustive, rtol=0, atol=1e-11)
    # 32 adjacent query coordinates are one plausible SIMD32 assignment.
    slow = scored > 1
    wave_slow = slow.any(-1)
    wave_checks = tested.amax(-1)
    return {'coordinates':scored.numel(), 'candidate_evaluations':int(scored.sum()),
            'floor_tests':int(tested.sum()), 'slow_coordinates':int(slow.sum()),
            'waves':wave_slow.numel(), 'slow_waves':int(wave_slow.sum()),
            'wave_max_floor_tests':int(wave_checks.sum()),
            'max_floor_tests':int(tested.max()), 'max_scored':int(scored.max()),
            'scored_histogram':torch.bincount(scored.flatten(), minlength=16).tolist(),
            'floor_histogram':torch.bincount(tested.flatten(), minlength=16).tolist()}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--layer', type=int, choices=(0,14), required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    torch.set_num_threads(4)
    layer = args.layer
    parent_path = DATA/f'key-nibble-cache/layer{layer:02d}.json'
    prior_path = DATA/f'paid-qk-cache-slack/layer{layer:02d}.json'
    joint_path = DATA/f'shared-query-joint-round/layer{layer:02d}.json'
    interval_path = DATA/f'shared-query-pruning/layer{layer:02d}.json'
    parent, prior, joint, interval = [json.loads(p.read_text()) for p in (parent_path, prior_path, joint_path, interval_path)]
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
    for split, windows in (('train',8), ('validation',4)):
        x = finite.load_capture(layer, split).reshape(-1,256,1024)[:windows]
        q, _ = paid.projected(x, weights, gamma)
        groups = []
        for g, group in enumerate(parent['groups']):
            idx = group['mask'] + [i+64 for i in group['mask']]
            arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
            steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
            a = q[:,2*g:2*g+2,:,idx].double()*steps
            head, weight = joint['groups'][g]['selected_joint']
            metrics = search(a[:,head:head+1], a[:,1-head:2-head], weight)
            metrics.update(group=g, base_head=head, weight=weight)
            groups.append(metrics)
        record = {key:sum(g[key] for g in groups) for key in ('coordinates','candidate_evaluations','floor_tests','slow_coordinates','waves','slow_waves','wave_max_floor_tests')}
        record['scored_histogram'] = [sum(g['scored_histogram'][i] for g in groups) for i in range(16)]
        record['floor_histogram'] = [sum(g['floor_histogram'][i] for g in groups) for i in range(16)]
        record['max_floor_tests'] = max(g['max_floor_tests'] for g in groups)
        record['max_scored'] = max(g['max_scored'] for g in groups)
        record['groups'] = groups
        assert record['coordinates'] == interval['splits'][split]['coordinate_count']
        records[split] = record
        print(layer, split, {k:record[k] for k in ('candidate_evaluations','floor_tests','slow_waves','waves')}, flush=True)
    sources = {'source':Path(__file__), 'pruning_source':ROOT/'shared-query-pruning/measure.py',
               'parent':parent_path, 'prior':prior_path, 'joint':joint_path, 'interval':interval_path,
               'model':finite.MODEL, 'capture':finite.value_fit.CAPTURES/f'layer{layer:02d}.npz',
               'paid_q':q_path, 'paid_k':k_path}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'layer':layer,'method':'FP64 neighbor lower-bound search with 1e-12 inclusive cost guard; exact conditional scores compared with full fifteen-label enumeration',
                                       'splits':records,'sha256':{k:sha(v) for k,v in sources.items()}},indent=2)+'\n')

if __name__ == '__main__':
    main()
