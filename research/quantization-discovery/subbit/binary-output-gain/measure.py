#!/usr/bin/env python3
"""Fit already-stored FP16 output-factor row scales to a complete A7 reader."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
BASE = Path(__file__).resolve().parents[1]
PARENT = BASE / 'binary-scale-selector/measure.py'
spec = importlib.util.spec_from_file_location('binary_scale_selector', PARENT)
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def score(pred, target):
    d = pred - target
    return {'relative_rms': float(np.linalg.norm(d) / np.linalg.norm(target)),
            'per_row_wins': None}


def fit(pred, target, post):
    # No extra parameters in the image: replace each existing FP16 post scale.
    num = np.einsum('bn,bn->n', pred, target)
    den = np.einsum('bn,bn->n', pred, pred)
    ratio = np.maximum(num / np.maximum(den, 1e-100), 0)
    selected = (post * ratio).astype(np.float16).astype(np.float64)
    gain = selected / post
    return gain, selected


def run(layer, train_start):
    image = parent.IMAGES / f'model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
    fixture = parent.FIXTURES / f'layer{layer:02d}-mlp_up_proj.npz'
    with np.load(image) as f:
        n, k, rank = map(int, f['dimensions'])
        v = 2 * np.unpackbits(f['V'], axis=1, count=k, bitorder='little').astype(np.int16) - 1
        u = 2 * np.unpackbits(f['U'], axis=1, count=rank, bitorder='little').astype(np.int16) - 1
        pre, post = f['scale_pre'].astype(np.float64), f['scale_post'].astype(np.float64)
    with np.load(fixture) as f:
        xs = {'train': f['train'][train_start:576].astype(np.float64),
              'held': f['validation'][576:704].astype(np.float64)}
        weight = f['weight'].astype(np.float64)
    splits = {}
    for name, x in xs.items():
        c = parent.first_candidates(x, v, pre, u, post)
        pred = parent.second_output(c, parent.choose(c, np.full(k // 32, .75)), u, post)
        splits[name] = (pred, c['truth'], x @ weight.T)
    train, held = splits['train'], splits['held']
    cases = {}
    for objective, target_col in [('same_image', 1), ('teacher', 2)]:
        gain, replacement = fit(train[0], train[target_col], post)
        report = {'replacement_scale_sha256': hashlib.sha256(replacement.astype('<f2').tobytes()).hexdigest(),
                  'changed_scales': int(np.count_nonzero(replacement != post)),
                  'gain_min_median_max': [float(np.min(gain)), float(np.median(gain)), float(np.max(gain))],
                  'splits': {}}
        for name, (prediction, image_truth, teacher) in splits.items():
            truth = image_truth if target_col == 1 else teacher
            before = score(prediction, truth)
            after = score(prediction * gain[None, :], truth)
            original_row_error = np.sum((prediction - truth)**2, axis=0)
            updated_row_error = np.sum((prediction * gain[None, :] - truth)**2, axis=0)
            after['per_row_wins'] = int(np.count_nonzero(updated_row_error < original_row_error))
            after['response_sha256'] = hashlib.sha256(np.ascontiguousarray(prediction * gain[None, :]).tobytes()).hexdigest()
            report['splits'][name] = {'before': before, 'after': after}
        # A held-only fit is an unattainable oracle for this frozen activation panel;
        # it bounds how much the existing post-scale coordinate could recover.
        oracle_gain, _ = fit(held[0], held[target_col], post)
        report['held_oracle_rms'] = score(held[0] * oracle_gain[None, :], held[target_col])['relative_rms']
        # One shared scalar is a lower-variance alternative with the same read work.
        scalar = max(float(np.sum(train[0] * train[target_col]) / np.sum(train[0] * train[0])), 0)
        global_gain = (post * scalar).astype(np.float16).astype(np.float64) / post
        report['global_train_gain'] = scalar
        report['global_held_rms'] = score(held[0] * global_gain[None, :], held[target_col])['relative_rms']
        cases[objective] = report
    return {'layer': layer, 'image_sha256': digest(image), 'fixture_sha256': digest(fixture),
            'train_rows': [train_start, 576], 'held_validation_rows': [576, 704],
            'dimensions': [n, k, rank], 'cases': cases}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('layer', type=int)
    parser.add_argument('--train-start', type=int, default=512, choices=(320, 512))
    args = parser.parse_args()
    row = run(args.layer, args.train_start)
    dest = ROOT / 'binary-output-gain' / f'layer{args.layer:02d}-train{576 - args.train_start}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps({'source_sha256': digest(Path(__file__)), 'parent_sha256': digest(PARENT),
        'contract': f'Paid frozen binary factors; safe .75 group A7 at both integer boundaries; {576 - args.train_start} train and 128 fresh validation original-producer mlp_up rows. Nonnegative optimal independent row gain fitted against either same-image or original-weight response; post scale rounded to FP16 before held evaluation. CPU FP64 response and teacher, no GPU or model NLL.',
        **row}, indent=2) + '\n')
    print(args.layer, {name: {split: (report['before']['relative_rms'], report['after']['relative_rms'])
        for split, report in case['splits'].items()} for name, case in row['cases'].items()}, flush=True)
    print(dest)

if __name__ == '__main__':
    main()
