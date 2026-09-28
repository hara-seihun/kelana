#!/usr/bin/env python3
"""Train-post-O selection among already paid raw and centered nibble cache coordinates."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'value-observer'))
spec = importlib.util.spec_from_file_location('centered_cache', ROOT / 'value-centered-int4/measure.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
DATA = Path('/path/to/workspace/data/kelana-subbit/value-cache-post-o-select')


def projected(p, z, left, group):
    return sum((p[:, 2 * group + h] @ z) @ left[h * 1024:(h + 1) * 1024].T for h in range(2))


def contributions(p, diff, left, group):
    # Each candidate changes one shared cached coordinate observed by both heads.
    a = [p[:, 2 * group + h] @ diff for h in range(2)]
    return (a[0].movedim(-1, 0).unsqueeze(-1) * left[:1024].T[:, None, None, :] +
            a[1].movedim(-1, 0).unsqueeze(-1) * left[1024:].T[:, None, None, :])


def build(layer, train_windows, held_windows):
    torch.set_num_threads(8)
    image_path = prior.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    metadata_path = prior.DATA / f'layer{layer:02d}-8x4.json'
    metadata = json.loads(metadata_path.read_text())
    assert prior.digest(image_path) == metadata['image_sha256']
    spec = importlib.util.spec_from_file_location('paid_factor_decode', prior.SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(image_path) as image:
        factors = [(decoder.decode({name: image[name][g].copy() for name in image.files}, 'left'),
                    decoder.decode({name: image[name][g].copy() for name in image.files}, 'right')) for g in range(8)]
    with safe_open(prior.MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'q_norm', 'k_norm', 'v_proj', 'o_proj')}
    states = {}
    for split, n in [('train', train_windows), ('validation', held_windows)]:
        x = prior.load_capture(layer, split).reshape(-1, 256, 1024)[:n]
        p = prior.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        teacher = prior.dense_attention(p, x, w['v_proj'], w['o_proj'])
        states[split] = (x, p, teacher)
        print('prepared', layer, split, flush=True)
    outputs = {s: {arm: torch.zeros_like(v[2]) for arm in ('raw', 'adaptive', 'fp8')} for s, v in states.items()}
    differences = {}
    for split, (x, p, _) in states.items():
        differences[split] = []
        for g, (left, right) in enumerate(factors):
            z = (x @ right.T).to(torch.bfloat16).float()
            options = {}
            for arm in ('int4_coordinate', 'int4_centered', 'int4_adaptive_center'):
                entry = metadata['metadata'][g][arm]
                c, step = torch.tensor(entry['center']), torch.tensor(entry['step'])
                options[arm] = prior.decode(z, c, step)
            fp8_receipt = json.loads((DATA.parent / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())
            scale = fp8_receipt['scales'][str(g)]['e4m3']
            fp8 = (z / scale).clamp(-448, 448).to(torch.float8_e4m3fn).float() * scale
            for name, codes in [('raw', options['int4_coordinate']),
                                ('adaptive', options['int4_adaptive_center']), ('fp8', fp8)]:
                outputs[split][name] += projected(p, codes, left, g)
            differences[split].append(options['int4_centered'] - options['int4_coordinate'])
            print('cached', layer, split, g, flush=True)
    # Hold only one group's response candidates at a time. Each greedy choice is
    # evaluated against the *complete* post-O residual, including both heads.
    residual = outputs['train']['raw'] - states['train'][2]
    selected = []
    trace = []
    for g, (left, _) in enumerate(factors):
        delta = contributions(states['train'][1], differences['train'][g], left, g)
        choices = []
        for c in range(delta.shape[0]):
            d = delta[c]
            improvement = -float(2 * (residual * d).sum() + d.square().sum())
            take = improvement > 0
            choices.append(take)
            if take:
                residual += d
            trace.append({'group': g, 'coordinate': c, 'take_centered': take, 'train_squared_error_reduction': improvement})
        selected.append(choices)
        del delta
    scores = {}
    for split, (_, p, teacher) in states.items():
        out = outputs[split]['raw'].clone()
        if split == 'train':
            out = residual + teacher
        else:
            for g, (left, _) in enumerate(factors):
                coords = [i for i, chosen in enumerate(selected[g]) if chosen]
                if coords:
                    d = contributions(p, differences[split][g][:, :, coords], left[:, coords], g)
                    out += d.sum(0)
        scores[split] = {arm: {'relative_teacher_error': prior.relative(y, teacher),
                               'per_window': [prior.relative(y[i], teacher[i]) for i in range(len(y))]}
                         for arm, y in {**outputs[split], 'post_o_select': out}.items()}
    receipt = {'layer': layer, 'train_windows': train_windows, 'held_windows': held_windows,
               'source_sha256': prior.digest(HERE), 'model_sha256': prior.digest(prior.MODEL),
               'capture_sha256': prior.digest(prior.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': prior.digest(image_path), 'frozen_cache_receipt_sha256': prior.digest(metadata_path),
               'domain': 'Original-producer 256-token train and repeatedly inspected validation windows; frozen paid rank-28 V/O and frozen nibble fits',
               'selection': 'One deterministic coordinate-descent pass in group/coordinate order, toggling raw to centered only if complete train post-O squared error falls; fixed codes and FP16 metadata, same signed-nibble cache and integer direct consumer',
               'selected_centers': selected, 'trace': trace, 'scores': scores,
               'cost_contract': '112 logical/128 padded value-cache bytes per token/layer and 896 FP16 center/step metadata bytes/layer unchanged; offline selector adds no producer or attention work. Integer mass and native latency not measured; response replay uses floating causal probabilities.'}
    DATA.mkdir(parents=True, exist_ok=True)
    path = DATA / f'layer{layer:02d}-{train_windows}x{held_windows}.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'selected': sum(map(sum, selected)),
                      'scores': {s: {a: v['relative_teacher_error'] for a, v in arms.items()} for s, arms in scores.items()}}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--train-windows', type=int, default=8)
    parser.add_argument('--held-windows', type=int, default=4)
    args = parser.parse_args()
    build(args.layer, args.train_windows, args.held_windows)
