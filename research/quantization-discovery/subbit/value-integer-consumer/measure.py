#!/usr/bin/env python3
"""Replay a mass-conserving integer probability / signed-nibble value consumer."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def integer_mass(p, mass):
    # Prefix rounding avoids sorting, conserves mass, and never assigns a negative count.
    cumulative = (p.double().cumsum(-1) * mass).round().clamp(0, mass).to(torch.int32)
    cumulative[..., -1] = mass
    return torch.diff(cumulative, dim=-1, prepend=torch.zeros_like(cumulative[..., :1]))


def relative(y, teacher):
    return float(((y - teacher).square().sum() / teacher.square().sum()).item())


def run(layer):
    torch.set_num_threads(8)
    prior = DATA / 'value-centered-int4' / f'layer{layer:02d}-8x4.json'
    metadata = json.loads(prior.read_text())
    factor_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(factor_path) == metadata['image_sha256']
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(factor_path) as image:
        factors = [(decoder.decode({key: image[key][g].copy() for key in image.files}, 'left'),
                    decoder.decode({key: image[key][g].copy() for key in image.files}, 'right'))
                   for g in range(8)]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    teacher = dense_attention(p, x, w['v_proj'], w['o_proj'])
    masses = (255, 4095)
    counts = {mass: integer_mass(p, mass) for mass in masses}
    for mass, n in counts.items():
        assert n.min() >= 0 and torch.all(n.sum(-1) == mass)
        assert torch.all(n[p == 0] == 0)
    arms = ('raw_float', 'center_float', 'raw_8', 'center_8', 'raw_12', 'center_12')
    output = {arm: torch.zeros_like(teacher) for arm in arms}
    group_error = {}
    for g, (left, right) in enumerate(factors):
        z = (x @ right.T).to(torch.bfloat16).float()
        for label, arm in [('raw', 'int4_coordinate'), ('center', 'int4_adaptive_center')]:
            entry = metadata['metadata'][g][arm]
            center = torch.tensor(entry['center'])
            step = torch.tensor(entry['step'])
            code = ((z - center) / step).round().clamp(-7, 7).to(torch.int8)
            decoded = code.float() * step + center
            for head in range(2):
                index = 2*g + head
                l = left[head*1024:(head+1)*1024]
                output[label+'_float'] += (p[:, index] @ decoded) @ l.T
                for bits, mass in [(8, 255), (12, 4095)]:
                    n = counts[mass][:, index]
                    # The integer dot is exact in float32: |sum n*c| <= 7*mass < 2^24.
                    integers = n.float() @ code.float()
                    if bits == 12:
                        low = ((n + 128) % 256) - 128
                        high = (n - low) // 256
                        assert low.min() >= -128 and low.max() <= 127
                        assert high.min() >= 0 and high.max() <= 16
                        split_dot = (low.float() @ code.float()) + 256 * (high.float() @ code.float())
                        assert torch.equal(integers, split_dot)
                    rebuilt = integers * (step / mass) + center
                    output[f'{label}_{bits}'] += rebuilt @ l.T
        print(f'group {g}', flush=True)
    for arm, value in output.items():
        group_error[arm] = {'aggregate': relative(value, teacher),
                            'per_window': [relative(value[i], teacher[i]) for i in range(4)]}
    extra = {}
    for label in ('raw', 'center'):
        for bits in (8, 12):
            ref = output[f'{label}_float']
            candidate = output[f'{label}_{bits}']
            extra[f'{label}_{bits}'] = relative(candidate, ref)
    source = Path(__file__)
    receipt = {'layer': layer, 'model_sha256': sha(MODEL),
               'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': sha(factor_path), 'prior_receipt_sha256': sha(prior),
               'source_sha256': sha(source), 'domain': 'four previously inspected original-producer validation windows; frozen paid rank-28 factors and train-selected signed-nibble steps',
               'masses': masses, 'scores': group_error, 'relative_to_same_float_cache': extra,
               'logical_cache_bytes_per_token_layer': 112,
               'padded_cache_bytes_per_token_layer': 128,
               'integer_products_per_key_layer_two_heads': 448,
               'probability_counts_per_query_layer': 16,
               'score_contract': 'FP32 integer dot of prefix-rounded nonnegative probability counts, FP32 step/mass and O multiplication; real mass-preserving center; not BF16/FP32 bit identity'}
    dest = DATA / 'value-integer-consumer' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'scores': {k: v['aggregate'] for k, v in group_error.items()}, 'relative_to_float': extra}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
