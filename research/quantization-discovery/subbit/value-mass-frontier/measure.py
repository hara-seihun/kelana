#!/usr/bin/env python3
"""Conserved-mass sweep for the frozen paid signed-byte narrow-value cache."""
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
MASSES = (255, 511, 1023, 2047, 4095)


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def counts(p, mass):
    cumulative = (p.double().cumsum(-1) * mass).round().clamp(0, mass).to(torch.int32)
    cumulative[..., -1] = mass
    n = torch.diff(cumulative, dim=-1, prepend=torch.zeros_like(cumulative[..., :1]))
    assert n.min() >= 0 and torch.all(n.sum(-1) == mass)
    return n


def relative(a, b):
    return float((a-b).square().sum().double() / b.square().sum().double())


def run(layer):
    torch.set_num_threads(8)
    parent_path = DATA / 'value-int8-consumer' / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(MODEL) == parent['model_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == parent['capture_sha256']
    assert sha(image_path) == parent['image_sha256']
    assert sha(SOURCE) == parent['factor_source_sha256']
    spec = importlib.util.spec_from_file_location('paid_factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(image_path) as image:
        factors = [(decoder.decode({k: image[k][g].copy() for k in image.files}, 'left'),
                    decoder.decode({k: image[k][g].copy() for k in image.files}, 'right'))
                   for g in range(8)]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    teacher = dense_attention(p, x, w['v_proj'], w['o_proj'])
    counts_by_mass = {mass: counts(p, mass) for mass in MASSES}
    outputs = {mass: torch.zeros_like(teacher) for mass in MASSES}
    code_hashes = []
    for g, (left, right) in enumerate(factors):
        z = (x @ right.T).to(torch.bfloat16).float()
        step = torch.tensor(json.loads((DATA / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())
                            ['scales'][str(g)]['int8_coordinate'], dtype=torch.float16).float()
        code = (z / step).round().clamp(-127, 127).to(torch.int8)
        code_hashes.append(hashlib.sha256(code.numpy().tobytes()).hexdigest())
        for h in range(2):
            i = 2*g+h
            left_head = left[h*1024:(h+1)*1024]
            for mass, n in counts_by_mass.items():
                dot = n[:, i].double() @ code.double()
                assert dot.abs().max() <= 127*mass
                if mass in (511, 1023, 2047):
                    base = n[:, i].clamp(max=255)
                    excess = (n[:, i] - base)
                    # Both matmuls are exact integer reductions on this bounded panel.
                    assert torch.equal(dot, base.double() @ code.double() + excess.double() @ code.double())
                outputs[mass] += (dot.float() * (step / mass)) @ left_head.T
        print(f'group {g}', flush=True)
    assert code_hashes == parent['code_sha256_by_group']
    assert abs(relative(outputs[255], teacher) - parent['scores']['int8_mass255']['teacher']) < 2e-7
    assert abs(relative(outputs[4095], teacher) - parent['scores']['int8_mass4095']['teacher']) < 2e-7
    result = {}
    for mass, n in counts_by_mass.items():
        overflow = (n > 255).sum(-1)
        by_window = [relative(outputs[mass][i], teacher[i]) for i in range(4)]
        result[str(mass)] = {
            'teacher_relative_squared': relative(outputs[mass], teacher),
            'per_window_teacher_relative_squared': by_window,
            'vs_mass4095_relative_squared': relative(outputs[mass], outputs[4095]),
            'overflow_keys': int(overflow.sum()),
            'overflow_keys_by_window': [int(overflow[i].sum()) for i in range(4)],
            'head_queries_with_overflow': int((overflow > 0).sum()),
            'maximum_overflow_keys_per_head_query': int(overflow.max()),
            'correction_products': int(overflow.sum())*28,
            'worst_case_correction_keys': mass//256,
            'integer_response_limit': 127*mass,
        }
        assert result[str(mass)]['maximum_overflow_keys_per_head_query'] <= mass//256
    receipt = {
        'layer': layer, 'source_sha256': sha(Path(__file__)),
        'parent_sha256': sha(parent_path), 'factor_source_sha256': sha(SOURCE),
        'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
        'image_sha256': sha(image_path), 'code_sha256_by_group': code_hashes,
        'domain': 'four previously inspected original-producer validation windows, 256 tokens, all 16 heads',
        'coordinate': 'frozen paid rank-28 V/O, FP16-rounded train-selected int8 scales, 224-byte signed V row',
        'count_rule': 'round(M times cumulative causal float probabilities), set last cumulative to M, difference',
        'reader': 'one unsigned-byte signed-byte dot over min(n,255), plus sparse (n-255)*code, scale after integer reduction, then paid O',
        'causal_byte_products': 58949632, 'padded_byte_products': 117440512,
        'quality_and_work': result,
        'boundary': 'CPU FP32 post-O observation; byte products and correction products are not measured native latency; no quantized-producer model loss',
    }
    dest = DATA / 'value-mass-frontier' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'quality_and_work': result}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
