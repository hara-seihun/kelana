#!/usr/bin/env python3
"""Coordinate-fit stored output codes against original-Q/K causal attention responses."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from fit import MODEL, OUTPUT, load_capture
from fit_direct import FAMILIES, SOURCE
from measure import probabilities, dense_attention


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def unpack_codes(packed, rows, cols, bits):
    planes = np.unpackbits(packed, axis=1, bitorder='little')[:, :cols*bits]
    return torch.from_numpy((planes.reshape(rows, cols, bits).astype(np.int16) << np.arange(bits)).sum(-1).astype(np.float32))


def features(x, prob, images, quantizer, rank):
    batch, length, _ = x.shape
    result = []
    for group, image in enumerate(images):
        right = quantizer.decode(image, 'right')
        value = (x @ right.T).to(torch.bfloat16).float()
        for local in range(2):
            result.append((prob[:, 2*group+local] @ value).reshape(batch*length, rank))
    return torch.cat(result, dim=1)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--layer', type=int, choices=(0, 14), required=True)
    p.add_argument('--sweeps', type=int, default=4)
    p.add_argument('--threads', type=int, default=8)
    args = p.parse_args()
    torch.set_num_threads(args.threads)
    torch.manual_seed(0)
    spec = importlib.util.spec_from_file_location('spectral_quant_pinned', SOURCE)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    with safe_open(MODEL, framework='pt', device='cpu') as src:
        names = {name: src.get_tensor(f'model.layers.{args.layer}.self_attn.{name}.weight').float()
                 for name in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    inputs = {split: load_capture(args.layer, split).reshape(count, 256, 1024)
              for split, count in (('train', 8), ('validation', 4))}
    probs = {split: probabilities(x, names['q_proj'], names['k_proj'], names['q_norm'], names['k_norm'])
             for split, x in inputs.items()}
    teacher = {split: dense_attention(probs[split], x, names['v_proj'], names['o_proj']).reshape(-1, 1024)
               for split, x in inputs.items()}
    report = {'layer': args.layer, 'train_tokens': len(teacher['train']),
              'validation_tokens': len(teacher['validation']), 'sweeps': args.sweeps,
              'objective': 'exact conditional left-code coordinate minimization and row/head FP16 scale fit on train causal post-O responses; right codes/scales and ranks frozen',
              'families': {}}
    source_dir = OUTPUT / f'layer{args.layer:02d}-direct'
    out_dir = OUTPUT / f'layer{args.layer:02d}-refined'
    out_dir.mkdir(parents=True, exist_ok=True)
    for family, (bits, _, rank) in FAMILIES.items():
        images = []
        for group in range(8):
            with np.load(source_dir / f'{family}-group{group}.npz') as image:
                images.append({key: image[key].copy() for key in image.files})
        z = {split: features(inputs[split], probs[split], images, quantizer, rank)
             for split in inputs}
        codes = torch.empty(1024, 16*rank)
        scales = torch.empty(1024, 16)
        for group, image in enumerate(images):
            unpacked = unpack_codes(image['left_codes'], 2048, rank, bits)
            for local in range(2):
                head = 2*group + local
                codes[:, head*rank:(head+1)*rank] = unpacked[local*1024:(local+1)*1024]
                scales[:, head] = torch.from_numpy(image['left_scales'][local*1024:(local+1)*1024, 0].copy()).float()
        initial_codes = codes.clone()
        levels = 2*codes - (2**bits - 1)
        amplitude = scales.repeat_interleave(rank, dim=1)
        coeff = levels * amplitude
        baseline = {split: ((z[split] @ coeff.T-teacher[split]).square().sum()/teacher[split].square().sum()).item()
                    for split in z}
        gram = z['train'].T @ z['train'] / len(z['train'])
        target = teacher['train'].T @ z['train'] / len(z['train'])
        for sweep in range(args.sweeps):
            current = coeff @ gram
            for d in range(16*rank):
                optimal = (target[:, d] - current[:, d] + coeff[:, d]*gram[d, d]) / gram[d, d].clamp_min(1e-20)
                scale = scales[:, d//rank].clamp_min(1e-20)
                updated_code = ((optimal/scale + (2**bits - 1))/2).round().clamp(0, 2**bits-1)
                updated = (2*updated_code-(2**bits-1))*scale
                delta = updated-coeff[:, d]
                coeff[:, d] = updated
                codes[:, d] = updated_code
                current += delta[:, None]*gram[d][None, :]
            prediction = z['train'] @ coeff.T
            for head in range(16):
                start, end = head*rank, (head+1)*rank
                old = z['train'][:, start:end] @ coeff[:, start:end].T
                raw = z['train'][:, start:end] @ (2*codes[:, start:end]-(2**bits-1)).T
                residual = teacher['train'] - prediction + old
                fitted = ((residual*raw).sum(0)/raw.square().sum(0).clamp_min(1e-20)).clamp_min(0)
                scales[:, head] = fitted.half().float()
                coeff[:, start:end] = (2*codes[:, start:end]-(2**bits-1))*scales[:, head, None]
                prediction += raw*scales[:, head][None, :] - old
        final = {split: ((z[split] @ coeff.T-teacher[split]).square().sum()/teacher[split].square().sum()).item()
                 for split in z}
        artifacts = []
        for group, image in enumerate(images):
            packed = torch.cat([codes[:, (2*group+local)*rank:(2*group+local+1)*rank]
                                for local in range(2)], dim=0).to(torch.uint8).numpy()
            image['left_codes'] = quantizer.pack_codes(packed, bits)
            image['left_scales'] = torch.cat([scales[:, 2*group], scales[:, 2*group+1]]).numpy().astype(np.float16)[:, None]
            path = out_dir / f'{family}-group{group}.npz'
            np.savez(path, **image)
            artifacts.append({'path': str(path), 'sha256': sha(path),
                              'payload_bytes_including_descriptors': sum(v.nbytes for v in image.values())})
        report['families'][family] = {'rank': rank, 'bits': bits,
                                      'baseline_train_validation_error': baseline,
                                      'refined_train_validation_error': final,
                                      'changed_left_codes': int((codes != initial_codes).sum()),
                                      'payload_bytes_including_descriptors': sum(x['payload_bytes_including_descriptors'] for x in artifacts),
                                      'images': artifacts}
    selection = min(report['families'], key=lambda family: report['families'][family]['refined_train_validation_error']['train'])
    report['train_selected_family'] = selection
    path = out_dir / 'refine.json'
    path.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'layer': args.layer, 'train_selected': selection,
                      'families': {name: item['refined_train_validation_error'] for name,item in report['families'].items()}}), flush=True)


if __name__ == '__main__':
    main()
