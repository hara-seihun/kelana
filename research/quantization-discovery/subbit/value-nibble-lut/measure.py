#!/usr/bin/env python3
"""Train 16-level signed-byte value tables and replay the complete two-head output."""
import argparse
import importlib.util
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('nibble_basis', SUBBIT / 'value-nibble-basis/measure.py')
baseline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baseline)
cache = baseline.cache

DATA = Path('/path/to/workspace/data/kelana-subbit/value-nibble-lut')


def learn(values):
    # Each signed-byte table is a Lloyd codebook rounded to its own FP16 scale.
    # Quantile initialization keeps all sixteen labels occupied even on skewed coordinates.
    flat = values.reshape(-1, 224).float()
    centers = torch.quantile(flat, torch.linspace(.015625, .984375, 16), dim=0).T.contiguous()
    for _ in range(12):
        code = (flat.T[:, :, None] - centers[:, None, :]).abs().argmin(-1)
        totals = torch.zeros_like(centers).scatter_add_(1, code, flat.T)
        counts = torch.zeros_like(centers).scatter_add_(1, code, torch.ones_like(flat.T))
        centers = torch.where(counts > 0, totals / counts.clamp_min(1), centers)
        centers, _ = centers.sort(dim=1)
    step = (centers.abs().amax(1) / 127).clamp_min(1e-8).half().float()
    levels = (centers / step[:, None]).round().clamp(-127, 127).to(torch.int8)
    return levels, step


def code_values(raw, levels, step):
    centers = levels.float() * step[:, None]
    flat = raw.reshape(-1, 224)
    code = (flat[:, :, None] - centers[None, :, :]).abs().argmin(-1)
    return torch.gather(centers[None, :, :].expand(len(flat), -1, -1), 2,
                        code.unsqueeze(-1)).squeeze(-1).reshape_as(raw)


def narrow_values(x, factors):
    return torch.cat([(x @ right.T).to(torch.bfloat16).float()
                      for _, right in factors], dim=-1)


def features(values, p):
    return torch.cat([p[:, h] @ values[:, :, (h // 2)*28:(h // 2+1)*28]
                      for h in range(16)], dim=-1).reshape(-1, 448)


def window_errors(z, y, c):
    return [baseline.relative(z[i*256:(i+1)*256], y[i*256:(i+1)*256], c)
            for i in range(len(y)//256)]


def run(layer):
    torch.set_num_threads(8)
    image = cache.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    nibble = DATA.parent / 'value-nibble-joint-fit' / f'layer{layer:02d}-8x4.json'
    fp8_path = DATA.parent / 'value-fp8-cache' / f'layer{layer:02d}.json'
    spec = importlib.util.spec_from_file_location('factor_decode', cache.SOURCE)
    dec = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dec)
    with np.load(image) as archive:
        original = [{k: archive[k][g].copy() for k in archive.files} for g in range(8)]
    factors = [(dec.decode(group, 'left'), dec.decode(group, 'right')) for group in original]
    with safe_open(cache.MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'q_norm', 'k_norm', 'v_proj', 'o_proj')}
    state = {}
    for split, count in (('train', 8), ('validation', 4)):
        x = cache.load_capture(layer, split).reshape(-1, 256, 1024)[:count]
        p = cache.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        y = cache.dense_attention(p, x, w['v_proj'], w['o_proj']).reshape(-1, 1024)
        v = narrow_values(x, factors)
        state[split] = (p, y, v)
        print('prepared', split, flush=True)
    levels, steps = learn(state['train'][2])
    DATA.mkdir(parents=True, exist_ok=True)
    table_path = DATA / f'layer{layer:02d}-levels.npz'
    np.savez(table_path, levels=levels.numpy(), steps=steps.numpy().astype(np.float16))
    score = {}
    for arm in ('lut', 'nibble', 'fp8'):
        z = {}
        for split, (p, y, v) in state.items():
            if arm == 'lut':
                qv = code_values(v, levels, steps)
                z[split] = features(qv, p)
            else:
                chosen = json.loads(nibble.read_text())['selected']
                fp8 = json.loads(fp8_path.read_text())['scales']
                # Baseline uses the same frozen values and original-producer probabilities.
                z[split] = baseline.features(cache.load_capture(layer, split).reshape(-1,256,1024)[:len(p)],
                    p, factors, chosen, None, fp8 if arm == 'fp8' else None)
        train_y = state['train'][1]
        held_y = state['validation'][1]
        penalties = [1e-4, 1e-3, 1e-2, .1, 1., 10.]
        selection = [baseline.relative(z['train'][1024:], train_y[1024:],
            baseline.solve(z['train'][:1024], train_y[:1024], penalty)) for penalty in penalties]
        ridge = penalties[int(np.argmin(selection))]
        fit = baseline.solve(z['train'], train_y, ridge)
        packed = []
        for g in range(8):
            group = {k: v.copy() for k, v in original[g].items()}
            group.update(dec.quantize(torch.cat([fit[g*56+h*28:g*56+(h+1)*28].T
                for h in range(2)]).contiguous(), 2, 128, 'left'))
            packed.append(group)
        paid = baseline.fit_codes(packed, dec, z['train'], train_y, 2)
        out = DATA / f'layer{layer:02d}-{arm}-left.npz'
        np.savez(out, **{k: np.stack([group[k] for group in packed]) for k in packed[0]})
        score[arm] = {'ridge': ridge, 'selection': selection,
                      'train': baseline.relative(z['train'], train_y, paid),
                      'held': baseline.relative(z['validation'], held_y, paid),
                      'held_windows': window_errors(z['validation'], held_y, paid),
                      'paid_image_sha256': cache.digest(out)}
        if arm == 'lut':
            p, _, v = state['validation']
            cumulative = (p.cumsum(-1) * 4095).round()
            cumulative[..., -1] = 4095
            counts = torch.diff(cumulative, dim=-1, prepend=torch.zeros_like(cumulative[..., :1]))
            assert counts.min() >= 0 and counts.sum(-1).eq(4095).all()
            code = (code_values(v, levels, steps) / steps).round()
            scaled = features(code, counts / 4095) * torch.cat([
                steps[(h//2)*28:(h//2+1)*28] for h in range(16)])[None, :]
            score[arm]['prefix_mass_4095'] = {
                'held': baseline.relative(scaled, held_y, paid),
                'held_windows': window_errors(scaled, held_y, paid),
                'max_integer_coordinate': int((features(code, counts).abs().max()).item())}
        print(arm, score[arm]['train'], score[arm]['held'], flush=True)
    report = {'layer': layer, 'scores': score, 'lut_sha256': cache.digest(table_path),
              'table_bytes': 224*16 + 224*2, 'cache_bytes_per_token': 112,
              'source_sha256': cache.digest(HERE), 'model_sha256': cache.digest(cache.MODEL),
              'capture_sha256': cache.digest(cache.CAPTURES / f'layer{layer:02d}.npz'),
              'factor_sha256': cache.digest(image), 'nibble_parent_sha256': cache.digest(nibble),
              'fp8_parent_sha256': cache.digest(fp8_path),
              'contract': 'Original-producer fixed paid rank-28 right image; 8x256 train and 4x256 repeatedly inspected validation windows. Lloyd signed-byte per-coordinate tables learned from BF16 narrow producer; paid two-bit O sign/FP16 scales fitted with same split, ridge grid and two response-code sweeps per arm. FP32 attention probability and floating replay of the corresponding table; a native integer-mass dot and complete-model behavior are not measured.'}
    output = DATA / f'layer{layer:02d}-8x4.json'
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(output, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
