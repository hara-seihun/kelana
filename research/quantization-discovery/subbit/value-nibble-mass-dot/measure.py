#!/usr/bin/env python3
"""Exact packed-nibble mass lowering and captured count/list cost panel."""
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
spec = importlib.util.spec_from_file_location('mass_radix', SUBBIT / 'value-mass-radix/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
MODEL, CAPTURES = parent.MODEL, parent.CAPTURES
counts, load_capture, probabilities, sha = parent.counts, parent.load_capture, parent.probabilities, parent.sha
DATA = Path('/path/to/workspace/data/kelana-subbit/value-nibble-mass-dot')


def dot8(a, b, signed_a=True, signed_b=False):
    total = 0
    for k in range(8):
        x, y = (a >> (4*k)) & 15, (b >> (4*k)) & 15
        total += (x - 16 if signed_a and x >= 8 else x) * (y - 16 if signed_b and y >= 8 else y)
    return total


def certificate():
    # Each possible count and signed code, including endpoints, exercises the packed operand.
    for n in range(4096):
        d = ((n >> 0) & 15, (n >> 4) & 15, (n >> 8) & 15)
        assert n == d[0] + 16*d[1] + 256*d[2]
        for c in range(-8, 8):
            packed = sum((c & 15) << (4*k) for k in range(8))
            products = [dot8(packed, 0x11111111*v) for v in d]
            assert products[0] + 16*products[1] + 256*products[2] == 8*n*c
    # Mixed lanes exercise both packing order and signedness independently.
    for seed in range(64):
        codes = [((seed*37 + i*19) % 16) - 8 for i in range(8)]
        n = [((seed*193 + i*541) % 4096) for i in range(8)]
        packed_c = sum((c & 15) << (4*i) for i, c in enumerate(codes))
        parts = [sum(((v >> (4*j)) & 15) << (4*i) for i, v in enumerate(n)) for j in range(3)]
        assert sum((16**j)*dot8(packed_c, parts[j]) for j in range(3)) == sum(c*v for c, v in zip(codes, n))
    return {'all_counts': 4096, 'all_signed_codes': 16, 'mixed_vectors': 64,
            'packed_instruction_semantics': 'signed four-bit first operand, unsigned four-bit second operand'}


def panel(n):
    batch, heads, length, _ = n.shape
    causal = torch.ones((length, length), dtype=torch.bool).tril()
    pairs = batch * heads * length * (length + 1) // 2
    digits = [(n >> shift) & 15 for shift in (0, 4, 8)]
    assert torch.equal(digits[0] + 16*digits[1] + 256*digits[2], n)
    outcome = []
    for shift, digit in zip((0, 4, 8), digits):
        support = (digit != 0) & causal
        per_row = support.sum(-1)
        outcome.append({'shift': shift, 'nonzero_pairs': int(support.sum()),
                        'max_keys_per_row': int(per_row.max()),
                        'issued_four_lane_pairs': int(((per_row + 3)//4*4).sum()),
                        'issued_eight_lane_pairs': int(((per_row + 7)//8*8).sum())})
    high = (n // 128 != 0) & causal
    low = (n % 128 != 0) & causal
    old = []
    for support in (low, high):
        per_row = support.sum(-1)
        old.append({'nonzero_pairs': int(support.sum()),
                    'issued_four_lane_pairs': int(((per_row + 3)//4*4).sum()),
                    'issued_eight_lane_pairs': int(((per_row + 7)//8*8).sum())})
    # A packed 32-coordinate nibble code consumes four dot8 instructions per key/pass.
    # Expanding that same code into bytes needs eight dot4 instructions per key/pass.
    return {'causal_pairs': pairs, 'nibble_digits': outcome, 'radix128_byte_digits': old,
            'ideal_dot_instructions_nibble': 4*sum(x['nonzero_pairs'] for x in outcome),
            'ideal_dot_instructions_byte': 8*sum(x['nonzero_pairs'] for x in old),
            'four_lane_issued_dot_instruction_slots_nibble': 4*sum(x['issued_four_lane_pairs'] for x in outcome),
            'four_lane_issued_dot_instruction_slots_byte': 8*sum(x['issued_four_lane_pairs'] for x in old),
            'eight_lane_issued_dot_instruction_slots_nibble': 4*sum(x['issued_eight_lane_pairs'] for x in outcome),
            'eight_lane_issued_dot_instruction_slots_byte': 8*sum(x['issued_eight_lane_pairs'] for x in old)}


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
        print(layer, split, results[split]['ideal_dot_instructions_nibble'],
              results[split]['ideal_dot_instructions_byte'], flush=True)
    receipt = {'layer': layer, 'certificate': certificate(), 'results': results,
               'source_sha256': sha(HERE), 'parent_source_sha256': sha(SUBBIT / 'value-mass-radix/measure.py'),
               'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
               'parent_receipt_sha256': sha(Path('/path/to/workspace/data/kelana-subbit/value-mass-radix') / f'layer{layer:02d}.json'),
               'domain': 'frozen original-producer Q/K, 8 train and 4 repeatedly inspected validation 256-token windows, 16 heads, 4095 prefix-rounded mass; same value codes and integer output as radix128',
               'cost_contract': '32 coordinates padded from 28 per head; three signed/unsigned packed nibble dot8 versus two byte dot4 passes. List lengths and subgroup padding only; digit construction, scans, compaction, cache gathers, occupancy, reduction, O and native time unpaid.'}
    DATA.mkdir(parents=True, exist_ok=True)
    dest = DATA / f'layer{layer:02d}.json'
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(dest, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
