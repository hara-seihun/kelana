#!/usr/bin/env python3
"""Train-window minimax allocation for frozen narrow values at exactly 192 coordinates."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from causal_prune import OUT, candidates, removed_indices, moments, pack_image, sha
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention


def window_scores(moment, masks):
    gram, linear, baseline, energy = moment[:4]
    drop = masks.astype(np.float64)
    return (baseline - 2 * (drop @ linear) + np.sum((drop @ gram) * drop, axis=1)) / energy


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--threads', type=int, default=8)
    args = parser.parse_args()
    torch.set_num_threads(args.threads)
    spec = importlib.util.spec_from_file_location('spectral_quant_pinned', SOURCE)
    q = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(q)
    image = OUT / f'layer{args.layer:02d}-joint-r28.npz'
    with np.load(image) as data:
        src = {key: data[key].copy() for key in data.files}
    factors = []
    for g in range(8):
        group = {key: val[g] for key, val in src.items()}
        factors.append((q.decode(group, 'left'), q.decode(group, 'right')))
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {n: model.get_tensor(f'model.layers.{args.layer}.self_attn.{n}.weight').float()
             for n in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    choices = list(candidates())
    masks = np.zeros((len(choices), 56), np.uint8)
    for i, choice in enumerate(choices):
        masks[i, removed_indices(choice)] = 1
    scores, energies = {}, {}
    for split, count in (('train', 8), ('validation', 4)):
        x = load_capture(args.layer, split).reshape(count, 256, 1024)
        prob = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        teacher = dense_attention(prob, x, w['v_proj'], w['o_proj'])
        _, _, _, _, c, y = moments(x, prob, teacher, factors)
        c = c.reshape(56, count, -1)
        y = y.reshape(count, -1)
        parts = []
        norms = []
        for k in range(count):
            ck, yk = c[:, k].double(), y[k].double()
            residual = ck.sum(0) - yk
            energy = yk.square().sum().item()
            gram = (ck @ ck.T).numpy()
            linear = (ck @ residual).numpy()
            baseline = residual.square().sum().item()
            parts.append(window_scores((gram, linear, baseline, energy), masks))
            norms.append(energy)
        scores[split] = np.stack(parts, axis=1)
        energies[split] = np.array(norms)
        print(f'{split} moments ready', flush=True)
    train = scores['train']
    weighted = (train * energies['train']).sum(1) / energies['train'].sum()
    held = scores['validation']
    held_weighted = (held * energies['validation']).sum(1) / energies['validation'].sum()
    names = {'mean': np.argmin(weighted), 'minimax': np.argmin(train.max(1))}
    for weight in (.25, .5, 1., 2.):
        names[f'mean_plus_{weight:g}_tail'] = np.argmin(weighted + weight * train.max(1))
    names['uniform'] = choices.index((1,) * 8)
    result = {'layer': args.layer, 'source_sha256': sha(Path(__file__)),
              'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{args.layer:02d}.npz'),
              'source_image_sha256': sha(image), 'choices': len(choices),
              'grammar': 'frozen two-bit rank-28 image, suffix blocks of four, eight GQA groups and exactly 192 retained coordinates; original-producer Q/K causal post-O FP32 response',
              'selection': 'training windows only; mean weights teacher squared norms, tail is worst per-window relative squared post-O error',
              'arms': {}}
    for name, i in names.items():
        i = int(i)
        result['arms'][name] = {'ranks': [28-4*n for n in choices[i]],
                               'train_mean': float(weighted[i]), 'train_worst': float(train[i].max()),
                               'held_mean': float(held_weighted[i]), 'held_worst': float(held[i].max()),
                               'train_windows': train[i].tolist(), 'held_windows': held[i].tolist()}
    result['held_only_mean_oracle'] = float(held_weighted.min())
    result['held_only_worst_oracle'] = float(held.max(1).min())
    path = OUT / f'layer{args.layer:02d}-robust-allocation.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'arms': {k: {v: r[v] for v in ('ranks','train_mean','train_worst','held_mean','held_worst')} for k, r in result['arms'].items()}}), flush=True)


if __name__ == '__main__':
    main()
