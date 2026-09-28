#!/usr/bin/env python3
"""Same affine int4 format as calibrated.py, without activation or Hessian fitting."""
import argparse
import json
from pathlib import Path

import torch
from safetensors import safe_open

from calibrated import MODEL, DATA, PROJECTIONS, quantize, save, image_path, record_manifest

ROOT = DATA / 'q4-diagnostic/asymmetric-rtn'


def fit(key, checkpoint, root, rows):
    source = checkpoint.get_slice(key)
    shape = source.get_shape()
    codes = torch.empty((shape[0], shape[1] // 2), dtype=torch.uint8).numpy()
    scales = torch.empty((shape[0], shape[1] // 128), dtype=torch.float16).numpy()
    origins = torch.empty_like(torch.from_numpy(scales)).numpy()
    for first in range(0, shape[0], rows):
        last = min(first + rows, shape[0])
        arrays = quantize(source[first:last].float(), row_chunk=rows)
        codes[first:last] = arrays['codes']
        scales[first:last] = arrays['scales']
        origins[first:last] = arrays['origins']
    image = dict(codes=codes, scales=scales, origins=origins,
                 shape=torch.tensor(shape, dtype=torch.int32).numpy())
    rec = save(key, image, root)
    image_path(key, root).with_suffix('.json').write_text(json.dumps(rec, indent=2) + '\n')
    print(json.dumps(rec), flush=True)


def run(args):
    args.out.mkdir(parents=True, exist_ok=True)
    with safe_open(MODEL / 'model.safetensors', framework='pt', device='cpu') as checkpoint:
        if args.embedding:
            if not torch.equal(checkpoint.get_tensor('model.embed_tokens.weight'),
                               checkpoint.get_tensor('lm_head.weight')):
                raise AssertionError('Checkpoint embedding/head mismatch')
            fit('model.embed_tokens.weight', checkpoint, args.out, args.rows)
        else:
            if args.layer is None or not 0 <= args.layer < 28:
                raise ValueError('Specify --embedding or --layer 0..27')
            for group in PROJECTIONS:
                for member in group:
                    fit(f'model.layers.{args.layer}.{member}.weight', checkpoint, args.out, args.rows)
    manifest = record_manifest(args.out, 0, method='asymmetric affine group128 int4 RTN, FP16 scale and origin',
                               source=Path(__file__))
    print(json.dumps({key: manifest[key] for key in ('complete', 'matrix_count', 'payload_bytes', 'bpw')}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--embedding', action='store_true')
    parser.add_argument('--layer', type=int)
    parser.add_argument('--rows', type=int, default=512)
    parser.add_argument('--out', type=Path, default=ROOT)
    args = parser.parse_args()
    torch.set_num_threads(8)
    run(args)
