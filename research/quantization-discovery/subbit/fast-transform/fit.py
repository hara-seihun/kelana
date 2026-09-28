#!/usr/bin/env python3
"""Fit an orthogonal butterfly plus row-scaled binary output coefficients."""
import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch

FIXTURES = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')


def rotate_rows(z, angles):
    width = z.shape[-1]
    for level, theta in enumerate(angles):
        stride = 1 << level
        pairs = z.reshape(-1, width // (2 * stride), 2, stride)
        left, right = pairs.unbind(2)
        cosine, sine = theta.cos().reshape(1, -1, stride), theta.sin().reshape(1, -1, stride)
        z = torch.stack((cosine * left - sine * right,
                         sine * left + cosine * right), dim=2).reshape(-1, width)
    return z


def inverse_rows(z, angles):
    width = z.shape[-1]
    for level in reversed(range(len(angles))):
        stride = 1 << level
        pairs = z.reshape(-1, width // (2 * stride), 2, stride)
        left, right = pairs.unbind(2)
        cosine = angles[level].cos().reshape(1, -1, stride)
        sine = angles[level].sin().reshape(1, -1, stride)
        z = torch.stack((cosine * left + sine * right,
                         -sine * left + cosine * right), dim=2).reshape(-1, width)
    return z


def solve(weight, theta, rank):
    coordinates = rotate_rows(weight, theta)
    # Global coordinate assignment is paid once, not separately for each output.
    selected = coordinates.abs().sum(0).topk(rank).indices.sort().values
    projection = coordinates[:, selected]
    scale = projection.abs().mean(1)
    signs = projection.sign()
    signs[signs == 0] = 1
    return selected, scale, signs


def evaluate(weight, x, heldout, theta, rank):
    norm = .6 * x.square().mean(0) + .4 * x.square().mean()
    pre = norm.sqrt().half().float()
    weighted = weight * pre
    rounded = [a.detach().half().float() for a in theta]
    selected, scale, signs = solve(weighted, rounded, rank)
    scale = scale.half().float()
    packed = np.packbits((signs.numpy() > 0).astype(np.uint8), axis=1, bitorder='little')
    signs = torch.from_numpy(np.unpackbits(packed, axis=1, bitorder='little')[:, :rank].astype(np.float32)) * 2 - 1
    # Row weights and activations use the same orthogonal coordinate map.
    features = rotate_rows(heldout / pre, rounded)[:, selected]
    estimate = (features @ signs.T) * scale
    reference = heldout @ weight.T
    response = ((estimate - reference).square().sum() / reference.square().sum()).item()
    reconstructed = inverse_rows(torch.zeros_like(weighted).scatter(1, selected[None, :].expand(weight.shape[0], -1), signs * scale[:, None]), rounded) / pre
    matrix_error = ((reconstructed - weight).square().sum() / weight.square().sum()).item()
    return response, matrix_error, selected, scale, packed, pre, rounded


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixture', type=Path, required=True)
    p.add_argument('--rank', type=int, default=496)
    p.add_argument('--steps', type=int, default=12)
    p.add_argument('--activation-steps', type=int, default=0)
    p.add_argument('--threads', type=int, default=8)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--image-dir', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/fast-transform'))
    a = p.parse_args()
    torch.set_num_threads(a.threads)
    torch.manual_seed(0)
    with np.load(a.fixture) as data:
        weight, train, heldout = [torch.from_numpy(data[k].copy()).float() for k in ('weight', 'train', 'validation')]
    n, k = weight.shape
    if k & (k - 1) or a.rank > k:
        raise ValueError('input must be power-of-two width and rank <= input width')
    start = time.monotonic()
    levels = int(math.log2(k))
    angles = [torch.nn.Parameter(torch.full((k // (2 << level), 1 << level), math.pi / 4)) for level in range(levels)]
    norm = .6 * train.square().mean(0) + .4 * train.square().mean()
    weighted = weight * norm.sqrt()
    baseline = evaluate(weight, train, heldout, angles, a.rank)[:2]
    optimizer = torch.optim.Adam(angles, lr=.025)
    for step in range(a.steps):
        optimizer.zero_grad()
        coordinates = rotate_rows(weighted, angles)
        # Envelope theorem: for frozen transform, signs and one row scale have
        # exact least-squares optima. Differentiate their eliminated objective.
        selected = coordinates.detach().abs().sum(0).topk(a.rank).indices
        gain = coordinates[:, selected].abs().sum(1).square().sum() / a.rank
        loss = -gain / weighted.square().sum()
        loss.backward()
        optimizer.step()
    before_activation = evaluate(weight, train, heldout, angles, a.rank)[0]
    if a.activation_steps:
        optimizer = torch.optim.Adam(angles, lr=.003)
        target = train @ weight.T
        pre_train = norm.sqrt().half().float()
        for step in range(a.activation_steps):
            if step % 8 == 0:
                with torch.no_grad():
                    selected, scale, signs = solve(weight * pre_train, angles, a.rank)
                    signs = signs.detach()
                    scale = scale.detach()
            subset = torch.randperm(train.shape[0])[:256]
            optimizer.zero_grad()
            features = rotate_rows(train[subset] / pre_train, angles)[:, selected]
            estimate = (features @ signs.T) * scale
            loss = (estimate - target[subset]).square().mean() / target.square().mean()
            loss.backward()
            optimizer.step()
    response, matrix_error, selected, scale, signs, pre, rounded = evaluate(weight, train, heldout, angles, a.rank)
    coefficient_bytes = n * math.ceil(a.rank / 8)
    transform_bytes = k * levels  # k/2 pairs * log2(k) FP16 angles
    pre_bytes, post_bytes = 2 * k, 2 * n
    index_bytes = 2 * a.rank  # uint16 selected coordinate indices
    bits = 8 * (coefficient_bytes + transform_bytes + pre_bytes + post_bytes + index_bytes)
    out = {'fixture': a.fixture.name, 'dimensions': [n, k], 'rank': a.rank, 'steps': a.steps,
           'elapsed_seconds_cpu': time.monotonic() - start,
           'walsh_heldout_response_error': baseline[0], 'walsh_weight_error': baseline[1],
           'fit_heldout_response_error': response, 'fit_weight_error': matrix_error,
           'before_activation_heldout_response_error': before_activation,
           'activation_steps': a.activation_steps,
           'payload_bytes': {'coefficient': coefficient_bytes, 'transform': transform_bytes,
                             'pre_scale': pre_bytes, 'post_scale': post_bytes, 'indices': index_bytes},
           'payload_bpw': bits / (n * k),
           'online': {'butterfly_pair_rotations': k * levels // 2,
                      'signed_output_terms': n * a.rank,
                      'lookup_8_table_build_additions': (a.rank // 8) * 255,
                      'lookup_8_output_reads': n * (a.rank // 8),
                      'lookup_8_table_scratch_bf16_bytes': (a.rank // 8) * 256 * 2,
                      'minimum_payload_read_bytes': bits // 8,
                      'minimum_bf16_vector_io_bytes': 2 * (k + n)}}
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.image_dir.mkdir(parents=True, exist_ok=True)
    image = a.image_dir / (a.output.stem + '.npz')
    np.savez(image, signs=signs, angles=np.concatenate([v.reshape(-1).numpy() for v in rounded]).astype(np.float16),
             selected=selected.numpy().astype(np.uint16), pre=pre.numpy().astype(np.float16),
             post=scale.numpy().astype(np.float16), dimensions=np.array([n, k, a.rank], dtype=np.int32))
    out['image'] = str(image)
    out['serialized_zip_bytes'] = image.stat().st_size
    a.output.write_text(json.dumps(out, indent=2) + '\n')
    print(json.dumps(out))


if __name__ == '__main__':
    main()
