#!/usr/bin/env python3
"""Price fixed subwave layouts for exact sparse value high-digit corrections."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
sys.path.insert(0, str(SUBBIT / 'value-observer'))
spec = importlib.util.spec_from_file_location('high_prefilter', SUBBIT / 'value-high-prefilter/measure.py')
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)

DATA = Path('/path/to/workspace/data/kelana-subbit/value-high-scheduling')


def scheduled(rows, lanes):
    """One wave owns 32/lanes independent rows, with a local lane mask per row."""
    assert rows.numel() % (32 // lanes) == 0
    steps = (rows.reshape(-1, 32 // lanes) + lanes - 1) // lanes
    return int(steps.amax(-1).sum().item()) * 32


def panel(p):
    n = source.counts(p)
    x = p.double() * source.MASS
    active = torch.ones((p.shape[-1], p.shape[-1]), dtype=torch.bool).tril()
    high = ((n >= 128) & active).sum(-1).int()
    guard = ((x >= 126) & active).sum(-1).int()
    assert not bool(((n >= 128) & ~((x >= 126) & active)).any())
    # Order is window, query position, head. Adjacent heads share the same key
    # context; each has its own probability row and output accumulators.
    rows = {name: counts.permute(0, 2, 1).contiguous().reshape(-1)
            for name, counts in [('post_scan', high), ('pre_scan_guard', guard)]}
    results = {}
    for name, counts in rows.items():
        pair_count = int(counts.sum())
        results[name] = {
            'high_pairs': pair_count,
            'wave_slots': {str(lanes): scheduled(counts, lanes) for lanes in (4, 8, 16, 32)},
            'nonempty_rows': int((counts > 0).sum()),
            'max_per_row': int(counts.max()),
        }
    # A wave of four fixed 8-lane subgroups consumes four rows concurrently.
    # Each subgroup reduces its own 28 output coordinates, without cross-head
    # atomics. Max steps, not sum of independently padded row slots, prices
    # divergence and idle subgroups at wave issue granularity.
    return {'rows': high.numel(), 'causal_pairs': p.shape[0] * p.shape[1] * p.shape[2] * (p.shape[2]+1)//2,
            'layouts': results}


def run(layer):
    torch.set_num_threads(8)
    with safe_open(source.MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    result = {}
    for split, windows in (('train', 8), ('validation', 4)):
        hidden = source.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        p = source.probabilities(hidden, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        result[split] = panel(p)
        print(layer, split, result[split]['layouts']['post_scan']['wave_slots'], flush=True)
    receipt = {'layer': layer, 'source_sha256': source.sha(HERE),
               'parent_source_sha256': source.sha(SUBBIT / 'value-high-prefilter/measure.py'),
               'model_sha256': source.sha(source.MODEL),
               'capture_sha256': source.sha(source.CAPTURES / f'layer{layer:02d}.npz'),
               'domain': 'frozen original-producer Q/K; 8 train and 4 repeatedly inspected validation windows of 256 tokens, 16 heads; prefix-rounded 4095-count mass',
               'layout': 'one 32-lane wave spans 32/lanes adjacent query heads at the same position, fixed subgroup lanes; maximum subgroup passes determines issued slots; last 16 heads divisible by every tested subgroup count',
               'cost_contract': 'issued high-dot lane slots only; count scan, probability threshold, compaction, index storage, nibble gathers, subgroup reductions, register pressure, low dot and native time excluded',
               'results': result}
    DATA.mkdir(parents=True, exist_ok=True)
    target = DATA / f'layer{layer:02d}.json'
    target.write_text(json.dumps(receipt, indent=2) + '\n')
    print(target, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
