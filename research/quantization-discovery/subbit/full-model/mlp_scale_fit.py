#!/usr/bin/env python3
"""Refit paid binary gate/up/down row scales against the complete layer-0 SwiGLU map."""
import argparse
import json
from pathlib import Path

import numpy as np
import torch

from mlp_factor_response import ROOT, PARTS, digest, error, unpack_bf16, weight


def response(g, u, down, log_gate, log_up, log_down):
    hidden = torch.nn.functional.silu(g * log_gate.exp()) * u * log_up.exp()
    return (hidden @ down.T) * log_down.exp()


def rounded_scales(source, log_multiplier):
    with np.load(source) as f:
        stored = f['scale_post'].astype(np.float32)
    new = (stored * log_multiplier.detach().exp().numpy()).astype(np.float16)
    return torch.from_numpy(new.astype(np.float32) / stored), new


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--train-rows', type=int, default=2048)
    parser.add_argument('--steps', type=int, default=16)
    parser.add_argument('--lr', type=float, default=.025)
    parser.add_argument('--ridge', type=float, default=.002)
    args = parser.parse_args()
    torch.set_num_threads(8)
    torch.manual_seed(20260922)
    files, w, paths = {}, {}, {}
    for part in PARTS:
        for quant in (False, True):
            tensor, path, sha = weight(part, quant)
            w[part, quant] = tensor
            files[path] = sha
            if quant:
                paths[part] = path
    capture = ROOT / 'capture/layer00.npz'
    files[str(capture)] = digest(capture)
    with np.load(capture) as f:
        inputs = {'train': unpack_bf16(f['train_gate_up'][:args.train_rows]),
                  'held': unpack_bf16(f['validation_gate_up'][:1024])}
    rows = {}
    for split, x in inputs.items():
        g = x @ w['gate', True].T
        u = x @ w['up', True].T
        gold_g = x @ w['gate', False].T
        gold_u = x @ w['up', False].T
        gold = (torch.nn.functional.silu(gold_g) * gold_u) @ w['down', False].T
        rows[split] = g, u, gold
    logs = {p: torch.nn.Parameter(torch.zeros(w[p, True].shape[0])) for p in PARTS}
    optimizer = torch.optim.Adam(list(logs.values()), lr=args.lr)
    g, u, gold = rows['train']
    baseline = response(g, u, w['down', True], *(logs[p] for p in PARTS))
    denom = gold.square().sum().detach()
    history = [{'step': 0, 'train_error': error(gold, baseline)}]
    for step in range(1, args.steps + 1):
        optimizer.zero_grad(set_to_none=True)
        prediction = response(g, u, w['down', True], *(logs[p] for p in PARTS))
        objective = (prediction - gold).square().sum() / denom
        penalty = args.ridge * sum(v.square().mean() for v in logs.values())
        (objective + penalty).backward()
        optimizer.step()
        history.append({'step': step, 'train_error': float(objective.detach()),
                        'penalty': float(penalty.detach())})
    rounded = {p: rounded_scales(paths[p], logs[p]) for p in PARTS}
    results = {}
    for split, (g, u, gold) in rows.items():
        with torch.no_grad():
            baseline = response(g, u, w['down', True], *(torch.zeros_like(logs[p]) for p in PARTS))
            continuous = response(g, u, w['down', True], *(logs[p] for p in PARTS))
            stored = response(g, u, w['down', True], *(rounded[p][0].log() for p in PARTS))
            results[split] = {'binary': error(gold, baseline), 'continuous': error(gold, continuous),
                              'stored_fp16_scales': error(gold, stored)}
            for subset in (('gate',), ('up',), ('down',), ('gate', 'up'), ('gate', 'down'), ('up', 'down')):
                multipliers = [rounded[p][0].log() if p in subset else torch.zeros_like(logs[p])
                               for p in PARTS]
                results[split]['stored_' + '_'.join(subset)] = error(
                    gold, response(g, u, w['down', True], *multipliers))
    image = ROOT / f'mlp-scale-fit-{args.train_rows}-image'
    image.mkdir(exist_ok=True)
    outputs = {}
    for p in PARTS:
        path = image / f'layer00-mlp_{p}_proj.npz'
        with np.load(paths[p]) as f:
            payload = {k: f[k] for k in f.files}
        payload['scale_post'] = rounded[p][1]
        np.savez_compressed(path, **payload)
        outputs[str(path)] = digest(path)
    receipt = {'format': 'layer0-paid-mlp-scale-fit/1', 'source_sha256': digest(Path(__file__)),
               'inputs_sha256': files, 'output_sha256': outputs, 'train_rows': args.train_rows,
               'held_rows': len(rows['held'][0]), 'steps': args.steps, 'lr': args.lr,
               'ridge': args.ridge, 'history': history, 'results': results,
               'observation': 'Original-producer BF16 layer-0 input; FP32 gate/up/down response. Existing binary codes and FP16 scale slots, no new bits or inference operations.'}
    output = ROOT / f'mlp-scale-fit-{args.train_rows}.json'
    output.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(output), 'results': results, 'last_train_step': history[-1]}, indent=2))


if __name__ == '__main__':
    main()
