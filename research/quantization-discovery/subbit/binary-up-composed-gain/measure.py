#!/usr/bin/env python3
"""Price existing binary up-row scales at the complete MLP output on paired Qwen producers."""
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
BASE = Path(__file__).resolve().parents[1]
PARENT = BASE / 'binary-scale-selector/measure.py'
IMAGE = ROOT / 'binary-factors/fixtures/model_layers_0_mlp_up_proj_weight_0.55.npz'
GATE = ROOT / 'full-model/fit-inputs/layer00-mlp_gate_proj.npz'
DOWN = ROOT / 'fixtures/qwen3-0.6b-wikitext/layer00-mlp_down_proj.npz'
UP = ROOT / 'fixtures/qwen3-0.6b-wikitext/layer00-mlp_up_proj.npz'
CAPTURE = ROOT / 'full-model/mlp-quantized-producer-capture.npz'
OUT = ROOT / 'binary-up-composed-gain/receipt.json'

spec = importlib.util.spec_from_file_location('binary_scale_selector', PARENT)
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bf16(bits):
    return (bits.astype(np.uint32) << 16).view(np.float32).astype(np.float64)


def a7_up(x, v, u, pre, post):
    """Same two-boundary safe A7 map as binary-scale-selector, without its threshold-sweep tensor."""
    a = (x * pre).reshape(len(x), -1, 32)
    maximum = np.max(np.abs(a), axis=2)
    global_max = np.maximum(maximum.max(axis=1), 1e-30)
    exp = np.minimum(np.floor(np.log2(global_max[:, None] / np.maximum(maximum, 1e-30))).astype(np.int32), 8)
    upper = global_max[:, None] / (63 * np.exp2(exp))
    lower = upper * .75
    use = (maximum / (63 * upper) <= .75) & (exp < 8)
    step = np.where(use, lower, upper)
    coeff = np.where(use, 3 << np.maximum(7 - exp, 0), 1 << (9 - exp)).astype(np.int32)
    q = np.clip(np.rint(a / step[:, :, None]), -64, 63).astype(np.int32)
    partial = np.einsum('rgk,bgk->brg', v.reshape(len(v), -1, 32).astype(np.int32), q, optimize=True)
    c = {'up': partial * coeff[:, None, :], 'delta': np.zeros_like(partial),
         'base': global_max / (63 * (1 << 9))}
    return parent.second_output(c, np.zeros((len(x), a.shape[1]), dtype=bool), u, post)


def gain(pred, target, post):
    ratio = np.maximum(np.sum(pred * target, axis=0) / np.maximum(np.sum(pred * pred, axis=0), 1e-100), 0)
    rounded = (post * ratio).astype(np.float16).astype(np.float64)
    return rounded / post, rounded


def score(pred, target):
    return float(np.linalg.norm(pred - target) / np.linalg.norm(target))


def main():
    with np.load(IMAGE) as f:
        n, k, rank = map(int, f['dimensions'])
        v = 2 * np.unpackbits(f['V'], axis=1, count=k, bitorder='little').astype(np.int16) - 1
        u = 2 * np.unpackbits(f['U'], axis=1, count=rank, bitorder='little').astype(np.int16) - 1
        pre, post = f['scale_pre'].astype(np.float64), f['scale_post'].astype(np.float64)
    with np.load(GATE) as f:
        gate_w = f['weight'].astype(np.float64)
    with np.load(DOWN) as f:
        down_w = f['weight'].astype(np.float64)
    with np.load(UP) as f:
        up_w = f['weight'].astype(np.float64)
    rows = {}
    with np.load(CAPTURE) as f:
        for producer in ('teacher', 'damaged'):
            for split, start, stop in (('train', 320, 576), ('held', 576, 704)):
                name = ('train' if split == 'train' else 'validation') + '_' + producer + '_input'
                x = bf16(f[name][start:stop])
                rows[producer, split] = x
    observations = {}
    for key, x in rows.items():
        predicted = np.concatenate([a7_up(batch, v, u, pre, post)
                                    for batch in np.array_split(x, (len(x) + 31) // 32)])
        teacher_up = x @ up_w.T
        gate = x @ gate_w.T
        gate = gate / (1 + np.exp(-gate))
        teacher = (gate * teacher_up) @ down_w.T
        observations[key] = (predicted, teacher_up, gate, teacher)
        print(key, 'up', score(predicted, teacher_up), 'mlp', score((gate * predicted) @ down_w.T, teacher), flush=True)
    training = observations['teacher', 'train']
    damaged_training = observations['damaged', 'train']
    fits = {}
    for label, data in (('teacher_up_original', training), ('teacher_up_damaged', damaged_training)):
        fits[label] = gain(data[0], data[1], post)
    fits['teacher_up_original_64'] = gain(training[0][-64:], training[1][-64:], post)
    fits['teacher_up_damaged_64'] = gain(damaged_training[0][-64:], damaged_training[1][-64:], post)
    fits['teacher_up_paired_512'] = gain(np.concatenate((training[0], damaged_training[0])),
                                         np.concatenate((training[1], damaged_training[1])), post)
    for label, data in (('composed_scalar_original', training), ('composed_scalar_damaged', damaged_training)):
        predicted, _, gate, teacher = data
        response = (gate * predicted) @ down_w.T
        scalar = max(float(np.sum(response * teacher) / np.sum(response * response)), 0)
        rounded = (post * scalar).astype(np.float16).astype(np.float64)
        fits[label] = (rounded / post, rounded)
    result = {'format': 'binary-up-composed-gain/1', 'source_sha256': sha(Path(__file__)),
              'inputs_sha256': {str(p): sha(p) for p in (PARENT, IMAGE, GATE, DOWN, UP, CAPTURE)},
              'shape': [n, k, rank], 'train_rows': [320, 576], 'held_validation_rows': [576, 704],
              'fits': {}, 'observations': {},
              'contract': 'FP64 replay of complete paid two-boundary A7 binary up reader; original BF16 gate and down weights in FP64, SiLU gate and full 1024-d MLP response. Original and damaged BF16 input captures are paired. Target is the original MLP applied at each arm input, not the original teacher post-layer residual. FP16 replacement up post scales, unchanged packed signs, bytes and online operations. Validation was previously inspected elsewhere; no GPU or model NLL.'}
    for label, (g, rounded) in fits.items():
        result['fits'][label] = {'scale_sha256': hashlib.sha256(rounded.astype('<f2').tobytes()).hexdigest(),
                                  'changed_scales': int(np.count_nonzero(rounded != post)),
                                  'gain_min_median_max': [float(np.min(g)), float(np.median(g)), float(np.max(g))]}
    for key, (pred, teacher_up, gate, teacher) in observations.items():
        name = '_'.join(key)
        base = (gate * pred) @ down_w.T
        case = {'input_sha256': hashlib.sha256(rows[key].tobytes()).hexdigest(),
                'target_sha256': hashlib.sha256(teacher.tobytes()).hexdigest(),
                'baseline_up_rms': score(pred, teacher_up), 'baseline_mlp_rms': score(base, teacher),
                'arms': {}}
        for label, (g, _) in fits.items():
            up = pred * g
            response = (gate * up) @ down_w.T
            case['arms'][label] = {'up_rms': score(up, teacher_up), 'mlp_rms': score(response, teacher),
                                   'response_sha256': hashlib.sha256(np.ascontiguousarray(response).tobytes()).hexdigest()}
        result['observations'][name] = case
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, indent=2) + '\n')
    print(OUT)
    for name, observation in result['observations'].items():
        print(name, observation['baseline_mlp_rms'],
              {label: values['mlp_rms'] for label, values in observation['arms'].items()}, flush=True)


if __name__ == '__main__':
    main()
