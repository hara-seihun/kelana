#!/usr/bin/env python3
"""Conserved integer-mass reader for the paid per-coordinate int8 narrow-value cache."""
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
from measure import probabilities, dense_attention

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def integer_mass(p, mass):
    cumulative = (p.double().cumsum(-1) * mass).round().clamp(0, mass).to(torch.int32)
    cumulative[..., -1] = mass
    return torch.diff(cumulative, dim=-1, prepend=torch.zeros_like(cumulative[..., :1]))


def score(y, teacher, bf16):
    def relative(a, b):
        return float((a-b).square().sum() / b.square().sum())
    return {'teacher': relative(y, teacher), 'vs_bf16': relative(y, bf16),
            'per_window': [relative(y[i], teacher[i]) for i in range(y.shape[0])]}


def run(layer):
    torch.set_num_threads(8)
    prior_path = DATA / 'value-fp8-cache' / f'layer{layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(image_path) == prior['image_sha256']
    assert sha(MODEL) == prior['model_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == prior['capture_sha256']
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(image_path) as image:
        factors = [(decoder.decode({k: image[k][g].copy() for k in image.files}, 'left'),
                    decoder.decode({k: image[k][g].copy() for k in image.files}, 'right'))
                   for g in range(8)]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    teacher = dense_attention(p, x, w['v_proj'], w['o_proj'])
    counts = {mass: integer_mass(p, mass) for mass in (255, 4095)}
    assert all((n.min() >= 0 and torch.all(n.sum(-1) == mass)) for mass, n in counts.items())
    arms = ('bf16', 'e4m3_fp16', 'int8_float', 'int8_mass255', 'int8_mass4095')
    output = {arm: torch.zeros_like(teacher) for arm in arms}
    code_hashes = []
    for g, (left, right) in enumerate(factors):
        z = (x @ right.T).to(torch.bfloat16).float()
        step = torch.tensor(prior['scales'][str(g)]['int8_coordinate'], dtype=torch.float16).float()
        code = (z / step).round().clamp(-127, 127).to(torch.int8)
        code_hashes.append(hashlib.sha256(code.numpy().tobytes()).hexdigest())
        decoded = code.float() * step
        e4_step = float(torch.tensor(prior['scales'][str(g)]['e4m3'], dtype=torch.float16))
        e4_cache = (z / e4_step).clamp(-448, 448).to(torch.float8_e4m3fn).float() * e4_step
        for h in range(2):
            index = 2*g+h
            left_head = left[h*1024:(h+1)*1024]
            output['bf16'] += (p[:, index] @ z) @ left_head.T
            output['e4m3_fp16'] += (p[:, index] @ e4_cache) @ left_head.T
            output['int8_float'] += (p[:, index] @ decoded) @ left_head.T
            for mass in counts:
                n = counts[mass][:, index]
                # The exact conserved integer dot has magnitude <= 127*mass = 520065.
                # A 256-key partial byte dot also fits signed int32; float64 matmul
                # produces exact integer products and sums on this captured panel.
                dot = n.double() @ code.double()
                assert torch.all(dot == dot.round()) and dot.abs().max() <= 127*mass
                if mass == 4095:
                    low = ((n + 128) % 256) - 128
                    high = (n - low) // 256
                    assert low.min() >= -128 and low.max() <= 127
                    assert high.min() >= 0 and high.max() <= 16
                    assert torch.equal(dot, low.double() @ code.double() + 256 * (high.double() @ code.double()))
                y = dot.float() * (step / mass)
                output[f'int8_mass{mass}'] += y @ left_head.T
        print(f'group {g}', flush=True)
    result = {arm: score(value, teacher, output['bf16']) for arm, value in output.items()}
    result['int8_mass255']['vs_float_cache'] = score(output['int8_mass255'], output['int8_float'], output['bf16'])['teacher']
    result['int8_mass4095']['vs_float_cache'] = score(output['int8_mass4095'], output['int8_float'], output['bf16'])['teacher']
    receipt = {'layer': layer, 'source_sha256': sha(Path(__file__)), 'parent_receipt_sha256': sha(prior_path),
               'factor_source_sha256': sha(SOURCE), 'model_sha256': sha(MODEL),
               'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'), 'image_sha256': sha(image_path),
               'code_sha256_by_group': code_hashes, 'scores': result,
               'reference_parent_held_scores': {k: v['aggregate'] for k,v in prior['scores']['validation'].items()},
               'domain': 'four previously inspected original-producer validation windows, 256 tokens each; train-frozen coordinate-MSE scales',
               'reader': 'prefix-round nonnegative conserved counts; signed-byte cache; integer count-code dot; coordinate scale after attention; then paid two-head O',
               'cache_bytes_per_token': 224, 'fp16_step_bytes_per_layer': 448,
               'scale_storage': 'parent FP32 train-selected int8 and E4M3 values rounded to FP16 before cache coding and response',
               'e4m3_fp16_step_bytes_per_layer': 16,
               'value_products_per_causal_key_layer': 448,
               'mass255_byte_dot_passes': 1, 'mass4095_byte_dot_passes': 2,
               'mass4095_split_checked': 'signed low [-128,127], nonnegative high [0,16], exact integer reconstruction on every held row',
               'boundary': 'FP32 attention probabilities rounded to 255/4095 mass units; real-valued factoring exact, FP32 O fold is reassociated'}
    dest = DATA / 'value-int8-consumer' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'scores': {k: v['teacher'] for k,v in result.items()}}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
