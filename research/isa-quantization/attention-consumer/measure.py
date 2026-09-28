#!/usr/bin/env python3
"""Complete causal Q/K/softmax/V/O head consumer on captured Qwen producer windows."""
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[3]
FIX = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
Q4 = ROOT / 'research/isa-quantization/producer-screen/affine-q4.bin'
SIGNED = ROOT / 'research/isa-quantization/producer-screen/signed-carrier96.bin'
OUT = Path(__file__).with_name('results.json')


def q4_decode(data):
    assert len(data) == 8704
    out = np.empty((128, 128), np.float32)
    for row in range(128):
        at = row * 68
        packed = np.frombuffer(data, dtype=np.uint8, count=64, offset=at)
        codes = np.stack((packed & 15, packed >> 4), axis=-1).reshape(-1)
        origin, step = np.frombuffer(data, dtype='<f2', count=2, offset=at + 64).astype(np.float32)
        out[row] = origin + step * codes
    return out


def signed_decode(data):
    assert len(data) == 8128
    rows = np.unpackbits(np.frombuffer(data, dtype=np.uint8, count=1536).reshape(96, 16),
                         axis=1, bitorder='little').astype(np.float32) * 2 - 1
    readout = np.empty((128, 96), np.float32)
    for row in range(128):
        at = 1536 + row * 50
        packed = np.frombuffer(data, dtype=np.uint8, count=48, offset=at)
        codes = np.stack((packed & 15, packed >> 4), axis=-1).reshape(-1).astype(np.int8)
        codes[codes >= 8] -= 16
        gain = float(np.frombuffer(data, dtype='<f2', count=1, offset=at+48)[0])
        readout[row] = codes.astype(np.float32) * gain
    gains = np.frombuffer(data, dtype='<f2', count=96, offset=1536+128*50).astype(np.float32)
    return (readout * gains[None, :]) @ rows


def normalized(z, gamma):
    z = z.to(torch.bfloat16).float()
    value = z * torch.rsqrt(z.square().mean(-1, keepdim=True) + 1e-6)
    return value.to(torch.bfloat16).float() * gamma.to(torch.bfloat16).float()


def rope(z):
    positions = torch.arange(z.shape[0], dtype=torch.float32)
    inverse = 1 / (1_000_000. ** (torch.arange(64, dtype=torch.float32) / 64))
    theta = torch.outer(positions, inverse)
    cos = torch.cat((theta.cos(), theta.cos()), dim=-1).to(torch.bfloat16).float()
    sin = torch.cat((theta.sin(), theta.sin()), dim=-1).to(torch.bfloat16).float()
    rotated = torch.cat((-z[:, 64:], z[:, :64]), dim=-1)
    return z * cos + rotated * sin


def head(qraw, kraw, vraw, qgamma, kgamma, wo):
    q = rope(normalized(qraw, qgamma))
    k = rope(normalized(kraw, kgamma))
    logits = q @ k.T / math.sqrt(128)
    logits = logits.masked_fill(torch.ones_like(logits, dtype=torch.bool).triu(1), -1e9)
    logp = logits.log_softmax(-1)
    value = (logp.exp() @ vraw) @ wo.T
    return logp, value, logits


def compare(reference, candidate):
    logp, output, logits = reference
    other, other_output, other_logits = candidate
    mask = torch.tril(torch.ones_like(logits, dtype=torch.bool))
    allowed = torch.where(mask, logits - other_logits, 0)
    counts = torch.arange(1, logits.shape[0] + 1)
    centered = allowed - allowed.sum(-1, keepdim=True)/counts[:, None]
    centered = torch.where(mask, centered, 0)
    return dict(attention_kl=float((logp.exp() * (logp-other)).sum(-1).mean()),
                post_o_rel_sq=float((output-other_output).square().sum()/output.square().sum()),
                centered_score_rel_sq=float(centered.square().sum()/torch.where(mask, logits, 0).square().sum()))


def main():
    torch.set_num_threads(1)
    with np.load(FIX) as fixture:
        train = fixture['train'].reshape(8, 256, 1024)[:2].copy()
        held = fixture['validation'].reshape(4, 256, 1024)[:2].copy()
        wq = fixture['weight'].astype(np.float32).copy()
    with safe_open(MODEL, framework='pt', device='cpu') as image:
        wk = image.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        wv = image.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        wo = image.get_tensor('model.layers.0.self_attn.o_proj.weight')[:, :128].float()
        qgamma = image.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma = image.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    q4_data = Q4.read_bytes()
    signed_data = SIGNED.read_bytes()
    variants = {'original_bf16_submatrix': wq[:128, :128],
                'affine_q4': q4_decode(q4_data),
                'signed_carrier96': signed_decode(signed_data)}
    signs = torch.tensor([(-1. if (i % 3 == 0) else 1.) for i in range(64)] * 2)
    candidate_weights = {}
    for name, submatrix in variants.items():
        full = wq[:128].copy()
        full[:, :128] = submatrix
        candidate_weights[name] = torch.from_numpy(full)
    result = dict(source_fixture=str(FIX), fixture_sha256=hashlib.sha256(FIX.read_bytes()).hexdigest(),
                  source_model=str(MODEL), q4_sha256=hashlib.sha256(q4_data).hexdigest(),
                  signed_sha256=hashlib.sha256(signed_data).hexdigest(),
                  submatrix_bytes={'original_bf16_submatrix':32768,'affine_q4':len(q4_data),
                                   'signed_carrier96':len(signed_data)},
                  panels={})
    with torch.no_grad():
        for panel, inputs in (('train', train), ('held', held)):
            records = {key:[] for key in variants}
            records['affine_q4_paired_sign_gauge'] = []
            gauge_logit_max = 0.
            for block in inputs:
                x = torch.from_numpy(block.astype(np.float32))
                qfull = (x @ torch.from_numpy(wq[:128]).T).to(torch.bfloat16).float()
                k = (x @ wk.T).to(torch.bfloat16).float()
                v = (x @ wv.T).to(torch.bfloat16).float()
                teacher = head(qfull,k,v,qgamma,kgamma,wo)
                for name in variants:
                    qcandidate = (x @ candidate_weights[name].T).to(torch.bfloat16).float()
                    candidate = head(qcandidate,k,v,qgamma,kgamma,wo)
                    record = compare(teacher,candidate)
                    record['raw_q_rel_sq'] = float((qcandidate-qfull).square().sum()/qfull.square().sum())
                    records[name].append(record)
                    if name == 'affine_q4':
                        # This is a joint representation change: both complete
                        # Q and K heads change signs on the same RoPE pairs.
                        gauged = head(qcandidate * signs, k * signs, v, qgamma, kgamma, wo)
                        changed = compare(teacher, gauged)
                        changed['raw_q_rel_sq'] = float(((qcandidate*signs)-qfull).square().sum()/qfull.square().sum())
                        records['affine_q4_paired_sign_gauge'].append(changed)
                        gauge_logit_max = max(gauge_logit_max,
                                              float((candidate[2]-gauged[2]).abs().max()))
            result['panels'][panel] = {name: {metric:sum(r[metric] for r in rows)/len(rows)
                                               for metric in rows[0]} for name, rows in records.items()}
            result['panels'][panel]['paired_gauge_max_logit_change'] = gauge_logit_max
    OUT.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['panels'], indent=2))


if __name__ == '__main__':
    main()
