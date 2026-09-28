#!/usr/bin/env python3
"""Jointly move the paid Q right codes and left codes at equal-byte rank."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'attention-metric'))
from refine import FIXTURE, MODEL, attention, decode_right, left_from_codes, measure, pack_codes, prep, unpack_codes

BASE = Path('/path/to/workspace/data/kelana-subbit/attention-radial/layer00-q-left2.npz')
EXTRA = Path('/path/to/workspace/data/kelana-subbit/spectral-refine/layer00-self_attn_q_proj-b0.539062-l2r4-g128-s0.5-f1-sweeps4.npz')
OUT = Path('/path/to/workspace/data/kelana-subbit/joint-right')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def init_left(target):
    levels = 3
    scale = target.abs().mean(1, keepdim=True).clamp_min(1e-7)
    for _ in range(12):
        codes = ((target / scale + levels) / 2).round().clamp(0, levels)
        odd = 2 * codes - levels
        scale = ((target * odd).sum(1, keepdim=True) / odd.square().sum(1, keepdim=True)).clamp_min(1e-7)
    return codes, scale


def product(lcode, llog, rcode, rlog, x, ste):
    def quant(c, maximum):
        rounded = c.round().clamp(0, maximum)
        return c + (rounded - c).detach() if ste else rounded
    left = (2 * quant(lcode, 3) - 3) * llog.exp().to(torch.float16).float()
    right = (2 * quant(rcode, 15) - 15) * rlog.exp().to(torch.float16).float().repeat_interleave(128, dim=1)
    return (x @ right.T) @ left.T


def run(rank, steps, lr):
    torch.set_num_threads(8)
    torch.manual_seed(0)
    OUT.mkdir(parents=True, exist_ok=True)
    with np.load(BASE) as z:
        image = {k: z[k].copy() for k in z.files}
    with np.load(EXTRA) as z:
        extra = {k: z[k].copy() for k in z.files}
    original_l = unpack_codes(image['left_codes'], 2048, 88, 2)
    original_r = unpack_codes(image['right_codes'], 88, 1024, 4)
    if rank == 108:
        extra_r = unpack_codes(extra['right_codes'], 128, 1024, 4)[88:108]
        rcode = torch.cat((original_r, extra_r), dim=0)
        rscales = np.concatenate((image['right_scales'], extra['right_scales'][88:108]), axis=0)
    else:
        rcode, rscales = original_r, image['right_scales']
    lscales = torch.from_numpy(image['left_scales'].copy()).float()
    with np.load(FIXTURE) as z:
        xtr = torch.from_numpy(z['train'].copy()).float().reshape(8, 256, -1)
        xva = torch.from_numpy(z['validation'].copy()).float().reshape(4, 256, -1)
        wq = torch.from_numpy(z['weight'].copy()).float()
    if rank == 108:
        # Fit only the added coordinates to the original response residual on train inputs.
        # This leaves the established 88-dimensional image exactly intact at initialization.
        with torch.no_grad():
            right_extra = (2 * extra_r - 15) * torch.from_numpy(rscales[88:].astype(np.float32)).repeat_interleave(128, 1)
            response = xtr.reshape(-1, 1024) @ right_extra.T
            base_right = decode_right(image)
            base_left = left_from_codes(original_l, image, False)
            residual = xtr.reshape(-1, 1024) @ wq.T - (xtr.reshape(-1, 1024) @ base_right.T) @ base_left.T
            coefficient = torch.linalg.lstsq(response, residual).solution.T
            # Factor gauge: move the extra coordinate's amplitude into its paid
            # right scales, so the one left group scale remains exactly unchanged.
            gains = (coefficient / lscales).abs().median(0).values.div(1.5).clamp_min(1e-4)
            scaled_right = (torch.from_numpy(rscales[88:].copy()).float() * gains[:, None]).half().float()
            rscales[88:] = scaled_right.numpy()
            more_codes = ((coefficient / (lscales * gains[None, :]) + 3) / 2).round().clamp(0, 3)
        lcode = torch.cat((original_l, more_codes), 1)
    else:
        lcode = original_l
    rlog = torch.from_numpy(rscales.copy()).float().log()
    with safe_open(MODEL, framework='pt', device='cpu') as z:
        wk = z.get_tensor('model.layers.0.self_attn.k_proj.weight').float()
        wv = z.get_tensor('model.layers.0.self_attn.v_proj.weight').float()
        wo = z.get_tensor('model.layers.0.self_attn.o_proj.weight').float()
        qgamma = z.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma = z.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    with torch.no_grad():
        contexts = {name: prep(x, wk, wv, qgamma, kgamma) for name, x in [('train', xtr), ('validation', xva)]}
        teachers = {name: measure(x, (x @ wq.T).to(torch.bfloat16).float(), wq, contexts[name], qgamma, wo)
                    for name, x in [('train', xtr), ('validation', xva)]}

    def evaluate(lc, ls, rc, rs):
        with torch.no_grad():
            return {name: measure(x, product(lc, ls, rc, rs, x, False).to(torch.bfloat16).float(),
                                  wq, contexts[name], qgamma, wo, teachers[name])
                    for name, x in [('train', xtr), ('validation', xva)]}

    initial = evaluate(lcode, lscales.log(), rcode, rlog)
    lc = torch.nn.Parameter(lcode.clone())
    ls = torch.nn.Parameter(lscales.log().clone())
    rc = torch.nn.Parameter(rcode.clone())
    rs = torch.nn.Parameter(rlog.clone())
    optimizer = torch.optim.Adam([{'params': [lc, ls], 'lr': lr}, {'params': [rc, rs], 'lr': lr * 4}])
    trace = []
    for step in range(steps):
        optimizer.zero_grad(set_to_none=True)
        logp, out, q = attention(product(lc, ls, rc, rs, xtr, True), xtr, *contexts['train'], qgamma, wo)
        t = teachers['train']
        kl = (t['logp'].exp() * (t['logp'] - logp)).sum(-1).mean()
        oe = (out - t['out']).square().sum() / t['out'].square().sum()
        qe = (q - t['q']).square().sum() / t['q'].square().sum()
        loss = kl + 2 * oe + .5 * qe
        loss.backward()
        optimizer.step()
        trace.append(float(loss.detach()))
    with torch.no_grad():
        lc = lc.round().clamp(0, 3)
        rc = rc.round().clamp(0, 15)
        ls = ls.exp().to(torch.float16).float()
        rs = rs.exp().to(torch.float16).float()
    final = evaluate(lc, ls.log(), rc, rs.log())
    image['left_shape'] = np.array([2048, rank, 2, 128], dtype=np.int32)
    image['right_shape'] = np.array([rank, 1024, 4, 128], dtype=np.int32)
    image['left_codes'] = pack_codes(lc.byte().numpy(), 2)
    image['left_scales'] = ls.half().numpy()
    image['right_codes'] = pack_codes(rc.byte().numpy(), 4)
    image['right_scales'] = rs.half().numpy()
    path = OUT / f'layer00-q-rank{rank}-joint.npz'
    np.savez(path, **image)
    report = {'source_sha256': sha(Path(__file__)), 'seed_sha256': sha(BASE), 'extension_sha256': sha(EXTRA),
              'fixture_sha256': sha(FIXTURE), 'model_sha256': sha(MODEL), 'image_sha256': sha(path),
              'rank': rank, 'steps': steps, 'lr': lr, 'bytes': sum(a.nbytes for a in image.values()),
              'factor_terms_per_query': rank * (1024 + 2048), 'initial': initial, 'final': final,
              'trace': trace, 'right_changed': int((rc != rcode).sum()), 'left_changed': int((lc != lcode).sum())}
    (OUT / f'layer00-q-rank{rank}-joint.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--rank', type=int, choices=[88, 108], required=True)
    p.add_argument('--steps', type=int, default=30)
    p.add_argument('--lr', type=float, default=.05)
    a = p.parse_args()
    run(a.rank, a.steps, a.lr)
