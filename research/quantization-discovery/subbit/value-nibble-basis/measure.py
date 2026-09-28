#!/usr/bin/env python3
"""Conditional full-response decoder for the frozen half-byte shared V coordinate."""
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
sys.path.insert(0, str(SUBBIT / 'value-observer'))
from refine import unpack_codes
spec = importlib.util.spec_from_file_location('cache', SUBBIT / 'value-centered-int4/measure.py')
cache = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cache)
DATA = Path('/path/to/workspace/data/kelana-subbit/value-nibble-basis')


def features(x, p, factors, steps, lows, fp8):
    columns = []
    for g, (_, right) in enumerate(factors):
        z = (x @ right.T).to(torch.bfloat16).float()
        if fp8:
            scale = fp8[str(g)]['e4m3']
            z = (z / scale).clamp(-448, 448).to(torch.float8_e4m3fn).float() * scale
        else:
            step = torch.tensor(steps[g]['steps'])
            low = torch.tensor(steps[g]['lows'])
            z = (z / step).round().clamp(max=7).maximum(low) * step
        for h in range(2):
            columns.append(p[:, 2*g+h] @ z)
    return torch.cat(columns, dim=-1).reshape(-1, 448)


def relative(z, y, c):
    err = ((z @ c - y) ** 2).sum()
    return float(err / (y*y).sum())


def solve(z, y, penalty):
    a = z.T.double() @ z.double() / len(z)
    b = z.T.double() @ y.double() / len(z)
    scale = a.trace() / a.shape[0]
    a.diagonal().add_(scale * penalty)
    return torch.linalg.solve(a, b).float()


def fit_codes(images, q, z, y, sweeps):
    ranks = [int(im['right_shape'][0]) for im in images]
    starts = np.cumsum([0] + [r for r in ranks for _ in range(2)]).tolist()
    codes = torch.cat([unpack_codes(images[h//2]['left_codes'], 2048, ranks[h//2], 2)
                       [(h%2)*1024:(h%2+1)*1024] for h in range(16)], dim=1)
    scales = torch.stack([torch.from_numpy(images[h//2]['left_scales']
                         [(h%2)*1024:(h%2+1)*1024, 0].copy()).float() for h in range(16)], dim=1)
    coeff = torch.cat([(2*codes[:, starts[h]:starts[h+1]]-3)*scales[:, h, None]
                       for h in range(16)], dim=1)
    gram, target = z.T @ z / len(z), y.T @ z / len(z)
    for _ in range(sweeps):
        current = coeff @ gram
        for d in range(starts[-1]):
            h = int(np.searchsorted(starts, d, side='right')-1)
            optimum = (target[:, d]-current[:, d]+coeff[:, d]*gram[d, d])/gram[d, d].clamp_min(1e-20)
            new_code = ((optimum/scales[:, h].clamp_min(1e-20)+3)/2).round().clamp(0, 3)
            updated = (2*new_code-3)*scales[:, h]
            delta = updated-coeff[:, d]
            codes[:, d], coeff[:, d] = new_code, updated
            current += delta[:, None]*gram[d][None, :]
        prediction = z @ coeff.T
        for h in range(16):
            a, b = starts[h:h+2]
            old = z[:, a:b] @ coeff[:, a:b].T
            raw = z[:, a:b] @ (2*codes[:, a:b]-3).T
            fitted = (((y-prediction+old)*raw).sum(0)/raw.square().sum(0).clamp_min(1e-20)).clamp_min(0)
            scales[:, h] = fitted.half().float()
            coeff[:, a:b] = (2*codes[:, a:b]-3)*scales[:, h, None]
            prediction += raw*scales[:, h][None, :]-old
    for g, image in enumerate(images):
        image['left_codes'] = q.pack_codes(torch.cat([codes[:, starts[h]:starts[h+1]]
                                for h in (2*g, 2*g+1)]).to(torch.uint8).numpy(), 2)
        image['left_scales'] = torch.cat([scales[:, 2*g], scales[:, 2*g+1]]).numpy().astype(np.float16)[:, None]
    return coeff.T


def run(layer):
    torch.set_num_threads(8)
    image = cache.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    parent = DATA.parent / 'value-nibble-joint-fit' / f'layer{layer:02d}-8x4.json'
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
    chosen = json.loads(parent.read_text())['selected']
    fp8 = json.loads(fp8_path.read_text())['scales']
    state = {}
    for split, count in [('train', 8), ('validation', 4)]:
        x = cache.load_capture(layer, split).reshape(-1, 256, 1024)[:count]
        p = cache.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        y = cache.dense_attention(p, x, w['v_proj'], w['o_proj']).reshape(-1, 1024)
        state[split] = (y, {arm: features(x, p, factors, chosen, None, fp8 if arm == 'fp8' else None)
                            for arm in ('nibble', 'fp8')})
        print('prepared', split, flush=True)
    y, z = state['train']
    held_y, held_z = state['validation']
    paid = torch.cat([factors[g][0][h*1024:(h+1)*1024].T for g in range(8) for h in range(2)])
    penalties = [1e-4, 1e-3, 1e-2, .1, 1., 10.]
    scores = {}
    for arm in ('nibble', 'fp8'):
        feat = z[arm]
        # Select on separate train windows, without touching the four inspected held windows.
        candidates = [solve(feat[:1024], y[:1024], value) for value in penalties]
        selection = [relative(feat[1024:], y[1024:], c) for c in candidates]
        index = min(range(len(penalties)), key=lambda i: selection[i])
        fit = solve(feat, y, penalties[index])
        rounded = []
        packed = []
        for g in range(8):
            group = {k: v.copy() for k, v in original[g].items()}
            group.update(dec.quantize(torch.cat([fit[g*56+h*28:g*56+(h+1)*28].T for h in range(2)]).contiguous(), 2, 128, 'left'))
            rounded.append(dec.decode(group, 'left'))
            packed.append(group)
        paid_fit = torch.cat([v[h*1024:(h+1)*1024].T for v in rounded for h in range(2)])
        rounded_before = {'train': relative(feat, y, paid_fit), 'held': relative(held_z[arm], held_y, paid_fit)}
        paid_fit = fit_codes(packed, dec, feat, y, 2)
        out_image = DATA / f'layer{layer:02d}-{arm}-left.npz'
        DATA.mkdir(parents=True, exist_ok=True)
        np.savez(out_image, **{k: np.stack([group[k] for group in packed]) for k in packed[0]})
        with np.load(out_image) as saved:
            replay = torch.cat([dec.decode({k: saved[k][g] for k in saved.files}, 'left')
                                [h*1024:(h+1)*1024].T for g in range(8) for h in range(2)])
        assert torch.equal(replay, paid_fit)
        # A held-label best linear decoder is an optimistic capacity diagnostic, not a deployable fit.
        oracle = solve(held_z[arm], held_y, 1e-8)
        scores[arm] = {'penalty': penalties[index], 'selection': selection,
                       'paid': {'train': relative(feat, y, paid), 'held': relative(held_z[arm], held_y, paid)},
                       'ridge': {'train': relative(feat, y, fit), 'held': relative(held_z[arm], held_y, fit)},
                       'rounded_ridge': rounded_before,
                       'refined_codes': {'train': relative(feat, y, paid_fit), 'held': relative(held_z[arm], held_y, paid_fit)},
                       'rounded_image_sha256': cache.digest(out_image),
                       'rounded_factor_bytes': sum(v.nbytes for group in packed for v in group.values()),
                       'held_linear_oracle': relative(held_z[arm], held_y, oracle),
                       'held_windows': {'paid': [relative(held_z[arm][i*256:(i+1)*256], held_y[i*256:(i+1)*256], paid) for i in range(4)],
                                        'ridge': [relative(held_z[arm][i*256:(i+1)*256], held_y[i*256:(i+1)*256], fit) for i in range(4)],
                                        'refined_codes': [relative(held_z[arm][i*256:(i+1)*256], held_y[i*256:(i+1)*256], paid_fit) for i in range(4)]}}
        print('solved', arm, scores[arm]['paid'], scores[arm]['ridge'], flush=True)
    receipt = {'layer': layer, 'scores': scores, 'penalties': penalties,
               'source_sha256': cache.digest(HERE), 'model_sha256': cache.digest(cache.MODEL),
               'capture_sha256': cache.digest(cache.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': cache.digest(image), 'nibble_receipt_sha256': cache.digest(parent),
               'fp8_receipt_sha256': cache.digest(fp8_path),
               'contract': 'Original-producer Qwen3-0.6B; eight 256-token train windows, first four to fit and next four to select regularization, then all eight to refit. Four previously inspected validation windows. Frozen rank-28 right and cache steps, full two-head float-probability post-O features; dense real left ridge and held-label oracle are capacity diagnostics, rounded ridge is a paid 2-bit output image, followed by two exact train-response output-code/scale sweeps. No native or complete-model quality claim.'}
    DATA.mkdir(parents=True, exist_ok=True)
    out = DATA / f'layer{layer:02d}-8x4.json'
    out.write_text(json.dumps(receipt, indent=2) + '\n')
    print(out, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
