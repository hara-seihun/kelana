#!/usr/bin/env python3
"""Fit paid E4M3 cache scales against the two-head causal output, not cache MSE."""
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
from importlib.machinery import SourceFileLoader
cache_tools = SourceFileLoader('cache_tools', str(SUB / 'value-fp8-cache' / 'measure.py')).load_module()

DATA = Path('/path/to/workspace/data/kelana-subbit/value-fp8-causal-scale')
IMAGE = Path('/path/to/workspace/data/kelana-subbit/value-observer')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def error(y, target):
    return float((y - target).square().sum() / target.square().sum())


def main(layer):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('pinned_quant', SOURCE)
    quant = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quant)
    image_path = IMAGE / f'layer{layer:02d}-joint-r28.npz'
    with np.load(image_path) as source:
        image = {name: source[name].copy() for name in source.files}
    factors = [(quant.decode({name: val[g] for name, val in image.items()}, 'left'),
                quant.decode({name: val[g] for name, val in image.items()}, 'right')) for g in range(8)]
    with safe_open(MODEL, framework='pt', device='cpu') as source:
        w = {name: source.get_tensor(f'model.layers.{layer}.self_attn.{name}.weight').float()
             for name in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    states = {}
    for split, count in (('train', 8), ('validation', 4)):
        x = load_capture(layer, split).reshape(count, 256, 1024)
        p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        states[split] = (x, p, dense_attention(p, x, w['v_proj'], w['o_proj']))

    # Responses in the real output coordinate, including both heads for each group.
    train_candidates = []
    held_candidates = []
    train_bf = []
    held_bf = []
    options_by_group = []
    mse_choices = []
    for g, (left, right) in enumerate(factors):
        z = {split: (state[0] @ right.T).to(torch.bfloat16).float() for split, state in states.items()}
        p95 = torch.quantile(z['train'].abs().flatten(), torch.tensor([.95, .99, .999, 1.]))
        options = sorted({float(v / 448 * f) for v in p95 for f in (.5, 1., 2., 4.) if v > 0})
        options_by_group.append(options)
        mse_choices.append(min(range(len(options)), key=lambda i: float((cache_tools.quantize(z['train'], 'e4m3', options[i])-z['train']).square().mean())))

        def response(split, v):
            p = states[split][1]
            return sum((p[:, 2*g+h] @ v) @ left[h*1024:(h+1)*1024].T for h in range(2))

        train_bf.append(response('train', z['train']))
        held_bf.append(response('validation', z['validation']))
        train_candidates.append([response('train', cache_tools.quantize(z['train'], 'e4m3', s)) for s in options])
        held_candidates.append([response('validation', cache_tools.quantize(z['validation'], 'e4m3', s)) for s in options])
        print(f'layer {layer} group {g} candidates {len(options)}', flush=True)

    mse_output = {split: sum(cs[g][idx] for g, idx in enumerate(mse_choices))
                  for split, cs in (('train', train_candidates), ('validation', held_candidates))}
    choices = mse_choices.copy()
    total = mse_output['train'].clone()
    target = states['train'][2]
    sweeps = []
    for _ in range(2):
        changed = 0
        for g in range(8):
            residual = target - (total - train_candidates[g][choices[g]])
            # A group is evaluated against the full original teacher and all other groups.
            scores = [float((candidate - residual).square().sum()) for candidate in train_candidates[g]]
            selected = min(range(len(scores)), key=lambda i: scores[i])
            if selected != choices[g]:
                total += train_candidates[g][selected] - train_candidates[g][choices[g]]
                choices[g] = selected
                changed += 1
        sweeps.append({'changed_groups': changed, 'train_error': error(total, target), 'choice': choices.copy()})
        if not changed:
            break
    held_oracle_choices = mse_choices.copy()
    held_total = mse_output['validation'].clone()
    held_teacher = states['validation'][2]
    for _ in range(2):
        changed = 0
        for g in range(8):
            residual = held_teacher - (held_total - held_candidates[g][held_oracle_choices[g]])
            selected = min(range(len(held_candidates[g])),
                           key=lambda i: float((held_candidates[g][i] - residual).square().sum()))
            if selected != held_oracle_choices[g]:
                held_total += held_candidates[g][selected] - held_candidates[g][held_oracle_choices[g]]
                held_oracle_choices[g] = selected
                changed += 1
        if not changed:
            break
    result = {}
    for split, cs, bf in (('train', train_candidates, train_bf), ('validation', held_candidates, held_bf)):
        teacher = states[split][2]
        outputs = {'bf16': sum(bf), 'coordinate_mse_e4m3': mse_output[split],
                   'causal_e4m3': sum(cs[g][idx] for g, idx in enumerate(choices))}
        if split == 'validation':
            outputs['held_fitted_diagnostic'] = held_total
        result[split] = {name: {'aggregate': error(y, teacher),
                                'per_window': [error(y[i], teacher[i]) for i in range(y.shape[0])],
                                'vs_bf16': error(y, outputs['bf16'])}
                         for name, y in outputs.items()}
    DATA.mkdir(parents=True, exist_ok=True)
    receipt = {'layer': layer, 'source_sha256': sha(Path(__file__)),
               'parent_source_sha256': sha(SUB / 'value-fp8-cache' / 'measure.py'),
               'model_sha256': sha(MODEL), 'model_revision': json.loads((MODEL.parent / 'source.json').read_text())['revision'],
               'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'), 'image_sha256': sha(image_path),
               'options': options_by_group, 'mse_choices': mse_choices, 'causal_choices': choices,
               'held_fitted_diagnostic_choices': held_oracle_choices,
               'sweeps': sweeps, 'scores': result, 'e4m3_value_bytes_per_token': 224,
               'static_fp16_scale_bytes_per_layer': 16}
    path = DATA / f'layer{layer:02d}.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'train': {k: v['aggregate'] for k,v in result['train'].items()},
                      'held': {k: v['aggregate'] for k,v in result['validation'].items()},
                      'mse_choices': mse_choices, 'causal_choices': choices}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    main(parser.parse_args().layer)
