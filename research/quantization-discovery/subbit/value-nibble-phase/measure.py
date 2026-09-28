#!/usr/bin/env python3
"""Finite shifted-prefix single-nibble mass search on frozen narrow V/O."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('mass', SUBBIT / 'value-mass-allocation/measure.py')
mass = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mass)
DATA, MODEL, CAPTURES = mass.DATA, mass.MODEL, mass.CAPTURES


def shifted_counts(p, offset):
    prefix = (p.double().cumsum(-1)*15 + offset).floor().clamp(0, 15).to(torch.int32)
    prefix[..., -1] = 15
    n = torch.diff(prefix, dim=-1, prepend=torch.zeros_like(prefix[..., :1]))
    assert n.min() >= 0 and n.max() <= 15 and torch.all(n.sum(-1) == 15)
    return n


def replay(layer, split, image, metadata, weights, decoder, phases):
    x = mass.load_capture(layer, split).reshape(-1, 256, 1024)[:8 if split == 'train' else 4]
    p = mass.probabilities(x, weights['q_proj'], weights['k_proj'], weights['q_norm'], weights['k_norm'])
    n255, n4095 = mass.counts(p, 255), mass.counts(p, 4095)
    shifted = [shifted_counts(p, offset) for offset in phases]
    base, ref, options = [], [], []
    with np.load(image) as factors:
        for group in range(8):
            arrays = {key: factors[key][group].copy() for key in factors.files}
            left, right = decoder.decode(arrays, 'left'), decoder.decode(arrays, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            step = torch.tensor(metadata['metadata'][group]['int4_coordinate']['step'])
            code = (z / step).round().clamp(-7, 7).float()
            for local in range(2):
                head = 2*group + local
                matrix = left[local*1024:(local+1)*1024]
                def output(n, divisor):
                    return ((n[:, head].float() @ code) * (step/divisor)) @ matrix.T
                base.append(output(n255, 255))
                ref.append(output(n4095, 4095))
                options.append([output(n, 15) for n in shifted])
            print(layer, split, group, flush=True)
    return torch.stack(base), torch.stack(ref), options, shifted, n255


def run(layer, phases):
    torch.set_num_threads(8)
    image = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    prior = DATA / 'value-centered-int4' / f'layer{layer:02d}-8x4.json'
    parent_path = DATA / 'value-nibble-255' / f'layer{layer:02d}.json'
    metadata, parent = json.loads(prior.read_text()), json.loads(parent_path.read_text())
    assert mass.sha(image) == metadata['image_sha256']
    mask = int(parent['train_selected']['mask'], 16)
    spec = importlib.util.spec_from_file_location('decoder', mass.SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        weights = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
                   for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    results = {}
    for split in ('train', 'validation'):
        base, ref, options, counts, n255 = replay(layer, split, image, metadata, weights, decoder, phases)
        # The parent retains 4095-unit heads. Search one replacement within its 255 mask.
        parent_sum = torch.stack([base[h] if mask & (1 << h) else ref[h] for h in range(16)]).sum(0)
        reference = ref.sum(0)
        residue = parent_sum - reference
        energy = float(reference.square().sum())
        entries = []
        for head in range(16):
            if not mask & (1 << head):
                continue
            old = n255[:, head]
            old_slots = sum(int((((((old >> shift) & 15).ne(0).sum(-1) + 3)//4)*16).sum())
                            for shift in (0, 4))
            for phase_idx, offset in enumerate(phases):
                delta = options[head][phase_idx] - base[head]
                error = float((residue + delta).square().sum()) / energy
                slots = counts[phase_idx][:, head].ne(0).sum(-1)
                entries.append({'head': head, 'offset': offset, 'error': error,
                                'parent_head_slots': old_slots,
                                'four_lane_dot8_slots': int(((slots + 3)//4*16).sum())})
        results[split] = {'parent_error': float(residue.square().sum())/energy,
                          'candidates': entries}
    train = results['train']['candidates']
    winner = min(train, key=lambda v: v['error'])
    held = next(v for v in results['validation']['candidates']
                if v['head'] == winner['head'] and v['offset'] == winner['offset'])
    receipt = {'layer': layer, 'phases': phases, 'parent_255_mask': f'{mask:04x}',
               'train': results['train'], 'held_parent_error': results['validation']['parent_error'],
               'selected_train': winner, 'selected_held': held,
               'held_all_candidates': results['validation']['candidates'],
               'model_sha256': mass.sha(MODEL), 'capture_sha256': mass.sha(CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': mass.sha(image), 'cache_fit_sha256': mass.sha(prior),
               'parent_receipt_sha256': mass.sha(parent_path), 'source_sha256': mass.sha(HERE),
               'domain': 'One 255-to-15 head switch, fixed paid V/O and original Q/K producer. Eight 256-token train windows select head and global prefix phase; four repeatedly inspected validation windows are held relative to selection. Shifted prefix floor(15*cumulative_probability+offset), final prefix 15. FP32 O replay.'}
    path = DATA / 'value-nibble-phase' / f'layer{layer:02d}.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'receipt': str(path), 'parent': results['train']['parent_error'],
                      'selected_train': winner, 'selected_held': held}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    args = parser.parse_args()
    run(args.layer, [i/16 for i in range(16)])
