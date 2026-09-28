#!/usr/bin/env python3
"""Fit a paid joint MLP output correction to frozen binary gate/up/down factors."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch

ROOT = Path('/path/to/workspace/data/kelana-subbit/full-model')
PARTS = ('gate', 'up', 'down')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unpack_bf16(bits):
    return torch.from_numpy(bits.copy().view(np.int16)).view(torch.bfloat16).float()


def weight(part, quant):
    path = ROOT / ('image-binary055-refined' if quant else 'fit-inputs') / (
        f'layer00-mlp_{part}_proj.npz')
    with np.load(path) as f:
        if quant:
            n, k, rank = f['dimensions'].tolist()
            left = np.unpackbits(f['U'], axis=1, bitorder='little')[:, :rank].astype(np.float32) * 2 - 1
            right = np.unpackbits(f['V'], axis=1, bitorder='little')[:, :k].astype(np.float32) * 2 - 1
            left *= f['scale_post'].astype(np.float32)[:, None]
            right *= f['scale_pre'].astype(np.float32)[None, :]
            value = torch.from_numpy(left) @ torch.from_numpy(right)
        else:
            value = torch.from_numpy(f['weight'].copy())
    return value, str(path), digest(path)


def mlp(x, gate, up, down):
    g = x @ gate.T
    h = torch.nn.functional.silu(g) * (x @ up.T)
    return h, h @ down.T


def error(y, prediction):
    return float(((y - prediction).square().sum() / y.square().sum()).item())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--train-rows', type=int, choices=(512, 1024, 2048), default=2048)
    args = parser.parse_args()
    torch.set_num_threads(8)
    weights = {}
    files = {}
    for part in PARTS:
        for quant in (False, True):
            w, path, sha = weight(part, quant)
            weights[part, quant] = w
            files[path] = sha
    capture = ROOT / 'capture/layer00.npz'
    files[str(capture)] = digest(capture)
    with np.load(capture) as f:
        x_train = unpack_bf16(f['train_gate_up'][:args.train_rows])
        x_held = unpack_bf16(f['validation_gate_up'][:1024])
    rows = {}
    for split, x in [('train', x_train), ('held', x_held)]:
        ht, yt = mlp(x, *(weights[p, False] for p in PARTS))
        hq, yq = mlp(x, *(weights[p, True] for p in PARTS))
        rows[split] = (yt, hq, yq)
    target, features, base = rows['train']
    residual = target - base
    # Existing down output scales admit one output gain at no additional storage.
    centered = base - base.mean(0)
    gains = (centered * (target - target.mean(0))).sum(0) / centered.square().sum(0).clamp_min(1e-10)
    scaled = lambda q: q * gains
    # Affine correction additionally spends one BF16 intercept per output row.
    bias = target.mean(0) - base.mean(0) * gains
    affine = lambda q: q * gains + bias
    result = {'format': 'layer0-mlp-joint-response/1', 'source_sha256': digest(Path(__file__)),
              'inputs_sha256': files, 'train_rows': args.train_rows, 'held_rows': 1024,
              'observation': 'real FP32 SwiGLU response on original layer-0 captured MLP inputs; frozen binary U/V codes; independent held validation rows',
              'results': {}}
    for split, (y, h, q) in rows.items():
        result['results'][split] = {'binary': error(y, q), 'gain': error(y, scaled(q)),
                                     'affine': error(y, affine(q)), 'teacher_energy': float(y.square().sum())}
    # Ridge regression of the residual on the *quantized* hidden features,
    # followed by an approximate rank-r SVD of its coefficient matrix.
    # This is not the optimal rank-r ridge solution. Price its FP16 map below.
    train_h = features - features.mean(0)
    gram = train_h @ train_h.T
    lam = 0.01 * torch.trace(gram) / len(train_h)
    alpha = torch.linalg.solve(gram + lam * torch.eye(len(train_h)), residual - residual.mean(0))
    map_full = train_h.T @ alpha
    torch.manual_seed(20260922)
    u, s, v = torch.svd_lowrank(map_full, q=40, niter=2)
    for rank in (8, 16, 32):
        left = (v[:, :rank] * s[:rank]).contiguous().to(torch.float16).float()
        right = u[:, :rank].contiguous().to(torch.float16).float()
        # A fresh bias fit is paid, and quantizing factors before scoring matters.
        correction_train = (features @ right) @ left.T
        offset = (residual - correction_train).mean(0).to(torch.float16).float()
        name = f'joint_rank{rank}'
        for split, (y, h, q) in rows.items():
            prediction = q + (h @ right) @ left.T + offset
            result['results'][split][name] = error(y, prediction)
        result['results'][name + '_bytes'] = 2 * (rank * (3072 + 1024) + 1024)
        result['results'][name + '_fp16_fma_per_token'] = rank * (3072 + 1024)
    result['ridge_lambda'] = float(lam)
    result['results']['affine_bytes'] = 2 * 1024
    out = ROOT / f'mlp-factor-response-{args.train_rows}.json'
    out.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result['results'], indent=2))


if __name__ == '__main__':
    main()
