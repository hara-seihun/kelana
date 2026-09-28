#!/usr/bin/env python3
"""Exact radix-256 mass split with a shared value-code prefix accumulator."""
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
DATA = Path('/path/to/workspace/data/kelana-subbit/value-prefix-gauge')
MASS = 4095


def slots(rows, lanes=4):
    steps = (rows.reshape(-1, 32 // lanes) + lanes - 1) // lanes
    return int(steps.amax(-1).sum()) * 32


def panel(p):
    n = source.counts(p).to(torch.int32)
    length = n.shape[-1]
    active = torch.ones((length, length), dtype=torch.bool).tril()
    high128 = ((n >= 128) & active).sum(-1).int()
    high256 = ((n >= 256) & active).sum(-1).int()
    low = (n & 255) - 128
    high = n >> 8
    assert low.min() >= -128 and low.max() <= 127
    assert high.min() >= 0 and high.max() <= 15
    assert torch.equal(n, low + 256 * high + 128)
    assert torch.equal(n.sum(-1), torch.full_like(n.sum(-1), MASS))
    # Independent small signed-nibble histories replay the complete prefix
    # relation, including zero-mass keys and all causal query positions.
    generator = torch.Generator().manual_seed(20260923)
    codes = torch.randint(-7, 8, (p.shape[0], p.shape[1] // 2, length, 28), generator=generator, dtype=torch.int32)
    shared = codes.repeat_interleave(2, dim=1)
    prefix = shared.cumsum(dim=2)
    sample = (0, min(7, length - 1), min(128, length - 1), length - 1)
    for t in sample:
        direct = (n[:, :, t, :t+1, None] * shared[:, :, :t+1]).sum(2)
        biased = (low[:, :, t, :t+1, None] * shared[:, :, :t+1]).sum(2)
        biased += 256 * (high[:, :, t, :t+1, None] * shared[:, :, :t+1]).sum(2)
        biased += 128 * prefix[:, :, t]
        assert torch.equal(direct, biased)
    pair_count = p.shape[0] * p.shape[1] * length * (length + 1) // 2
    rows = {key: value.permute(0, 2, 1).contiguous().reshape(-1) for key, value in
            [('radix128', high128), ('prefix256', high256)]}
    return {
        'causal_pairs': pair_count, 'rows': high128.numel(),
        'high_pairs': {key: int(value.sum()) for key, value in rows.items()},
        'high_fraction': {key: float(value.sum()) / pair_count for key, value in rows.items()},
        'four_lane_wave_slots': {key: slots(value) for key, value in rows.items()},
        'one_wave_per_row_slots': {key: slots(value, 32) for key, value in rows.items()},
        'max_high_keys': {key: int(value.max()) for key, value in rows.items()},
        'late_high_pairs': {key: int(((n[:, :, 128:, :] >= threshold) & active[128:, :]).sum())
                            for key, threshold in [('radix128', 128), ('prefix256', 256)]},
        'checked_code_prefix_positions': list(sample),
    }


def run(layer):
    torch.set_num_threads(8)
    with safe_open(source.MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    results = {}
    for split, windows in (('train', 8), ('validation', 4)):
        x = source.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        results[split] = panel(source.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm']))
        print(layer, split, results[split]['high_pairs'], flush=True)
    receipt = {
        'layer': layer, 'source_sha256': source.sha(HERE),
        'parent_source_sha256': source.sha(SUBBIT / 'value-mass-residual/measure.py'),
        'radix_receipt_sha256': source.sha(Path('/path/to/workspace/data/kelana-subbit/value-mass-radix') / f'layer{layer:02d}.json'),
        'model_sha256': source.sha(source.MODEL), 'capture_sha256': source.sha(source.CAPTURES / f'layer{layer:02d}.npz'),
        'domain': '4095 prefix-rounded integer mass; Qwen3-0.6B original-producer frozen Q/K, eight train and four repeatedly inspected 256-token validation windows; 16 query heads',
        'cost_contract': 'high-dot logical products and ideal fixed-subgroup issued slots; prefix code sum needs 224 int32 updates/token/layer and 896 bytes state/layer/sequence; threshold/ballot, scan, gather, low dot, prefix storage, O and native time unpaid',
        'results': results,
    }
    DATA.mkdir(parents=True, exist_ok=True)
    path = DATA / f'layer{layer:02d}.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(path, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
