#!/usr/bin/env python3
"""Affine signed-byte value labels, with the constant consumed after attention."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
SUB = HERE.parent
sys.path.insert(0, str(SUB / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention

DATA = Path('/path/to/workspace/data/kelana-subbit')
OFFSETS = (-.5, -.25, 0., .25, .5)


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def relative(y, target):
    return float(((y-target).square().sum() / target.square().sum()).item())


def run(layer):
    torch.set_num_threads(8)
    prior_path = DATA / 'value-int8-consumer' / f'layer{layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    cache_path = DATA / 'value-fp8-cache' / f'layer{layer:02d}.json'
    cache = json.loads(cache_path.read_text())
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(cache_path) == prior['parent_receipt_sha256']
    assert sha(image_path) == prior['image_sha256']
    assert sha(MODEL) == prior['model_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == prior['capture_sha256']
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(image_path) as image:
        factors = [(decoder.decode({k: image[k][g].copy() for k in image.files}, 'left'),
                    decoder.decode({k: image[k][g].copy() for k in image.files}, 'right')) for g in range(8)]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    states = {}
    for split, windows in (('train', 8), ('validation', 4)):
        x = load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        teacher = dense_attention(p, x, w['v_proj'], w['o_proj'])
        # The same 4,095-unit cumulative rounding as the paid signed-byte reader.
        cumulative = (p.double().cumsum(-1) * 4095).round().clamp(0, 4095).to(torch.int32)
        cumulative[..., -1] = 4095
        n = torch.diff(cumulative, dim=-1, prepend=torch.zeros_like(cumulative[..., :1]))
        assert n.min() >= 0 and torch.all(n.sum(-1) == 4095)
        states[split] = (x, n, teacher)
    results = {split: {'base': torch.zeros_like(state[2]), 'affine': torch.zeros_like(state[2])}
               for split, state in states.items()}
    choices = []
    code_hashes = []
    group_candidates = {split: [] for split in states}
    for g, (left, right) in enumerate(factors):
        step = torch.tensor(cache['scales'][str(g)]['int8_coordinate'], dtype=torch.float16).float()
        z_train = (states['train'][0] @ right.T).to(torch.bfloat16).float()
        norm = z_train / step
        # Conditional scalar fit with frozen scale and code alphabet. An offset
        # changes thresholds as well as adding a constant after the dot.
        mse = torch.stack([((torch.clamp((norm - off).round(), -127, 127) + off - norm) ** 2).mean(dim=(0, 1))
                           for off in OFFSETS])
        index = mse.argmin(dim=0)
        offset = torch.tensor(OFFSETS)[index]
        choices.append([float(v) for v in offset])
        for split, (x, n, _) in states.items():
            z = z_train if split == 'train' else (x @ right.T).to(torch.bfloat16).float()
            codes = {}
            candidates = []
            for off_scalar in OFFSETS:
                off = torch.full_like(offset, off_scalar)
                code = ((z / step - off).round().clamp(-127, 127)).to(torch.int8)
                candidate = torch.zeros_like(states[split][2])
                for h in range(2):
                    dot = n[:, 2*g+h].double() @ code.double()
                    assert torch.all(dot == dot.round()) and dot.abs().max() <= 127 * 4095
                    attended = (dot.float() / 4095 + off) * step
                    candidate += attended @ left[h*1024:(h+1)*1024].T
                candidates.append(candidate)
                if off_scalar == 0:
                    codes['base'] = code
                    results[split]['base'] += candidate
            group_candidates[split].append(candidates)
            code = ((z / step - offset).round().clamp(-127, 127)).to(torch.int8)
            codes['affine'] = code
            for h in range(2):
                dot = n[:, 2*g+h].double() @ code.double()
                attended = (dot.float() / 4095 + offset) * step
                results[split]['affine'] += attended @ left[h*1024:(h+1)*1024].T
            if split == 'validation':
                code_hashes.append({key: hashlib.sha256(code.numpy().tobytes()).hexdigest()
                                    for key, code in codes.items()})
        print(f'group {g}', flush=True)
    # Conditional group offsets fit the actual composed post-O response on train.
    # This is a larger target-aware family than per-coordinate MSE offsets.
    selected = []
    train_current = results['train']['base'].clone()
    for g in range(8):
        original = group_candidates['train'][g][OFFSETS.index(0.)]
        losses = [float(((train_current - original + cand - states['train'][2]).square().sum()).item())
                  for cand in group_candidates['train'][g]]
        choice = min(range(len(losses)), key=losses.__getitem__)
        train_current += group_candidates['train'][g][choice] - original
        selected.append(OFFSETS[choice])
    results['train']['group_response'] = train_current
    results['validation']['group_response'] = results['validation']['base'].clone()
    for g, choice in enumerate(selected):
        results['validation']['group_response'] += (group_candidates['validation'][g][OFFSETS.index(choice)]
                                                    - group_candidates['validation'][g][OFFSETS.index(0.)])
    scores = {split: {key: {'teacher': relative(y, states[split][2]),
                            'per_window': [relative(y[i], states[split][2][i]) for i in range(y.shape[0])],
                            'vs_base': relative(y, results[split]['base'])}
                      for key, y in ys.items()}
              for split, ys in results.items()}
    assert abs(scores['validation']['base']['teacher'] - prior['scores']['int8_mass4095']['teacher']) < 2e-6
    receipt = {'layer': layer, 'source_sha256': sha(Path(__file__)), 'parent_receipt_sha256': sha(prior_path),
               'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
               'image_sha256': sha(image_path), 'factor_source_sha256': sha(SOURCE),
               'offset_grid': OFFSETS, 'coordinate_mse_offsets_by_group': choices,
               'train_composed_response_group_offsets': selected,
               'validation_code_hashes_by_group': code_hashes,
               'scores': scores, 'domain': 'eight original-producer train and four previously inspected held 256-token windows; frozen paid V/O factors and FP16 steps',
               'cost': {'cache_bytes_per_token': 224,
                        'coordinate_grid_index_bytes_per_layer_packed': 84,
                        'group_grid_index_bytes_per_layer_packed': 3,
                        'alternative_fp32_output_bias_bytes_per_layer': 4096,
                        'alternative_bf16_output_bias_bytes_per_layer_approximate': 2048,
                        'additional_pre_O_coordinate_adds_per_query': 448,
                        'integer_dot_products': 'same as paid 4095 signed-byte reader',
                        'append_code_operations': 'one offset subtraction per coordinate before rounding'},
               'boundary': 'grid offsets and FP16 steps decode exactly as binary floating values; conserved integer count factoring is real algebra, while FP32 paid O folding and a precomputed output bias are not bit identities'}
    dest = DATA / 'value-int8-affine' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'scores': {s: {k: v['teacher'] for k, v in scores[s].items()} for s in scores}}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
