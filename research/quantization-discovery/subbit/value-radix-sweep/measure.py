#!/usr/bin/env python3
"""Compare two exact integer mass coordinates under a common four-lane wave schedule."""
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
spec = importlib.util.spec_from_file_location('mass_residual', SUBBIT / 'value-mass-residual/measure.py')
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)
DATA = Path('/path/to/workspace/data/kelana-subbit/value-radix-sweep')


def waves(n):
    batch, heads, length, _ = n.shape
    mask = torch.ones((length, length), dtype=torch.bool).tril()
    n = n * mask
    counts = {
        'low128': ((n % 128 != 0) & mask).sum(-1),
        'high128': (n >= 128).sum(-1),
        'high256': (n >= 256).sum(-1),
    }
    by_wave = {}
    for name, count in counts.items():
        step = (count.permute(0, 2, 1).reshape(batch, length, heads // 8, 8) + 3) // 4
        by_wave[name] = 32 * step.amax(-1)
    dense = torch.arange(1, length + 1).reshape(1, length, 1).expand(batch, length, heads // 8)
    dense = 32 * ((dense + 3) // 4)
    sparse = by_wave['low128'] + by_wave['high128']
    prefix = dense + by_wave['high256']
    choose_prefix = prefix < sparse
    oracle = torch.minimum(sparse, prefix)
    # A static wave decision can be selected on train without peeking at held labels.
    return {
        'sparse128': sparse, 'prefix256': prefix, 'oracle': oracle,
        'choose_prefix': choose_prefix, 'low128': by_wave['low128'],
        'high128': by_wave['high128'], 'high256': by_wave['high256'],
        'dense': dense,
        'nonzero_low_pairs': int(counts['low128'].sum()),
        'high128_pairs': int(counts['high128'].sum()),
        'high256_pairs': int(counts['high256'].sum()),
        'causal_pairs': batch * heads * length * (length + 1) // 2,
    }


def unsigned_radices(n):
    batch, heads, length, _ = n.shape
    mask = torch.ones((length, length), dtype=torch.bool).tril()
    steps = {}
    for radix in (32, 64, 128):
        assert radix <= 128 and (4095 // radix) <= 127
        lo = ((n % radix != 0) & mask).sum(-1)
        hi = (n >= radix).sum(-1)
        def slot(count):
            rows = count.permute(0, 2, 1).reshape(batch, length, heads // 8, 8)
            return 32 * ((rows + 3) // 4).amax(-1)
        steps[str(radix)] = {
            'slots': slot(lo) + slot(hi),
            'low_pairs': int(lo.sum()), 'high_pairs': int(hi.sum()),
        }
    return steps


def summary(w, static):
    sums = {name: int(w[name].sum()) for name in ('sparse128', 'prefix256', 'oracle', 'low128', 'high128', 'high256', 'dense')}
    selected = torch.where(static[None, None, :], w['prefix256'], w['sparse128'])
    gain = w['sparse128'] - w['prefix256']
    advantage = gain.clamp_min(0)
    return {
        'issued_lane_slots': {**sums, 'train_fixed_wave': int(selected.sum())},
        'prefix_favorable_waves': int(w['choose_prefix'].sum()),
        'total_waves': w['choose_prefix'].numel(),
        'prefix_favorable_by_wave': w['choose_prefix'].sum((0, 1)).tolist(),
        'static_prefix_wave': static.tolist(),
        'positive_gain_slots_by_wave': advantage.sum((0, 1)).tolist(),
        'negative_gain_slots_by_wave': (-gain).clamp_min(0).sum((0, 1)).tolist(),
        'count_pairs': {name: w[name] for name in ('nonzero_low_pairs', 'high128_pairs', 'high256_pairs', 'causal_pairs')},
    }


def run(layer):
    torch.set_num_threads(8)
    with safe_open(source.MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    panels = {}
    radices = {}
    for split, windows in (('train', 8), ('validation', 4)):
        x = source.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        n = source.counts(source.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm']))
        assert torch.all(n.sum(-1) == 4095)
        panels[split] = waves(n)
        radices[split] = unsigned_radices(n)
    train = panels['train']
    static = train['prefix256'].sum((0, 1)) < train['sparse128'].sum((0, 1))
    result = {split: summary(panel, static) for split, panel in panels.items()}
    best_radix = min(radices['train'], key=lambda radix: int(radices['train'][radix]['slots'].sum()))
    for split, values in radices.items():
        result[split]['unsigned_radix_sweep'] = {
            radix: {'issued_lane_slots': int(row['slots'].sum()),
                    'nonzero_low_pairs': row['low_pairs'], 'nonzero_high_pairs': row['high_pairs']}
            for radix, row in values.items()}
        result[split]['train_selected_unsigned_radix'] = best_radix
    receipt = {
        'layer': layer,
        'source_sha256': source.sha(HERE),
        'parent_sha256': source.sha(SUBBIT / 'value-mass-residual/measure.py'),
        'model_sha256': source.sha(source.MODEL),
        'capture_sha256': source.sha(source.CAPTURES / f'layer{layer:02d}.npz'),
        'domain': 'Qwen3-0.6B frozen original-producer Q/K, eight train and four previously inspected validation 256-token windows; prefix-rounded nonnegative 4095 counts and 16 heads',
        'cost_contract': 'one 32-lane wave holds eight adjacent heads, four lanes/head; two separate compacted unsigned-radix lists versus one dense prefix-256 low dot plus high list. Issued signed-byte dot lane slots only. Prefix-256 also pays 224 int32 code updates per token, 896 bytes per-sequence state per layer and 448 correction adds per query; sparse-128 pays extra list construction. Count preparation, gathers, output projection, synchronization and GPU time excluded. Oracle wave selection pays for both sets of list lengths and a branch.',
        'results': result,
    }
    DATA.mkdir(parents=True, exist_ok=True)
    dest = DATA / f'layer{layer:02d}.json'
    dest.write_text(json.dumps(receipt, indent=2) + '\n')
    print(layer, {k: v['issued_lane_slots'] for k, v in result.items()}, flush=True)
    print(dest, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
