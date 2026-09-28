#!/usr/bin/env python3
"""Refit paid left codes/scales after causal rank allocation, with right codes frozen."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from causal_prune import OUT, sha
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention
from refine import unpack_codes


def load_image(path):
    with np.load(path) as image:
        return [{key: image[f'group{g}_{key}'].copy() for key in ('left_codes', 'left_scales', 'left_shape', 'right_codes', 'right_scales', 'right_shape')}
                for g in range(8)]


def response_features(x, probs, images, q):
    columns = []
    for g, image in enumerate(images):
        right = q.decode(image, 'right')
        value = (x @ right.T).to(torch.bfloat16).float()
        for local in range(2):
            columns.append((probs[:, 2*g+local] @ value).reshape(-1, right.shape[0]))
    return torch.cat(columns, dim=1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--arm', choices=('uniform_24', 'train_causal_optimum'), required=True)
    parser.add_argument('--sweeps', type=int, default=2)
    args = parser.parse_args()
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('spectral_quant_pinned', SOURCE)
    q = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(q)
    source = OUT / f'layer{args.layer:02d}-causal-{args.arm}.npz'
    images = load_image(source)
    ranks = [int(image['right_shape'][0]) for image in images]
    widths = [rank for rank in ranks for _ in range(2)]
    starts = np.cumsum([0] + widths).tolist()
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {name: model.get_tensor(f'model.layers.{args.layer}.self_attn.{name}.weight').float()
             for name in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    inputs = {split: load_capture(args.layer, split).reshape(count, 256, 1024)
              for split, count in (('train', 8), ('validation', 4))}
    targets, features = {}, {}
    for split, x in inputs.items():
        probs = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        targets[split] = dense_attention(probs, x, w['v_proj'], w['o_proj']).reshape(-1, 1024)
        features[split] = response_features(x, probs, images, q)
    codes = torch.empty(1024, starts[-1])
    scales = torch.empty(1024, 16)
    for g, image in enumerate(images):
        rank = ranks[g]
        raw = unpack_codes(image['left_codes'], 2048, rank, 2)
        for local in range(2):
            h = 2*g+local
            codes[:, starts[h]:starts[h+1]] = raw[local*1024:(local+1)*1024]
            scales[:, h] = torch.from_numpy(image['left_scales'][local*1024:(local+1)*1024, 0].copy()).float()
    original = codes.clone()
    def coefficients():
        return torch.cat([(2*codes[:, starts[h]:starts[h+1]]-3)*scales[:, h, None] for h in range(16)], dim=1)
    coeff = coefficients()
    def error(split):
        return ((features[split] @ coeff.T-targets[split]).square().sum()/targets[split].square().sum()).item()
    before = {split: error(split) for split in inputs}
    def window_errors(split):
        difference = (features[split] @ coeff.T-targets[split]).reshape(-1, 256, 1024)
        reference = targets[split].reshape(-1, 256, 1024)
        return (difference.square().sum((1, 2))/reference.square().sum((1, 2))).tolist()
    before_windows = window_errors('validation')
    z, y = features['train'], targets['train']
    gram = z.T @ z / len(z)
    target = y.T @ z / len(z)
    for _ in range(args.sweeps):
        current = coeff @ gram
        for d in range(starts[-1]):
            h = int(np.searchsorted(starts, d, side='right')-1)
            optimum = (target[:, d] - current[:, d] + coeff[:, d]*gram[d, d])/gram[d, d].clamp_min(1e-20)
            new_code = ((optimum/scales[:, h].clamp_min(1e-20)+3)/2).round().clamp(0, 3)
            updated = (2*new_code-3)*scales[:, h]
            delta = updated-coeff[:, d]
            coeff[:, d] = updated
            codes[:, d] = new_code
            current += delta[:, None]*gram[d][None, :]
        prediction = z @ coeff.T
        for h in range(16):
            a, b = starts[h:h+2]
            old = z[:, a:b] @ coeff[:, a:b].T
            raw = z[:, a:b] @ (2*codes[:, a:b]-3).T
            residual = y-prediction+old
            fitted = ((residual*raw).sum(0)/raw.square().sum(0).clamp_min(1e-20)).clamp_min(0)
            scales[:, h] = fitted.half().float()
            coeff[:, a:b] = (2*codes[:, a:b]-3)*scales[:, h, None]
            prediction += raw*scales[:, h][None, :]-old
    after = {split: error(split) for split in inputs}
    after_windows = window_errors('validation')
    packed = {}
    for g, image in enumerate(images):
        chunks = [codes[:, starts[h]:starts[h+1]] for h in (2*g, 2*g+1)]
        image['left_codes'] = q.pack_codes(torch.cat(chunks).to(torch.uint8).numpy(), 2)
        image['left_scales'] = torch.cat([scales[:, 2*g], scales[:, 2*g+1]]).numpy().astype(np.float16)[:, None]
        packed.update({f'group{g}_{key}': value for key, value in image.items()})
    output = OUT / f'layer{args.layer:02d}-causal-refit-{args.arm}.npz'
    np.savez(output, **packed)
    payload = sum(value.nbytes for value in packed.values())
    assert payload == 183552, payload
    restored = load_image(output)
    restored_coeff = torch.cat([q.decode(restored[h//2], 'left')[((h%2)*1024):((h%2+1)*1024)] for h in range(16)], dim=1)
    assert torch.equal(restored_coeff, coeff)
    receipt = {'layer': args.layer, 'arm': args.arm, 'ranks': ranks, 'sweeps': args.sweeps,
               'train_tokens': len(y), 'validation_tokens': len(targets['validation']),
               'objective': 'train original-Q/K causal post-O squared error; frozen paid right codes/scales and ranks; two-bit left codes and FP16 scales refitted',
               'before': before, 'after': after, 'validation_window_error_before': before_windows,
               'validation_window_error_after': after_windows,
               'changed_left_codes': int((codes != original).sum()),
               'payload_bytes': payload, 'source_image_sha256': sha(source), 'image_sha256': sha(output),
               'source_sha256': sha(Path(__file__)), 'model_sha256': sha(MODEL),
               'capture_sha256': sha(CAPTURES / f'layer{args.layer:02d}.npz')}
    path = OUT / f'layer{args.layer:02d}-causal-refit-{args.arm}.json'
    path.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'receipt': str(path), 'before': before, 'after': after, 'changed_codes': receipt['changed_left_codes']}), flush=True)


if __name__ == '__main__':
    main()
