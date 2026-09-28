#!/usr/bin/env python3
"""Packed affine three-level group128 images fitted to quantized producers.

This is not a signed ternary image. Each group stores two independent FP16
numbers: its scale and its origin. The reconstructed levels are z, z+s, z+2s.
"""
import argparse
import importlib.util
import json
import math
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

_base_spec = importlib.util.spec_from_file_location('_q4_calibrated_base', Path(__file__).with_name('calibrated.py'))
base = importlib.util.module_from_spec(_base_spec)
_base_spec.loader.exec_module(base)

ROOT = base.DATA / 'q4-diagnostic/three-level-affine'
GROUP = 128
POWERS = np.array([1, 3, 9, 27, 81], dtype=np.int16)


def image_path(key, root=ROOT):
    return root / (key.replace('.', '_') + '.npz')


def _initial_grid(w):
    """Fit two degrees of freedom, searching initialization but not held data."""
    v = w.reshape(w.shape[0], -1, GROUP)
    mean = v.mean(-1, keepdim=True)
    centered = v - mean
    # Several starts matter for highly skewed groups. Alternating exact affine
    # least squares and digit assignment then scores the actual FP16 grid.
    radius = centered.abs().amax(-1, keepdim=True).clamp_min(1e-9)
    best = torch.full_like(mean, float('inf'))
    best_scale = torch.ones_like(mean)
    best_origin = torch.zeros_like(mean)
    for shrink in (1., .7, .5, .35):
        step = radius * shrink
        origin = mean - step
        for _ in range(8):
            digit = ((v - origin) / step.clamp_min(1e-10)).round().clamp_(0, 2)
            center_code = digit.mean(-1, keepdim=True)
            center_value = mean
            centered_code = digit - center_code
            step = ((centered_code * (v - center_value)).sum(-1, keepdim=True) /
                    centered_code.square().sum(-1, keepdim=True).clamp_min(1e-10)).clamp_min(1e-10)
            origin = center_value - center_code * step
        rounded_scale = step.half().float().clamp_min(1e-10)
        rounded_origin = origin.half().float()
        digit = ((v - rounded_origin) / rounded_scale).round().clamp_(0, 2)
        error = (v - (digit * rounded_scale + rounded_origin)).square().sum(-1, keepdim=True)
        take = error < best
        best = torch.minimum(best, error)
        best_scale = torch.where(take, rounded_scale, best_scale)
        best_origin = torch.where(take, rounded_origin, best_origin)
    return best_scale.squeeze(-1), best_origin.squeeze(-1)


def _strict_scale(w):
    """Exact signed {-1,0,1} LS solution for every nonzero count per group."""
    v = w.reshape(w.shape[0], -1, GROUP)
    sorted_abs = v.abs().sort(dim=-1, descending=True).values
    prefix = sorted_abs.cumsum(-1)
    counts = torch.arange(1, GROUP + 1, device=w.device, dtype=torch.float32)
    best = (prefix.square() / counts).argmax(-1, keepdim=True)
    return (prefix.gather(-1, best) / (best + 1)).squeeze(-1).half().float().clamp_min(1e-10)


@torch.no_grad()
def quantize(w, *, upper=None, row_chunk=256, strict=False):
    if w.ndim != 2 or w.shape[1] % GROUP:
        raise ValueError('Expected matrix with 128-aligned input width')
    rows, cols = w.shape
    if upper is not None and upper.shape != (cols, cols):
        raise ValueError('Inverse-Hessian shape mismatch')
    bytes_per_row = math.ceil(cols / 5)
    packed = np.empty((rows, bytes_per_row), dtype=np.uint8)
    scales = np.empty((rows, cols // GROUP), dtype=np.float16)
    origins = None if strict else np.empty_like(scales)
    for first in range(0, rows, row_chunk):
        last = min(first + row_chunk, rows)
        original = w[first:last].float()
        if strict:
            step = _strict_scale(original)
            origin = -step
        else:
            step, origin = _initial_grid(original)
            origins[first:last] = origin.half().cpu().numpy()
        scales[first:last] = step.half().cpu().numpy()
        if upper is None:
            digits = ((original.reshape(-1, cols // GROUP, GROUP) - origin.unsqueeze(-1)) /
                      step.unsqueeze(-1)).round().clamp_(0, 2).to(torch.uint8).reshape(-1, cols)
        else:
            working = original.clone()
            digits = torch.empty_like(working, dtype=torch.uint8)
            for left in range(0, cols, GROUP):
                right = left + GROUP
                s = step[:, left // GROUP]
                z = origin[:, left // GROUP]
                errors = torch.empty((last - first, GROUP), device=w.device)
                for col in range(left, right):
                    value = working[:, col]
                    digit = ((value - z) / s).round().clamp_(0, 2).to(torch.uint8)
                    digits[:, col] = digit
                    error = (value - (digit.float() * s + z)) / upper[col, col]
                    errors[:, col - left] = error
                    if col + 1 < right:
                        working[:, col + 1:right].add_(-error[:, None] * upper[col, col + 1:right])
                if right < cols:
                    working[:, right:].addmm_(errors, upper[left:right, right:], beta=1., alpha=-1.)
        raw = digits.cpu().numpy()
        padding = (-cols) % 5
        if padding:
            raw = np.pad(raw, ((0, 0), (0, padding)))
        packed[first:last] = (raw.reshape(last - first, bytes_per_row, 5) * POWERS).sum(-1).astype(np.uint8)
    arrays = dict(codes=packed, scales=scales, shape=np.array((rows, cols), dtype=np.int32))
    if origins is not None:
        arrays['origins'] = origins
    return arrays


def decode(path, device='cpu'):
    """Expand the actual five-trits-per-byte payload to FP32 original coordinates."""
    with np.load(path) as image:
        rows, cols = map(int, image['shape'])
        packed = image['codes']
        if packed.shape != (rows, math.ceil(cols / 5)) or packed.max() > 242:
            raise ValueError('Malformed packed three-level image')
        digits = ((packed[:, :, None].astype(np.int16) // POWERS) % 3).reshape(rows, -1)[:, :cols]
        codes = torch.from_numpy(digits.astype(np.float32)).to(device)
        scale = torch.from_numpy(image['scales'].astype(np.float32)).to(device)
        origin = (torch.from_numpy(image['origins'].astype(np.float32)).to(device)
                  if 'origins' in image else -scale)
        if scale.shape != (rows, cols // GROUP) or origin.shape != scale.shape:
            raise ValueError('Malformed scale/origin group shape')
    return (codes.reshape(rows, cols // GROUP, GROUP) * scale.unsqueeze(-1) +
            origin.unsqueeze(-1)).reshape(rows, cols)


def save(key, arrays, root):
    path = image_path(key, root)
    if path.exists():
        raise FileExistsError(path)
    np.savez(path, **arrays)
    return dict(key=key, path=str(path), sha256=base.sha(path),
                payload_bytes=sum(a.nbytes for a in arrays.values()),
                file_bytes=path.stat().st_size, shape=arrays['shape'].tolist())


def manifest(root, windows, strict=False):
    method = ('strict signed {-1,0,1} group128, packed five trits/byte, one FP16 scale; '
              'body full-Hessian quantized-producer GPTQ' if strict else
              'affine three-level group128, packed five trits/byte, FP16 scale and origin; '
              'body full-Hessian quantized-producer GPTQ')
    return base.record_manifest(root, windows, method=method, source=Path(__file__))


def tokens(windows):
    with np.load(base.TOKENS) as fixture:
        return torch.tensor(fixture['train'][:windows].copy(), device='cuda', dtype=torch.long)


@torch.inference_mode()
def run(args):
    root = args.out
    root.mkdir(parents=True, exist_ok=True)
    rows = tokens(args.windows)
    model = base.load_model()
    if args.embedding:
        key = 'model.embed_tokens.weight'
        with safe_open(base.MODEL / 'model.safetensors', framework='pt', device='cpu') as checkpoint:
            if not torch.equal(checkpoint.get_tensor(key), checkpoint.get_tensor('lm_head.weight')):
                raise AssertionError('Embedding/head mismatch')
        rec = save(key, quantize(model.model.embed_tokens.weight.float(), row_chunk=512,
                                 strict=args.strict), root)
        image_path(key, root).with_suffix('.json').write_text(json.dumps(rec, indent=2) + '\n')
        manifest(root, args.windows, args.strict)
        print(json.dumps(rec), flush=True)
        return
    if args.layer is None or not 0 <= args.layer < 28:
        raise ValueError('Specify --embedding or --layer 0..27')
    model.model.embed_tokens.weight.copy_(decode(image_path('model.embed_tokens.weight', root), 'cuda'))
    for prior in range(args.layer):
        for group in base.PROJECTIONS:
            for member in group:
                key = f'model.layers.{prior}.{member}.weight'
                model.get_parameter(key).copy_(decode(image_path(key, root), 'cuda'))
    if model.lm_head.weight.data_ptr() != model.model.embed_tokens.weight.data_ptr():
        raise AssertionError('Expected tied head')
    if args.layer:
        x = torch.load(root / f'input-{args.layer:02}.pt', map_location='cuda', weights_only=True)
        if x.shape[:2] != rows.shape:
            raise ValueError('Activation cache does not match calibration windows')
    else:
        x = model.model.embed_tokens(rows)
    layer = model.model.layers[args.layer]
    kwargs = base.layer_arguments(model, x)
    for group in base.PROJECTIONS:
        exists = [image_path(f'model.layers.{args.layer}.{member}.weight', root).exists()
                  for member in group]
        if not all(exists):
            inputs = base.capture(layer, group[0], x, kwargs)
            upper = base._upper_inverse(inputs.T @ inputs / len(inputs), args.damp)
            for member, found in zip(group, exists):
                key = f'model.layers.{args.layer}.{member}.weight'
                if not found:
                    started = time.monotonic()
                    rec = save(key, quantize(layer.get_submodule(member).weight.float(),
                                             upper=upper, row_chunk=args.row_chunk,
                                             strict=args.strict), root)
                    rec.update(calibration_rows=len(inputs), damp=args.damp,
                               seconds=time.monotonic() - started)
                    image_path(key, root).with_suffix('.json').write_text(json.dumps(rec, indent=2) + '\n')
                    print(json.dumps(rec), flush=True)
            del inputs, upper
        for member in group:
            key = f'model.layers.{args.layer}.{member}.weight'
            layer.get_submodule(member).weight.copy_(decode(image_path(key, root), 'cuda'))
    next_input = base.forward(layer, x, kwargs).cpu()
    torch.save(next_input, root / f'input-{args.layer+1:02}.pt')
    print(json.dumps({'layer': args.layer, 'next_input': str(root / f'input-{args.layer+1:02}.pt')}), flush=True)
    manifest(root, args.windows, args.strict)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--embedding', action='store_true')
    parser.add_argument('--layer', type=int)
    parser.add_argument('--windows', type=int, default=32)
    parser.add_argument('--damp', type=float, default=.01)
    parser.add_argument('--row-chunk', type=int, default=256)
    parser.add_argument('--strict', action='store_true', help='signed {-1,0,1} with implicit origin=-scale')
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    if args.out is None:
        args.out = base.DATA / ('q4-diagnostic/three-level-strict' if args.strict
                                else 'q4-diagnostic/three-level-affine')
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    run(args)
