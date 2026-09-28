#!/usr/bin/env python3
"""Fit a frozen two-arm four-bit spectral-factor shortlist at sub-bit rate."""
import argparse
import hashlib
import importlib.util
import json
import math
import time
from pathlib import Path

import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'spectral_quant.py'
OUT = Path('/path/to/workspace/data/kelana-subbit/size-transfer/factors')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 22), b''):
            h.update(block)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixture', type=Path, required=True)
    p.add_argument('--out', type=Path, default=OUT)
    p.add_argument('--threads', type=int, default=8)
    args = p.parse_args()
    torch.set_num_threads(args.threads)
    spec = importlib.util.spec_from_file_location('pinned_spectral_quant', SOURCE)
    method = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(method)
    with np.load(args.fixture) as fixture:
        w, x, xv = [torch.from_numpy(fixture[key].copy()).float()
                    for key in ('weight', 'train', 'validation')]
    n, k = w.shape
    y, yv = x @ w.T, xv @ w.T
    begin = time.monotonic()
    alpha = .4
    diagonal = .6 * x.square().mean(0) + .4 * x.square().mean()
    gram = (1 - alpha) * (y.T @ y) + alpha * len(x) * ((w * diagonal.sqrt()) @ (w * diagonal.sqrt()).T)
    eigenvalues, eigenvectors = torch.linalg.eigh(gram)
    basis = eigenvectors.flip(1).contiguous()
    spectrum_seconds = time.monotonic() - begin
    coordinates = basis.T @ w
    args.out.mkdir(parents=True, exist_ok=True)
    entries = []
    for left_bits, right_bits in ((4, 4), (4, 2)):
        group = 128
        rank = max((r for r in range(8, min(n, k) + 1, 8)
                    if 8 * (method.packed_bytes(n, r, left_bits, group) +
                            method.packed_bytes(r, k, right_bits, group) + 32) <= .55 * n * k))
        left = basis[:, :rank].clone()
        right = coordinates[:rank].clone()
        amplitude = right.square().sum(1).sqrt().clamp_min(1e-20).sqrt()
        left *= amplitude
        right /= amplitude[:, None]
        arrays = method.quantize(left, left_bits, group, 'left')
        left_q = method.decode(arrays, 'left')
        right_fit = torch.linalg.solve(left_q.T @ left_q + torch.eye(rank) * 1e-8,
                                       left_q.T @ w)
        arrays.update(method.quantize(right_fit, right_bits, group, 'right'))
        right_q = method.decode(arrays, 'right')
        prediction_train = (x @ right_q.T) @ left_q.T
        prediction_val = (xv @ right_q.T) @ left_q.T
        payload = sum(a.nbytes for a in arrays.values())
        image = args.out / f'{args.fixture.stem}-spectral-l{left_bits}r{right_bits}.npz'
        np.savez(image, **arrays)
        entry = {'left_bits': left_bits, 'right_bits': right_bits, 'rank': rank,
                 'group': group, 'balance': .5, 'covariance_shrinkage': alpha,
                 'refit_input_factor': True, 'dimensions': [n, k],
                 'payload_bytes_including_shapes': payload, 'payload_bpw': 8 * payload / (n * k),
                 'train_response_error': ((prediction_train - y).square().sum() / y.square().sum()).item(),
                 'heldout_response_error': ((prediction_val - yv).square().sum() / yv.square().sum()).item(),
                 'online_per_vector': {'factor_terms': rank * (n + k),
                                       'wmma16_padded_terms': math.ceil(rank / 16) * 16 * (n + k),
                                       'scale_values': (n * math.ceil(rank / group) if left_bits != 16 else 0) +
                                                       (rank * math.ceil(k / group) if right_bits != 16 else 0),
                                       'unfused_intermediate_write_read_bf16_bytes': 4 * rank},
                 'image': str(image), 'image_sha256': sha(image),
                 'serialized_bytes': image.stat().st_size}
        entries.append(entry)
    selected = min(entries, key=lambda row: row['train_response_error'])
    report = {'fixture': str(args.fixture), 'fixture_sha256': sha(args.fixture),
              'method': 'activation-covariance spectral output basis, 0.4 diagonal shrinkage, paid 4/4 or 4/2 quantized factors',
              'source_sha256': sha(SOURCE), 'train_tokens': len(x), 'validation_tokens': len(xv),
              'spectrum_seconds_cpu': spectrum_seconds, 'threads': args.threads,
              'selection': 'minimum train response error among two frozen precision arms',
              'selected_image': selected['image'], 'selected_left_right_bits':
                  [selected['left_bits'], selected['right_bits']], 'entries': entries}
    output = args.out / f'{args.fixture.stem}-spectral.json'
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
