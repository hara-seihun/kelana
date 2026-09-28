#!/usr/bin/env python3
"""Fit signed-nibble value-cache steps against the full causal two-head O response."""
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
spec = importlib.util.spec_from_file_location('frozen_cache', ROOT / 'value-centered-int4/measure.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
DATA = Path('/path/to/workspace/data/kelana-subbit/value-nibble-response-step')
RATIOS = (.5, .7, .85, 1., 1.15, 1.4, 1.8, 2.4)


def responses(p, z, steps):
    # [windows, head, query, coordinate, candidate]. Both heads see the same cache.
    codes = ((z[:, :, :, None] / steps).round().clamp(-7, 7) * steps).float()
    w, t, d, c = codes.shape
    return (p @ codes.reshape(w, t, d * c)[:, None]).reshape(w, 2, t, d, c)


def output(p, z, left, steps):
    a = responses(p, z, steps[:, None])[:, :, :, :, 0]
    return sum(a[:, h] @ left[h * 1024:(h + 1) * 1024].T for h in range(2))


def fit(layer, train_windows, held_windows):
    torch.set_num_threads(8)
    image_path = prior.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    cache_path = prior.DATA / f'layer{layer:02d}-8x4.json'
    frozen = json.loads(cache_path.read_text())
    assert prior.digest(image_path) == frozen['image_sha256']
    spec = importlib.util.spec_from_file_location('factor_decode', prior.SOURCE)
    dec = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dec)
    with np.load(image_path) as image:
        factors = [(dec.decode({k: image[k][g].copy() for k in image.files}, 'left'),
                    dec.decode({k: image[k][g].copy() for k in image.files}, 'right')) for g in range(8)]
    with safe_open(prior.MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'q_norm', 'k_norm', 'v_proj', 'o_proj')}
    states = {}
    for split, n in (('train', train_windows), ('validation', held_windows)):
        x = prior.load_capture(layer, split).reshape(-1, 256, 1024)[:n]
        p = prior.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        teacher = prior.dense_attention(p, x, w['v_proj'], w['o_proj'])
        states[split] = (x, p, teacher)
        print('prepared', layer, split, flush=True)
    zs = {s: [(x @ right.T).to(torch.bfloat16).float() for _, right in factors]
          for s, (x, _, _) in states.items()}
    base_steps = [torch.tensor(frozen['metadata'][g]['int4_coordinate']['step']) for g in range(8)]
    residual = -states['train'][2].clone()
    held_raw = -states['validation'][2].clone()
    held_fp8 = -states['validation'][2].clone()
    fp8_receipt = json.loads((DATA.parent / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())
    for g, (left, _) in enumerate(factors):
        for split, (_, p, _) in states.items():
            raw = output(p[:, 2*g:2*g+2], zs[split][g], left, base_steps[g])
            if split == 'train':
                residual += raw
            else:
                held_raw += raw
                scale = fp8_receipt['scales'][str(g)]['e4m3']
                fp8 = (zs[split][g] / scale).clamp(-448, 448).to(torch.float8_e4m3fn).float() * scale
                held_fp8 += sum((p[:, 2*g+h] @ fp8) @ left[h*1024:(h+1)*1024].T for h in range(2))
    selected = []
    trace = []
    train_before = float(residual.square().sum())
    for g, (left, _) in enumerate(factors):
        _, p, _ = states['train']
        candidates = (base_steps[g][:, None] * torch.tensor(RATIOS)).to(torch.float16).float()
        a = responses(p[:, 2*g:2*g+2], zs['train'][g], candidates)
        base = a[..., 3:4]
        steps = base_steps[g].clone()
        for i in range(28):
            da = a[:, :, :, i] - base[:, :, :, i]
            l = torch.stack((left[:1024, i], left[1024:, i]))
            # E(R + D) - E(R) = 2<R,D> + ||D||^2; includes all other groups.
            r_l = torch.stack([residual @ l[h] for h in range(2)], dim=1)
            cross = (l @ l.T).float()
            score = 2 * (r_l[..., None] * da).sum((0, 1, 2))
            score += torch.einsum('bhtc,hk,bktc->c', da, cross, da)
            j = int(score.argmin())
            gain = -float(score[j])
            if gain > 0:
                steps[i] = candidates[i, j]
                residual += da[:, 0, :, j, None] * l[0] + da[:, 1, :, j, None] * l[1]
            trace.append({'group': g, 'coordinate': i, 'ratio': RATIOS[j] if gain > 0 else 1., 'gain': max(0., gain)})
        selected.append(steps.tolist())
        print('fitted', layer, g, flush=True)
    held_selected = -states['validation'][2].clone()
    for g, (left, _) in enumerate(factors):
        held_selected += output(states['validation'][1][:, 2*g:2*g+2], zs['validation'][g], left, torch.tensor(selected[g]))
    scores = {'train': {'raw': train_before / float(states['train'][2].square().sum()),
                        'selected': prior.relative(residual + states['train'][2], states['train'][2])},
              'validation': {name: float(r.square().sum() / states['validation'][2].square().sum())
                             for name, r in (('raw', held_raw), ('selected', held_selected), ('e4m3', held_fp8))}}
    windows = {name: [float(r[i].square().sum() / states['validation'][2][i].square().sum()) for i in range(held_windows)]
               for name, r in (('raw', held_raw), ('selected', held_selected), ('e4m3', held_fp8))}
    receipt = {'layer': layer, 'train_windows': train_windows, 'held_windows': held_windows,
               'source_sha256': prior.digest(HERE), 'model_sha256': prior.digest(prior.MODEL),
               'capture_sha256': prior.digest(prior.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': prior.digest(image_path), 'frozen_cache_receipt_sha256': prior.digest(cache_path),
               'ratios': RATIOS, 'selected_steps': selected, 'trace': trace, 'scores': scores, 'held_windows_relative': windows,
               'contract': 'Frozen paid rank-28 V/O, original-producer captured hidden states, floating causal probabilities, one pass of train-only coordinate step choices minimizing whole two-head post-O teacher squared error. FP16 steps, signed nibble codes, raw zero center. Not integer probability or BF16-bit-identical native execution.',
               'cost': 'Same 112 logical/128 padded V-cache bytes, 448 FP16 step bytes/layer, 224 producer divisions/round/clamps and 448 nibble accumulations per key across heads as raw control. No extra online work or weight BPW; offline fitting only.'}
    DATA.mkdir(parents=True, exist_ok=True)
    path = DATA / f'layer{layer:02d}-{train_windows}x{held_windows}.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'scores': scores, 'changed': sum(x['ratio'] != 1 for x in trace)}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--train-windows', type=int, default=8)
    parser.add_argument('--held-windows', type=int, default=4)
    args = parser.parse_args()
    fit(args.layer, args.train_windows, args.held_windows)
