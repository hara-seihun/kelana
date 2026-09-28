#!/usr/bin/env python3
"""Fit a new paid shared V basis on quantized upstream activations, then causal O codes."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from causal_refit import load_image, response_features
from fit import MODEL
from fit_direct import SOURCE, sha
from measure import probabilities, dense_attention, error
from refine import unpack_codes

OUT = Path('/path/to/workspace/data/kelana-subbit/value-observer')


def fit_codes(images, q, features, teacher, sweeps):
    ranks = [int(im['right_shape'][0]) for im in images]
    starts = np.cumsum([0] + [r for r in ranks for _ in range(2)]).tolist()
    codes = torch.cat([unpack_codes(images[h//2]['left_codes'], 2048, ranks[h//2], 2)
                       [(h%2)*1024:(h%2+1)*1024] for h in range(16)], dim=1)
    scales = torch.stack([torch.from_numpy(images[h//2]['left_scales']
                         [(h%2)*1024:(h%2+1)*1024, 0].copy()).float() for h in range(16)], dim=1)
    coeff = torch.cat([(2*codes[:, starts[h]:starts[h+1]]-3)*scales[:, h, None]
                       for h in range(16)], dim=1)
    z, y = features, teacher
    gram, target = z.T @ z / len(z), y.T @ z / len(z)
    for _ in range(sweeps):
        current = coeff @ gram
        for d in range(starts[-1]):
            h = int(np.searchsorted(starts, d, side='right')-1)
            optimum = (target[:, d]-current[:, d]+coeff[:, d]*gram[d, d])/gram[d, d].clamp_min(1e-20)
            new_code = ((optimum/scales[:, h].clamp_min(1e-20)+3)/2).round().clamp(0, 3)
            updated = (2*new_code-3)*scales[:, h]
            delta = updated-coeff[:, d]
            codes[:, d], coeff[:, d] = new_code, updated
            current += delta[:, None]*gram[d][None, :]
        prediction = z @ coeff.T
        for h in range(16):
            a, b = starts[h:h+2]
            old = z[:, a:b] @ coeff[:, a:b].T
            raw = z[:, a:b] @ (2*codes[:, a:b]-3).T
            fitted = (((y-prediction+old)*raw).sum(0)/raw.square().sum(0).clamp_min(1e-20)).clamp_min(0)
            scales[:, h] = fitted.half().float()
            coeff[:, a:b] = (2*codes[:, a:b]-3)*scales[:, h, None]
            prediction += raw*scales[:, h][None, :]-old
    packed = {}
    for g, image in enumerate(images):
        image['left_codes'] = q.pack_codes(torch.cat([codes[:, starts[h]:starts[h+1]]
                                for h in (2*g, 2*g+1)]).to(torch.uint8).numpy(), 2)
        image['left_scales'] = torch.cat([scales[:, 2*g], scales[:, 2*g+1]]).numpy().astype(np.float16)[:, None]
        packed.update({f'group{g}_{key}': value for key, value in image.items()})
    assert sum(value.nbytes for value in packed.values()) == 183552
    return packed, coeff


def run(arm):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('pinned_spectral_quant', SOURCE)
    q = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(q)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {n: model.get_tensor(f'model.layers.14.self_attn.{n}.weight').float()
             for n in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    source = OUT / f'layer14-quantized-upstream-{arm}.npz'
    images = load_image(source)
    with np.load(OUT / 'layer14-quantized-upstream.npz') as data:
        x = {split: torch.from_numpy(data[split].copy().view(np.int16)).view(torch.bfloat16).float()
             for split in ('train', 'validation')}
    ranks = [int(im['right_shape'][0]) for im in images]
    for g, rank in enumerate(ranks):
        v = w['v_proj'][g*128:(g+1)*128]
        opair = torch.cat([w['o_proj'][:, h*128:(h+1)*128] for h in (2*g, 2*g+1)])
        responses = x['train'].reshape(-1, 1024) @ v.T
        basis, triangular = torch.linalg.qr(responses, mode='reduced')
        u, spectrum, vh = torch.linalg.svd(triangular @ opair.T, full_matrices=False)
        right = torch.linalg.solve(triangular, u[:, :rank]).T @ v
        left = vh[:rank].T * spectrum[:rank]
        amplitude = right.square().sum(1).sqrt().clamp_min(1e-20).sqrt()
        left, right = left * amplitude[None], right / amplitude[:, None]
        paid = q.quantize(left.contiguous(), 2, 128, 'left')
        left_q = q.decode(paid, 'left')
        right = torch.linalg.solve(left_q.T @ left_q + torch.eye(rank)*1e-8,
                                   left_q.T @ (opair @ v))
        paid.update(q.quantize(right.contiguous(), 2, 128, 'right'))
        assert sum(a.nbytes for a in paid.values()) == sum(a.nbytes for a in images[g].values())
        images[g] = paid
    features, teachers = {}, {}
    for split, xx in x.items():
        p = probabilities(xx, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        teachers[split] = dense_attention(p, xx, w['v_proj'], w['o_proj'])
        features[split] = response_features(xx, p, images, q).reshape(-1, sum(ranks)*2)
    before = {s: error(features[s] @ torch.cat([q.decode(images[h//2], 'left')
              [(h%2)*1024:(h%2+1)*1024] for h in range(16)], dim=1).T,
              teachers[s].reshape(-1, 1024)) for s in x}
    packed, coeff = fit_codes(images, q, features['train'], teachers['train'].reshape(-1, 1024), 2)
    output = OUT / f'layer14-quantized-upstream-right-{arm}.npz'
    np.savez(output, **packed)
    restored = load_image(output)
    replay = torch.cat([q.decode(restored[h//2], 'left')[(h%2)*1024:(h%2+1)*1024]
                        for h in range(16)], dim=1)
    assert torch.equal(replay, coeff)
    after = {}
    for split in x:
        prediction = (features[split] @ coeff.T).reshape_as(teachers[split])
        after[split] = {'aggregate': error(prediction, teachers[split]),
                        'per_window': [error(a, b) for a, b in zip(prediction, teachers[split])]}
    receipt = {'arm': arm, 'ranks': ranks, 'before': before, 'after': after,
               'paid_bytes': sum(a.nbytes for a in packed.values()),
               'terms_per_token': 589824, 'logical_value_bytes_per_token': 384,
               'contract': 'four quantized-producer train windows fit continuous shared V/O response basis, paid 2-bit right and left codes, two train-only causal left sweeps; four held validation windows; original layer14 Q/K and teacher V/O; CPU FP32 matmul and BF16 narrow value rounding',
               'input_capture_sha256': sha(OUT / 'layer14-quantized-upstream.npz'),
               'model_sha256': sha(MODEL), 'source_image_sha256': sha(source),
               'quantizer_sha256': sha(SOURCE), 'script_sha256': sha(Path(__file__)),
               'output_image_sha256': sha(output)}
    path = OUT / f'layer14-quantized-upstream-right-{arm}.json'
    path.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'receipt': str(path), 'before': before, 'after': after}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('arm', choices=('selected192', 'uniform192'))
    run(parser.parse_args().arm)
