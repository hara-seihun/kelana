#!/usr/bin/env python3
"""Count exact single-byte rows and unavoidable second-digit work for frozen V mass."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
sys.path.insert(0, str(SUBBIT / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from measure import probabilities

DATA = Path('/path/to/workspace/data/kelana-subbit/value-mass-residual')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def counts(p):
    prefix = (p.double().cumsum(-1) * 4095).round().clamp(0, 4095).to(torch.int32)
    prefix[..., -1] = 4095
    n = torch.diff(prefix, dim=-1, prepend=torch.zeros_like(prefix[..., :1]))
    assert n.min() >= 0 and torch.all(n.sum(-1) == 4095)
    high, low = n // 32, n % 32
    assert high.max() <= 127 and low.max() <= 31
    assert torch.equal(n, 32*high + low)
    return n


def panel(n):
    batch, heads, length, _ = n.shape
    max_count = n.amax(-1)
    eligible = max_count <= 127
    tail = (n % 32 != 0)
    high = (n >= 32)
    active = (n != 0)
    rows = []
    for start, end in ((0, 16), (16, 32), (32, 64), (64, 128), (128, 256)):
        sub = eligible[:, :, start:end]
        high_nnz = high[:, :, start:end, :end].sum().item()
        nnz = tail[:, :, start:end, :end].sum().item()
        nonzero = active[:, :, start:end, :end].sum().item()
        keys = batch * heads * sum(range(start + 1, end + 1))
        rows.append({'positions': [start, end], 'one_dot_rows': int(sub.sum()),
                     'total_rows': sub.numel(), 'one_dot_key_products_fraction':
                     float((sub * torch.arange(start + 1, end + 1)).sum().item()/keys),
                     'radix32_high_nonzero_fraction_of_keys': high_nnz/keys,
                     'radix32_residue_nonzero_fraction_of_keys': nnz/keys,
                     'radix32_residue_nonzero_fraction_of_active_counts': nnz/nonzero})
    all_keys = batch * heads * length*(length+1)//2
    one_keys = int((eligible * torch.arange(1, length+1)).sum())
    residue = int(tail.tril().sum())
    high_count = int(high.tril().sum())
    group_high = high.reshape(batch, 8, 2, length, length)
    group_union = int(group_high.any(2).tril().sum())
    active_count = int(active.tril().sum())
    # Single digit n<=127 needs no change of probability mass or value codes.
    # For other rows, floor(n/32) is a signed-byte high digit and n%32 is the exact low digit.
    # Dense two-dot cost: 2*all_keys*28. Ideal sparse-low cost charges only nonzero low codes.
    return {'rows': batch*heads*length, 'causal_keys': all_keys,
            'one_dot_rows': int(eligible.sum()), 'one_dot_key_pairs': one_keys,
            'one_dot_key_fraction': one_keys/all_keys,
            'one_dot_both_heads_rows': int(eligible.reshape(batch, 8, 2, length).all(2).sum()),
            'one_dot_all_heads_rows': int(eligible.all(1).sum()),
            'radix32_nonzero_low_pairs': residue, 'radix32_nonzero_high_pairs': high_count,
            'radix32_group_union_high_pairs': group_union,
            'radix32_active_pairs': active_count,
            'radix32_nonzero_high_fraction_of_keys': high_count/all_keys,
            'radix32_group_union_fraction_of_group_keys': group_union/(all_keys//2),
            'radix32_nonzero_low_fraction_of_keys': residue/all_keys,
            'radix32_nonzero_low_fraction_of_active': residue/active_count,
            'ideal_dynamic_one_dot_products_per_coordinate': 2*all_keys-one_keys,
            'ideal_sparse_radix32_products_per_coordinate': all_keys+residue,
            'ideal_sparse_high_products_per_coordinate': all_keys+high_count,
            'dense_two_dot_products_per_coordinate': 2*all_keys,
            'by_position': rows}


def run(layer):
    torch.set_num_threads(8)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    result = {}
    for split in ('train', 'validation'):
        x = load_capture(layer, split).reshape(-1, 256, 1024)[:8 if split == 'train' else 4]
        n = counts(probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm']))
        result[split] = panel(n)
        print(layer, split, result[split]['one_dot_key_fraction'],
              result[split]['radix32_nonzero_low_fraction_of_keys'], flush=True)
    receipt = {'layer': layer, 'source_sha256': sha(HERE), 'model_sha256': sha(MODEL),
               'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
               'domain': 'frozen original-producer Q/K, 8 train and 4 previously inspected validation 256-token windows, 16 heads; 4095-mass prefix rounding',
               'results': result, 'cost_contract': 'logical signed-byte dot products only; no probability prep, max reduction, scheduling, sparse gather, cache traffic, V/O producer or native timing'}
    DATA.mkdir(parents=True, exist_ok=True)
    dest = DATA / f'layer{layer:02d}.json'
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(dest, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
