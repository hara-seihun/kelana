#!/usr/bin/env python3
"""Price head grouping for the exact sparse radix-128 value consumer."""
import argparse
import importlib.util
import itertools
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
sys.path.insert(0, str(SUBBIT / 'value-observer'))
spec = importlib.util.spec_from_file_location('mass_residual', SUBBIT / 'value-mass-residual/measure.py')
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)
DATA = Path('/path/to/workspace/data/kelana-subbit/value-low-occupancy-bound')


def lengths(p):
    n = source.counts(p)
    lo = (n % 128 > 0).sum(-1)
    hi = (n >= 128).sum(-1)
    # One row is a query position with sixteen heads; the two digits use the
    # same grouping, so any permutation must be paid by both passes.
    return torch.stack((lo, hi), dim=-1).permute(0, 2, 1, 3).reshape(-1, 16, 2).numpy()


def steps(rows, lanes, order=None):
    if order is not None:
        rows = rows[:, order]
    return ((rows + lanes - 1) // lanes).reshape(-1, 32 // lanes, 2).max(axis=1).sum(axis=0).astype(int)


def dynamic_steps(rows, lanes):
    g = 32 // lanes
    out = []
    for d in range(2):
        # Sorting all sixteen row lengths gives the optimal equal-sized
        # partition for the sum of group maxima; the two dots can permute
        # differently only if the index/accumulator mapping is paid.
        sorted_rows = np.sort((rows[:, :, d] + lanes - 1) // lanes, axis=1)
        out.append(int(sorted_rows[:, g-1::g].sum()))
    return np.array(out)


def optimize_fixed(train, lanes):
    order = list(range(16))
    score = int(steps(train, lanes, order).sum())
    while True:
        best = None
        for i in range(16):
            for j in range(i + 1, 16):
                candidate = order.copy()
                candidate[i], candidate[j] = candidate[j], candidate[i]
                trial = int(steps(train, lanes, candidate).sum())
                if trial < score and (best is None or trial < best[0]):
                    best = (trial, candidate)
        if best is None:
            return order, score
        score, order = best


def group_partitions(remaining, block_size):
    if not remaining:
        yield ()
        return
    first, *rest = remaining
    for others in itertools.combinations(rest, block_size - 1):
        block = (first, *others)
        for suffix in group_partitions(tuple(x for x in rest if x not in others), block_size):
            yield (block, *suffix)


def optimize_gqa(train, lanes):
    groups_per_wave = (32 // lanes) // 2
    best = None
    for partition in group_partitions(tuple(range(8)), groups_per_wave):
        order = [head for block in partition for group in block for head in (2 * group, 2 * group + 1)]
        score = int(steps(train, lanes, order).sum())
        if best is None or score < best[0]:
            best = (score, order)
    return best[1], best[0]


def panel(rows, lanes, order, gqa_order):
    original = steps(rows, lanes)
    fixed = steps(rows, lanes, order)
    gqa = steps(rows, lanes, gqa_order)
    oracle = dynamic_steps(rows, lanes)
    # One wave per head supplies an attainable non-divergent but high-idle
    # control. A perfect lane scheduler cannot beat ceil(total pairs / 32).
    one_head = ((rows + 31) // 32).sum(axis=(0, 1))
    ideal = (rows.sum(axis=1) + 31) // 32
    return {'adjacent_slots': (original * 32).tolist(),
            'train_fixed_slots': (fixed * 32).tolist(),
            'train_gqa_slots': (gqa * 32).tolist(),
            'per_query_sorted_slots': (oracle * 32).tolist(),
            'one_head_wave_slots': (one_head * 32).tolist(),
            'unconstrained_dot_slot_floor': (ideal.sum(axis=0) * 32).astype(int).tolist(),
            'logical_pairs': rows.sum(axis=(0, 1)).astype(int).tolist(),
            'fixed_order': order, 'gqa_order': gqa_order}


def run(layer):
    torch.set_num_threads(8)
    with safe_open(source.MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    arrays = {}
    for split, windows in (('train', 8), ('validation', 4)):
        x = source.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        arrays[split] = lengths(source.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm']))
    result = {}
    for lanes in (4, 8, 16):
        order, objective = optimize_fixed(arrays['train'], lanes)
        gqa_order, gqa_objective = optimize_gqa(arrays['train'], lanes)
        result[str(lanes)] = {'train_objective_steps': objective,
                              'train_gqa_objective_steps': gqa_objective,
                              **{split: panel(rows, lanes, order, gqa_order) for split, rows in arrays.items()}}
    receipt = {'layer': layer, 'source_sha256': source.sha(HERE),
               'parent_source_sha256': source.sha(SUBBIT / 'value-mass-residual/measure.py'),
               'model_sha256': source.sha(source.MODEL),
               'capture_sha256': source.sha(source.CAPTURES / f'layer{layer:02d}.npz'),
               'domain': 'frozen original-producer Qwen3-0.6B; eight train and four repeatedly inspected validation 256-token windows; 16 query heads, prefix-rounded 4095 mass',
               'cost_contract': 'wave dot lane slots for two exact sparse radix-128 digits only. Each four/eight/sixteen-lane subgroup owns one head, with 28 coordinates over its lanes; unrestricted fixed orders use train local exchanges, GQA-preserving fixed orders enumerate all group partitions and keep adjacent head pairs. Dynamic sorted order is a per-query non-free oracle. Softmax, count scan, list compaction, remapping, nibble gathers, register pressure and O remain uncharged.',
               'results': result}
    DATA.mkdir(parents=True, exist_ok=True)
    target = DATA / f'layer{layer:02d}.json'
    target.write_text(json.dumps(receipt, indent=2) + '\n')
    print(target, flush=True)
    for lanes, item in result.items():
        print(layer, lanes, 'held', item['validation']['adjacent_slots'], item['validation']['train_gqa_slots'], item['validation']['train_fixed_slots'], item['validation']['per_query_sorted_slots'], flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
