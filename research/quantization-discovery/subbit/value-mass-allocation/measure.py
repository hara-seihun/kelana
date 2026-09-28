#!/usr/bin/env python3
"""Exact train allocation of one-dot versus two-dot probability mass by Q head."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def counts(p, mass):
    prefix = (p.double().cumsum(-1) * mass).round().clamp(0, mass).to(torch.int32)
    prefix[..., -1] = mass
    n = torch.diff(prefix, dim=-1, prepend=torch.zeros_like(prefix[..., :1]))
    assert n.min() >= 0 and n.max() <= mass and torch.all(n.sum(-1) == mass)
    assert torch.all(n[p == 0] == 0)
    return n


def replay(layer, split, factor, meta, weights):
    x = load_capture(layer, split).reshape(-1, 256, 1024)[:8 if split == 'train' else 4]
    p = probabilities(x, weights['q_proj'], weights['k_proj'], weights['q_norm'], weights['k_norm'])
    n7, n12 = counts(p, 127), counts(p, 4095)
    heads = []
    alternative = []
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(factor) as image:
        for g in range(8):
            arrays = {key: image[key][g].copy() for key in image.files}
            left = decoder.decode(arrays, 'left')
            right = decoder.decode(arrays, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            entry = meta['metadata'][g]['int4_coordinate']
            step = torch.tensor(entry['step'])
            code = (z / step).round().clamp(-7, 7).to(torch.int8).float()
            for local in range(2):
                h = 2*g+local
                l = left[local*1024:(local+1)*1024]
                y12 = ((n12[:, h].float() @ code) * (step/4095)) @ l.T
                y7 = ((n7[:, h].float() @ code) * (step/127)) @ l.T
                heads.append(y12)
                alternative.append(y7)
            print(split, g, flush=True)
    head_outputs = torch.stack(heads)
    one_dot_outputs = torch.stack(alternative)
    base = head_outputs.sum(0)
    d = one_dot_outputs - head_outputs
    # This is the exact quadratic for frozen per-head maps, up to FP32 replay rounding.
    flat = d.reshape(16, -1).double()
    gram = (flat @ flat.T).numpy()
    energy = float(base.square().sum())
    teacher = dense_attention(p, x, weights['v_proj'], weights['o_proj'])
    return head_outputs, one_dot_outputs, gram, energy, teacher


def select(gram, energy):
    # Exhaust all 2^16 head subsets by recurrence; retain the minimum-error subset at each cardinality.
    cost = np.zeros(1 << 16)
    best = [(0., 0)] + [(float('inf'), 0) for _ in range(16)]
    for mask in range(1, 1 << 16):
        bit = mask & -mask
        i = bit.bit_length()-1
        prev = mask ^ bit
        cost[mask] = cost[prev] + gram[i, i] + 2 * sum(gram[i, j] for j in range(16) if prev & (1 << j))
        size = mask.bit_count()
        err = max(0., cost[mask] / energy)
        if err < best[size][0]:
            best[size] = (err, mask)
    return best


def score(two_dot, one_dot, mask, teacher):
    base = two_dot.sum(0)
    selected = [i for i in range(16) if mask & (1 << i)]
    candidate = torch.stack([one_dot[i] if i in selected else two_dot[i] for i in range(16)]).sum(0)
    difference = candidate - base
    return {'relative_to_12bit': float(difference.square().sum()/base.square().sum()),
            'relative_to_original': float((candidate-teacher).square().sum()/teacher.square().sum()),
            'per_window': [float(difference[w].square().sum()/base[w].square().sum()) for w in range(base.shape[0])]}


def run(layer):
    torch.set_num_threads(8)
    prior = DATA / 'value-centered-int4' / f'layer{layer:02d}-8x4.json'
    meta = json.loads(prior.read_text())
    factor = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(factor) == meta['image_sha256']
    parent = json.loads((DATA / 'value-integer-consumer' / f'layer{layer:02d}.json').read_text())
    assert parent['model_sha256'] == sha(MODEL)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    _, _, gram, energy, _ = replay(layer, 'train', factor, meta, w)
    best = select(gram, energy)
    held_two, held_one, _, _, held_teacher = replay(layer, 'validation', factor, meta, w)
    points = []
    for size, (err, mask) in enumerate(best):
        points.append({'one_dot_heads': size, 'mask': format(mask, '04x'), 'train_error': err,
                       'held': score(held_two, held_one, mask, held_teacher),
                       'products_per_key_layer': 448 * 2 - size*28})
    receipt = {'layer': layer, 'domain': 'eight original-producer 256-token train and four previously inspected validation windows; frozen paid V/O and signed-nibble coordinate codes',
               'masses': {'one_dot': 127, 'two_dot': 4095}, 'head_allocation': points,
               'model_sha256': parent['model_sha256'], 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': sha(factor), 'nibble_receipt_sha256': sha(prior),
               'integer_parent_sha256': sha(DATA / 'value-integer-consumer' / f'layer{layer:02d}.json'),
               'source_sha256': sha(Path(__file__)),
               'note': 'Train objective is probability-rounding post-O error relative to 12-bit code consumer, not original V/O quality. Two dots use signed-byte digits of counts; one-dot counts fit signed byte. All prep, nibble unpack, paid V/O and score work remains.'}
    dest = DATA / 'value-mass-allocation' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'receipt': str(dest), 'points': [(r['one_dot_heads'], r['train_error'], r['held']['relative_to_12bit']) for r in points]}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
