#!/usr/bin/env python3
"""Rank the two-head narrow-V output map in its causal response geometry."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
SUB = HERE.parent
sys.path.insert(0, str(SUB / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention
from refine import features

DATA = Path('/path/to/workspace/data/kelana-subbit/value-cohead-output-rank')
IMAGE = Path('/path/to/workspace/data/kelana-subbit/value-observer')
RANKS = (32, 64, 96, 128, 160, 192, 224, 256, 288, 312, 384, 448)


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def scored(prediction, reference):
    return float((prediction-reference).square().sum() / reference.square().sum())


def main(layer):
    torch.set_num_threads(8)
    path = IMAGE / f'layer{layer:02d}-joint-r28.npz'
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(path) as packed:
        images = [{k: packed[k][g].copy() for k in packed.files} for g in range(8)]
    a = torch.cat([torch.cat([decoder.decode(image, 'left')[h*1024:(h+1)*1024]
                                    for h in range(2)], dim=1)
                   for image in images], dim=1).contiguous()
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    data = {}
    for split, count in (('train', 8), ('validation', 4)):
        x = load_capture(layer, split).reshape(count, 256, 1024)
        p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        z = features(x, p, images, decoder, 28)
        teacher = dense_attention(p, x, w['v_proj'], w['o_proj']).reshape(-1, 1024)
        data[split] = (z, teacher)
    zt, yt = data['train']
    # Thin QR makes the response-rank problem exactly a 448 x 1024 SVD.
    q, r = torch.linalg.qr(zt, mode='reduced')
    u, s, vt = torch.linalg.svd(r @ a.T, full_matrices=False)
    # R is nonsingular on this panel. A_k^T = R^-1 U_k S_k V_k^T.
    assert torch.linalg.matrix_rank(r) == 448
    lower = torch.linalg.solve_triangular(r, u * s[None, :], upper=True)
    # Try the existing odd-grid two-bit quantizer on both new factors at the
    # first rank with a held real-valued improvement. This is a paid image,
    # unlike the continuous SVD floor above.
    rank = 256
    b = lower[:, :rank].T.contiguous()
    c = vt[:rank].T.contiguous()
    quantized = {}
    for group in (32, 128):
        bi = decoder.quantize(b, 2, group, 'b')
        ci = decoder.quantize(c, 2, group, 'c')
        qb = decoder.decode(bi, 'b')
        qc = decoder.decode(ci, 'c')
        quantized[str(group)] = {
            'b': qb, 'c': qc,
            'payload_bytes': sum(v.nbytes for v in bi.values()) + sum(v.nbytes for v in ci.values()),
            'packed_hashes': {key: hashlib.sha256(value.tobytes()).hexdigest()
                              for key, value in {**bi, **ci}.items()},
        }
    records = {}
    for split, (z, teacher) in data.items():
        base = z @ a.T
        projection = z @ lower
        numer = teacher.square().sum()
        records[split] = {
            'paid_baseline_teacher_error': scored(base, teacher),
            'paid_baseline_window_error': [scored(base.reshape(-1, 256, 1024)[i], teacher.reshape(-1, 256, 1024)[i])
                                            for i in range(len(z)//256)],
            'ranks': {},
        }
        records[split]['two_bit_rank256'] = {}
        for group, image in quantized.items():
            pred = (z @ image['b'].T) @ image['c'].T
            records[split]['two_bit_rank256'][group] = {
                'teacher_error': scored(pred, teacher), 'paid_response_error': scored(pred, base),
                'payload_bytes': image['payload_bytes'],
            }
        for rank in RANKS:
            pred = projection[:, :rank] @ vt[:rank]
            records[split]['ranks'][str(rank)] = {
                'teacher_error': scored(pred, teacher),
                'paid_response_error': scored(pred, base),
                'window_teacher_error': [scored(pred.reshape(-1, 256, 1024)[i], teacher.reshape(-1, 256, 1024)[i])
                                         for i in range(len(z)//256)],
                'relative_singular_tail_energy_train': float(s[rank:].square().sum()/s.square().sum()),
                'ideal_two_bit_left_bytes': (1024*rank+rank*448)//4,
                'new_left_terms': 1024*rank+rank*448,
            }
    report = {
        'layer': layer, 'source_sha256': sha(Path(__file__)), 'factor_decoder_sha256': sha(SOURCE),
        'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
        'paid_image_sha256': sha(path), 'train_rows': len(zt), 'held_rows': len(data['validation'][0]),
        'left_baseline_codes_bytes': 1024*448//4, 'left_baseline_terms': 1024*448,
        'map': 'same paid BF16 narrow V coordinates and original Q/K probabilities; one common output basis for all sixteen heads; train-response-optimal real rank projection of frozen paid decoder, no code fitting',
        'quantized_rank256_image_hashes': {k: v['packed_hashes'] for k, v in quantized.items()},
        'split': records,
    }
    DATA.mkdir(parents=True, exist_ok=True)
    dest = DATA / f'layer{layer:02d}.json'
    dest.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'baseline_held': records['validation']['paid_baseline_teacher_error'],
                      'held': {str(rank): records['validation']['ranks'][str(rank)]['teacher_error']
                               for rank in RANKS},
                      'quantized': records['validation']['two_bit_rank256']}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    main(parser.parse_args().layer)
