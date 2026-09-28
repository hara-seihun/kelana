#!/usr/bin/env python3
"""Compress learned coordinate palettes to one signed-byte shape per GQA group."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('lut', SUBBIT / 'value-nibble-lut/measure.py')
lut = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lut)
cache = lut.cache
DATA = Path('/path/to/workspace/data/kelana-subbit/value-shared-palette')
PARENT = DATA.parent / 'value-nibble-lut'


def shared_palette(centers, group_size):
    """Best unconstrained rank-one group template, then byte/FP16 realization."""
    tables = []
    steps = []
    continuous = []
    for group in centers.reshape(224 // group_size, group_size, 16).double():
        u, s, vh = torch.linalg.svd(group, full_matrices=False)
        shape = vh[0] * (127 / vh[0].abs().max())
        if shape[-1] < shape[0]:
            shape = -shape
        shape = shape.round().clamp(-127, 127).to(torch.int8)
        # Solve each coordinate's step after rounding the shared table.
        real_shape = shape.double()
        step = ((group @ real_shape) / (real_shape @ real_shape)).clamp_min(1e-9)
        steps.append(step.half())
        tables.append(shape)
        continuous.append(float(s[0]**2 / (s*s).sum()))
    return torch.stack(tables), torch.cat(steps), continuous


def quantized(raw, tables, steps, group_size):
    levels = tables.repeat_interleave(group_size, dim=0)
    return lut.code_values(raw, levels, steps.float())


def run(layer, group_size):
    torch.set_num_threads(8)
    DATA.mkdir(parents=True, exist_ok=True)
    source = PARENT / f'layer{layer:02d}-levels.npz'
    with np.load(source) as a:
        original = torch.from_numpy(a['levels'].copy()).float() * torch.from_numpy(a['steps'].copy()).float()[:, None]
        original_levels = torch.from_numpy(a['levels'].copy())
        original_steps = torch.from_numpy(a['steps'].copy()).float()
    tables, steps, explained = shared_palette(original, group_size)
    palette_path = DATA / f'layer{layer:02d}-palette-g{group_size}.npz'
    np.savez(palette_path, tables=tables.numpy(), steps=steps.numpy())
    factor_path = cache.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    decoder = importlib.util.spec_from_file_location('factor_decode', cache.SOURCE)
    dec = importlib.util.module_from_spec(decoder)
    decoder.loader.exec_module(dec)
    with np.load(factor_path) as archive:
        factors = [(dec.decode({k: archive[k][g].copy() for k in archive.files}, 'left'),
                    dec.decode({k: archive[k][g].copy() for k in archive.files}, 'right')) for g in range(8)]
    paid_path = PARENT / f'layer{layer:02d}-lut-left.npz'
    with np.load(paid_path) as a:
        paid = torch.cat([dec.decode({k: a[k][g].copy() for k in a.files}, 'left')
                          [h*1024:(h+1)*1024].T for g in range(8) for h in range(2)])
    with safe_open(cache.MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'q_norm', 'k_norm', 'v_proj', 'o_proj')}
    results = {}
    for split, count in (('train', 8), ('validation', 4)):
        x = cache.load_capture(layer, split).reshape(-1, 256, 1024)[:count]
        p = cache.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        y = cache.dense_attention(p, x, w['v_proj'], w['o_proj']).reshape(-1, 1024)
        v = lut.narrow_values(x, factors)
        features = {arm: lut.features(qv(v), p) for arm, qv in (
            ('coordinate', lambda v: lut.code_values(v, original_levels, original_steps)),
            ('shared', lambda v: quantized(v, tables, steps, group_size)))}
        results[split] = (y, features)
        print('prepared', split, flush=True)
    scores = {}
    for arm in ('coordinate', 'shared'):
        y, z = results['train'][0], results['train'][1][arm]
        held_y, held_z = results['validation'][0], results['validation'][1][arm]
        penalties = (1e-4, 1e-3, 1e-2, .1, 1., 10.)
        candidates = [lut.baseline.solve(z[:1024], y[:1024], lam) for lam in penalties]
        selection = [lut.baseline.relative(z[1024:], y[1024:], c) for c in candidates]
        lam = penalties[int(np.argmin(selection))]
        fit = lut.baseline.solve(z, y, lam)
        images = []
        with np.load(factor_path) as a:
            for g in range(8):
                group = {k: a[k][g].copy() for k in a.files}
                group.update(dec.quantize(torch.cat([fit[g*56+h*28:g*56+(h+1)*28].T
                    for h in range(2)]).contiguous(), 2, 128, 'left'))
                images.append(group)
        coeff = lut.baseline.fit_codes(images, dec, z, y, 2)
        out = DATA / f'layer{layer:02d}-{arm}-g{group_size}-left.npz'
        np.savez(out, **{k: np.stack([im[k] for im in images]) for k in images[0]})
        scores[arm] = {'ridge': lam, 'selection': selection,
                       'train': lut.baseline.relative(z, y, coeff),
                       'held': lut.baseline.relative(held_z, held_y, coeff),
                       'held_windows': lut.window_errors(held_z, held_y, coeff),
                       'image_sha256': cache.digest(out),
                       'fixed_parent_O_held': lut.baseline.relative(held_z, held_y, paid)}
        print(arm, scores[arm]['held'], flush=True)
    receipt = {'layer': layer, 'group_size': group_size, 'scores': scores, 'unconstrained_group_table_energy_fraction': explained,
               'palette_sha256': cache.digest(palette_path), 'source_sha256': cache.digest(HERE),
               'parent_levels_sha256': cache.digest(source), 'parent_paid_O_sha256': cache.digest(paid_path),
               'model_sha256': cache.digest(cache.MODEL),
               'capture_sha256': cache.digest(cache.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': cache.digest(factor_path),
               'contract': 'Original-producer eight train/four repeatedly inspected validation windows. Frozen right factor. Rank-one real SVD of consecutive group_size x16 tables within GQA groups, rounded shared signed-byte palette and per-coordinate positive FP16 step; nearest-label assignment. Each arm receives the same ridge selection and two paid O code sweeps. Floating probabilities, no native or full-model result.'}
    output = DATA / f'layer{layer:02d}-g{group_size}-8x4.json'
    output.write_text(json.dumps(receipt, indent=2) + '\n')
    print(output, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--group-size', type=int, choices=(2, 4, 7, 14, 28), default=28)
    args = parser.parse_args()
    run(args.layer, args.group_size)
