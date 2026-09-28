"""Shared causal observer, adapted from the canonical attention-consumer replay.

Kept locally so this study runs in its own managed checkout before integration.
"""
import math
from pathlib import Path

import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[3]
FIX = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
Q4 = ROOT / 'research/isa-quantization/producer-screen/affine-q4.bin'


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
