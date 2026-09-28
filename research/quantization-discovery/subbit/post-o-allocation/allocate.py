#!/usr/bin/env python3
"""Exact fixed-cardinality quadratic allocation for frozen Q head responses."""
import argparse
import hashlib
import itertools
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'attention-metric'))
from refine import FIXTURE, MODEL, attention, decode_right, left_from_codes, measure, prep, unpack_codes

SOURCE = Path('/path/to/workspace/data/kelana-subbit/attention-radial')
OUT = Path('/path/to/workspace/data/kelana-subbit/post-o-allocation')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def head_responses(raw, x, prepared, gamma, wo):
    logp, _, _ = attention(raw, x, *prepared, gamma, wo)
    value = prepared[1]
    h = (logp.exp() @ value).permute(1, 0, 2, 3).contiguous()
    return torch.stack([h[i].reshape(-1, 128) @ wo[:, 128*i:128*(i+1)].T for i in range(16)])


def quadratic(base, switched, reference):
    # A frozen head changes only its own V response. O is linear in those responses.
    # Use float64 for the offline quadratic; actual consumer scores use float32 O.
    delta = (switched - base).reshape(16, -1).double()
    reference = reference.reshape(-1, reference.shape[-1])
    residual = (base.sum(0) - reference).reshape(-1).double()
    linear = (delta @ residual).numpy()
    gram = (delta @ delta.T).numpy()
    constant = residual.square().sum().item()
    denominator = reference.double().square().sum().item()
    return constant, linear, gram, denominator


def enumerate_energies(coefficients, cardinality):
    constant, linear, gram, denominator = coefficients
    masks = np.zeros((len(list(itertools.combinations(range(16), cardinality))), 16), dtype=np.float64)
    for i, indices in enumerate(itertools.combinations(range(16), cardinality)):
        masks[i, indices] = 1
    energies = (constant + 2 * masks @ linear + np.einsum('ni,ij,nj->n', masks, gram, masks)) / denominator
    return masks.astype(bool), energies


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--split', choices=['train', 'validation'], required=True)
    args = ap.parse_args()
    torch.set_num_threads(8)
    OUT.mkdir(parents=True, exist_ok=True)
    paths = [SOURCE / f'layer00-q-left{bits}.npz' for bits in (2, 3)]
    with np.load(paths[0]) as z:
        two = {k: z[k].copy() for k in z.files}
    with np.load(paths[1]) as z:
        three = {k: z[k].copy() for k in z.files}
    assert all(np.array_equal(two[k], three[k]) for k in ('right_shape', 'right_codes', 'right_scales'))
    right = decode_right(two)
    left = [left_from_codes(unpack_codes(image['left_codes'], 2048, 88, bits), image, False)
            for bits, image in ((2, two), (3, three))]
    with np.load(FIXTURE) as z:
        x = torch.from_numpy(z[args.split].copy()).float().reshape(-1, 256, 1024)
        wq = torch.from_numpy(z['weight'].copy()).float()
    with safe_open(MODEL, framework='pt', device='cpu') as z:
        wk = z.get_tensor('model.layers.0.self_attn.k_proj.weight').float()
        wv = z.get_tensor('model.layers.0.self_attn.v_proj.weight').float()
        wo = z.get_tensor('model.layers.0.self_attn.o_proj.weight').float()
        qgamma = z.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma = z.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    with torch.no_grad():
        prepared = prep(x, wk, wv, qgamma, kgamma)
        teacher = measure(x, (x @ wq.T).to(torch.bfloat16).float(), wq, prepared, qgamma, wo)
        responses = x @ right.T
        raw = [(responses @ factor.T).to(torch.bfloat16).float() for factor in left]
        base, switched = [head_responses(q, x, prepared, qgamma, wo) for q in raw]
        coefficients = quadratic(base, switched, teacher['out'])
        masks, energies = enumerate_energies(coefficients, 8)
        winner = int(np.argmin(energies))
        head_rate = json.loads((Path('/path/to/workspace/data/kelana-subbit/head-rate/results.json')).read_text())
        train_selection = np.flatnonzero(masks[winner]).tolist() if args.split == 'train' else json.loads((OUT / 'train.json').read_text())['scores']['post_o']['heads']
        allocations = {'post_o': train_selection,
                       'held_oracle': np.flatnonzero(masks[winner]).tolist(),
                       'attention_kl': head_rate['allocation']['train_kl'],
                       'even': head_rate['allocation']['even'],
                       'reverse': head_rate['allocation']['reverse']}
        scored = {}
        for name, heads in allocations.items():
            chosen = np.zeros(16, dtype=bool)
            chosen[heads] = True
            matched = np.flatnonzero(np.all(masks == chosen, axis=1))[0]
            mixed = torch.where(torch.from_numpy(chosen.repeat(128))[:, None], left[1], left[0])
            observed = measure(x, (responses @ mixed.T).to(torch.bfloat16).float(), wq,
                               prepared, qgamma, wo, teacher)
            scored[name] = {'heads': heads, 'quadratic_output_error': float(energies[matched]),
                            'actual_output_error': observed['attention_output_relative_squared_error'],
                            'actual_attention_kl': observed['causal_attention_kl']}
        report = {'split': args.split, 'source_sha256': sha(Path(__file__)),
                  'fixture_sha256': sha(FIXTURE), 'model_sha256': sha(MODEL),
                  'input_image_sha256': [sha(p) for p in paths],
                  'head_rate_receipt_sha256': sha(Path('/path/to/workspace/data/kelana-subbit/head-rate/results.json')),
                  'windows': x.shape[0], 'tokens_per_window': x.shape[1],
                  'fixed_three_bit_heads': 8, 'combinations': len(energies),
                  'minimum_quadratic_output_error': float(energies[winner]),
                  'maximum_absolute_quadratic_actual_gap': max(abs(s['quadratic_output_error'] - s['actual_output_error']) for s in scored.values()),
                  'scores': scored}
        if args.split == 'train':
            chosen = np.zeros(16, dtype=bool)
            chosen[train_selection] = True
            rows3 = np.flatnonzero(chosen.repeat(128))
            rows2 = np.flatnonzero(~chosen.repeat(128))
            records = {'head_three_mask': np.packbits(chosen.astype(np.uint8), bitorder='little'),
                       'left_codes_two': two['left_codes'][rows2],
                       'left_codes_three': three['left_codes'][rows3],
                       'left_scales_two': two['left_scales'][rows2],
                       'left_scales_three': three['left_scales'][rows3],
                       'right_codes': two['right_codes'],
                       'right_scales': two['right_scales'],
                       'shape': np.array([2048, 1024, 88, 128], dtype=np.int32)}
            image_path = OUT / 'layer00-q-post-o-eight-heads.npz'
            np.savez(image_path, **records)
            report['image_sha256'] = sha(image_path)
            report['stored_bytes'] = sum(v.nbytes for v in records.values())
            report['bits_per_original_weight'] = 8 * report['stored_bytes'] / (2048 * 1024)
        (OUT / f'{args.split}.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report))


if __name__ == '__main__':
    main()
