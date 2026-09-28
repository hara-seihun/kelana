#!/usr/bin/env python3
"""Prepare device-resident inputs and comparator images from the pinned Qwen projection."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

FACTOR = Path('/path/to/workspace/data/kelana-subbit/spectral-quant/layer00-self_attn_q_proj-b0.539062-l4r4-g128-s0.5-f1.npz')
FIXTURE = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def decode(f, name):
    rows, cols, bits, group = f[name + '_shape']
    raw = f[name + '_codes']
    codes = np.stack((raw & 15, raw >> 4), axis=-1).reshape(rows, cols).astype(np.int16)
    scales = np.repeat(f[name + '_scales'].astype(np.float32), group, axis=1)[:, :cols]
    return (2 * codes - 15) * scales


def put(path, x):
    x.tofile(path)
    return {'bytes': x.nbytes, 'sha256': sha(path)}


def run(out, factor=FACTOR, fixture=FIXTURE):
    out.mkdir(parents=True, exist_ok=True)
    with np.load(factor) as f, np.load(fixture) as d:
        if f['left_shape'].tolist() != [2048, 88, 4, 128] or f['right_shape'].tolist() != [88, 1024, 4, 128]:
            raise ValueError('this native probe consumes rank-88 four-bit factors with group 128')
        left, right = decode(f, 'left'), decode(f, 'right')
        x = d['validation'][:16].astype(np.float16).copy()
        original = d['weight'].astype(np.float32)
        manifests = {}
        for name in ('left', 'right'):
            for suffix, array in (('codes', f[name + '_codes']), ('scales', f[name + '_scales'])):
                manifests[name + '_' + suffix] = put(out / (name + '_' + suffix + '.bin'), array)
        exact_map = left @ right
        expanded = exact_map.astype(np.float16)
        manifests['x'] = put(out / 'x.bin', x)
        manifests['left_f16'] = put(out / 'left_f16.bin', left.astype(np.float16))
        manifests['right_f16'] = put(out / 'right_f16.bin', right.astype(np.float16))
        manifests['expanded_f16'] = put(out / 'expanded_f16.bin', expanded)
        # Independent full-matrix int4 control, not the factor map: odd signed levels, group 128.
        grouped = exact_map.reshape(2048, 8, 128)
        scales = (np.max(abs(grouped), axis=2) / 15).astype(np.float16)
        scales = np.maximum(scales.astype(np.float32), 1e-9).astype(np.float16)
        code = np.clip(np.rint((exact_map / np.repeat(scales.astype(np.float32), 128, axis=1) + 15) / 2), 0, 15).astype(np.uint8)
        packed = (code[:, 0::2] | (code[:, 1::2] << 4)).astype(np.uint8)
        manifests['int4_codes'] = put(out / 'int4_codes.bin', packed)
        manifests['int4_scales'] = put(out / 'int4_scales.bin', scales)
        ref = x.astype(np.float32) @ right.T @ left.T
        int4_map = (code.astype(np.float32) * 2 - 15) * np.repeat(scales.astype(np.float32), 128, axis=1)
        def rel(a, b): return float(np.sum((a-b)**2) / np.sum(b**2))
        info = {'factor': str(factor), 'factor_sha256': sha(factor), 'fixture': str(fixture),
                'fixture_sha256': sha(fixture), 'source_sha256': sha(Path(__file__)), 'inputs': manifests, 'rows': [1, 16],
                'reference_map': 'float32 factor decode, float32 right then left numpy matmul; validation first 16 rounded to fp16',
                'expanded_f16_vs_factor_output_relative_squared_error': rel(x.astype(np.float32) @ expanded.T, ref),
                'int4_vs_factor_output_relative_squared_error': rel(x.astype(np.float32) @ int4_map.T, ref),
                'factor_vs_original_output_relative_squared_error': rel(ref, x.astype(np.float32) @ original.T),
                'payload_factor_bytes': sum(f[k].nbytes for k in f.files),
                'payload_expanded_f16_bytes': expanded.nbytes,
                'payload_int4_bytes': packed.nbytes + scales.nbytes}
        (out / 'inputs.json').write_text(json.dumps(info, indent=2) + '\n')
        ref.astype(np.float32).tofile(out / 'reference.bin')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('out', type=Path)
    p.add_argument('--factor', type=Path, default=FACTOR)
    p.add_argument('--fixture', type=Path, default=FIXTURE)
    args = p.parse_args()
    run(args.out, args.factor, args.fixture)
