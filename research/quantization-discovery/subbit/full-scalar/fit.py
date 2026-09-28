#!/usr/bin/env python3
"""Pack all Qwen3-0.6B body matrices and one shared embedding/head with grouped LS scalar codes."""
import argparse
import hashlib
import json
import math
import sys
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from spectral_quant import quantize

MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b')
MATRICES = ('self_attn.q_proj', 'self_attn.k_proj', 'self_attn.v_proj',
            'self_attn.o_proj', 'mlp.gate_proj', 'mlp.up_proj', 'mlp.down_proj')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as file:
        for block in iter(lambda: file.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def image_path(root, name, bits):
    return root / f'{name.replace(".", "_")}-g128-b{bits}.npz'


def pack_blocks(source, name, bits, block_rows):
    n, k = source.get_shape()
    codes, scales = [], []
    for row in range(0, n, block_rows):
        weight = source[row:min(n, row + block_rows)].float()
        arrays = quantize(weight, bits, 128, 'weight')
        codes.append(arrays['weight_codes'])
        scales.append(arrays['weight_scales'])
    return {'weight_shape': np.array([n, k, bits, 128], dtype=np.int32),
            'weight_codes': np.concatenate(codes), 'weight_scales': np.concatenate(scales)}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--first-layer', type=int, default=0)
    p.add_argument('--last-layer', type=int, default=0, help='exclusive')
    p.add_argument('--embedding', action='store_true')
    p.add_argument('--out', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/full-scalar'))
    p.add_argument('--threads', type=int, default=8)
    args = p.parse_args()
    torch.set_num_threads(args.threads)
    if not args.embedding and not 0 <= args.first_layer < args.last_layer <= 28:
        p.error('choose a nonempty layer range inside 0..28, or --embedding')
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'receipts').mkdir(exist_ok=True)
    names = (['model.embed_tokens.weight'] if args.embedding else
             [f'model.layers.{layer}.{matrix}.weight'
              for layer in range(args.first_layer, args.last_layer) for matrix in MATRICES])
    if args.embedding:
        names.append('lm_head.weight')
    started = time.monotonic()
    receipt = {'model_revision': json.loads((MODEL/'source.json').read_text())['revision'],
               'model_sha256': sha(MODEL/'model.safetensors'),
               'quantizer_sha256': sha(Path(__file__).resolve().parents[1]/'spectral_quant.py'),
               'source_sha256': sha(Path(__file__)), 'threads': args.threads,
               'range': [args.first_layer, args.last_layer], 'embedding': args.embedding,
               'method': 'spectral_quant.quantize, symmetric signed odd levels, group128, four clip seeds and five alternating LS scale/code steps per seed',
               'entries': []}
    with safe_open(MODEL/'model.safetensors', framework='pt', device='cpu') as store:
        if args.embedding:
            # The checkpoint carries both named matrices; model config ties the pointers.
            assert torch.equal(store.get_tensor('model.embed_tokens.weight'), store.get_tensor('lm_head.weight'))
            names.remove('lm_head.weight')
        for name in names:
            source = store.get_slice(name)
            for bits in (2, 4):
                start = time.monotonic()
                image = image_path(args.out, name, bits)
                if image.exists():
                    raise FileExistsError(image)
                arrays = pack_blocks(source, name, bits, block_rows=512)
                np.savez(image, **arrays)
                n, k = source.get_shape()
                payload = sum(value.nbytes for value in arrays.values())
                assert payload == math.ceil(k*bits/8)*n + n*math.ceil(k/128)*2 + 16
                record = {'name': name, 'bits': bits, 'shape': [n, k],
                          'payload_bytes': payload, 'container_bytes': image.stat().st_size,
                          'image': str(image), 'sha256': sha(image),
                          'seconds': time.monotonic() - start}
                receipt['entries'].append(record)
                print(json.dumps(record), flush=True)
    receipt['seconds'] = time.monotonic() - started
    receipt_path = args.out/'receipts'/('embedding.json' if args.embedding else
                                      f'layers-{args.first_layer:02d}-{args.last_layer:02d}.json')
    receipt_path.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'receipt': str(receipt_path), 'seconds': receipt['seconds']}), flush=True)


if __name__ == '__main__':
    main()
