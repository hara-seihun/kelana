#!/usr/bin/env python3
"""Exact isotropic rank allocation for one-dimensional post-RoPE plane cache."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from safetensors import safe_open
import torch

from sys import path as sys_path
ROOT = Path(__file__).resolve().parent.parent
sys_path.insert(0, str(ROOT / 'rope-key-orbit'))
from orbit import orbit_covariance


def sha(file):
    with open(file, 'rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def allocate(cov, budget):
    """Exact rank-0/1/2 choice for every RoPE plane under isotropic score queries."""
    axes = np.stack((np.arange(64), np.arange(64, 128)), axis=1)
    eig = np.linalg.eigh(cov[axes[:, :, None], axes[:, None, :]])
    values, vectors = eig.eigenvalues, eig.eigenvectors
    gains = np.stack((np.zeros(64), values[:, 1], values.sum(axis=1)), axis=1)
    scores = np.full((65, budget+1), -np.inf)
    choices = np.full((65, budget+1), -1, dtype=np.int8)
    scores[0, 0] = 0
    for i in range(64):
        for b in range(budget+1):
            for rank in range(min(2, b)+1):
                value = scores[i, b-rank] + gains[i, rank]
                if value > scores[i+1, b]:
                    scores[i+1, b], choices[i+1, b] = value, rank
    rank = np.empty(64, dtype=np.int8)
    b = budget
    for i in range(64, 0, -1):
        rank[i-1] = choices[i, b]
        b -= int(rank[i-1])
    assert b == 0
    return rank, vectors[:, :, 1], float(scores[64, budget])


def projector(rank, axes):
    p = np.zeros((128, 128), dtype=np.float64)
    for i in range(64):
        ix = np.array([i, i+64])
        if rank[i] == 2:
            p[ix, ix] = 1
        elif rank[i] == 1:
            p[np.ix_(ix, ix)] = np.outer(axes[i], axes[i])
    return p


def q_fraction(q, cov, p):
    residual = np.eye(128) - p
    return float(1 - np.sum((residual @ q @ residual) * cov) / np.sum(q * cov))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    model, config = args.model / 'model.safetensors', args.model / 'config.json'
    cfg = json.loads(config.read_text())
    assert (cfg['hidden_size'], cfg['head_dim'], cfg['num_attention_heads'], cfg['num_key_value_heads']) == (1024, 128, 16, 8)
    allocation = Path('/path/to/workspace/data/kelana-subbit/rope-plane-rate-allocation/receipt.json')
    prior = json.loads(allocation.read_text())
    out = dict(source_sha256=sha(Path(__file__)), orbit_source_sha256=sha(ROOT/'rope-key-orbit'/'orbit.py'),
               allocation_sha256=sha(allocation), model_sha256=sha(model), config_sha256=sha(config),
               positions=4096, budget_per_group=28, layers={})
    with safe_open(model, framework='pt', device='cpu') as f:
        for layer in (0, 14):
            stem = f'model.layers.{layer}.self_attn.'
            k = f.get_tensor(stem+'k_proj.weight').to(dtype=torch.float64).numpy()
            q = f.get_tensor(stem+'q_proj.weight').to(dtype=torch.float64).numpy()
            groups = []
            total_iso = total_weighted = iso_half = iso_whole = weight_half = weight_whole = weight_capped = 0.
            capped_masks = prior['layers'][str(layer)]['weighted']['choices']['capped16']['masks']
            for g in range(8):
                cov = orbit_covariance(k[128*g:128*(g+1)], cfg['rope_theta'], 4096)
                query = np.concatenate((q[256*g:256*g+128], q[256*g+128:256*(g+1)]), axis=1)/np.sqrt(2)
                qc = orbit_covariance(query, cfg['rope_theta'], 4096)
                rank, axes, gain = allocate(cov, 28)
                energy = np.diag(cov)[:64] + np.diag(cov)[64:]
                selected = np.argsort(-energy, kind='stable')[:14]
                whole = np.zeros(64, dtype=np.int8)
                whole[selected] = 2
                capped = np.zeros(64, dtype=np.int8)
                capped[capped_masks[g]] = 2
                ph = projector(rank, axes)
                pw = projector(whole, axes)
                pc = projector(capped, axes)
                denom = float(np.sum(qc * cov))
                rh = q_fraction(qc, cov, ph)
                rw = q_fraction(qc, cov, pw)
                rc = q_fraction(qc, cov, pc)
                total_iso += np.trace(cov)
                iso_half += gain
                iso_whole += energy[selected].sum()
                total_weighted += denom
                weight_half += rh * denom
                weight_whole += rw * denom
                weight_capped += rc * denom
                groups.append(dict(group=g, ranks=rank.tolist(), one_axis={str(i):axes[i].tolist() for i in np.flatnonzero(rank==1)},
                                   whole14=sorted(map(int, selected)), capped_planes=capped_masks[g], rank1_count=int(np.sum(rank==1)),
                                   isotropic_half=float(gain/np.trace(cov)), isotropic_whole=float(energy[selected].sum()/np.trace(cov)),
                                   q_weighted_half=rh, q_weighted_whole=rw, q_weighted_capped=rc,
                                   isotropic_denominator=float(np.trace(cov)), q_weighted_denominator=denom))
            out['layers'][str(layer)] = dict(isotropic_half=float(iso_half/total_iso), isotropic_whole=float(iso_whole/total_iso),
                q_weighted_half=float(weight_half/total_weighted), q_weighted_whole=float(weight_whole/total_weighted),
                q_weighted_capped=float(weight_capped/total_weighted), groups=groups)
            print(layer, {key:out['layers'][str(layer)][key] for key in ('isotropic_half','isotropic_whole','q_weighted_half','q_weighted_whole','q_weighted_capped')}, flush=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(out, indent=2)+'\n')


if __name__ == '__main__':
    main()
