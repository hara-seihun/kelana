#!/usr/bin/env python3
"""Asymmetric group-128 int4 images, with sequential quantized-producer GPTQ.

Each CLI invocation fits one layer. The activation cache is the *output of its
quantized predecessor*; no validation or test rows enter calibration. The tied
vocabulary matrix is stored once. Images are expanded only for quality tests.
"""
import argparse
import hashlib
import json
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open
from transformers import AutoModelForCausalLM

DATA = Path('/path/to/workspace/data/kelana-subbit')
MODEL = DATA / 'models/qwen3-0.6b'
TOKENS = DATA / 'ternary/expanded-tokens.npz'
ROOT = DATA / 'q4-diagnostic/calibrated'
GROUP = 128
PROJECTIONS = (('self_attn.q_proj', 'self_attn.k_proj', 'self_attn.v_proj'),
               ('self_attn.o_proj',), ('mlp.gate_proj', 'mlp.up_proj'),
               ('mlp.down_proj',))


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def image_path(key, root=ROOT):
    return root / (key.replace('.', '_') + '.npz')


def _initial_grid(w, *, weighted=None):
    """Search clipping ranges, then alternate affine LS and integer assignments."""
    rows, cols = w.shape
    v = w.reshape(rows, cols // GROUP, GROUP)
    lo = v.amin(-1, keepdim=True)
    hi = v.amax(-1, keepdim=True)
    best_error = torch.full_like(lo, float('inf'))
    best_step = torch.ones_like(lo)
    best_origin = torch.zeros_like(lo)
    if weighted is not None:
        weight = weighted.reshape(1, cols // GROUP, GROUP).clamp_min(1e-12)
    else:
        weight = 1.
    for shrink in (1., .85, .7):
        origin = lo * shrink
        step = ((hi - lo) * shrink / 15).clamp_min(1e-10)
        for _ in range(4):
            code = torch.round((v - origin) / step).clamp_(0, 15)
            mass = (weight * torch.ones_like(code)).sum(-1, keepdim=True)
            mean_code = (weight * code).sum(-1, keepdim=True) / mass
            mean_value = (weight * v).sum(-1, keepdim=True) / mass
            centered = code - mean_code
            step = ((weight * centered * (v - mean_value)).sum(-1, keepdim=True) /
                    (weight * centered.square()).sum(-1, keepdim=True).clamp_min(1e-12)).clamp_min(1e-10)
            origin = mean_value - step * mean_code
        step = step.half().float().clamp_min(1e-10)
        origin = origin.half().float()
        code = ((v - origin) / step).round().clamp(0, 15)
        error = (weight * (v - (code * step + origin)).square()).sum(-1, keepdim=True)
        choose = error < best_error
        best_step = torch.where(choose, step, best_step)
        best_origin = torch.where(choose, origin, best_origin)
        best_error = torch.minimum(error, best_error)
    return best_step.squeeze(-1), best_origin.squeeze(-1)


def _upper_inverse(h, damp):
    h = (h + h.T) * .5
    diagonal = h.diag().mean().clamp_min(1e-12)
    identity = torch.eye(len(h), device=h.device)
    for multiplier in (1, 10, 100):
        factor, info = torch.linalg.cholesky_ex(h + identity * diagonal * damp * multiplier)
        if not info.any().item():
            upper, info = torch.linalg.cholesky_ex(torch.cholesky_inverse(factor), upper=True)
            if not info.any().item():
                return upper
    raise ArithmeticError('Calibration Hessian failed Cholesky after damping')


@torch.no_grad()
def quantize(w, *, upper=None, row_chunk=256, weighted=None):
    """Return packed CPU arrays for FP32 [out,in], with optional inverse-Hessian factor."""
    if w.ndim != 2 or w.shape[1] % GROUP:
        raise ValueError('Expected a matrix with group-aligned input width')
    rows, cols = w.shape
    if upper is not None and upper.shape != (cols, cols):
        raise ValueError('Inverse-Hessian dimensions do not match the matrix')
    codes = np.empty((rows, cols // 2), dtype=np.uint8)
    scales = np.empty((rows, cols // GROUP), dtype=np.float16)
    origins = np.empty_like(scales)
    for first in range(0, rows, row_chunk):
        last = min(first + row_chunk, rows)
        original = w[first:last].float()
        step, origin = _initial_grid(original, weighted=weighted)
        scales[first:last] = step.half().cpu().numpy()
        origins[first:last] = origin.half().cpu().numpy()
        if upper is None:
            q = ((original.reshape(-1, cols // GROUP, GROUP) - origin.unsqueeze(-1)) /
                 step.unsqueeze(-1)).round().clamp_(0, 15).to(torch.uint8).reshape(-1, cols)
        else:
            working = original.clone()
            q = torch.empty_like(working, dtype=torch.uint8)
            for left in range(0, cols, GROUP):
                right = left + GROUP
                s = step[:, left // GROUP]
                z = origin[:, left // GROUP]
                errors = torch.empty((last - first, GROUP), device=w.device)
                for col in range(left, right):
                    value = working[:, col]
                    digit = ((value - z) / s).round().clamp_(0, 15).to(torch.uint8)
                    q[:, col] = digit
                    err = (value - (digit.float() * s + z)) / upper[col, col]
                    errors[:, col - left] = err
                    if col + 1 < right:
                        working[:, col + 1:right].add_(-err[:, None] * upper[col, col + 1:right])
                if right < cols:
                    working[:, right:].addmm_(errors, upper[left:right, right:], beta=1., alpha=-1.)
        nibble = q.cpu().numpy()
        codes[first:last] = nibble[:, 0::2] | (nibble[:, 1::2] << 4)
    return dict(codes=codes, scales=scales, origins=origins,
                shape=np.array((rows, cols), dtype=np.int32))


def decode(path, device='cpu'):
    """Decode the actual four-bit payload into FP32 [out,in] torch weights."""
    with np.load(path) as image:
        rows, cols = map(int, image['shape'])
        packed = image['codes']
        if packed.shape != (rows, cols // 2):
            raise ValueError(f'Invalid packed shape in {path}')
        digits = np.empty((rows, cols), dtype=np.uint8)
        digits[:, 0::2] = packed & 15
        digits[:, 1::2] = packed >> 4
        codes = torch.from_numpy(digits.astype(np.float32)).to(device)
        scales = torch.from_numpy(image['scales'].astype(np.float32)).to(device)
        origins = torch.from_numpy(image['origins'].astype(np.float32)).to(device)
    return (codes.reshape(rows, cols // GROUP, GROUP) * scales.unsqueeze(-1) +
            origins.unsqueeze(-1)).reshape(rows, cols)


def save(key, arrays, root):
    path = image_path(key, root)
    if path.exists():
        raise FileExistsError(path)
    np.savez(path, **arrays)
    return dict(key=key, path=str(path), sha256=sha(path),
                payload_bytes=sum(value.nbytes for value in arrays.values()),
                file_bytes=path.stat().st_size, shape=arrays['shape'].tolist())


def load_model():
    return AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
               dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')


def parameters(model, root, through):
    model.get_parameter('model.embed_tokens.weight').copy_(decode(image_path('model.embed_tokens.weight', root), 'cuda'))
    for layer in range(through):
        for group in PROJECTIONS:
            for member in group:
                key = f'model.layers.{layer}.{member}.weight'
                model.get_parameter(key).copy_(decode(image_path(key, root), 'cuda'))
    if model.lm_head.weight.data_ptr() != model.model.embed_tokens.weight.data_ptr():
        raise AssertionError('Expected tied embedding and head')


def token_rows(windows):
    with np.load(TOKENS) as f:
        return torch.tensor(f['train'][:windows].copy(), device='cuda', dtype=torch.long)


def layer_arguments(model, x):
    positions = torch.arange(x.shape[1], device='cuda')
    pos = positions[None]
    rope = model.model.rotary_emb(x[:1], pos)
    return dict(position_ids=pos, cache_position=positions,
                position_embeddings=rope, use_cache=False, attention_mask=None)


def forward(layer, x, kwargs):
    return torch.cat([layer(batch, **kwargs) for batch in x.split(1)])


def capture(layer, member, x, kwargs):
    collected = []
    handle = layer.get_submodule(member).register_forward_pre_hook(
        lambda module, inputs: collected.append(inputs[0].detach().reshape(-1, inputs[0].shape[-1]).float()))
    try:
        forward(layer, x, kwargs)
    finally:
        handle.remove()
    return torch.cat(collected)


def save_norms(root):
    """Keep the charged BF16 norms in the image owner, not only in the teacher."""
    arrays = {}
    with safe_open(MODEL / 'model.safetensors', framework='pt', device='cpu') as checkpoint:
        for key in checkpoint.keys():
            if len(checkpoint.get_slice(key).get_shape()) != 2:
                arrays[key] = checkpoint.get_tensor(key).to(torch.bfloat16).view(torch.int16).numpy().view(np.uint16)
    path = root / 'norms.npz'
    if path.exists():
        with np.load(path) as existing:
            if set(existing.files) != set(arrays) or any(not np.array_equal(existing[k], v) for k, v in arrays.items()):
                raise ValueError('stored norms differ from the pinned teacher')
    else:
        np.savez(path, **arrays)
    record = dict(path=str(path), sha256=sha(path), payload_bytes=sum(v.nbytes for v in arrays.values()),
                  names=list(arrays), dtype='BF16 bits in uint16', model_source_sha256=sha(MODEL / 'source.json'))
    receipt = root / 'norms.json'
    if receipt.exists() and json.loads(receipt.read_text()) != record:
        raise ValueError('norm receipt changed')
    if not receipt.exists():
        receipt.write_text(json.dumps(record, indent=2) + '\n')
    return record


def record_manifest(root, windows, *, method=None, source=None):
    receipts = sorted(root.glob('model*.json'))
    records = [json.loads(path.read_text()) for path in receipts]
    if any(sha(r['path']) != r['sha256'] for r in records):
        raise ValueError('Image differs from its receipt')
    norms = save_norms(root)
    complete = len(records) == 197
    total = sum(r['payload_bytes'] for r in records) + norms['payload_bytes']
    manifest = dict(complete=complete, matrix_count=len(records), matrices=records,
                    norm_bytes=norms['payload_bytes'], norm_names=norms['names'], norm_image=norms,
                    payload_bytes=total, bpw=8 * total / 596049920,
                    unique_parameters=596049920, calibration_windows=windows,
                    calibration_tokens_sha256=sha(TOKENS) if windows else None,
                    source_sha256=sha(source or Path(__file__)),
                    model_source_sha256=sha(MODEL / 'source.json'),
                    method=method or 'asymmetric affine group128 int4, FP16 scale and origin; body full-Hessian sequential GPTQ')
    (root / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


@torch.inference_mode()
def run(args):
    root = args.out
    root.mkdir(parents=True, exist_ok=True)
    rows = token_rows(args.windows)
    model = load_model()
    if args.embedding:
        key = 'model.embed_tokens.weight'
        with safe_open(MODEL / 'model.safetensors', framework='pt', device='cpu') as checkpoint:
            if not torch.equal(checkpoint.get_tensor(key), checkpoint.get_tensor('lm_head.weight')):
                raise AssertionError('Checkpoint embedding/head mismatch')
        w = model.model.embed_tokens.weight.float()
        # Keep the shared embedding/classifier on unweighted affine LS. The
        # fitted origin does not require a representable coefficient at zero.
        rec = save(key, quantize(w, row_chunk=512), root)
        (image_path(key, root).with_suffix('.json')).write_text(json.dumps(rec, indent=2) + '\n')
        print(json.dumps(rec), flush=True)
        return
    if args.layer is None or not 0 <= args.layer < 28:
        raise ValueError('Specify --embedding or --layer 0..27')
    parameters(model, root, args.layer)
    cache = root / f'input-{args.layer:02}.pt'
    if args.layer == 0:
        x = model.model.embed_tokens(rows)
    else:
        x = torch.load(cache, map_location='cuda', weights_only=True)
        if x.shape[:2] != rows.shape:
            raise ValueError('Activation cache does not match calibration windows')
    layer = model.model.layers[args.layer]
    kwargs = layer_arguments(model, x)
    if args.group is not None and not 0 <= args.group < len(PROJECTIONS):
        raise ValueError('Select --group 0..3')
    end_group = args.group if args.group is not None else len(PROJECTIONS) - 1
    for index, group in enumerate(PROJECTIONS[:end_group + 1]):
        if args.group is not None and index < args.group:
            for member in group:
                key = f'model.layers.{args.layer}.{member}.weight'
                layer.get_submodule(member).weight.copy_(decode(image_path(key, root), 'cuda'))
            continue
        existing = [image_path(f'model.layers.{args.layer}.{member}.weight', root).exists()
                    for member in group]
        if all(existing):
            for member in group:
                key = f'model.layers.{args.layer}.{member}.weight'
                layer.get_submodule(member).weight.copy_(decode(image_path(key, root), 'cuda'))
            continue
        inputs = capture(layer, group[0], x, kwargs)
        upper = _upper_inverse(inputs.T @ inputs / len(inputs), args.damp)
        for member, exists in zip(group, existing):
            key = f'model.layers.{args.layer}.{member}.weight'
            module = layer.get_submodule(member)
            if not exists:
                began = time.monotonic()
                rec = save(key, quantize(module.weight.float(), upper=upper,
                                         row_chunk=args.row_chunk), root)
                rec.update(calibration_rows=len(inputs), damp=args.damp,
                           seconds=time.monotonic() - began)
                image_path(key, root).with_suffix('.json').write_text(json.dumps(rec, indent=2) + '\n')
                print(json.dumps(rec), flush=True)
            module.weight.copy_(decode(image_path(key, root), 'cuda'))
        del inputs, upper
    if end_group == len(PROJECTIONS) - 1:
        next_input = forward(layer, x, kwargs).cpu()
        torch.save(next_input, root / f'input-{args.layer + 1:02}.pt')
        print(json.dumps({'layer': args.layer, 'next_input': str(root / f'input-{args.layer + 1:02}.pt')}), flush=True)
    record_manifest(root, args.windows)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--embedding', action='store_true')
    parser.add_argument('--layer', type=int)
    parser.add_argument('--group', type=int)
    parser.add_argument('--windows', type=int, default=32)
    parser.add_argument('--damp', type=float, default=.01)
    parser.add_argument('--row-chunk', type=int, default=256)
    parser.add_argument('--out', type=Path, default=ROOT)
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    run(args)
