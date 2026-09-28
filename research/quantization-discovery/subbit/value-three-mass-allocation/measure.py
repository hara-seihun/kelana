#!/usr/bin/env python3
"""Exact three-mass head assignment on frozen, prepared original-producer V/O captures."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
PREP = DATA / 'value-cache-mixed-rate'
META = DATA / 'value-nibble-joint-fit'
OUT = DATA / 'value-three-mass-allocation'


def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for part in iter(lambda: f.read(1 << 20), b''):
            h.update(part)
    return h.hexdigest()


def count(p, mass):
    prefix = (p.double().cumsum(-1) * mass).round().long()
    prefix[..., -1] = mass
    prev = torch.nn.functional.pad(prefix[..., :-1], (1, 0))
    result = prefix-prev
    assert result.min() >= 0 and torch.all(result.sum(-1) == mass)
    return result


def response(layer, split):
    path = PREP / f'layer{layer:02d}-{split}.npz'
    with np.load(path) as data:
        p, z, left = (torch.from_numpy(data[k].copy()) for k in ('p', 'z', 'left'))
    metadata = META / f'layer{layer:02d}-8x4.json'
    selected = json.loads(metadata.read_text())['selected']
    step = torch.tensor([v['steps'] for v in selected])
    lows = torch.tensor([v['lows'] for v in selected])
    codes = (z / step[None, :, None, :]).round().clamp(max=7).maximum(lows[None, :, None, :])
    values = codes*step[None, :, None, :]
    x = torch.stack((values, values), dim=2).reshape(z.shape[0], 16, 256, 28)
    outputs, slots = [], []
    for mass in (4095, 255, 15):
        n = count(p, mass)
        narrow = torch.matmul(n.float().reshape(-1, 256, 256), x.reshape(-1, 256, 28)).reshape(p.shape[0], 16, 256, 28) / mass
        full = torch.stack([narrow[:, h] @ left[h*28:(h+1)*28] for h in range(16)])
        outputs.append(full.double())
        digits = 3 if mass == 4095 else 2 if mass == 255 else 1
        per_head = torch.zeros(16, dtype=torch.long)
        for digit in range(digits):
            present = ((n >> (4*digit)) & 15) != 0
            per_head += ((present.sum(-1) + 3)//4*4).sum((0, 2)) * 4
        slots.append(per_head.tolist())
    return outputs, np.array(slots).T, {'prepared_sha256': digest(path), 'cache_fit_sha256': digest(metadata)}


def run(layer):
    torch.set_num_threads(8)
    train, train_cost, tr_hash = response(layer, 'train')
    held, held_cost, he_hash = response(layer, 'validation')
    baseline = train[0].sum(0)
    delta = torch.stack([train[i][h]-train[0][h] for h in range(16) for i in (1, 2)]).flatten(1)
    gram = (delta @ delta.T).numpy()
    denominator = float((baseline*baseline).sum())
    binary = HERE / 'search'
    input_text = '\n'.join([repr(denominator), ' '.join(map(str, train_cost.flatten()))] + [' '.join(repr(float(v)) for v in row) for row in gram])+'\n'
    searches = {}
    for budget in (1e-4, 2e-4, 5e-4, 1e-3, 2e-3, 5e-3, 1e-2):
        comparisons = {}
        for name, args in (('three_mass', []), ('two_mass_control', ['no15'])):
            raw = subprocess.run([str(binary), repr(budget), *args], input=input_text, text=True,
                                 capture_output=True, check=True, timeout=40)
            found = json.loads(raw.stdout)
            arms = found['arms']
            assert found['work'] == sum(train_cost[h, arm] for h, arm in enumerate(arms))
            original = held[0].sum(0)
            candidate = sum((held[arm][h] for h, arm in enumerate(arms)), torch.zeros_like(original))
            found['held_error'] = float(((candidate-original)**2).sum()/(original**2).sum())
            found['held_windows'] = [float(((candidate[w]-original[w])**2).sum()/(original[w]**2).sum()) for w in range(4)]
            found['held_work'] = int(sum(held_cost[h, arm] for h, arm in enumerate(arms)))
            comparisons[name] = found
        searches[str(budget)] = comparisons
        print(layer, budget, {name: {k: found[k] for k in ('work', 'train_error', 'held_error', 'held_work', 'arms')} for name, found in comparisons.items()}, flush=True)
    receipt = {'layer': layer, 'train_slots_per_head_mass_4095_255_15': train_cost.tolist(),
               'held_slots_per_head_mass_4095_255_15': held_cost.tolist(), 'train_denominator': denominator,
               'train_gram': gram.tolist(), 'budgets': searches,
               'hashes': {'source': digest(HERE/'measure.py'), 'search_source': digest(HERE/'search.cpp'),
                          'train': tr_hash, 'held': he_hash},
               'contract': '8 train and 4 repeatedly inspected validation original-producer 256-token windows; frozen refitted two-bit O basis and per-coordinate nibble steps/endpoints; prefix-rounded 4095/255/15 conserved masses, BF16-prepared rank-28 V and recorded FP32 probabilities. Four-lane issued nibble dot slots include padded nonzero lists but exclude compaction/softmax/O. Enumerate all 3^16 independent head assignments by incremental Gram quadratic and monotone-work branch pruning; select by train rounding-error budget, replay held output separately.'}
    OUT.mkdir(exist_ok=True)
    target = OUT/f'layer{layer:02d}.json'
    target.write_text(json.dumps(receipt, indent=2)+'\n')
    print(target, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
