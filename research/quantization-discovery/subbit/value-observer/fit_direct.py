#!/usr/bin/env python3
"""Fit one paid shared value basis per GQA group to its two composed O maps."""
import argparse
import hashlib
import importlib.util
import json
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from fit import MODEL, OUTPUT, CAPTURES, load_capture

SOURCE = Path(__file__).resolve().parents[1] / 'spectral_quant.py'
FAMILIES = {'binary2-r28': (2, 2, 28), 'input4-output2-r20': (2, 4, 20),
            'four4-r14': (4, 4, 14)}


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--layer', type=int, choices=(0, 14), required=True)
    p.add_argument('--threads', type=int, default=8)
    p.add_argument('--groups', type=int, nargs='+', default=list(range(8)))
    args = p.parse_args()
    torch.set_num_threads(args.threads)
    torch.manual_seed(0)
    spec = importlib.util.spec_from_file_location('spectral_quant_pinned', SOURCE)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    with safe_open(MODEL, framework='pt', device='cpu') as source:
        wv = source.get_tensor(f'model.layers.{args.layer}.self_attn.v_proj.weight').float()
        wo = source.get_tensor(f'model.layers.{args.layer}.self_attn.o_proj.weight').float()
    xtrain = load_capture(args.layer, 'train')
    xval = load_capture(args.layer, 'validation')
    target = OUTPUT / f'layer{args.layer:02d}-direct'
    target.mkdir(parents=True, exist_ok=True)
    by_family = {name: [] for name in FAMILIES}
    begin = time.monotonic()
    for g in args.groups:
        if g not in range(8):
            raise ValueError('group must be 0..7')
        group_value = wv[g*128:(g+1)*128]
        output_pair = torch.cat([wo[:, h*128:(h+1)*128] for h in (2*g, 2*g+1)], 0)
        pair_map = output_pair @ group_value
        teacher_train = xtrain @ pair_map.T
        teacher_val = xval @ pair_map.T
        values = xtrain @ group_value.T
        q, r = torch.linalg.qr(values, mode='reduced')
        u, spectrum, vh = torch.linalg.svd(r @ output_pair.T, full_matrices=False)
        for family, (left_bits, right_bits, rank) in FAMILIES.items():
            left = vh[:rank].T * spectrum[:rank]
            right = torch.linalg.solve(r, u[:, :rank]).T @ group_value
            # Balance coordinates before paid group-128 rounding, as in the spectral study.
            amplitude = right.square().sum(1).sqrt().clamp_min(1e-20).sqrt()
            left = left * amplitude[None, :]
            right = right / amplitude[:, None]
            arrays = quantizer.quantize(left.contiguous(), left_bits, 128, 'left')
            left_q = quantizer.decode(arrays, 'left')
            right_fit = torch.linalg.solve(left_q.T @ left_q + torch.eye(rank) * 1e-8,
                                           left_q.T @ pair_map)
            arrays.update(quantizer.quantize(right_fit, right_bits, 128, 'right'))
            right_q = quantizer.decode(arrays, 'right')
            estimate_train = (xtrain @ right_q.T) @ left_q.T
            estimate_val = (xval @ right_q.T) @ left_q.T
            train_err = ((estimate_train - teacher_train).square().sum() / teacher_train.square().sum()).item()
            val_err = ((estimate_val - teacher_val).square().sum() / teacher_val.square().sum()).item()
            image = target / f'{family}-group{g}.npz'
            np.savez(image, **arrays)
            payload = sum(v.nbytes for v in arrays.values())
            row = {'layer': args.layer, 'group': g, 'heads': [2*g, 2*g+1],
                   'family': family, 'rank': rank, 'left_bits': left_bits, 'right_bits': right_bits,
                   'input_width': xtrain.shape[1], 'output_width_per_head': wo.shape[0],
                   'conditional_best_rank_train_error':
                       (spectrum[rank:].square().sum() / teacher_train.square().sum()).item(),
                   'train_composed_response_error': train_err,
                   'validation_composed_response_error': val_err,
                   'payload_bytes_including_descriptors': payload,
                   'image': str(image), 'image_sha256': sha(image),
                   'serialized_bytes': image.stat().st_size}
            by_family[family].append(row)
    report = {'method': 'shared GQA value basis from exact train-response rank optimum, output/input signed-grid factors, weight-LS repaired input factor',
              'layer': args.layer, 'source_model_revision': json.loads((MODEL.parent / 'source.json').read_text())['revision'],
              'source_quantizer_sha256': sha(SOURCE),
              'capture_sha256': sha(CAPTURES / f'layer{args.layer:02d}.npz'),
              'train_tokens': len(xtrain), 'validation_tokens': len(xval),
              'seconds_cpu': time.monotonic() - begin,
              'independent_binary_bytes_including_descriptors': 210968,
              'families': {name: {'total_payload_bytes_including_descriptors': sum(r['payload_bytes_including_descriptors'] for r in rows),
                                  'total_bpw_against_original_V_plus_O':
                                      8*sum(r['payload_bytes_including_descriptors'] for r in rows)/(wv.numel()+wo.numel()),
                                  'groups': rows} for name, rows in by_family.items()}}
    output = target / ('fit.json' if args.groups == list(range(8)) else
                       'fit-' + '-'.join(str(g) for g in args.groups) + '.json')
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'layer': args.layer, 'seconds_cpu': report['seconds_cpu'],
                      'families': {name: {'bytes': v['total_payload_bytes_including_descriptors'],
                                          'bpw': v['total_bpw_against_original_V_plus_O'],
                                          'mean_train_composed_error': np.mean([r['train_composed_response_error'] for r in v['groups']]),
                                          'mean_validation_composed_error': np.mean([r['validation_composed_response_error'] for r in v['groups']])}
                                   for name, v in report['families'].items()}}), flush=True)


if __name__ == '__main__':
    main()
