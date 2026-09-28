#!/usr/bin/env python3
"""Train-static nibble value cache on a frozen paid shared V/O image (CPU)."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
SUBBIT = HERE.parent
sys.path.insert(0, str(SUBBIT / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention

IMAGE = Path('/path/to/workspace/data/kelana-subbit/value-observer')
DATA = Path('/path/to/workspace/data/kelana-subbit/value-centered-int4')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def relative(y, t):
    return float(((y - t).square().sum() / t.square().sum()).item())


def fit(z, centered, coordinate):
    # A shared center per coordinate is invisible to real attention once moved to O.
    center = z.mean(dim=(0, 1)) if centered else torch.zeros(z.shape[-1])
    residual = z - center
    if coordinate:
        p = torch.quantile(residual.abs().reshape(-1, z.shape[-1]),
                           torch.tensor([.9, .99, 1.]), dim=0)
    else:
        p = torch.quantile(residual.abs().flatten(), torch.tensor([.9, .99, 1.]))[:, None]
    steps = (p[:, None] * torch.tensor([.5, 1., 2., 4.])[None, :, None] / 7).reshape(12, -1).clamp_min(1e-8)
    a = residual.reshape(-1, z.shape[-1])
    if not coordinate:
        a = a.flatten()[:, None]
    err = ((a[None, :, :] / steps[:, None, :]).round().clamp(-7, 7) * steps[:, None, :] - a[None, :, :]).square().mean(dim=1)
    chosen = err.argmin(dim=0)
    step = steps[chosen, torch.arange(steps.shape[-1])]
    if not coordinate:
        step = step.expand(z.shape[-1])
    # Half-precision metadata is charged in the image; replay the rounded constants.
    return center.to(torch.float16).float(), step.to(torch.float16).float()


def decode(z, center, step):
    code = ((z - center) / step).round().clamp(-7, 7).to(torch.int8)
    return code.float() * step + center


def run(layer, train_windows, held_windows):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('paid_factor_decode', SOURCE)
    quant = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quant)
    image_path = IMAGE / f'layer{layer:02d}-joint-r28.npz'
    with np.load(image_path) as source:
        image = {name: source[name].copy() for name in source.files}
    factors = [(quant.decode({name: val[g] for name, val in image.items()}, 'left'),
                quant.decode({name: val[g] for name, val in image.items()}, 'right')) for g in range(8)]
    with safe_open(MODEL, framework='pt', device='cpu') as source:
        w = {name: source.get_tensor(f'model.layers.{layer}.self_attn.{name}.weight').float()
             for name in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    states = {}
    for split, count in [('train', train_windows), ('validation', held_windows)]:
        x = load_capture(layer, split).reshape(-1, 256, 1024)[:count]
        p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        teacher = dense_attention(p, x, w['v_proj'], w['o_proj'])
        states[split] = (x, p, teacher)
    arms = ('bf16', 'e4m3', 'int4_group', 'int4_coordinate', 'int4_centered', 'int4_adaptive_center')
    outputs = {split: {arm: torch.zeros_like(s[2]) for arm in arms} for split, s in states.items()}
    metadata = []
    fp8_receipt = json.loads((Path('/path/to/workspace/data/kelana-subbit/value-fp8-cache') / f'layer{layer:02d}.json').read_text())
    for g, (left, right) in enumerate(factors):
        train_z = (states['train'][0] @ right.T).to(torch.bfloat16).float()
        fits = {'int4_group': fit(train_z, False, False),
                'int4_coordinate': fit(train_z, False, True),
                'int4_centered': fit(train_z, True, True)}
        raw_center, raw_step = fits['int4_coordinate']
        mean_center, mean_step = fits['int4_centered']
        raw_mse = (decode(train_z, raw_center, raw_step) - train_z).square().mean((0, 1))
        mean_mse = (decode(train_z, mean_center, mean_step) - train_z).square().mean((0, 1))
        use_mean = mean_mse < raw_mse
        fits['int4_adaptive_center'] = (torch.where(use_mean, mean_center, raw_center),
                                         torch.where(use_mean, mean_step, raw_step))
        metadata.append({arm: {'center': c.tolist(), 'step': step.tolist()} for arm, (c, step) in fits.items()})
        for split, (x, p, _) in states.items():
            z = train_z if split == 'train' else (x @ right.T).to(torch.bfloat16).float()
            fp8_scale = fp8_receipt['scales'][str(g)]['e4m3']
            caches = {'bf16': z,
                      'e4m3': (z / fp8_scale).clamp(-448, 448).to(torch.float8_e4m3fn).float() * fp8_scale}
            for arm, (center, step) in fits.items():
                caches[arm] = decode(z, center, step)
            for h in range(2):
                l = left[h * 1024:(h + 1) * 1024]
                for arm in arms:
                    outputs[split][arm] += (p[:, 2*g+h] @ caches[arm]) @ l.T
        print(f'group {g} complete', flush=True)
    scores = {split: {arm: {'aggregate': relative(y, state[2]),
                             'per_window': [relative(y[i], state[2][i]) for i in range(y.shape[0])],
                             'against_bf16': relative(y, outputs[split]['bf16'])}
                      for arm, y in outputs[split].items()} for split, state in states.items()}
    result = {'layer': layer, 'train_windows': train_windows, 'held_windows': held_windows,
              'image_sha256': digest(image_path), 'capture_sha256': digest(CAPTURES / f'layer{layer:02d}.npz'),
              'model_sha256': digest(MODEL), 'source_sha256': digest(Path(__file__)),
              'fp8_receipt_sha256': digest(Path('/path/to/workspace/data/kelana-subbit/value-fp8-cache') / f'layer{layer:02d}.json'),
              'metadata': metadata, 'scores': scores,
              'selection': 'train coordinate MSE among 12 signed-int4 step candidates; centers are BF16-narrow train means rounded to FP16; adaptive chooses raw or mean per coordinate on train MSE',
              'packed_value_bytes_per_token_layer': 112, 'padded_value_bytes_per_token_layer': 128,
              'centered_metadata_bytes_per_layer': 896}
    DATA.mkdir(parents=True, exist_ok=True)
    path = DATA / f'layer{layer:02d}-{train_windows}x{held_windows}.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'held': {k: v['aggregate'] for k, v in scores['validation'].items()}}), flush=True)


if __name__ == '__main__':
    a = argparse.ArgumentParser()
    a.add_argument('--layer', type=int, choices=(0, 14), required=True)
    a.add_argument('--train-windows', type=int, default=8)
    a.add_argument('--held-windows', type=int, default=4)
    args = a.parse_args()
    run(args.layer, args.train_windows, args.held_windows)
