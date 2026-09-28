#!/usr/bin/env python3
"""Give the pinned NanoQuant factor the same binary-output activation refit."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch

from fit import quality, refine_u_activations

SOURCE = Path('/path/to/workspace/data/kelana-subbit/binary-factors/fixtures')
FIXTURES = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--layer', type=int, required=True)
    p.add_argument('--projection', choices=('q', 'o'), required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--image-dir', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/block-factor'))
    args = p.parse_args()
    torch.set_num_threads(8)
    stem = f'layer{args.layer:02d}-self_attn_{args.projection}_proj'
    image = SOURCE / f'model_layers_{args.layer}_self_attn_{args.projection}_proj_weight_0.55.npz'
    with np.load(FIXTURES / (stem + '.npz')) as d:
        weight, train, heldout = [torch.from_numpy(d[key].copy()).float() for key in ('weight', 'train', 'validation')]
    with np.load(image) as d:
        dimensions = d['dimensions'].copy()
        n, k, rank = (int(x) for x in dimensions)
        packed_v = d['V'].copy()
        u = torch.from_numpy(np.unpackbits(d['U'], axis=1, bitorder='little')[:, :rank].copy().astype('float32')) * 2 - 1
        v = torch.from_numpy(np.unpackbits(packed_v, axis=1, bitorder='little')[:, :k].copy().astype('float32')) * 2 - 1
        pre, post = [torch.from_numpy(d[key].copy()).float() for key in ('scale_pre', 'scale_post')]
    original = quality(weight, heldout, u, v, pre, post)[:2]
    u, post = refine_u_activations(weight, train, u, v, pre, post, 4)
    packed_u = np.packbits((u.numpy() > 0).astype(np.uint8), axis=1, bitorder='little')
    refined = quality(weight, heldout, u, v, pre, post)[:2]
    args.image_dir.mkdir(parents=True, exist_ok=True)
    output_image = args.image_dir / f'control-layer{args.layer}-{args.projection}.npz'
    np.savez(output_image, U=packed_u, V=packed_v,
             scale_pre=pre.numpy().astype(np.float16), scale_post=post.numpy().astype(np.float16),
             dimensions=dimensions)
    digest = hashlib.sha256(output_image.read_bytes()).hexdigest()
    report = {'fixture': stem + '.npz', 'comparator_image': str(image), 'dimensions': [n, k],
              'rank': rank, 'train_tokens': len(train), 'validation_tokens': len(heldout),
              'activation_output_sweeps': 4, 'admm_response_and_weight_error': original,
              'refined_response_and_weight_error': refined,
              'payload_bpw': 8 * (n * rank // 8 + rank * k // 8 + 2 * (n + k)) / (n * k),
              'refined_image': str(output_image), 'refined_image_sha256': digest,
              'refined_image_zip_bytes': output_image.stat().st_size}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
