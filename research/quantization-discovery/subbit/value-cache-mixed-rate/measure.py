#!/usr/bin/env python3
"""Frozen shared-V mixed 3/5-bit allocation against the complete two-head response."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'value-observer'))
from fit_direct import SOURCE
spec = importlib.util.spec_from_file_location('base', ROOT / 'value-centered-int4/measure.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
DATA = Path('/path/to/workspace/data/kelana-subbit/value-cache-mixed-rate')


def paths(layer, split):
    return DATA / f'layer{layer:02d}-{split}.npz'


def prepare(layer, split):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('quant', SOURCE)
    quant = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quant)
    factor = DATA.parent / 'value-nibble-basis' / f'layer{layer:02d}-nibble-left.npz'
    with np.load(factor) as archive:
        groups = [{k: archive[k][g].copy() for k in archive.files} for g in range(8)]
    right = [quant.decode(g, 'right') for g in groups]
    left = torch.cat([quant.decode(groups[g], 'left')[h*1024:(h+1)*1024].T for g in range(8) for h in range(2)])
    with safe_open(base.MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'q_norm', 'k_norm', 'v_proj', 'o_proj')}
    x = base.load_capture(layer, split).reshape(-1, 256, 1024)[:8 if split == 'train' else 4]
    p = base.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    y = base.dense_attention(p, x, w['v_proj'], w['o_proj']).reshape(-1, 1024)
    z = torch.stack([(x @ r.T).to(torch.bfloat16).float() for r in right], dim=1)
    DATA.mkdir(parents=True, exist_ok=True)
    np.savez(paths(layer, split), p=p.numpy(), y=y.numpy(), z=z.numpy(), left=left.numpy())
    print(paths(layer, split), flush=True)


def cached(layer, split):
    with np.load(paths(layer, split)) as a:
        return (torch.from_numpy(a['p'].copy()), torch.from_numpy(a['y'].copy()),
                torch.from_numpy(a['z'].copy()), torch.from_numpy(a['left'].copy()))


def codes(z, step, bits):
    return (z / step).round().clamp(-(1 << (bits-1)), (1 << (bits-1))-1) * step


def run(layer):
    torch.set_num_threads(8)
    train = cached(layer, 'train')
    held = cached(layer, 'validation')
    meta_path = DATA.parent / 'value-nibble-joint-fit' / f'layer{layer:02d}-8x4.json'
    metadata = json.loads(meta_path.read_text())['selected']
    # Paired response features of the frozen paid output decoder.
    def responses(state, bit_map, steps):
        p, y, z, left = state
        chunks = []
        for g in range(8):
            val = torch.stack([((z[:, g, :, j] / steps[g, j]).round().clamp(max=7).clamp(min=int(lows[g, j])) * steps[g, j])
                               if bit_map[g, j] == 4 else codes(z[:, g, :, j], steps[g, j], int(bit_map[g, j]))
                               for j in range(28)], dim=-1)
            for h in range(2):
                chunks.append(p[:, 2*g+h] @ val)
        return torch.cat(chunks, dim=-1).reshape(-1, 448) @ left

    base_step = torch.tensor([metadata[g]['steps'] for g in range(8)])
    lows = torch.tensor([metadata[g]['lows'] for g in range(8)])
    # The parent used per-coordinate -7 or -8 lower endpoints.
    def parent(state):
        p, _, z, left = state
        parts = []
        for g in range(8):
            val = (z[:, g] / base_step[g]).round().clamp(max=7).maximum(lows[g]) * base_step[g]
            for h in range(2):
                parts.append(p[:, 2*g+h] @ val)
        return torch.cat(parts, dim=-1).reshape(-1, 448) @ left

    baseline = {name: parent(state) for name, state in [('train', train), ('validation', held)]}
    # Choose each candidate step from training coordinate error, then select the
    # promoted and demoted coordinates by exact full-response one-coordinate deltas.
    p, y, z, left = train
    residual = baseline['train'] - y
    savings = {}
    options = {}
    for g in range(8):
        for j in range(28):
            original = (z[:, g, :, j] / base_step[g, j]).round().clamp(max=7).clamp(min=int(lows[g, j])) * base_step[g, j]
            for bits in (3, 5):
                values = z[:, g, :, j].flatten()
                scales = torch.quantile(values.abs(), torch.tensor([.90, .99, 1.]))[:, None] * torch.tensor([.5, 1., 2., 4.])[None, :] / ((1 << (bits-1))-1)
                scales = torch.cat((scales.flatten(), base_step[g, j].view(1))).half().float().clamp_min(1e-8)
                mse = torch.stack([(codes(values, s, bits)-values).square().mean() for s in scales])
                step = scales[mse.argmin()]
                delta = torch.stack([(p[:, 2*g+h] @ (codes(z[:, g, :, j], step, bits)-original).unsqueeze(-1)).squeeze(-1)
                                     for h in range(2)], dim=-1).reshape(-1, 2)
                cols = left[(2*g)*28+j], left[(2*g+1)*28+j]
                projection = delta @ torch.stack(cols)
                change = float((2*residual*projection + projection.square()).sum())
                savings[(g, j, bits)] = change
                options[(g, j, bits)] = float(step)
        print('scored group', g, flush=True)
    coords = [(g, j) for g in range(8) for j in range(28)]
    # Under a 4-bit mean budget, one 5-bit coordinate finances one 3-bit coordinate.
    # The one-coordinate surrogate is additive; the complete selected map is replayed.
    # Each group occupies exactly 112 bits and fits a 16-byte cache line.
    # For each group and pair count, choose the smallest independent 3-bit
    # deltas, then the smallest disjoint 5-bit deltas. DP allocates pair counts
    # across groups under the train surrogate; exact train response selects n.
    allocations = []
    for g in range(8):
        local3 = sorted(range(28), key=lambda j: savings[(g,j,3)])
        local5 = sorted(range(28), key=lambda j: savings[(g,j,5)])
        choices = []
        for k in range(15):
            if k == 1:
                _, i, j = min((savings[(g,i,3)]+savings[(g,j,5)], i, j)
                              for i in range(28) for j in range(28) if i != j)
                a, b = {i}, {j}
            else:
                a = set(local3[:k])
                b = set([j for j in local5 if j not in a][:k])
            choices.append((sum(savings[(g,j,3)] for j in a) + sum(savings[(g,j,5)] for j in b), a, b))
        allocations.append(choices)
    dp = {0: (0., [])}
    for g in range(8):
        next_dp = {}
        for n, (score, choice) in dp.items():
            for k, (cost, _, _) in enumerate(allocations[g]):
                m = n+k
                if m not in next_dp or score+cost < next_dp[m][0]:
                    next_dp[m] = score+cost, choice+[k]
        dp = next_dp
    candidates = []
    for pairs in (0, 1, 2, 4, 8, 16, 32, 56, 80, 112):
        _, counts = dp[pairs]
        bit_map = np.full((8, 28), 4, dtype=np.int8)
        steps = base_step.clone()
        for g, k in enumerate(counts):
            _, a, b = allocations[g][k]
            for bits, selected in ((3, a), (5, b)):
                for j in selected:
                    bit_map[g, j] = bits
                    steps[g, j] = options[(g, j, bits)]
        out = responses(train, bit_map, steps)
        candidates.append((pairs, float(((out-y).square().sum()/y.square().sum())), bit_map, steps))
    selected = min(candidates, key=lambda item: item[1])
    # Include original parent and a strict uniform-four-bit same-decoder control.
    control = responses(train, np.full((8,28),4), base_step)
    hp, hy, _, _ = held
    def score(out, state):
        target = state[1]
        return {'relative': float((out-target).square().sum()/target.square().sum()),
                'windows': [float((out[i*256:(i+1)*256]-target[i*256:(i+1)*256]).square().sum() /
                                  target[i*256:(i+1)*256].square().sum()) for i in range(len(target)//256)]}
    bit_map, steps = selected[2:]
    receipt = {'layer': layer, 'selected_pairs': selected[0], 'candidates': [{'pairs': n, 'train_error': e} for n,e,*_ in candidates],
               'parent': {'train': score(baseline['train'], train), 'held': score(baseline['validation'], held)},
               'uniform_4bit_step_control': {'train': score(control, train), 'held': score(responses(held, np.full((8,28),4), base_step), held)},
               'mixed': {'train': score(responses(train, bit_map, steps), train), 'held': score(responses(held, bit_map, steps), held)},
               'bits': bit_map.tolist(), 'steps': steps.tolist(), 'coordinate_deltas': {f'{g}:{j}': {'three': savings[(g,j,3)], 'five': savings[(g,j,5)]} for g,j in coords},
               'logical_cache_bytes': 112, 'padded_per_group_bytes': [((sum(int(v) for v in row)+7)//8) for row in bit_map],
               'source_sha256': base.digest(HERE), 'model_sha256': base.digest(base.MODEL),
               'capture_sha256': base.digest(base.CAPTURES / f'layer{layer:02d}.npz'),
               'paid_left_sha256': base.digest(DATA.parent / 'value-nibble-basis' / f'layer{layer:02d}-nibble-left.npz'),
               'parent_cache_sha256': base.digest(meta_path),
               'prepared_sha256': {s: base.digest(paths(layer,s)) for s in ('train','validation')},
               'contract': 'Original-producer Qwen3-0.6B, eight 256-token train and four repeatedly inspected held windows. Frozen rank-28 right and paid 2-bit O. FP32 probability in prepared fixture; per-coordinate train-MSE 3/5-bit scales; 4-bit baseline steps, 3/5 coordinate deltas on complete post-O response; disjoint greedy group assignments and global train-surrogate pair-count DP, exact train selection and held replay. Every group packs 112 bits. No native timing or model loss.'}
    out = DATA / f'layer{layer:02d}.json'
    out.write_text(json.dumps(receipt, indent=2)+'\n')
    print(out, 'parent', receipt['parent']['held']['relative'], 'mixed', receipt['mixed']['held']['relative'], flush=True)


if __name__ == '__main__':
    a = argparse.ArgumentParser()
    a.add_argument('mode', choices=['prepare', 'fit'])
    a.add_argument('--layer', type=int, choices=[0,14], required=True)
    a.add_argument('--split', choices=['train','validation'])
    args = a.parse_args()
    if args.mode == 'prepare':
        prepare(args.layer, args.split)
    else:
        run(args.layer)
