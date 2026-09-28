#!/usr/bin/env python3
"""Compare exact signed-byte mass radices on frozen Qwen causal probabilities."""
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
spec = importlib.util.spec_from_file_location('value_mass_residual', SUBBIT / 'value-mass-residual/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
MODEL, CAPTURES = parent.MODEL, parent.CAPTURES
counts, load_capture, probabilities, sha = parent.counts, parent.load_capture, parent.probabilities, parent.sha

DATA = Path('/path/to/workspace/data/kelana-subbit/value-mass-radix')
RADICES = (32, 64, 128)


def panel(n):
    batch, heads, length, _ = n.shape
    causal = torch.ones((length, length), dtype=torch.bool).tril()
    pairs = batch * heads * length * (length + 1) // 2
    outcome = {}
    for radix in RADICES:
        low = n % radix
        high = n // radix
        assert low.max() <= 127 and high.max() <= 127
        assert torch.equal(radix * high + low, n)
        support = (high != 0) & causal
        low_support = (low != 0) & causal
        per_row = support.sum(-1)
        union = support.reshape(batch, 8, 2, length, length).any(2)
        actual = int(support.sum())
        # A compact high-key list still has lane-fill and scheduling costs. These
        # counts charge a whole group of 4/8/16/32 keys per query/head.
        outcome[str(radix)] = {
            'high_pairs': actual,
            'high_fraction': actual / pairs,
            'low_nonzero_pairs': int(low_support.sum()),
            'group_union_high_pairs': int(union.sum()),
            'max_high_keys_per_row': int(per_row.max()),
            'mean_high_keys_per_row': float(per_row.float().mean()),
            'p90_high_keys_per_row': int(torch.quantile(per_row.float().flatten(), .9)),
            'p99_high_keys_per_row': int(torch.quantile(per_row.float().flatten(), .99)),
            'rows_with_high': int((per_row > 0).sum()),
            'rounded_high_pairs': {str(width): int(((per_row + width - 1) // width * width).sum())
                                   for width in (4, 8, 16, 32)},
            'ideal_products_per_coordinate': pairs + actual,
            'ideal_saving_vs_two_dense': (pairs - actual) / (2 * pairs),
            'position_128_256_high_fraction': float(support[:, :, 128:256].sum()) /
                                              (batch * heads * sum(range(129, 257))),
        }
    for a, b in zip(RADICES, RADICES[1:]):
        assert outcome[str(b)]['high_pairs'] <= outcome[str(a)]['high_pairs']
    return {'causal_pairs': pairs, 'radices': outcome}


def run(layer):
    torch.set_num_threads(8)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    results = {}
    for split in ('train', 'validation'):
        x = load_capture(layer, split).reshape(-1, 256, 1024)[:8 if split == 'train' else 4]
        n = counts(probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm']))
        results[split] = panel(n)
        print(layer, split, {r: round(v['high_fraction'], 5)
                             for r, v in results[split]['radices'].items()}, flush=True)
    receipt = {
        'layer': layer, 'source_sha256': sha(HERE), 'parent_source_sha256': sha(SUBBIT / 'value-mass-residual/measure.py'),
        'parent_receipt_sha256': sha(Path('/path/to/workspace/data/kelana-subbit/value-mass-residual') / f'layer{layer:02d}.json'),
        'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
        'domain': 'frozen original-producer Q/K, 8 train and 4 repeatedly inspected validation 256-token windows, 16 query heads; 4095 prefix-rounded mass',
        'results': results,
        'cost_contract': 'logical signed-byte products and hypothetical compact-list width padding; count conversion, scan, compaction, gathers, cache and native timing unpaid',
    }
    DATA.mkdir(parents=True, exist_ok=True)
    dest = DATA / f'layer{layer:02d}.json'
    dest.write_text(json.dumps(receipt, indent=2) + '\n')
    print(dest, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
