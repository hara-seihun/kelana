#!/usr/bin/env python3
"""Test single-nibble probability mass on a frozen paid narrow V/O consumer."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('mass_allocation', SUBBIT / 'value-mass-allocation/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
DATA, MODEL, CAPTURES = parent.DATA, parent.MODEL, parent.CAPTURES
sha, counts, probabilities, load_capture = parent.sha, parent.counts, parent.probabilities, parent.load_capture


def replay(layer, split, image, metadata, weights, decoder):
    x = load_capture(layer, split).reshape(-1, 256, 1024)[:8 if split == 'train' else 4]
    p = probabilities(x, weights['q_proj'], weights['k_proj'], weights['q_norm'], weights['k_norm'])
    masses = (15, 255, 4095)
    ns = {mass: counts(p, mass) for mass in masses}
    outputs = {mass: [] for mass in masses}
    with np.load(image) as factors:
        for group in range(8):
            arrays = {key: factors[key][group].copy() for key in factors.files}
            left = decoder.decode(arrays, 'left')
            right = decoder.decode(arrays, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            step = torch.tensor(metadata['metadata'][group]['int4_coordinate']['step'])
            codes = (z / step).round().clamp(-7, 7).float()
            for local in range(2):
                head = 2*group + local
                matrix = left[local*1024:(local+1)*1024]
                for mass in masses:
                    outputs[mass].append(((ns[mass][:, head].float() @ codes) * (step/mass)) @ matrix.T)
            print(layer, split, group, flush=True)
    return {mass: torch.stack(outputs[mass]) for mass in masses}, ns[15]


def selected(outputs, mask, mass):
    return torch.stack([outputs[mass][i] if mask & (1 << i) else outputs[4095][i]
                        for i in range(16)]).sum(0)


def score(reference, candidate):
    diff = candidate - reference
    return {'relative_error': float(diff.square().sum()/reference.square().sum()),
            'per_window': [float(diff[i].square().sum()/reference[i].square().sum())
                           for i in range(reference.shape[0])]}


def slots(n):
    count = (n != 0).sum(-1)
    return {'nonzero_pairs': int(count.sum()), 'max_keys_per_row': int(count.max()),
            'four_lane_dot8_slots': int((count.add(3).div(4, rounding_mode='floor')*16).sum())}


def run(layer):
    torch.set_num_threads(8)
    image = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    prior = DATA / 'value-centered-int4' / f'layer{layer:02d}-8x4.json'
    previous = DATA / 'value-nibble-255' / f'layer{layer:02d}.json'
    metadata = json.loads(prior.read_text())
    assert sha(image) == metadata['image_sha256']
    previous_data = json.loads(previous.read_text())
    assert previous_data['factor_sha256'] == sha(image) and previous_data['cache_fit_sha256'] == sha(prior)
    spec = importlib.util.spec_from_file_location('decoder', parent.SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        weights = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
                   for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    train, _ = replay(layer, 'train', image, metadata, weights, decoder)
    original_mask = int(previous_data['train_selected']['mask'], 16)
    reference = train[4095].sum(0)
    base = selected(train, original_mask, 255)
    delta = (train[15] - train[255]).reshape(16, -1).double()
    gram = (delta @ delta.T).numpy()
    linear = 2 * (delta @ (base-reference).reshape(-1).double()).numpy()
    energy = float(reference.square().sum())
    # Search all subsets of the already selected 255-unit heads. Each subset
    # changes 255 to 15, while every other head retains its 4095-unit map.
    allowed = [i for i in range(16) if original_mask & (1 << i)]
    best = [(float('inf'), 0) for _ in range(len(allowed)+1)]
    best[0] = (float((base-reference).square().sum())/energy, 0)
    for mask in range(1, 1 << len(allowed)):
        indices = [allowed[j] for j in range(len(allowed)) if mask & (1 << j)]
        err = (float((base-reference).square().sum()) + linear[indices].sum()
               + gram[np.ix_(indices, indices)].sum()) / energy
        size = len(indices)
        if err < best[size][0]:
            best[size] = (max(0., float(err)), sum(1 << i for i in indices))
    del train, delta, gram, linear, base, reference
    held, held_n = replay(layer, 'validation', image, metadata, weights, decoder)
    held_ref = held[4095].sum(0)
    held_base = selected(held, original_mask, 255)
    points = []
    for size, (train_error, mask) in enumerate(best):
        candidate = held_base + sum((held[15][i]-held[255][i] for i in range(16) if mask & (1 << i)),
                                    torch.zeros_like(held_base))
        points.append({'one_digit_heads': size, 'one_digit_mask': f'{mask:04x}',
                       'train_error': train_error, 'held': score(held_ref, candidate)})
    size = max(i for i, point in enumerate(points) if point['train_error'] <= 1e-4)
    receipt = {'layer': layer, 'masses': [15, 255, 4095], 'original_255_mask': f'{original_mask:04x}',
               'train_selected_15': points[size], 'per_cardinality': points,
               'held_all_15': score(held_ref, held[15].sum(0)),
               'held_15_slots': slots(held_n),
               'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES/f'layer{layer:02d}.npz'),
               'factor_sha256': sha(image), 'cache_fit_sha256': sha(prior),
               'parent_receipt_sha256': sha(previous), 'source_sha256': sha(HERE),
               'domain': 'frozen original-producer Q/K and signed-nibble rank-28 V/O; eight train and four repeatedly inspected validation windows of 256 tokens. Exact subset search within heads assigned mass 255 by the parent; FP32 floating O replay.'}
    dest = DATA / 'value-nibble-one-digit' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'receipt': str(dest), 'selected': receipt['train_selected_15'],
                      'all_15': receipt['held_all_15'], 'slots': receipt['held_15_slots']}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
