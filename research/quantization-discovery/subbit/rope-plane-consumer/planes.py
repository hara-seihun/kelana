#!/usr/bin/env python3
"""Price RoPE-commuting plane selection on pinned Qwen Q/K linear maps."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from safetensors import safe_open
import torch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'rope-key-orbit'))
from orbit import orbit_covariance


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def ratio(matrix, selected):
    omitted = np.ones(64, dtype=bool)
    omitted[selected] = False
    return 1 - float(matrix[np.ix_(omitted, omitted)].sum() / matrix.sum())


def select_planes(matrix, count):
    selected = list(range(64))
    while len(selected) > count:
        selected.remove(max(selected, key=lambda j: ratio(matrix, [k for k in selected if k != j])))
    initial = ratio(matrix, selected)
    while True:
        best = (ratio(matrix, selected), None)
        for leave in selected:
            for enter in range(64):
                if enter in selected:
                    continue
                candidate = [k for k in selected if k != leave] + [enter]
                score = ratio(matrix, candidate)
                if score > best[0] + 1e-12:
                    best = (score, candidate)
        if best[1] is None:
            return sorted(selected), initial, best[0]
        selected = best[1]


def score_gram(q, k_cov):
    # Isotropic independent hidden inputs. Each score is a sum of 64 plane terms.
    # Cross-plane covariance is retained, not silently assumed zero.
    q_cov = q @ q.T
    order = np.arange(128).reshape(2, 64).T.ravel()
    pointwise = q_cov[np.ix_(order, order)] * k_cov[np.ix_(order, order)]
    gram = pointwise.reshape(64, 2, 64, 2).sum(axis=(1, 3))
    assert np.allclose(gram, gram.T, atol=1e-7)
    return gram


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    config_path, model_path = args.model / 'config.json', args.model / 'model.safetensors'
    config = json.loads(config_path.read_text())
    assert (config['hidden_size'], config['head_dim'], config['num_attention_heads'], config['num_key_value_heads']) == (1024, 128, 16, 8)
    result = dict(model_sha256=digest(model_path), config_sha256=digest(config_path), source_sha256=digest(Path(__file__)),
                  horizon=4096, plane_counts=[7, 14, 28], layers={})
    with safe_open(model_path, framework='pt', device='cpu') as file:
        for layer in (0, 14):
            stem = f'model.layers.{layer}.self_attn.'
            kw = file.get_tensor(stem + 'k_proj.weight').to(dtype=torch.float64).numpy()
            qw = file.get_tensor(stem + 'q_proj.weight').to(dtype=torch.float64).numpy()
            groups = []
            for g in range(8):
                key = kw[128*g:128*(g+1)]
                # Both query heads observe one common cached key plane set.
                query = np.concatenate((qw[256*g:256*g+128], qw[256*g+128:256*(g+1)]), axis=1) / np.sqrt(2)
                rotated = orbit_covariance(key, config['rope_theta'], 4096)
                gram = score_gram(query, rotated)
                q_cov = query @ query.T
                eigen, vectors = np.linalg.eigh(q_cov)
                q_sqrt = (vectors * np.sqrt(np.maximum(eigen, 0))) @ vectors.T
                unconstrained_spectrum = np.linalg.eigvalsh(q_sqrt @ rotated @ q_sqrt)[::-1]
                energy = (key**2).sum(axis=1)
                plane_energy = energy[:64] + energy[64:]
                iso = np.diag(plane_energy)
                assert gram.sum() > 0
                entries = {}
                for count in (7, 14, 28):
                    optimal_iso = np.argsort(plane_energy)[-count:]
                    selected, greedy, swapped = select_planes(gram, count)
                    entries[str(count)] = dict(unrestricted_q_weighted_optimal=float(unconstrained_spectrum[:2*count].sum() / unconstrained_spectrum.sum()),
                                               isotropic_optimal=float(ratio(iso, optimal_iso)),
                                               isotropic_planes=sorted(map(int, optimal_iso)),
                                               q_weighted_isotropic_choice=float(ratio(gram, optimal_iso)),
                                               q_weighted_greedy=float(greedy),
                                               q_weighted_exchanged=float(swapped),
                                               q_weighted_planes=selected)
                groups.append(dict(group=g, total_q_weighted_score_variance=float(gram.sum()),
                                   off_diagonal_fraction=float((gram.sum()-np.trace(gram))/gram.sum()),
                                   counts=entries))
            result['layers'][str(layer)] = groups
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    for layer, groups in result['layers'].items():
        for count in (7, 14, 28):
            print(layer, count, 'isotropic', np.mean([g['counts'][str(count)]['isotropic_optimal'] for g in groups]),
                  'Q weighted', np.mean([g['counts'][str(count)]['q_weighted_exchanged'] for g in groups]),
                  'unrestricted Q weighted', np.mean([g['counts'][str(count)]['unrestricted_q_weighted_optimal'] for g in groups]))


if __name__ == '__main__':
    main()
