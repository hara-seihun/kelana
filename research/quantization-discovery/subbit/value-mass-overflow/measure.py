#!/usr/bin/env python3
"""Price an exact sparse overflow correction to one unsigned-byte narrow-V dot."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

SUB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SUB / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def run(layer):
    torch.set_num_threads(8)
    parent_path = DATA / 'value-int8-consumer' / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(MODEL) == parent['model_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == parent['capture_sha256']
    assert sha(image_path) == parent['image_sha256']
    spec = importlib.util.spec_from_file_location('paid_factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(image_path) as image:
        right = [decoder.decode({k: image[k][g].copy() for k in image.files}, 'right') for g in range(8)]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    mass = 4095
    cum = (p.double().cumsum(-1) * mass).round().clamp(0, mass).to(torch.int32)
    cum[..., -1] = mass
    n = torch.diff(cum, dim=-1, prepend=torch.zeros_like(cum[..., :1]))
    assert n.min() >= 0 and torch.all(n.sum(-1) == mass)
    assert not torch.any(torch.triu(n, diagonal=1))
    base = n.clamp(max=255)
    excess = n - base
    count = (excess > 0).sum(-1)
    assert count.max() <= mass // 256
    assert torch.all(base >= 0) and torch.all(base <= 255)
    per_window = []
    for v in range(4):
        c = count[v].flatten()
        per_window.append({'queries': int(c.numel()), 'overflow_keys': int(c.sum()),
                           'rows_with_overflow': int((c > 0).sum()), 'maximum': int(c.max()),
                           'by_count': torch.bincount(c, minlength=16).tolist()})
    scales = json.loads((DATA / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())['scales']
    code_hashes = []
    response_hash = hashlib.sha256()
    for g, r in enumerate(right):
        z = (x @ r.T).to(torch.bfloat16).float()
        step = torch.tensor(scales[str(g)]['int8_coordinate'], dtype=torch.float16).float()
        code = (z / step).round().clamp(-127, 127).to(torch.int8)
        code_hashes.append(hashlib.sha256(code.numpy().tobytes()).hexdigest())
        for h in range(2):
            i = 2*g+h
            # FP64 represents every bounded integer partial exactly. Gather
            # only overflow keys, then scatter their 28-coordinate corrections.
            q = code.double()
            direct = n[:, i].double() @ q
            split = base[:, i].double() @ q
            nz = excess[:, i].nonzero()
            correction = torch.zeros_like(split)
            values = excess[:, i][tuple(nz.T)].double()[:, None] * q[nz[:, 0], nz[:, 2]]
            correction.view(-1, 28).index_add_(0, nz[:, 0]*256 + nz[:, 1], values)
            split += correction
            assert torch.equal(direct, split)
            assert direct.abs().max() <= 127*mass
            response_hash.update(split.to(torch.int32).numpy().tobytes())
        print(f'group {g}', flush=True)
    assert code_hashes == parent['code_sha256_by_group']
    total = sum(v['overflow_keys'] for v in per_window)
    rows = sum(v['queries'] for v in per_window)
    causal_products = rows // 256 * (256 * 257 // 2) * 28
    receipt = {
        'layer': layer, 'source_sha256': sha(Path(__file__)),
        'parent_sha256': sha(parent_path), 'image_sha256': sha(image_path),
        'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
        'code_sha256_by_group': code_hashes, 'integer_response_sha256': response_hash.hexdigest(),
        'domain': 'four previously inspected original-producer validation windows, 256 keys, all 16 heads',
        'mass': mass, 'per_window': per_window, 'head_query_rows': rows,
        'total_overflow_keys': total, 'mean_overflow_keys_per_head_query': total / rows,
        'causal_byte_dot_products': causal_products,
        'padded_256_byte_dot_products': rows * 256 * 28,
        'sparse_scalar_correction_products': total * 28,
        'sparse_correction_fraction_of_second_causal_dot': total * 28 / causal_products,
        'sparse_correction_fraction_of_second_padded_dot': total / (rows * 256),
        'worst_case_overflow_keys_per_head_query': mass // 256,
        'identity': 'n=min(n,255)+(n-255)_+; one unsigned-byte/signed-byte full dot plus sparse (n-255)*code; exact int32 response',
        'cost_boundary': 'counts, overflow discovery/compaction, irregular correction, native integer/scale/O and occupancy unmeasured; full dot operand still padded as native layout requires',
    }
    dest = DATA / 'value-mass-overflow' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'causal_overflow_fraction': receipt['sparse_correction_fraction_of_second_causal_dot'], 'worst_seen': max(v['maximum'] for v in per_window)}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
