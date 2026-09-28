#!/usr/bin/env python3
"""Static one-byte shared value-cache experiment on the paid narrow V/O image."""
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
VO = HERE.parent / 'value-observer'
sys.path.insert(0, str(VO))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention

DATA = Path('/path/to/workspace/data/kelana-subbit/value-fp8-cache')
IMAGE = Path('/path/to/workspace/data/kelana-subbit/value-observer')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def quantize(z, kind, scale):
    if kind.startswith('int8'):
        return (z / scale).round().clamp(-127, 127).to(torch.int8).float() * scale
    dtype = torch.float8_e4m3fn if kind == 'e4m3' else torch.float8_e5m2
    cap = 448 if kind == 'e4m3' else 57344
    return (z / scale).clamp(-cap, cap).to(dtype).float() * scale


def select_scale(z, kind):
    cap = {'int8': 127, 'e4m3': 448, 'e5m2': 57344}[kind]
    # Train-only scalar choice; these candidates include a clipping arm and
    # a wider-range arm, but the subsequent causal response is not fitted.
    p = torch.quantile(z.abs().flatten(), torch.tensor([.95, .99, .999, 1.]))
    options = sorted({float(v / cap * f) for v in p for f in (.5, 1., 2., 4.) if v > 0})
    scores = [(float((quantize(z, kind, s) - z).square().mean()), s) for s in options]
    return min(scores), len(options)


def rel_error(y, target):
    return float(((y-target).square().sum() / target.square().sum()).item())


def main(layer):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('spectral_quant_pinned', SOURCE)
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
    for split, count in [('train', 8), ('validation', 4)]:
        x = load_capture(layer, split).reshape(count, 256, 1024)
        p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        teacher = dense_attention(p, x, w['v_proj'], w['o_proj'])
        states[split] = (x, p, teacher)
    kinds = ('bf16', 'e4m3', 'e5m2', 'int8', 'int8_coordinate')
    outputs = {split: {kind: torch.zeros_like(state[2]) for kind in kinds}
               for split, state in states.items()}
    scales = {}
    fitted_mse = {}
    candidates = {}
    for g, (left, right) in enumerate(factors):
        x_train = states['train'][0]
        z_train = (x_train @ right.T).to(torch.bfloat16).float()
        scales[g] = {}
        fitted_mse[g] = {}
        candidates[g] = {}
        for kind in kinds[1:]:
            if kind == 'int8_coordinate':
                choices = [select_scale(z_train[..., j], 'int8')[0] for j in range(28)]
                fitted_mse[g][kind] = float(np.mean([v[0] for v in choices]))
                scales[g][kind] = [v[1] for v in choices]
                candidates[g][kind] = 16 * 28
            else:
                (fitted_mse[g][kind], scales[g][kind]), candidates[g][kind] = select_scale(z_train, kind)
        for split, (x, p, teacher) in states.items():
            z = z_train if split == 'train' else (x @ right.T).to(torch.bfloat16).float()
            for kind in kinds:
                scale = torch.tensor(scales[g][kind]) if kind == 'int8_coordinate' else scales[g].get(kind)
                cache = z if kind == 'bf16' else quantize(z, kind, scale)
                for h in range(2):
                    output_slice = left[h*1024:(h+1)*1024]
                    outputs[split][kind] += (p[:, 2*g+h] @ cache) @ output_slice.T
    scores = {}
    for split, (_, _, teacher) in states.items():
        scores[split] = {
            kind: {'aggregate': rel_error(y, teacher),
                   'per_window': [rel_error(y[i], teacher[i]) for i in range(y.shape[0])],
                   'against_bf16': rel_error(y, outputs[split]['bf16'])}
            for kind, y in outputs[split].items()
        }
    DATA.mkdir(parents=True, exist_ok=True)
    receipt = {'layer': layer, 'model_revision': json.loads((MODEL.parent / 'source.json').read_text())['revision'],
               'image_sha256': sha(image_path), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
               'source_sha256': sha(Path(__file__)), 'model_sha256': sha(MODEL),
               'selection': 'train BF16 narrow-coordinate MSE among 16 percentile/cap choices; one scalar/group or 28 scalars/group for int8_coordinate',
               'scales': scales, 'train_cache_mse': fitted_mse, 'candidate_counts': candidates,
               'scores': scores, 'value_cache_bytes_per_token': dict.fromkeys(kinds[1:], 224) | {'bf16': 448},
               'kv_cache_bytes_per_token': dict.fromkeys(kinds[1:], 2272) | {'bf16': 2496},
               'metadata_bytes_per_layer': {'bf16': 0, 'e4m3': 16, 'e5m2': 16, 'int8': 16, 'int8_coordinate': 448}}
    path = DATA / f'layer{layer:02d}.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'held': {k: v['aggregate'] for k, v in scores['validation'].items()},
                      'train': {k: v['aggregate'] for k, v in scores['train'].items()}}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    main(parser.parse_args().layer)
