#!/usr/bin/env python3
"""Revisit all frozen nibble-cache coordinates by cyclic full-response descent."""
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
DATA = Path('/path/to/workspace/data/kelana-subbit/value-nibble-joint-fit')
RATIOS = (.7, .85, 1., 1.15, 1.4)
LOWS = (-7,) * len(RATIOS) + (-8,) * len(RATIOS)


def responses(p, z, steps, lows):
    # [windows, head, query, coordinate, candidate]. Both heads share the signed code.
    codes = ((z[:, :, :, None] / steps).round().clamp(min=lows, max=torch.tensor(7.)) * steps).float()
    w, t, d, c = codes.shape
    return (p @ codes.reshape(w, t, d * c)[:, None]).reshape(w, 2, t, d, c)


def output(p, z, left, steps, lows):
    a = responses(p, z, steps[:, None], lows[:, None])[:, :, :, :, 0]
    return sum(a[:, h] @ left[h * 1024:(h + 1) * 1024].T for h in range(2))


def fit(layer, train_windows, held_windows):
    torch.set_num_threads(8)
    image_path = prior.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    cache_path = prior.DATA / f'layer{layer:02d}-8x4.json'
    frozen = json.loads(cache_path.read_text())
    parent_path = DATA.parent / 'value-nibble-code-fit' / f'layer{layer:02d}-{train_windows}x{held_windows}.json'
    parent = json.loads(parent_path.read_text())
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
    base_steps = [torch.tensor(parent['selected'][g]['steps']) for g in range(8)]
    base_lows = [torch.tensor(parent['selected'][g]['lows']) for g in range(8)]
    residual = -states['train'][2].clone()
    held_parent = -states['validation'][2].clone()
    held_all16 = -states['validation'][2].clone()
    held_fp8 = -states['validation'][2].clone()
    fp8_receipt = json.loads((DATA.parent / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())
    for g, (left, _) in enumerate(factors):
        for split, (_, p, _) in states.items():
            raw = output(p[:, 2*g:2*g+2], zs[split][g], left, base_steps[g], base_lows[g])
            if split == 'train':
                residual += raw
            else:
                held_parent += raw
                held_all16 += output(p[:, 2*g:2*g+2], zs[split][g], left, base_steps[g], torch.full((28,), -8.))
                scale = fp8_receipt['scales'][str(g)]['e4m3']
                fp8 = (zs[split][g] / scale).clamp(-448, 448).to(torch.float8_e4m3fn).float() * scale
                held_fp8 += sum((p[:, 2*g+h] @ fp8) @ left[h*1024:(h+1)*1024].T for h in range(2))
    chosen = [torch.tensor([2 if low == -7 else 7 for low in lows], dtype=torch.long) for lows in base_lows]
    trace = []
    train_before = float(residual.square().sum())
    candidate_steps = [(steps[:, None] * torch.tensor(RATIOS * 2)).to(torch.float16).float() for steps in base_steps]
    for sweep in range(3):
        changed = 0
        for g, (left, _) in enumerate(factors):
            p = states['train'][1][:, 2*g:2*g+2]
            a = responses(p, zs['train'][g], candidate_steps[g], torch.tensor(LOWS))
            for i in range(28):
                incumbent = int(chosen[g][i])
                da = a[:, :, :, i] - a[:, :, :, i, incumbent, None]
                l = torch.stack((left[:1024, i], left[1024:, i]))
                # E(R+D)-E(R), including all other coordinates and GQA groups.
                r_l = torch.stack([residual @ l[h] for h in range(2)], dim=1)
                cross = (l @ l.T).float()
                score = 2 * (r_l[..., None] * da).sum((0, 1, 2))
                score += torch.einsum('bhtc,hk,bktc->c', da, cross, da)
                score[incumbent] = 0
                j = int(score.argmin())
                gain = -float(score[j])
                if j != incumbent and gain > 1e-5:
                    chosen[g][i] = j
                    residual += da[:, 0, :, j, None] * l[0] + da[:, 1, :, j, None] * l[1]
                    changed += 1
                    trace.append({'sweep': sweep + 1, 'group': g, 'coordinate': i,
                                  'from': incumbent, 'to': j, 'gain': gain})
            print('fitted', layer, sweep + 1, g, flush=True)
        trace.append({'sweep': sweep + 1, 'changed': changed,
                      'train_relative': float(residual.square().sum() / states['train'][2].square().sum())})
        if not changed:
            break
    selected = [{'steps': candidate_steps[g][torch.arange(28), chosen[g]].tolist(),
                 'lows': [LOWS[j] for j in chosen[g].tolist()]} for g in range(8)]
    held_selected = -states['validation'][2].clone()
    for g, (left, _) in enumerate(factors):
        held_selected += output(states['validation'][1][:, 2*g:2*g+2], zs['validation'][g], left, torch.tensor(selected[g]['steps']), torch.tensor(selected[g]['lows']))
    scores = {'train': {'parent': train_before / float(states['train'][2].square().sum()),
                        'selected': float(residual.square().sum() / states['train'][2].square().sum())},
              'validation': {name: float(r.square().sum() / states['validation'][2].square().sum())
                             for name, r in (('parent', held_parent), ('all16', held_all16), ('selected', held_selected), ('e4m3', held_fp8))}}
    windows = {name: [float(r[i].square().sum() / states['validation'][2][i].square().sum()) for i in range(held_windows)]
               for name, r in (('parent', held_parent), ('all16', held_all16), ('selected', held_selected), ('e4m3', held_fp8))}
    receipt = {'layer': layer, 'train_windows': train_windows, 'held_windows': held_windows,
               'source_sha256': prior.digest(HERE), 'model_sha256': prior.digest(prior.MODEL),
               'capture_sha256': prior.digest(prior.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': prior.digest(image_path), 'frozen_cache_receipt_sha256': prior.digest(cache_path),
               'parent_receipt_sha256': prior.digest(parent_path), 'ratios': RATIOS, 'lows': LOWS,
               'selected': selected, 'trace': trace, 'scores': scores, 'held_windows_relative': windows,
               'contract': 'Frozen paid rank-28 V/O, original-producer hidden, floating causal probabilities. Three or fewer cyclic train-only coordinate passes over ten FP16 step/endpoint candidates centered on the preceding one-pass image. Complete two-head post-O squared error. No joint global optimality, integer mass, or native rounding claim.',
               'cost': 'Same 112 logical/128 padded V-cache bytes and 448 FP16 step bytes/layer; 224 producer divisions/round/clamps and 448 nibble accumulations/key. Per-coordinate endpoint mask costs 28 bytes/layer if stored literally. Extra fitting is offline.'}
    DATA.mkdir(parents=True, exist_ok=True)
    path = DATA / f'layer{layer:02d}-{train_windows}x{held_windows}.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'scores': scores, 'changed': len([x for x in trace if 'group' in x])}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--train-windows', type=int, default=8)
    parser.add_argument('--held-windows', type=int, default=4)
    args = parser.parse_args()
    fit(args.layer, args.train_windows, args.held_windows)
