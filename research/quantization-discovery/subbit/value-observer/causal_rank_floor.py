#!/usr/bin/env python3
"""Separate fixed narrow-feature capacity from the paid causal decoder's error."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from causal_refit import load_image, response_features
from fit import MODEL
from fit_direct import SOURCE, sha
from measure import probabilities, dense_attention

OUT = Path('/path/to/workspace/data/kelana-subbit/value-observer')


def solve(z, y):
    # An orthogonal projection, with the numerical rank declared in the receipt.
    u, s, vt = torch.linalg.svd(z.double(), full_matrices=False)
    keep = s > s[0] * 1e-8
    coeff = (vt[keep].T / s[keep]) @ (u[:, keep].T @ y.double())
    return coeff.float(), int(keep.sum()), float(s[keep][-1] / s[0])


def score(z, y, coeff):
    p = (z @ coeff).reshape(-1, 256, 1024)
    t = y.reshape(-1, 256, 1024)
    return {'aggregate': float(((p-t)**2).sum() / (t*t).sum()),
            'per_window': (((p-t)**2).sum((1, 2)) / (t*t).sum((1, 2))).tolist()}


def ridge_family(z, y, penalties):
    gram = z.T @ z / len(z)
    cross = z.T @ y / len(z)
    eigen, vectors = torch.linalg.eigh(gram.double())
    projected = vectors.T @ cross.double()
    scale = float(eigen.sum() / len(eigen))
    return [(vectors @ (projected / (eigen[:, None] + scale * penalty))).float()
            for penalty in penalties]


def run(arm, ridge):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('pinned_spectral_quant', SOURCE)
    q = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(q)
    path = OUT / f'layer14-quantized-upstream-right-{arm}.npz'
    images = load_image(path)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {n: model.get_tensor(f'model.layers.14.self_attn.{n}.weight').float()
             for n in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    data_path = OUT / 'layer14-quantized-upstream.npz'
    with np.load(data_path) as data:
        inputs = {split: torch.from_numpy(data[split].copy().view(np.int16)).view(torch.bfloat16).float()
                  for split in ('train', 'validation')}
    features, targets = {}, {}
    for split, x in inputs.items():
        p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        features[split] = response_features(x, p, images, q).reshape(-1, 384)
        targets[split] = dense_attention(p, x, w['v_proj'], w['o_proj']).reshape(-1, 1024)
    paid = torch.cat([q.decode(images[h//2], 'left')[((h%2)*1024):((h%2+1)*1024)]
                      for h in range(16)], dim=1).T
    if ridge:
        penalties = [1e-5, 1e-4, 1e-3, 1e-2, .1, 1., 10.]
        loo = [[] for _ in penalties]
        train_z, train_y = features['train'].reshape(4, 256, 384), targets['train'].reshape(4, 256, 1024)
        for held in range(4):
            training = [n for n in range(4) if n != held]
            candidates = ridge_family(train_z[training].reshape(-1, 384),
                                      train_y[training].reshape(-1, 1024), penalties)
            for values, coeff in zip(loo, candidates):
                values.append(score(train_z[held], train_y[held], coeff)['aggregate'])
        selected = min(range(len(penalties)), key=lambda i: sum(loo[i]))
        candidates = ridge_family(features['train'], targets['train'], penalties)
        scores = {str(penalty): {split: score(features[split], targets[split], coeff)
                                for split in ('train', 'validation')}
                  for penalty, coeff in zip(penalties, candidates)}
        scores['paid'] = {split: score(features[split], targets[split], paid)
                          for split in ('train', 'validation')}
        starts = np.cumsum([0] + [int(image['right_shape'][0]) for image in images for _ in range(2)])
        decoded = []
        packed = {}
        for g, image in enumerate(images):
            left = torch.cat([candidates[selected][starts[h]:starts[h+1]].T for h in (2*g, 2*g+1)])
            quant = q.quantize(left.contiguous(), 2, 128, 'left')
            image.update(quant)
            decoded.extend([q.decode(image, 'left')[local*1024:(local+1)*1024].T
                            for local in range(2)])
            packed.update({f'group{g}_{key}': value for key, value in image.items()})
        assert sum(a.nbytes for a in packed.values()) == 183552
        rounded = torch.cat(decoded)
        scores['rounded_ridge'] = {split: score(features[split], targets[split], rounded)
                                   for split in ('train', 'validation')}
        output_image = OUT / f'layer14-causal-rank-floor-{arm}-ridge.npz'
        np.savez(output_image, **packed)
        extra = {'penalties': penalties, 'leave_one_train_window_out': loo,
                 'selected_penalty': penalties[selected], 'ridge_scale': 'trace(Z.T Z / N) / feature_count',
                 'rounded_image_sha256': sha(output_image), 'rounded_image_bytes': 183552}
        train_rank = held_rank = train_ratio = held_ratio = None
    else:
        fit, train_rank, train_ratio = solve(features['train'], targets['train'])
        oracle, held_rank, held_ratio = solve(features['validation'], targets['validation'])
        scores = {name: {split: score(features[split], targets[split], coeff)
                         for split in ('train', 'validation')}
                  for name, coeff in (('paid', paid), ('train_real_decoder', fit), ('held_real_oracle', oracle))}
        extra = {}
    result = {'arm': arm, 'contract': 'fixed paid two-bit right factors, BF16-rounded narrow values, original layer-14 Q/K and teacher V/O on quantized-producer inputs; free dense real left decoder, one shared coefficient matrix for all windows in each split; held fit is a diagnostic oracle, not a selectable image',
              'features': list(features['train'].shape), 'train_rank': train_rank,
              'held_rank': held_rank, 'train_min_singular_ratio': train_ratio,
              'held_min_singular_ratio': held_ratio, 'svd_relative_cutoff': 1e-8,
              'scores': scores, 'capture_sha256': sha(data_path), 'image_sha256': sha(path),
              'model_sha256': sha(MODEL), 'quantizer_sha256': sha(SOURCE),
              'source_sha256': sha(Path(__file__)), **extra}
    receipt = OUT / f'layer14-causal-rank-floor-{arm}{"-ridge" if ridge else ""}.json'
    receipt.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(receipt), 'ranks': [train_rank, held_rank],
                      'aggregate': {n: [v['train']['aggregate'], v['validation']['aggregate']]
                                    for n, v in scores.items()}}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('arm', choices=('selected192', 'uniform192'))
    parser.add_argument('--ridge', action='store_true')
    args = parser.parse_args()
    run(args.arm, args.ridge)
