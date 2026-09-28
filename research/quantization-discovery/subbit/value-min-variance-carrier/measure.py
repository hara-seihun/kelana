#!/usr/bin/env python3
"""Minimum-variance exact-response carrier for frozen narrow-V one-digit attention."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open
from scipy.optimize import linprog

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('mass_parent', SUBBIT/'value-mass-allocation/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
DATA, MODEL, CAPTURES = parent.DATA, parent.MODEL, parent.CAPTURES


def carrier(c, p, metric, mass=15):
    p = p/p.sum()
    mu = p @ c
    delta = c - mu
    cost = np.einsum('ij,jk,ik->i', delta, metric, delta)
    # Rank reduction is unnecessary here: the 28 integer code coordinates are the constraints.
    result = linprog(cost, A_eq=np.vstack([np.ones(len(c)), c.T]),
                     b_eq=np.r_[1., mu], bounds=(0, None), method='highs-ds',
                     options={'primal_feasibility_tolerance': 1e-9,
                              'dual_feasibility_tolerance': 1e-9})
    if not result.success:
        raise RuntimeError(result.message)
    q = result.x
    gap = np.max(np.abs(q @ c - mu))
    if gap > 2e-7 or abs(q.sum()-1) > 2e-7 or q.min() < -1e-9:
        raise ArithmeticError((gap, q.sum(), q.min()))
    # Greedy conditional-expectation derandomization of iid draws from q.
    residual = np.zeros(c.shape[1])
    tally = np.zeros(len(c), dtype=np.int32)
    for _ in range(mass):
        score = np.einsum('ij,jk,ik->i', delta + residual, metric, delta + residual)
        choice = int(np.argmin(np.where(q > 1e-9, score, np.inf)))
        tally[choice] += 1
        residual += delta[choice]
    original = float(p @ cost) / mass
    optimal = float(q @ cost) / mass
    actual = float(residual @ metric @ residual) / mass**2
    if actual > optimal + 2e-7:
        raise ArithmeticError((actual, optimal))
    return tally, {'original_variance_bound': original, 'optimal_variance_bound': optimal,
                   'derandomized_error_to_float': actual,
                   'carrier_support': int(np.count_nonzero(q > 1e-9)),
                   'response_gap': float(gap), 'mass_support': int(np.count_nonzero(tally))}


def run(layer, windows):
    torch.set_num_threads(8)
    factor = DATA/'value-observer'/f'layer{layer:02d}-joint-r28.npz'
    meta_path = DATA/'value-centered-int4'/f'layer{layer:02d}-8x4.json'
    meta = json.loads(meta_path.read_text())
    assert meta['image_sha256'] == parent.sha(factor)
    head = {0: 7, 14: 12}[layer]
    decoder_spec = importlib.util.spec_from_file_location('decoder', parent.SOURCE)
    decoder = importlib.util.module_from_spec(decoder_spec)
    decoder_spec.loader.exec_module(decoder)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        weights = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
                   for k in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    with np.load(factor) as image:
        group = head//2
        arrays = {k: image[k][group].copy() for k in image.files}
        left = decoder.decode(arrays, 'left')[head%2*1024:(head%2+1)*1024].double().numpy()
        right = decoder.decode(arrays, 'right')
    step = np.array(meta['metadata'][group]['int4_coordinate']['step'], dtype=np.float64)
    metric = (step[:, None]*left.T) @ (left*step[None, :])
    records = {}
    for split, count in (('train', 8), ('validation', 4)):
        if split == 'train' and windows == 0:
            continue
        count = min(count, windows)
        x = parent.load_capture(layer, split).reshape(-1, 256, 1024)[:count]
        p = parent.probabilities(x, weights['q_proj'], weights['k_proj'], weights['q_norm'], weights['k_norm'])
        positions = (63, 127, 191, 255)
        indices = (torch.arange(count)[:, None], torch.tensor(positions)[None, :])
        prob = p[indices[0], head, indices[1]].reshape(-1, 256)
        ref = parent.counts(prob, 4095).numpy()
        prefix = parent.counts(prob, 15).numpy()
        z = (x @ right.T).to(torch.bfloat16).float()
        codes = (z/torch.tensor(step, dtype=torch.float32)).round().clamp(-7, 7).numpy().reshape(count, 256, 28)
        rows = []
        for j in range(count*4):
            w, t = divmod(j, 4)
            pos = positions[t]
            c = codes[w, :pos+1].astype(np.float64)
            p_row = prob[j, :pos+1].double().numpy()
            p_row /= p_row.sum()
            tally, evidence = carrier(c, p_row, metric)
            r = ref[j, :pos+1] @ c/4095
            pr = prefix[j, :pos+1] @ c/15
            chosen = tally @ c/15
            def error(v):
                d = v-r
                return float(d @ metric @ d)
            rows.append({'window': w, 'position': pos, **evidence,
                         'energy': float(r @ metric @ r),
                         'prefix_sq': error(pr), 'carrier_sq': error(chosen),
                         'reference_to_float_sq': error(p_row @ c)})
        energy = sum(row['energy'] for row in rows)
        records[split] = {'rows': rows, 'relative_prefix': sum(row['prefix_sq'] for row in rows)/energy,
                          'relative_carrier': sum(row['carrier_sq'] for row in rows)/energy,
                          'relative_original_bound': sum(row['original_variance_bound'] for row in rows)/energy,
                          'relative_optimal_bound': sum(row['optimal_variance_bound'] for row in rows)/energy}
        print(layer, split, records[split]['relative_prefix'], records[split]['relative_carrier'],
              records[split]['relative_optimal_bound'], flush=True)
    receipt = {'layer': layer, 'head': head, 'windows_per_split': windows, 'records': records,
               'model_sha256': parent.sha(MODEL), 'capture_sha256': parent.sha(CAPTURES/f'layer{layer:02d}.npz'),
               'factor_sha256': parent.sha(factor), 'cache_fit_sha256': parent.sha(meta_path),
               'source_sha256': parent.sha(HERE),
               'scope': 'CPU original-producer sampled head, four fixed causal positions per window. LP preserves the frozen nibble-code float response. Relative errors use the frozen 4095-count response. No native latency or model loss.'}
    dest = DATA/'value-min-variance-carrier'/f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(dest, flush=True)


if __name__ == '__main__':
    a = argparse.ArgumentParser()
    a.add_argument('--layer', type=int, choices=(0, 14), required=True)
    a.add_argument('--windows', type=int, default=4)
    args = a.parse_args()
    run(args.layer, args.windows)
