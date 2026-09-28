#!/usr/bin/env python3
"""Causal mass concentration at the radix-128 high-list boundary."""
import argparse
import importlib.util
import json
from pathlib import Path

import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('mass_radix', SUBBIT / 'value-mass-radix/measure.py')
radix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(radix)

DATA = Path('/path/to/workspace/data/kelana-subbit/value-mass-optimal-rounding')
CAPS = (0, 1, 2, 4, 8, 16, 32)


def concentrate(n, owner, cap):
    """Move counts from low-high boundary keys into an already-high owner."""
    owns = torch.zeros_like(n, dtype=torch.bool).scatter_(-1, owner, True)
    owner_high = n.gather(-1, owner) >= 128
    donors = (n >= 128) & (n <= 127 + cap) & ~owns & owner_high
    moved = torch.where(donors, n - 127, 0)
    candidate = (n - moved).scatter_add(-1, owner, moved.sum(-1, keepdim=True, dtype=torch.int32))
    assert bool((candidate >= 0).all()) and bool((candidate.sum(-1) == 4095).all())
    return candidate, donors, moved


def slots(n):
    length = n.shape[-1]
    causal = torch.ones((length, length), dtype=torch.bool).tril()
    low = ((n % 128 != 0) & causal).sum(-1).reshape(-1, 8, length)
    high = ((n >= 128) & causal).sum(-1).reshape(-1, 8, length)
    # Each four-lane subgroup processes a head; one 32-lane wave owns eight heads.
    return int(sum((32 * ((v + 3) // 4).max(dim=1).values).sum() for v in (low, high)))


def panel(n, owner):
    active = torch.ones(n.shape[-2:], dtype=torch.bool).tril()
    baseline_high = int(((n >= 128) & active).sum())
    result = {}
    for cap in CAPS:
        candidate, donors, moved = concentrate(n, owner, cap)
        total_moved = int(moved.sum())
        result[str(cap)] = {
            'high_pairs': int(((candidate >= 128) & active).sum()),
            'removed_high_pairs': int((donors & active).sum()),
            'max_possible_removed_without_shifting_more_than_cap_per_key': int((((n >= 128) & (n <= 127 + cap)) & active).sum()),
            'transferred_count_units': total_moved,
            'mean_count_l1_over_mass': 2 * total_moved / (n.shape[0] * n.shape[1] * n.shape[2] * 4095),
            'four_lane_slots': slots(candidate),
        }
        assert result[str(cap)]['high_pairs'] == baseline_high - result[str(cap)]['removed_high_pairs']
    return result


def run(layer):
    torch.set_num_threads(8)
    with safe_open(radix.MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    outcome = {}
    for split, windows in (('train', 8), ('validation', 4)):
        x = radix.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        p = radix.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        n = radix.counts(p)
        outcome[split] = {'windows': windows, 'baseline_high_pairs': int((n >= 128).sum()),
                          'baseline_four_lane_slots': slots(n),
                          'caps': panel(n, p.argmax(-1, keepdim=True))}
        print(layer, split, {cap: (v['removed_high_pairs'], v['four_lane_slots'])
                             for cap, v in outcome[split]['caps'].items()}, flush=True)
    receipt = {
        'layer': layer, 'domain': 'Qwen3-0.6B original-producer Q/K; 256-token causal prefixes; 4095 prefix-rounded counts; eight train and four repeatedly inspected validation windows',
        'source_sha256': radix.sha(HERE), 'parent_source_sha256': radix.sha(SUBBIT / 'value-mass-radix/measure.py'),
        'model_sha256': radix.sha(radix.MODEL), 'capture_sha256': radix.sha(radix.CAPTURES / f'layer{layer:02d}.npz'),
        'results': outcome,
        'cost_contract': 'the altered integer attention map needs argmax of probability, per-key crossing predicate and subtraction, transferred-count reduction, owner scatter, then low/high list construction; four-lane dot slots exclude all preparation, nibble gathers and O',
    }
    DATA.mkdir(parents=True, exist_ok=True)
    target = DATA / f'layer{layer:02d}.json'
    target.write_text(json.dumps(receipt, indent=2) + '\n')
    print(target, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
