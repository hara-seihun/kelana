#!/usr/bin/env python3
"""Price exact zero-mass compaction of the frozen integer narrow-value consumer."""
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
DATA = Path('/path/to/workspace/data/kelana-subbit/value-zero-compaction')


def slots(rows, lanes):
    groups = rows.reshape(-1, 32 // lanes)
    return int(((groups + lanes - 1) // lanes).amax(-1).sum()) * 32


def panel(p):
    n = source.counts(p)
    windows, heads, length, _ = n.shape
    mask = torch.ones((length, length), dtype=torch.bool).tril()
    lo = n.remainder(128)
    hi = n.div(128, rounding_mode='floor')
    assert torch.equal(n, lo + 128 * hi)
    assert int(lo.max()) <= 127 and int(hi.max()) <= 31
    generator = torch.Generator().manual_seed(3917)
    code = torch.randint(-7, 8, (length, 28), generator=generator, dtype=torch.int32)
    for t in (0, min(length - 1, 7), min(length - 1, 128), length - 1):
        count = n[0, 0, t, :t + 1]
        direct = (count[:, None] * code[:t + 1]).sum(0)
        sparse = ((count % 128)[:, None] * code[:t + 1]).sum(0)
        sparse += 128 * ((count // 128)[:, None] * code[:t + 1]).sum(0)
        assert torch.equal(direct, sparse)
    selections = {'active': (n > 0) & mask, 'low': (lo > 0) & mask,
                  'high': (hi > 0) & mask, 'multiple128': (lo == 0) & (hi > 0) & mask}
    rows = {name: selected.sum(-1).permute(0, 2, 1).contiguous().reshape(-1)
            for name, selected in selections.items()}
    causal_pairs = windows * heads * length * (length + 1) // 2
    dense = torch.arange(1, length + 1).repeat_interleave(heads).repeat(windows)
    by_position = []
    for begin, end in ((0, 32), (32, 64), (64, 128), (128, 256)):
        by_position.append({'query_positions': [begin, end],
                            'causal_pairs': windows * heads * sum(range(begin + 1, end + 1)),
                            **{name + '_pairs': int(selected[:, :, begin:end].sum())
                               for name, selected in selections.items()}})
    return {'rows': rows['active'].numel(), 'causal_pairs': causal_pairs,
            'pairs': {name: int(value.sum()) for name, value in rows.items()},
            'wave_slots': {str(lanes): {'dense_low': slots(dense, lanes),
                                      **{name: slots(value, lanes) for name, value in rows.items()},
                                      'sparse_two_list_total': slots(rows['low'], lanes) + slots(rows['high'], lanes),
                                      'dense_low_sparse_high_total': slots(dense, lanes) + slots(rows['high'], lanes)}
                           for lanes in (4, 8, 16, 32)},
            'by_position': by_position,
            'max_row': {name: int(value.max()) for name, value in rows.items()},
            'checked_positions': [0, min(length - 1, 7), min(length - 1, 128), length - 1]}


def run(layer):
    torch.set_num_threads(8)
    with safe_open(source.MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    results = {}
    for split, windows in (('train', 8), ('validation', 4)):
        x = source.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        p = source.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        results[split] = panel(p)
        print(layer, split, results[split]['pairs'], flush=True)
    receipt = {'layer': layer, 'source_sha256': source.sha(HERE),
               'parent_source_sha256': source.sha(SUBBIT / 'value-mass-residual/measure.py'),
               'model_sha256': source.sha(source.MODEL),
               'capture_sha256': source.sha(source.CAPTURES / f'layer{layer:02d}.npz'),
               'domain': 'frozen original-producer Qwen3-0.6B Q/K; eight train and four repeatedly inspected validation 256-token windows; 16 heads; prefix-rounded 4095 integer mass',
               'cost_contract': 'exact integer map; logical byte products and fixed-subgroup issued dot slots only. Count scan and softmax remain dense; ballot, index writes, compaction, nibble cache gathers, subgroup reduction, register pressure and O output not timed. Two lists need up to two indices per nonzero key, and extra list scans unless built in the count pass.',
               'results': results}
    DATA.mkdir(parents=True, exist_ok=True)
    dest = DATA / f'layer{layer:02d}.json'
    dest.write_text(json.dumps(receipt, indent=2) + '\n')
    print(dest, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
