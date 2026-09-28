#!/usr/bin/env python3
"""Certify modular ranks of the frozen paid observer's direct integer queries."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit')
MODULUS = 65521


def imported(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


lower = imported(ROOT/'nibble-query-lowering/measure.py', 'nibble_query_lower')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def rank_growth(rows):
    """Incremental exact elimination over F_65521, returning each rank jump's row index."""
    basis = {}
    pivots = []
    for index, row in enumerate(rows):
        v = [int(x) % MODULUS for x in row]
        for pivot in sorted(basis):
            factor = v[pivot]
            if factor:
                v = [(a-factor*b) % MODULUS for a, b in zip(v, basis[pivot])]
        pivot = next((i for i, value in enumerate(v) if value), None)
        if pivot is not None:
            inverse = pow(v[pivot], -1, MODULUS)
            basis[pivot] = [(a*inverse) % MODULUS for a in v]
            pivots.append(index)
    return pivots


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--window', type=int, choices=range(4), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    parent_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    prior_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    parent = json.loads(parent_path.read_text())
    prior = json.loads(prior_path.read_text())
    finite = lower.finite
    paid = lower.paid
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        weights = {name: model.get_tensor(prefix+name+'.weight').float()
                   for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)[args.window:args.window+1]
    q, _ = paid.projected(x, weights, gamma)
    records = []
    for g, group in enumerate(parent['groups']):
        idx = group['mask'] + [p+64 for p in group['mask']]
        arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
        prepared = q[0, 2*g:2*g+2, :, idx].double()*steps
        delta = prepared.abs().amax(-1, keepdim=True).clamp_min(1e-20)/119
        codes = (prepared/delta).round().clamp(-119, 119).to(torch.int16)
        heads = []
        for h in range(2):
            rows = codes[h, 1:].tolist()
            pivots = rank_growth(rows)
            starts = list(range(1, 210, 16)) + [224]
            future = [{'start': start, 'rank': len(rank_growth(rows[start-1:start+31]))}
                      for start in starts]
            heads.append({'rank': len(pivots), 'first_full_rank_query_position': pivots[31]+1 if len(pivots) == 32 else None,
                          'independent_query_positions': [p+1 for p in pivots],
                          'witness_codes': [rows[p] for p in pivots],
                          'future_32_query_windows': future,
                          'query_codes_positions_1_to_255': rows})
        records.append({'group': g, 'heads': heads})
    result = {'layer': args.layer, 'validation_window': args.window, 'prime': MODULUS,
              'map': 'original-producer hidden; paid binary Q/K image; 128 selected RoPE planes; frozen nibble key steps; two dynamic signed-eight-bit queries/head/group; causal query positions 1..255',
              'groups': records, 'max_first_full_rank_position': max(h['first_full_rank_query_position'] for group in records for h in group['heads']),
              'minimum_future_window_rank': min(w['rank'] for group in records for h in group['heads'] for w in h['future_32_query_windows']),
              'source_sha256': sha(Path(__file__)), 'model_sha256': sha(finite.MODEL),
              'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'parent_sha256': sha(parent_path), 'prior_sha256': sha(prior_path),
              'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print('layer', args.layer, 'window', args.window, 'max full-rank query position', result['max_first_full_rank_position'])


if __name__ == '__main__':
    main()
