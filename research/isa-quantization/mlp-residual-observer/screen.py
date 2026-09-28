#!/usr/bin/env python3
"""Frozen complete layer-0 residual observer, with an actual pre-MLP skip state."""
import hashlib
import json
from pathlib import Path

import numpy as np
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = Path('/path/to/workspace/data/kelana-subbit')
CAPTURE = ROOT / 'full-model/mlp-quantized-producer-capture.npz'
MODEL = ROOT / 'models/qwen3-0.6b/model.safetensors'
Q4 = ROOT / 'full-scalar'
EPS = 1e-6


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def bf16(a):
    return (a.astype(np.uint32) << 16).view(np.float32)


def q4_decode(path):
    with np.load(path) as f:
        rows, cols, bits, group = f['weight_shape'].tolist()
        assert bits == 4 and group == 128 and cols % group == 0
        codes = np.unpackbits(f['weight_codes'], axis=1, bitorder='little')[:, :4*cols].reshape(rows, cols, 4)
        integers = (codes.astype(np.int16) * (1 << np.arange(4))).sum(2)
        scales = np.repeat(f['weight_scales'].astype(np.float32), group, 1)
        paid = sum(f[name].nbytes for name in ('weight_codes', 'weight_scales', 'weight_shape'))
        return np.ascontiguousarray((2*integers-15)*scales), int(paid)


def response(x, matrices):
    g = x @ matrices['gate'].T
    u = x @ matrices['up'].T
    h = (g / (1 + np.exp(-np.clip(g, -80, 80)))) * u
    return h @ matrices['down'].T


def norm(x, gamma):
    return x * (1 / np.sqrt(np.mean(x*x, axis=-1, keepdims=True) + EPS)) * gamma


def rms(a, target):
    return float(np.linalg.norm((a-target).astype(np.float64)) / np.linalg.norm(target.astype(np.float64)))


def scores(pre, target, q, gamma, reader):
    t = pre + target
    b = pre + q
    nt = norm(t, gamma)
    nb = norm(b, gamma)
    # Reader is every live next-attention Q/K/V projection, not a selected row.
    observed = nt @ reader
    summary = {'branch': rms(q, target), 'residual': rms(b, t),
               'next_norm': rms(nb, nt), 'next_qkv': rms(nb @ reader, observed)}
    for name, c in (('half', .5), ('twice', 2.0)):
        bc = c*b
        nc = norm(bc, gamma)
        summary[name] = {'branch': rms(bc-pre, target), 'residual': rms(bc, t),
                         'next_norm': rms(nc, nt), 'next_qkv': rms(nc @ reader, observed),
                         'norm_drift_from_q4': rms(nc, nb)}
    delta = t-b
    radial = np.sum(delta*b, axis=1, keepdims=True) / np.sum(b*b, axis=1, keepdims=True) * b
    summary['branch_error_radial_energy_fraction'] = float(np.sum(radial**2, dtype=np.float64) / np.sum(delta**2, dtype=np.float64))
    summary['radial_oracle_next_norm'] = rms(norm(b+radial, gamma), nt)
    return summary


def main():
    images = {}
    paths = {}
    with safe_open(MODEL, framework='pt', device='cpu') as checkpoint:
        source = {name: np.ascontiguousarray(checkpoint.get_tensor('model.layers.0.mlp.'+name+'_proj.weight').float().numpy()) for name in ('gate', 'up', 'down')}
        gamma = checkpoint.get_tensor('model.layers.1.input_layernorm.weight').float().numpy()
        reader = np.concatenate([checkpoint.get_tensor('model.layers.1.self_attn.'+name+'_proj.weight').float().numpy() for name in ('q', 'k', 'v')]).T.copy()
    for name in source:
        path = Q4/f'model_layers_0_mlp_{name}_proj_weight-g128-b4.npz'
        images[name], paid = q4_decode(path)
        paths[name] = {'sha256':sha(path), 'payload_bytes':paid}
    result = {'source_checkpoint_sha256':sha(MODEL), 'capture_sha256':sha(CAPTURE),
              'q4_images':paths, 'q4_payload_bytes':sum(p['payload_bytes'] for p in paths.values()),
              'epsilon':EPS, 'gamma_dimension':len(gamma), 'next_qkv_rows':reader.shape[1], 'splits':{}}
    with np.load(CAPTURE) as f:
        for split in ('train', 'validation'):
            pre = bf16(f[f'{split}_teacher_pre'].copy())
            x = bf16(f[f'{split}_teacher_input'].copy())
            post = bf16(f[f'{split}_teacher_post'].copy())
            target = response(x, source)
            q = response(x, images)
            # The recorded BF16 layer output validates that pre is the skip, not the normalized MLP input.
            pre_post = rms(pre+target, post)
            if pre_post > .01:
                raise ValueError(f'producer/skip mismatch {split}: {pre_post}')
            result['splits'][split] = {'positions':int(len(x)), 'pre_plus_source_vs_captured_post':pre_post,
                                        **scores(pre, target, q, gamma, reader)}
    (HERE/'results.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result['splits'], indent=2))


if __name__ == '__main__':
    main()
