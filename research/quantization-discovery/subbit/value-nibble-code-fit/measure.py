#!/usr/bin/env python3
"""Fit the unused negative nibble endpoint against full post-O response."""
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
DATA = Path('/path/to/workspace/data/kelana-subbit/value-nibble-code-fit')
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
    parent_path = DATA.parent / 'value-nibble-response-step' / f'layer{layer:02d}-{train_windows}x{held_windows}.json'
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
    base_steps = [torch.tensor(parent['selected_steps'][g]) for g in range(8)]
    base_lows = [torch.full((28,), -7.) for _ in range(8)]
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
    selected = []
    trace = []
    train_before = float(residual.square().sum())
    for g, (left, _) in enumerate(factors):
        _, p, _ = states['train']
        ratios = torch.tensor(RATIOS * 2)
        candidates = (base_steps[g][:, None] * ratios).to(torch.float16).float()
        a = responses(p[:, 2*g:2*g+2], zs['train'][g], candidates, torch.tensor(LOWS))
        base = a[..., 2:3]
        steps = base_steps[g].clone()
        lows = base_lows[g].clone()
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
                lows[i] = LOWS[j]
                residual += da[:, 0, :, j, None] * l[0] + da[:, 1, :, j, None] * l[1]
            trace.append({'group': g, 'coordinate': i, 'ratio': float(ratios[j]) if gain > 0 else 1., 'low': LOWS[j] if gain > 0 else -7, 'gain': max(0., gain)})
        selected.append({'steps': steps.tolist(), 'lows': lows.tolist()})
        print('fitted', layer, g, flush=True)
    held_selected = -states['validation'][2].clone()
    for g, (left, _) in enumerate(factors):
        held_selected += output(states['validation'][1][:, 2*g:2*g+2], zs['validation'][g], left, torch.tensor(selected[g]['steps']), torch.tensor(selected[g]['lows']))
    scores = {'train': {'parent': train_before / float(states['train'][2].square().sum()),
                        'selected': prior.relative(residual + states['train'][2], states['train'][2])},
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
               'contract': 'Frozen paid rank-28 V/O, original-producer hidden, floating causal probabilities, one pass train-only coordinate step and signed-nibble endpoint choices on complete two-head post-O squared error. Relative to preceding response-fitted image. Not integer probability or native rounding.',
               'cost': '112 logical/128 padded V-cache bytes and 448 FP16 step bytes/layer; 224 producer divisions/round/clamps and 448 nibble accumulations/key. New per-coordinate endpoint mask costs 28 bytes/layer if stored literally. The signed-byte direct consumer accepts -8 without an extra dot.'}
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
