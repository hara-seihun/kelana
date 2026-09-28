#!/usr/bin/env python3
"""Fit a regularized causal decoder into the paid layer-0 narrow V/O slots."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from causal_refit import load_image, response_features
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention
from refine import unpack_codes

OUT = Path('/path/to/workspace/data/kelana-subbit/value-observer')
PENALTIES = (0.0001, 0.001, 0.01, 0.1, 1.)


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def relative(z, y, coeff):
    delta = (z @ coeff - y).reshape(-1, 256, 1024)
    target = y.reshape(-1, 256, 1024)
    numerator = delta.square().sum((1, 2))
    denominator = target.square().sum((1, 2))
    return {'aggregate': float(numerator.sum() / denominator.sum()),
            'per_window': (numerator / denominator).tolist()}


def ridge(z, y, penalty):
    gram = z.T @ z / len(z)
    cross = z.T @ y / len(z)
    gram = gram.double()
    scale = float(gram.trace() / gram.shape[0])
    return torch.linalg.solve(gram + penalty * scale * torch.eye(len(gram), dtype=torch.float64),
                              cross.double()).float()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, default=OUT / 'layer00-causal-ridge.json')
    args = p.parse_args()
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('pinned_spectral_quant', SOURCE)
    quant = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quant)
    source = OUT / 'layer00-causal-refit-train_causal_optimum.npz'
    images = load_image(source)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {name: model.get_tensor(f'model.layers.0.self_attn.{name}.weight').float()
             for name in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    features, targets = {}, {}
    for split, count in (('train', 8), ('validation', 4)):
        x = load_capture(0, split).reshape(count, 256, 1024)
        prob = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        targets[split] = dense_attention(prob, x, w['v_proj'], w['o_proj']).reshape(-1, 1024)
        features[split] = response_features(x, prob, images, quant).reshape(-1, 384)
        print('built', split, flush=True)
    z, y = features['train'], targets['train']
    folds = []
    for held in range(8):
        other = [i for i in range(8) if i != held]
        folds.append((z.reshape(8, 256, -1)[other].reshape(-1, 384),
                      y.reshape(8, 256, -1)[other].reshape(-1, 1024),
                      z[held*256:(held+1)*256], y[held*256:(held+1)*256]))
    cv = {str(value): [] for value in PENALTIES}
    for a, b, held_z, held_y in folds:
        for value in PENALTIES:
            cv[str(value)].append(relative(held_z, held_y, ridge(a, b, value))['aggregate'])
    choice = min(PENALTIES, key=lambda value: sum(cv[str(value)]))
    original_coeff = torch.cat([quant.decode(images[h//2], 'left')[(h%2)*1024:((h%2)+1)*1024].T
                                for h in range(16)], dim=0)
    continuous = ridge(z, y, choice)
    starts = np.cumsum([0] + [int(image['right_shape'][0]) for image in images for _ in range(2)])
    packed = {}
    pieces = []
    for group, image in enumerate(images):
        left = torch.cat([continuous[starts[h]:starts[h+1]].T for h in (2*group, 2*group+1)])
        image.update(quant.quantize(left.contiguous(), 2, 128, 'left'))
        pieces.extend([quant.decode(image, 'left')[local*1024:(local+1)*1024].T for local in range(2)])
        packed.update({f'group{group}_{key}': value for key, value in image.items()})
    rounded = torch.cat(pieces)
    rounded_scores = {split: relative(features[split], targets[split], rounded)
                      for split in ('train', 'validation')}
    # Ask whether the continuous ridge initializer survives projection into the
    # same sign/scale family after the same two paid-code sweeps as the control.
    codes = torch.empty(1024, 384)
    scales = torch.empty(1024, 16)
    for group, image in enumerate(images):
        rank = int(image['right_shape'][0])
        raw = unpack_codes(image['left_codes'], 2048, rank, 2)
        for local in range(2):
            head = 2*group+local
            codes[:, starts[head]:starts[head+1]] = raw[local*1024:(local+1)*1024]
            scales[:, head] = torch.from_numpy(image['left_scales'][local*1024:(local+1)*1024, 0].copy()).float()
    coeff = rounded.T.clone()
    gram = z.T @ z / len(z)
    target = y.T @ z / len(z)
    for _ in range(2):
        current = coeff @ gram
        for d in range(384):
            head = int(np.searchsorted(starts, d, side='right')-1)
            optimum = (target[:, d]-current[:, d]+coeff[:, d]*gram[d, d]) / gram[d, d].clamp_min(1e-20)
            new_code = ((optimum / scales[:, head].clamp_min(1e-20)+3)/2).round().clamp(0, 3)
            updated = (2*new_code-3)*scales[:, head]
            delta = updated-coeff[:, d]
            coeff[:, d] = updated
            codes[:, d] = new_code
            current += delta[:, None]*gram[d][None, :]
        prediction = z @ coeff.T
        for head in range(16):
            a, b = starts[head:head+2]
            old = z[:, a:b] @ coeff[:, a:b].T
            raw = z[:, a:b] @ (2*codes[:, a:b]-3).T
            residual = y-prediction+old
            fitted = ((residual*raw).sum(0)/raw.square().sum(0).clamp_min(1e-20)).clamp_min(0)
            scales[:, head] = fitted.half().float()
            coeff[:, a:b] = (2*codes[:, a:b]-3)*scales[:, head, None]
            prediction += raw*scales[:, head][None, :]-old
    for group, image in enumerate(images):
        chunks = [codes[:, starts[head]:starts[head+1]] for head in (2*group, 2*group+1)]
        image['left_codes'] = quant.pack_codes(torch.cat(chunks).to(torch.uint8).numpy(), 2)
        image['left_scales'] = torch.cat([scales[:, 2*group], scales[:, 2*group+1]]).numpy().astype(np.float16)[:, None]
        packed.update({f'group{group}_{key}': value for key, value in image.items()})
    fitted = torch.cat([quant.decode(images[head//2], 'left')[(head%2)*1024:((head%2)+1)*1024].T
                        for head in range(16)])
    assert torch.equal(fitted, coeff.T)
    image_path = args.output.with_suffix('.npz')
    image_path.parent.mkdir(parents=True, exist_ok=True)
    np.savez(image_path, **packed)
    assert sum(value.nbytes for value in packed.values()) == 183552
    result = {'contract': 'layer-0 original-producer, original Q/K and causal attention; frozen 192 paid two-bit right coordinates; train-selected ridge dense left target, rounded to existing two-bit codes and FP16 scales',
              'penalty_scale': 'trace(train feature Gram) / 384', 'cv_eight_train_windows': cv,
              'selected_penalty': choice, 'left_code_image': str(image_path), 'payload_bytes': 183552,
              'scores': {name: {split: relative(features[split], targets[split], coeff)
                                for split in ('train', 'validation')}
                         for name, coeff in (('existing_paid', original_coeff),
                                             ('ridge_real', continuous), ('ridge_seed_paid', rounded),
                                             ('ridge_two_sweeps_paid', fitted))},
              'seed_paid_scores': rounded_scores,
              'sha256': {'source': sha(Path(__file__)), 'model': sha(MODEL),
                         'initial_image': sha(source), 'output_image': sha(image_path),
                         'capture_train_validation': sha(CAPTURES / 'layer00.npz')}}
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'selected_penalty': choice, 'held': {name: arm['validation']['aggregate'] for name, arm in result['scores'].items()}}, indent=2), flush=True)


if __name__ == '__main__':
    main()
