#!/usr/bin/env python3
"""Fit and evaluate a shared output basis for routed MoE down projections.

Input: float32 .npy or raw C-contiguous BF16 [expert, output=2048, intermediate=512].
No GPU/model inference. The held-out panel uses independent synthetic hidden vectors.
"""

import argparse
import json
from pathlib import Path

import numpy as np
from scipy.linalg import eigh

D = 2048
F = 512
E = 256
K = 8


def cost(rank, weight_bytes, activation_bytes=2):
    direct_mac = K * D * F
    composed_mac = K * rank * F + D * rank
    direct_weights = E * D * F * weight_bytes
    composed_weights = (E * rank * F + D * rank) * weight_bytes
    return {
        'rank': rank,
        'routed_down_mac_per_token': direct_mac,
        'composed_down_mac_per_token': composed_mac,
        'mac_ratio': composed_mac / direct_mac,
        'direct_layer_weights_bytes': round(direct_weights),
        'shared_basis_and_expert_factors_bytes': round(composed_weights),
        'storage_ratio': composed_weights / direct_weights,
        'direct_selected_expert_weight_bytes_per_token': round(K * D * F * weight_bytes),
        'composed_selected_expert_plus_common_bytes_per_token': round((K * rank * F + D * rank) * weight_bytes),
        'rank_scatter_bytes_if_materialized': K * rank * 4,
        'extra_common_input_quant_bytes_if_materialized': D * activation_bytes,
        'extra_common_output_bytes_if_materialized': D * 4,
        'router_weight_products': K * rank,
        'excluded_unchanged_router_logits': E,
        'excluded_unchanged_gate_up_and_shared_expert_mac': K * 2 * F * D + 3 * F * D,
    }


def panel(weights, basis, pool, seed, trials):
    rng = np.random.default_rng(seed)
    output = []
    for _ in range(trials):
        ids = rng.choice(pool, size=K, replace=False)
        hidden = rng.standard_normal((K, F)).astype('float32')
        logits = rng.standard_normal(K)
        gate = np.exp(logits - logits.max())
        gate = (gate / gate.sum()).astype('float32')
        contributions = np.einsum('kdf,kf->kd', weights[ids], hidden, optimize=True)
        reference = (gate[:, None] * contributions).sum(axis=0, dtype=np.float32)
        factors = np.einsum('dr,kdf->krf', basis, weights[ids], optimize=True)
        latent = np.einsum('krf,kf->kr', factors, hidden, optimize=True)
        candidate = (gate[:, None] * latent).sum(axis=0, dtype=np.float32) @ basis.T
        output.append(float(np.linalg.norm(reference - candidate) / np.linalg.norm(reference)))
    return {
        'routed_relative_rms_mean': float(np.mean(output)),
        'routed_relative_rms_max': float(np.max(output)),
        'trials': trials,
        'expert_pool': list(pool),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('weights', type=Path)
    parser.add_argument('--train-experts', type=int, default=8)
    parser.add_argument('--raw-experts', type=int, help='expert count for raw BF16 input')
    parser.add_argument('--ranks', type=int, nargs='+', default=[128, 256, 512])
    parser.add_argument('--trials', type=int, default=16)
    parser.add_argument('--seed', type=int, default=44)
    parser.add_argument('--bytes-per-weight', type=float, default=0.5625)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.raw_experts:
        raw = np.fromfile(args.weights, dtype='<u2')
        if raw.size != args.raw_experts * D * F:
            parser.error('raw BF16 size does not match [N,2048,512]')
        weights = (raw.astype('<u4') << 16).view('<f4').reshape(args.raw_experts, D, F)
    else:
        weights = np.load(args.weights, mmap_mode='r')
        if weights.ndim != 3 or weights.shape[1:] != (D, F) or weights.dtype != np.float32:
            parser.error('expected float32 .npy [N,2048,512]')
    n = weights.shape[0]
    if not K <= args.train_experts <= n:
        parser.error('need at least eight training experts and at most all available experts')
    if args.train_experts != n and n - args.train_experts < K:
        parser.error('need eight disjoint held experts, or train on all as an in-sample oracle')
    if args.trials <= 0 or args.bytes_per_weight <= 0 or any(r <= 0 or r > D for r in args.ranks):
        parser.error('trials, bytes-per-weight and ranks must be in range')
    train = range(args.train_experts)
    held = range(args.train_experts, n)
    gram = np.zeros((D, D), dtype=np.float64)
    for expert in train:
        w = np.asarray(weights[expert], dtype=np.float64)
        gram += w @ w.T
    ranks = sorted(set(args.ranks))
    eigenvalues, eigenvectors = eigh(gram, subset_by_index=[D - max(ranks), D - 1], check_finite=False,
                                     driver='evr')
    total_energy = float(np.trace(gram))
    result = {
        'source': str(args.weights), 'shape': list(weights.shape),
        'fit_experts': list(train), 'held_experts': list(held),
        'fit_objective': 'minimum isotropic-hidden squared output error, shared orthonormal output basis',
        'numerical_contract': 'BF16 source weights decoded to float32; real-valued rank-r approximation and float32 CPU evaluation; factor/basis quantization not evaluated',
        'rank_panels': [],
    }
    for rank in ranks:
        basis = np.asarray(eigenvectors[:, -rank:], dtype=np.float32)
        train_captured = sum(float(np.linalg.norm(basis.T @ np.asarray(weights[e], dtype=np.float32)) ** 2) for e in train)
        row = cost(rank, args.bytes_per_weight)
        row['fit_weight_relative_rms'] = float(np.sqrt(max(0, 1 - train_captured / total_energy)))
        row['fit_routing'] = panel(weights, basis, train, args.seed, args.trials)
        if len(held) >= K:
            held_total = sum(float(np.linalg.norm(weights[e]) ** 2) for e in held)
            held_captured = sum(float(np.linalg.norm(basis.T @ np.asarray(weights[e], dtype=np.float32)) ** 2) for e in held)
            row['held_weight_relative_rms'] = float(np.sqrt(max(0, 1 - held_captured / held_total)))
            row['held_routing'] = panel(weights, basis, held, args.seed + 1, args.trials)
        result['rank_panels'].append(row)
    text = json.dumps(result, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + '\n')
    print(text)


if __name__ == '__main__':
    main()
