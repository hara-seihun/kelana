#!/usr/bin/env python3
"""Fit frozen four-coordinate shared V/O blocks through the causal post-O consumer."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
VO = HERE.parent / 'value-observer'
sys.path.insert(0, str(VO))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention
from causal_prune import OUT, sha


def responses(x, p, teacher, factors):
    blocks = []
    for g, (left, right) in enumerate(factors):
        z = (x @ right.T).to(torch.bfloat16).float()
        for b in range(7):
            piece = torch.zeros_like(teacher)
            for h in range(2):
                value = p[:, 2*g+h] @ z[:, :, b*4:b*4+4]
                piece += value @ left[h*1024:(h+1)*1024, b*4:b*4+4].T
            blocks.append(piece.reshape(-1))
    return torch.stack(blocks).double()


def fit(blocks, target, ridge):
    gram = blocks @ blocks.T
    residual = blocks @ (target.flatten().double() - blocks.sum(0))
    penalty = torch.diag(gram).clamp_min(1) * ridge
    delta = torch.linalg.solve(gram + torch.diag(penalty), residual)
    return (delta + 1).clamp_min(0)


def error(blocks, target, gains):
    return float(((gains @ blocks - target.flatten()).square().sum() / target.square().sum()).item())


def main(layer):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('spectral_quant_pinned', SOURCE)
    quant = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quant)
    source = OUT / f'layer{layer:02d}-joint-r28.npz'
    with np.load(source) as data:
        image = {name: data[name].copy() for name in data.files}
    factors = [(quant.decode({name: val[g] for name, val in image.items()}, 'left'),
                quant.decode({name: val[g] for name, val in image.items()}, 'right')) for g in range(8)]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {n: model.get_tensor(f'model.layers.{layer}.self_attn.{n}.weight').float()
             for n in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    states = {}
    for split, count in [('train', 8), ('validation', 4)]:
        x = load_capture(layer, split).reshape(count, 256, 1024)
        p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        teacher = dense_attention(p, x, w['v_proj'], w['o_proj'])
        blocks = responses(x, p, teacher, factors)
        states[split] = (blocks, teacher.double(), x, p)
    train, target, _, _ = states['train']
    train_windows = train.reshape(56, 8, -1)
    target_windows = target.reshape(8, -1)
    choices = [0., .0001, .001, .01, .1, 1., 10.]
    cv = {}
    for ridge in choices:
        errors = []
        for held in range(8):
            keep = [i for i in range(8) if i != held]
            a = train_windows[:, keep].reshape(56, -1)
            b = target_windows[keep].reshape(-1)
            gains = fit(a, b, ridge)
            errors.append(error(train_windows[:, held], target_windows[held], gains))
        cv[str(ridge)] = float(np.mean(errors))
    selected = min(choices, key=lambda v: (cv[str(v)], v))
    gains = fit(train, target, selected)
    ones = torch.ones(56, dtype=torch.double)
    held_fit = fit(states['validation'][0], states['validation'][1], 0)
    scores = {name: {split: error(state[0], state[1].double(), vector)
                     for split, state in states.items()}
              for name, vector in [('base', ones), ('unregularized', fit(train, target, 0)),
                                   ('selected', gains), ('held_oracle', held_fit)]}
    for g in range(8):
        for b in range(7):
            image['right_scales'][g, 4*b:4*b+4] = (
                image['right_scales'][g, 4*b:4*b+4].astype(np.float32) * gains[g*7+b].item()
            ).astype(np.float16)
    output = OUT / f'layer{layer:02d}-value-softmax-rank.npz'
    np.savez(output, **image)
    paid = [(quant.decode({name: val[g] for name, val in image.items()}, 'left'),
             quant.decode({name: val[g] for name, val in image.items()}, 'right')) for g in range(8)]
    held_blocks = responses(states['validation'][2], states['validation'][3], states['validation'][1], paid)
    paid_score = error(held_blocks, states['validation'][1], ones)
    result = {'layer': layer, 'grammar': '56 nonnegative gains on frozen four-coordinate V/O blocks; fold into existing FP16 right scales, BF16 narrow value cache',
              'train_windows': 8, 'held_windows': 4, 'ridge_candidates': cv, 'selected_ridge': selected,
              'scores': scores, 'paid_held': paid_score, 'gains': gains.tolist(),
              'held_oracle_gain_range': [float(held_fit.min()), float(held_fit.max())],
              'train_unregularized_gain_range': [float(fit(train, target, 0).min()), float(fit(train, target, 0).max())],
              'held_by_window_base': [error(states['validation'][0][:, i*256*1024:(i+1)*256*1024], states['validation'][1][i], ones) for i in range(4)],
              'held_by_window_paid': [error(held_blocks[:, i*256*1024:(i+1)*256*1024], states['validation'][1][i], ones) for i in range(4)],
              'bytes': sum(x.nbytes for x in image.values()), 'source_sha256': sha(Path(__file__)),
              'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
              'parent_sha256': sha(source), 'image_sha256': sha(output)}
    receipt = OUT / f'layer{layer:02d}-value-softmax-rank.json'
    receipt.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(receipt), 'cv': cv, 'scores': scores, 'paid_held': paid_score}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=[0, 14], required=True)
    main(parser.parse_args().layer)
