#!/usr/bin/env python3
"""Prune the attention-fitted Q output factor and retrain its paid codes/scales."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'attention-metric'))
from refine import (FIXTURE, MODEL, attention, decode_right, left_from_codes, measure,
                    pack_codes, prep, rms, unpack_codes)

SOURCE = Path('/path/to/workspace/data/kelana-subbit/attention-metric/final/layer00_q_rank88_attention_refined.npz')
OUT = Path('/path/to/workspace/data/kelana-subbit/attention-radial')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def initialize(target, levels):
    scale = target.abs().mean(dim=1, keepdim=True).clamp_min(1e-8)
    for _ in range(12):
        code = ((target / scale + levels) / 2).round().clamp(0, levels)
        odd = 2 * code - levels
        scale = ((target * odd).sum(1, keepdim=True) / odd.square().sum(1, keepdim=True)).clamp_min(1e-8)
    return code, scale


def prediction(codes, log_scale, image, right, x, levels, ste):
    if ste:
        rounded = codes.round().clamp(0, levels)
        codes = codes + (rounded - codes).detach()
    scales = log_scale.exp().to(torch.float16).float()
    left = (2 * codes - levels) * scales
    return (x @ right.T) @ left.T


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--bits', type=int, choices=(2, 3), required=True)
    p.add_argument('--steps', type=int, default=30)
    p.add_argument('--lr', type=float, default=.2)
    p.add_argument('--out', type=Path, default=OUT)
    a = p.parse_args()
    torch.set_num_threads(8)
    torch.manual_seed(0)
    a.out.mkdir(parents=True, exist_ok=True)
    with np.load(SOURCE) as z:
        source = {k: z[k].copy() for k in z.files}
    n, rank, _, group = map(int, source['left_shape'])
    original = unpack_codes(source['left_codes'], n, rank, 4)
    target = left_from_codes(original, source, False)
    right = decode_right(source)
    levels = (1 << a.bits) - 1
    codes, scale = initialize(target, levels)
    with np.load(FIXTURE) as z:
        xtr = torch.from_numpy(z['train'].copy()).float().reshape(8, 256, -1)
        xva = torch.from_numpy(z['validation'].copy()).float().reshape(4, 256, -1)
        wq = torch.from_numpy(z['weight'].copy()).float()
    with safe_open(MODEL, framework='pt', device='cpu') as z:
        wk = z.get_tensor('model.layers.0.self_attn.k_proj.weight').float()
        wv = z.get_tensor('model.layers.0.self_attn.v_proj.weight').float()
        wo = z.get_tensor('model.layers.0.self_attn.o_proj.weight').float()
        qgamma = z.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma = z.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    with torch.no_grad():
        contexts = {tag: prep(x, wk, wv, qgamma, kgamma) for tag, x in [('train', xtr), ('validation', xva)]}
        teachers = {tag: measure(x, (x @ wq.T).to(torch.bfloat16).float(), wq,
                                 contexts[tag], qgamma, wo) for tag, x in [('train', xtr), ('validation', xva)]}

    def evaluate(c, s):
        with torch.no_grad():
            return {tag: measure(x, prediction(c, s, source, right, x, levels, False).to(torch.bfloat16).float(),
                                 wq, contexts[tag], qgamma, wo, teachers[tag])
                    for tag, x in [('train', xtr), ('validation', xva)]}

    log_scale = scale.log()
    initial = evaluate(codes, log_scale)
    latent = torch.nn.Parameter(codes.clone())
    log_scale = torch.nn.Parameter(log_scale.clone())
    optim = torch.optim.Adam([latent, log_scale], lr=a.lr)
    trace = []
    for step in range(a.steps):
        optim.zero_grad(set_to_none=True)
        raw = prediction(latent, log_scale, source, right, xtr, levels, True)
        logp, out, q = attention(raw, xtr, *contexts['train'], qgamma, wo)
        t = teachers['train']
        kl = (t['logp'].exp() * (t['logp'] - logp)).sum(-1).mean()
        oe = (out - t['out']).square().sum() / t['out'].square().sum()
        qe = (q - t['q']).square().sum() / t['q'].square().sum()
        loss = kl + 2 * oe + .5 * qe
        loss.backward()
        optim.step()
        trace.append(loss.detach().item())
    final_codes = latent.detach().round().clamp(0, levels)
    final_scales = log_scale.detach().exp().to(torch.float16)
    final = evaluate(final_codes, final_scales.float().log())
    with torch.no_grad():
        raw_train = prediction(final_codes, final_scales.float().log(), source, right, xtr, levels, False)
        raw_teacher = xtr @ wq.T
        r = raw_train.reshape(-1, 16, 128)
        t = raw_teacher.reshape(-1, 16, 128)
        head_gain = ((r * t).sum((0, 2)) / r.square().sum((0, 2))).clamp_min(1e-5)
        gauge_scales = (final_scales.float().reshape(16, 128) * head_gain[:, None]).to(torch.float16).reshape(-1, 1)
    gauge = evaluate(final_codes, gauge_scales.float().log())
    image = dict(source)
    image['left_shape'] = np.array([n, rank, a.bits, group], dtype=np.int32)
    image['left_codes'] = pack_codes(final_codes.to(torch.uint8).numpy(), a.bits)
    image['left_scales'] = gauge_scales.numpy()
    path = a.out / f'layer00-q-left{a.bits}.npz'
    np.savez(path, **image)
    payload = sum(v.nbytes for v in image.values())
    report = {'script_sha256': digest(Path(__file__)), 'source_sha256': digest(SOURCE), 'fixture_sha256': digest(FIXTURE),
              'model_sha256': digest(MODEL), 'image_sha256': digest(path),
              'bits_left': a.bits, 'bits_right': 4, 'rank': rank, 'steps': a.steps,
              'lr': a.lr, 'objective': 'attention KL + 2 post-O relative squared error + .5 normalized-Q relative squared error',
              'image': str(path), 'payload_bytes': payload, 'matrix_bpw': payload * 8 / (2048 * 1024),
              'factor_terms_per_query': rank * (1024 + 2048),
              'initial': initial, 'final': final, 'gauge': gauge,
              'train_head_gains': head_gain.tolist(), 'loss_trace': trace,
              'changed_codes': int((final_codes != codes).sum()),
              'scale_ratio_range': [float((final_scales.float() / scale).min()), float((final_scales.float() / scale).max())]}
    receipt = a.out / f'layer00-q-left{a.bits}.json'
    receipt.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
