#!/usr/bin/env python3
"""Refine paid 4-bit Q factor codes against the real Qwen attention consumer."""
import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from safetensors import safe_open

MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
FIXTURE = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
SEED = Path('/path/to/workspace/data/kelana-subbit/spectral-quant/layer00-self_attn_q_proj-b0.539062-l4r4-g128-s0.5-f1.npz')
BINARY = Path('/path/to/workspace/data/kelana-subbit/spectral-residual/binary-postfit/layer00-self_attn_q_proj_binary_rate0.55_postfit.npz')
STRONG_BINARY = Path('/path/to/workspace/data/kelana-subbit/block-factor/control-layer0-q.npz')


def unpack_codes(packed, rows, cols, bits):
    planes = np.unpackbits(packed, axis=1, bitorder='little')[:, :cols * bits]
    return torch.from_numpy((planes.reshape(rows, cols, bits).astype(np.int16) << np.arange(bits)).sum(-1).astype(np.float32))


def pack_codes(codes, bits):
    shifts = np.arange(bits, dtype=np.uint8)
    planes = (codes[..., None] >> shifts) & 1
    return np.packbits(planes.reshape(len(codes), -1), axis=1, bitorder='little')


def decode_right(image):
    rows, cols, bits, group = map(int, image['right_shape'])
    codes = unpack_codes(image['right_codes'], rows, cols, bits)
    scales = torch.from_numpy(np.repeat(image['right_scales'].astype(np.float32), group, axis=1)[:, :cols])
    return (2 * codes - (2**bits - 1)) * scales


def left_from_codes(codes, image, straight_through):
    rows, cols, bits, group = map(int, image['left_shape'])
    if straight_through:
        rounded = codes.round().clamp(0, 2**bits - 1)
        codes = (rounded - codes).detach() + codes
    scale = torch.from_numpy(np.repeat(image['left_scales'].astype(np.float32), group, axis=1)[:, :cols])
    return (2 * codes - (2**bits - 1)) * scale


def binary_weight(path):
    with np.load(path) as img:
        n, k, rank = map(int, img['dimensions'])
        u = torch.from_numpy(np.unpackbits(img['U'], axis=1, bitorder='little')[:, :rank].astype(np.float32)) * 2 - 1
        v = torch.from_numpy(np.unpackbits(img['V'], axis=1, bitorder='little')[:, :k].astype(np.float32)) * 2 - 1
        pre = torch.from_numpy(img['scale_pre'].astype(np.float32))
        post = torch.from_numpy(img['scale_post'].astype(np.float32))
    return (u * post[:, None]) @ (v * pre[None, :])


def rms(x, gamma):
    x = x.to(torch.bfloat16)
    return ((x.float() * torch.rsqrt(x.float().square().mean(-1, keepdim=True) + 1e-6))
            .to(torch.bfloat16) * gamma.to(torch.bfloat16)).float()


def rotary(q, k):
    pos = torch.arange(q.shape[2], dtype=torch.float32)
    inv = 1 / (1_000_000. ** (torch.arange(0, 128, 2).float() / 128))
    phase = torch.outer(pos, inv)
    phase = torch.cat((phase, phase), dim=-1)
    cos, sin = phase.cos().to(torch.bfloat16).float(), phase.sin().to(torch.bfloat16).float()
    cos, sin = cos[None, None], sin[None, None]
    def rotate(z):
        half = z.shape[-1] // 2
        return torch.cat((-z[..., half:], z[..., :half]), dim=-1)
    return (q * cos + rotate(q) * sin), (k * cos + rotate(k) * sin)


def prep(x, wk, wv, qgamma, kgamma):
    batch, length, _ = x.shape
    key = rms((x @ wk.T).to(torch.bfloat16).float().reshape(batch, length, 8, 128), kgamma)
    value = (x @ wv.T).to(torch.bfloat16).float().reshape(batch, length, 8, 128).permute(0, 2, 1, 3)
    return key.permute(0, 2, 1, 3), value.repeat_interleave(2, dim=1)


def attention(qraw, x, key, value, qgamma, wo):
    batch, length, _ = x.shape
    q = rms(qraw.to(torch.bfloat16).float().reshape(batch, length, 16, 128), qgamma).permute(0, 2, 1, 3)
    q, key = rotary(q, key)
    key = key.repeat_interleave(2, dim=1)
    logits = (q @ key.transpose(-1, -2)) / math.sqrt(128)
    mask = torch.ones(length, length, dtype=torch.bool).triu(1)
    logits = logits.masked_fill(mask, -1e9)
    logp = logits.log_softmax(dim=-1)
    prob = logp.exp()
    out = (prob @ value).permute(0, 2, 1, 3).reshape(batch, length, -1) @ wo.T
    return logp, out, q


def measure(x, qraw, wq, prepared, qgamma, wo, teacher=None):
    key, value = prepared
    logp, out, q = attention(qraw, x, key, value, qgamma, wo)
    if teacher is None:
        return {'logp': logp.detach(), 'out': out.detach(), 'q': q.detach(),
                'raw': (x @ wq.T).detach()}
    p = teacher['logp'].exp()
    kl = (p * (teacher['logp'] - logp)).sum(-1).mean()
    out_err = (out - teacher['out']).square().sum() / teacher['out'].square().sum()
    qerr = (q - teacher['q']).square().sum() / teacher['q'].square().sum()
    raw = (qraw - teacher['raw']).square().sum() / teacher['raw'].square().sum()
    return {'causal_attention_kl': kl.item(), 'attention_output_relative_squared_error': out_err.item(),
            'normalized_q_relative_squared_error': qerr.item(), 'raw_q_relative_squared_error': raw.item()}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--seed-image', type=Path, default=SEED)
    p.add_argument('--binary-image', type=Path, default=BINARY)
    p.add_argument('--strong-binary-image', type=Path, default=STRONG_BINARY)
    p.add_argument('--fixture', type=Path, default=FIXTURE)
    p.add_argument('--model', type=Path, default=MODEL)
    p.add_argument('--steps', type=int, default=12)
    p.add_argument('--lr', type=float, default=.2)
    p.add_argument('--output-weight', type=float, default=0.,
                   help='weight for relative error after attention-V and O projection')
    p.add_argument('--q-direction-weight', type=float, default=0.,
                   help='weight for normalized and rotated Q direction error')
    p.add_argument('--threads', type=int, default=8)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    torch.set_num_threads(a.threads)
    torch.manual_seed(0)
    a.out.mkdir(parents=True, exist_ok=True)
    with np.load(a.fixture) as fx:
        wq = torch.from_numpy(fx['weight'].copy()).float()
        xtrain = torch.from_numpy(fx['train'].copy()).reshape(8, 256, 1024).float()
        xval = torch.from_numpy(fx['validation'].copy()).reshape(4, 256, 1024).float()
    with safe_open(a.model, framework='pt', device='cpu') as f:
        wk = f.get_tensor('model.layers.0.self_attn.k_proj.weight').float()
        wv = f.get_tensor('model.layers.0.self_attn.v_proj.weight').float()
        wo = f.get_tensor('model.layers.0.self_attn.o_proj.weight').float()
        qgamma = f.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma = f.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    with np.load(a.seed_image) as src:
        image = {k: src[k].copy() for k in src.files}
    n, rank, bits, _ = map(int, image['left_shape'])
    codes0 = unpack_codes(image['left_codes'], n, rank, bits)
    right = decode_right(image)
    binweight = binary_weight(a.binary_image)
    strong_binweight = binary_weight(a.strong_binary_image)
    with torch.no_grad():
        prepared = {tag: prep(x, wk, wv, qgamma, kgamma) for tag, x in [('train', xtrain), ('validation', xval)]}
        teacher = {tag: measure(x, (x @ wq.T).to(torch.bfloat16).float(), wq,
                                prepared[tag], qgamma, wo)
                   for tag, x in [('train', xtrain), ('validation', xval)]}
        arms = {}
        for name, weight in [('seed', left_from_codes(codes0, image, False) @ right),
                             ('binary_postfit', binweight),
                             ('binary_coordinate_refit', strong_binweight)]:
            arms[name] = {tag: measure(x, (x @ weight.T).to(torch.bfloat16).float(), wq,
                                       prepared[tag], qgamma, wo, teacher[tag])
                          for tag, x in [('train', xtrain), ('validation', xval)]}
    latent = torch.nn.Parameter(codes0.clone())
    optimizer = torch.optim.Adam([latent], lr=a.lr)
    started = time.monotonic()
    trace = []
    gradient_stats = None
    # Full eight training windows; validation has no role in updates or selection.
    for step in range(a.steps):
        optimizer.zero_grad(set_to_none=True)
        left = left_from_codes(latent, image, True)
        raw = (xtrain @ right.T) @ left.T
        logp, out, q = attention(raw, xtrain, *prepared['train'], qgamma, wo)
        t = teacher['train']['logp']
        kl = (t.exp() * (t - logp)).sum(-1).mean()
        out_ref = teacher['train']['out']
        output_error = (out - out_ref).square().sum() / out_ref.square().sum()
        q_ref = teacher['train']['q']
        q_direction_error = (q - q_ref).square().sum() / q_ref.square().sum()
        loss = kl + a.output_weight * output_error + a.q_direction_weight * q_direction_error
        loss.backward()
        if step == 0:
            gradient_stats = {'mean_abs': latent.grad.abs().mean().item(),
                              'max_abs': latent.grad.abs().max().item()}
        optimizer.step()
        trace.append(loss.item())
    seconds = time.monotonic() - started
    final_codes = latent.detach().round().clamp(0, 15).to(torch.uint8).numpy()
    image['left_codes'] = pack_codes(final_codes, bits)
    final_path = a.out / 'layer00_q_rank88_attention_refined.npz'
    np.savez(final_path, **image)
    with torch.no_grad():
        refined_weight = left_from_codes(torch.from_numpy(final_codes.astype(np.float32)), image, False) @ right
        arms['refined'] = {tag: measure(x, (x @ refined_weight.T).to(torch.bfloat16).float(), wq,
                                       prepared[tag], qgamma, wo, teacher[tag])
                           for tag, x in [('train', xtrain), ('validation', xval)]}
    report = {'method': 'fixed 4-bit right factor and scales; STE refinement of paid left 4-bit codes against Q/K attention KL plus optional output and direction losses',
              'seed_image': str(a.seed_image), 'binary_image': str(a.binary_image),
              'strong_binary_image': str(a.strong_binary_image),
              'image': str(final_path), 'payload_bytes_including_shapes': sum(v.nbytes for v in image.values()),
              'serialized_file_bytes': final_path.stat().st_size, 'rank': rank, 'factor_bits': bits,
              'changed_codes': int((final_codes != codes0.numpy()).sum()), 'training_seconds': seconds,
              'steps': a.steps, 'lr': a.lr, 'output_weight': a.output_weight,
              'q_direction_weight': a.q_direction_weight,
              'initial_gradient': gradient_stats,
              'train_windows': 8, 'validation_windows': 4,
              'tokens_per_window': 256, 'loss_trace': trace, 'arms': arms}
    (a.out / 'layer00_q_attention_refined.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
