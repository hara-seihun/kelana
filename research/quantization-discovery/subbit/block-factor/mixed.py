#!/usr/bin/env python3
"""Keep high-impact eight-input groups exact; code only the least sensitive groups."""
import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch

from fit import cluster, initial_factor, quality, refine_post, refine_u, refine_u_activations


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixture', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--compressed-groups', type=int, default=32)
    p.add_argument('--rounds', type=int, default=8)
    p.add_argument('--activation-sweeps', type=int, default=4)
    p.add_argument('--group-score', choices=('weight', 'activation'), default='weight')
    p.add_argument('--image-dir', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/block-factor'))
    args = p.parse_args()
    torch.set_num_threads(8)
    torch.manual_seed(0)
    with np.load(args.fixture) as d:
        weight, train, heldout = [torch.from_numpy(d[key].copy()).float() for key in ('weight', 'train', 'validation')]
    n, k = weight.shape
    groups, compressed = k // 8, args.compressed_groups
    if not 0 < compressed < groups:
        raise ValueError('compressed group count must be positive and smaller than group count')
    full = groups - compressed
    overhead = 16 * (n + k) + compressed * 16 * 8 + groups
    rank_cost = n + full * 8 + compressed * 4
    rank = 8 * ((int(.55 * n * k) - overhead) // (rank_cost * 8))
    start = time.monotonic()
    u, v, pre, post = initial_factor(weight, train, rank, 400)
    same_rank = quality(weight, heldout, u, v, pre, post)[:2]
    dictionary, labels = cluster(v, 16, 8)
    candidates = dictionary[torch.arange(groups)[:, None], labels].transpose(0, 1)
    original = v.reshape(rank, groups, 8)
    a = u * post[:, None]
    distortion = []
    for g in range(groups):
        delta = (original[:, g] - candidates[:, g]) * pre[g * 8:(g + 1) * 8]
        response_map = a @ delta
        if args.group_score == 'activation':
            inputs = train[:, g * 8:(g + 1) * 8]
            covariance = inputs.T @ inputs
            distortion.append((response_map.T @ response_map * covariance).sum().item())
        else:
            distortion.append(response_map.square().sum().item())
    selected = torch.tensor(np.argsort(distortion)[:compressed].copy(), dtype=torch.long).sort().values
    v = original.clone()
    v[:, selected] = candidates[:, selected]
    v = v.reshape(rank, k)
    before = quality(weight, heldout, u, v, pre, post)[:2]
    for _ in range(args.rounds):
        u = refine_u(weight, u, v, pre, post, 1)
        post = refine_post(weight, u, v, pre)
        a = u * post[:, None]
        gram = a.T @ a
        h = (a.T @ weight).reshape(rank, groups, 8)
        blocks = v.reshape(rank, groups, 8)
        input_scale = pre.reshape(groups, 8)
        current = (gram @ blocks.reshape(rank, k)).reshape(rank, groups, 8)
        for r in range(rank):
            score = h[r, selected] - input_scale[selected] * (current[r, selected] - gram[r, r] * blocks[r, selected])
            choice = torch.einsum('gb,gcb->gc', score, dictionary[selected] * input_scale[selected, None, :]).argmax(1)
            updated = dictionary[selected, choice]
            delta = updated - blocks[r, selected]
            blocks[r, selected] = updated
            labels[selected, r] = choice
            current[:, selected] += gram[:, r, None, None] * delta[None, :, :]
        v = blocks.reshape(rank, k)
        post = refine_post(weight, u, v, pre)
    before_activation = quality(weight, heldout, u, v, pre, post)[:2]
    u, post = refine_u_activations(weight, train, u, v, pre, post, args.activation_sweeps)
    response, weight_error, packed_u = quality(weight, heldout, u, v, pre, post)
    payload = {'output_signs': n * rank // 8, 'full_input_signs': full * rank,
               'compressed_labels': compressed * rank // 2, 'dictionaries': compressed * 16,
               'pre_post_scales': 2 * (n + k), 'group_mask': math.ceil(groups / 8)}
    report = {'fixture': args.fixture.name, 'dimensions': [n, k], 'rank': rank,
              'compressed_groups': compressed, 'uncompressed_groups': full,
              'group_score': args.group_score,
              'same_rank_admm_response_and_weight_error': same_rank,
              'after_group_coding_response_and_weight_error': before,
              'after_weight_refit_response_and_weight_error': before_activation,
              'activation_output_sweeps': args.activation_sweeps,
              'fit_heldout_response_error': response, 'fit_weight_error': weight_error,
              'seconds_cpu': time.monotonic() - start, 'payload_bytes': payload,
              'payload_bpw': 8 * sum(payload.values()) / (n * k),
              'online': {'input_label_lookups': rank * groups,
                         'input_table_additions_upper': full * 255 + compressed * 16 * 8,
                         'output_table_additions': rank // 8 * 255,
                         'output_table_reads': n * rank // 8,
                         'input_table_bf16_bytes': 2 * (full * 256 + compressed * 16),
                         'output_table_bf16_bytes': 2 * (rank // 8) * 256}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.image_dir.mkdir(parents=True, exist_ok=True)
    image = args.image_dir / (args.output.stem + '.npz')
    mask = np.zeros(groups, dtype=np.uint8)
    mask[selected.numpy()] = 1
    dense = np.packbits((v.reshape(rank, groups, 8)[:, mask == 0].numpy() > 0).astype(np.uint8), axis=2, bitorder='little')[:, :, 0]
    codebook = np.packbits((dictionary[selected].numpy() > 0).astype(np.uint8), axis=2, bitorder='little')[:, :, 0]
    codes = labels[selected].numpy()
    packed_labels = np.packbits(np.stack([(codes >> bit) & 1 for bit in range(4)], axis=2).reshape(compressed, rank * 4), axis=1, bitorder='little')
    np.savez(image, U=packed_u, full_patterns=dense, labels=packed_labels, dictionary=codebook,
             group_mask=np.packbits(mask, bitorder='little'), pre=pre.numpy().astype(np.float16),
             post=post.numpy().astype(np.float16), dimensions=np.array([n, k, rank], dtype=np.int32))
    report['image'] = str(image)
    report['serialized_zip_bytes'] = image.stat().st_size
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
