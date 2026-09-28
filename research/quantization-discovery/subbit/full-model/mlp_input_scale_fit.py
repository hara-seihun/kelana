#!/usr/bin/env python3
"""Fit existing input and output scales through the complete binary layer-0 MLP."""
import argparse
import json
from pathlib import Path

import numpy as np
import torch

from mlp_factor_response import ROOT, PARTS, digest, error, unpack_bf16, weight


def mlp(x, weights, logs):
    gate = ((x * logs['gate_pre'].exp()) @ weights['gate'].T) * logs['gate_post'].exp()
    up = ((x * logs['up_pre'].exp()) @ weights['up'].T) * logs['up_post'].exp()
    return (torch.nn.functional.silu(gate) * up) @ weights['down'].T * logs['down_post'].exp()


def stored_scales(paths, logs):
    stored, effective = {}, {}
    for part in PARTS:
        with np.load(paths[part]) as f:
            payload = {key: f[key] for key in f.files}
        for side in ('pre', 'post') if part != 'down' else ('post',):
            key = f'scale_{side}'
            value = payload[key].astype(np.float32)
            updated = (value * logs[f'{part}_{side}'].detach().exp().numpy()).astype(np.float16)
            payload[key] = updated
            effective[f'{part}_{side}'] = torch.from_numpy(updated.astype(np.float32) / value)
        stored[part] = payload
    return stored, effective


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--train-rows', type=int, default=2048)
    parser.add_argument('--steps', type=int, default=16)
    parser.add_argument('--lr', type=float, default=.025)
    parser.add_argument('--ridge', type=float, default=.002)
    args = parser.parse_args()
    torch.set_num_threads(8)
    torch.manual_seed(20260922)
    files, weights, paths = {}, {}, {}
    for part in PARTS:
        for quant in (False, True):
            w, path, sha = weight(part, quant)
            weights[part, quant] = w
            files[path] = sha
            if quant:
                paths[part] = path
    capture = ROOT / 'capture/layer00.npz'
    files[str(capture)] = digest(capture)
    with np.load(capture) as f:
        inputs = {'train': unpack_bf16(f['train_gate_up'][:args.train_rows]),
                  'held': unpack_bf16(f['validation_gate_up'][:1024])}
    gold = {}
    for split, x in inputs.items():
        g = x @ weights['gate', False].T
        u = x @ weights['up', False].T
        gold[split] = (torch.nn.functional.silu(g) * u) @ weights['down', False].T
    quant = {part: weights[part, True] for part in PARTS}
    initial = {f'{part}_{side}': torch.zeros(weights[part, True].shape[0 if side == 'post' else 1])
               for part in PARTS for side in (('pre', 'post') if part != 'down' else ('post',))}
    baseline = {split: error(gold[split], mlp(x, quant, initial)) for split, x in inputs.items()}
    results, output_hashes = {}, {}
    for arm in ('output', 'joint'):
        logs = {name: torch.nn.Parameter(value.clone(), requires_grad=(arm == 'joint' or name.endswith('post')))
                for name, value in initial.items()}
        opt = torch.optim.Adam([v for v in logs.values() if v.requires_grad], lr=args.lr)
        history = []
        for step in range(1, args.steps + 1):
            opt.zero_grad(set_to_none=True)
            predicted = mlp(inputs['train'], quant, logs)
            objective = (predicted - gold['train']).square().sum() / gold['train'].square().sum()
            penalty = args.ridge * sum(v.square().mean() for v in logs.values())
            (objective + penalty).backward()
            opt.step()
            history.append({'step': step, 'train_error': float(objective.detach()),
                            'penalty': float(penalty.detach())})
        stored, effective = stored_scales(paths, logs)
        rounded = {name: value.log() for name, value in effective.items()}
        rounded.update({name: torch.zeros_like(value) for name, value in initial.items() if name not in rounded})
        scores = {split: error(gold[split], mlp(x, quant, rounded)) for split, x in inputs.items()}
        results[arm] = {'stored_fp16': scores, 'last_train_step': history[-1], 'history': history}
        if arm == 'joint':
            out_dir = ROOT / f'mlp-input-scale-{args.train_rows}-image'
            out_dir.mkdir(exist_ok=True)
            for part, payload in stored.items():
                path = out_dir / f'layer00-mlp_{part}_proj.npz'
                np.savez_compressed(path, **payload)
                output_hashes[str(path)] = digest(path)
    receipt = {'format': 'layer0-paid-mlp-input-scale/1', 'source_sha256': digest(Path(__file__)),
               'inputs_sha256': files, 'output_sha256': output_hashes, 'train_rows': args.train_rows,
               'held_rows': len(inputs['held']), 'steps': args.steps, 'lr': args.lr, 'ridge': args.ridge,
               'baseline': baseline, 'results': results,
               'observation': 'Original-producer BF16 layer-0 input; FP32 complete MLP response, binary factor codes unchanged. Both arms have identical train positions, loss, steps and optimizer. FP16 pre/post scales already paid in the binary image.'}
    out = ROOT / f'mlp-input-scale-{args.train_rows}.json'
    out.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(out), 'baseline': baseline,
                      'results': {key: value['stored_fp16'] for key, value in results.items()}}, indent=2))


if __name__ == '__main__':
    main()
