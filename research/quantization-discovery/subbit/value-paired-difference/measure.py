#!/usr/bin/env python3
"""Rank-price the paired GQA attention difference on frozen paid V/O images."""
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
from measure import probabilities
from refine import features

IMAGE = Path('/path/to/workspace/data/kelana-subbit/value-observer')
DATA = Path('/path/to/workspace/data/kelana-subbit/value-paired-difference')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def main(layer):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    image_path = IMAGE / f'layer{layer:02d}-joint-r28.npz'
    with np.load(image_path) as packed:
        images = [{k: packed[k][g].copy() for k in packed.files} for g in range(8)]
    matrix = []
    for image in images:
        left = decoder.decode(image, 'left').double()
        matrix.append(left.reshape(2, 1024, 28))
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    x = load_capture(layer, 'validation').reshape(4, 256, 1024)
    p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    z = features(x, p, images, decoder, 28).double().reshape(-1, 8, 2, 28)
    exact = sum(z[:, g, 0] @ matrix[g][0].T + z[:, g, 1] @ matrix[g][1].T for g in range(8))
    full_energy = exact.square().sum()
    reports = []
    approximations = {r: torch.zeros_like(exact) for r in (0, 4, 8, 12, 16, 20, 24, 28)}
    for g, left in enumerate(matrix):
        common = (left[0] + left[1]).T / 2
        difference = (left[0] - left[1]).T / 2
        singular = torch.linalg.svd(difference, full_matrices=False)
        avg_z = z[:, g, 0] + z[:, g, 1]
        delta_z = z[:, g, 0] - z[:, g, 1]
        base = avg_z @ common
        group_full = base + delta_z @ difference
        group_energy = group_full.square().sum()
        # A held-only best rank-r factor is an optimistic bound on any fixed rank-r reader.
        dz_gram = delta_z.T @ delta_z
        evals, eigenvectors = torch.linalg.eigh(dz_gram)
        root = (eigenvectors * evals.clamp_min(0).sqrt()) @ eigenvectors.T
        oracle_squares = torch.linalg.eigvalsh(root @ difference @ difference.T @ root).clamp_min(0).flip(0).tolist()
        tails = {}
        oracle_tails = {}
        for r, out in approximations.items():
            projected = (delta_z @ singular.U[:, :r]) * singular.S[:r]
            approx = base + projected @ singular.Vh[:r]
            out += approx
            tails[str(r)] = float((approx-group_full).square().sum() / group_energy)
            oracle_tails[str(r)] = float(sum(oracle_squares[r:]) / group_energy)
        reports.append({'group': g, 'singular_values': singular.S.tolist(),
                        'held_oracle_rank_tail_relative_to_group_output': oracle_tails,
                        'difference_frobenius_tail_fraction_rank14':
                        float(singular.S[14:].square().sum() / singular.S.square().sum()),
                        'group_relative_squared_error': tails})
    scores = {}
    for r, y in approximations.items():
        scores[str(r)] = {
            'relative_squared_change_to_paid_output': float((y-exact).square().sum() / full_energy),
            'per_window': [float((y[i*256:(i+1)*256]-exact[i*256:(i+1)*256]).square().sum() /
                                 exact[i*256:(i+1)*256].square().sum()) for i in range(4)],
            'value_dot_coordinates_per_group': 28+r,
            'extra_key_cache_coordinates_for_direct_reader': r,
            'append_transform_products_per_key_group': 28*r,
            'post_attention_difference_output_products_per_query_group': 1024*r,
        }
    assert torch.allclose(approximations[28], exact, rtol=0, atol=1e-7)
    report = {'layer': layer, 'source_sha256': sha(Path(__file__)),
              'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
              'image_sha256': sha(image_path), 'decoder_sha256': sha(SOURCE),
              'paid_output_sha256': hashlib.sha256(exact.numpy().tobytes()).hexdigest(),
              'domain': 'four inspected 256-token original-producer validation windows; frozen rank-28 paid V/O image',
              'observation': 'FP64 post-O output of the paid narrow value image, not the original model or gold loss',
              'scores': scores, 'groups': reports}
    DATA.mkdir(parents=True, exist_ok=True)
    path = DATA / f'layer{layer:02d}.json'
    path.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'path': str(path), 'scores': scores}), flush=True)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--layer', type=int, choices=(0, 14), required=True)
    main(ap.parse_args().layer)
