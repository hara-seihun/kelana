#!/usr/bin/env python3
"""Independent-moment optimal bilinear rank control for finite causal Q/K scores."""
import argparse
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('finite_fit', HERE.parent / 'rope-finite-kl/fit.py')
finite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(finite)


def factor(q, k, ranks):
    """Minimize independent Q/K second-moment squared score error at fixed ranks."""
    factors, energy = [], []
    for group, rank in enumerate(ranks):
        queries = q[:, group*2:group*2+2].reshape(-1, 128).double()
        keys = k[:, group].reshape(-1, 128).double()
        cq = queries.T @ queries / len(queries)
        ck = keys.T @ keys / len(keys)
        eq, uq = torch.linalg.eigh(cq)
        ek, uk = torch.linalg.eigh(ck)
        if eq[0] <= 0 or ek[0] <= 0:
            raise ValueError('second moment not positive definite')
        qroot = (uq * eq.sqrt()) @ uq.T
        kroot = (uk * ek.sqrt()) @ uk.T
        qinv = (uq * eq.rsqrt()) @ uq.T
        kinv = (uk * ek.rsqrt()) @ uk.T
        left, singular, right = torch.linalg.svd(qroot @ kroot)
        a = (qinv @ left[:, :rank] * singular[:rank].sqrt()).float().contiguous()
        b = (kinv @ right[:rank, :].T * singular[:rank].sqrt()).float().contiguous()
        factors.append((a, b))
        energy.append(float(singular[:rank].square().sum() / singular.square().sum()))
    return factors, energy


def evaluate(q, k, masks, factors):
    results = {name: [] for name in ('whole_plane', 'bilinear_rank', 'fp16_factor_bf16_cache')}
    triangle = torch.ones(256, 256, dtype=torch.bool).triu(1)
    for window in range(q.shape[0]):
        totals = {name: {'kl': 0., 'weighted_score_variance': 0.} for name in results}
        for group in range(8):
            keys = k[window, group]
            mask = masks[group]
            coords = mask + [i+64 for i in mask]
            a, b = factors[group]
            compressed_keys = keys @ b
            paid_a, paid_b = a.half().float(), b.half().float()
            paid_keys = (keys @ paid_b).bfloat16().float()
            for head in (group*2, group*2+1):
                query = q[window, head]
                teacher = (query @ keys.T / math.sqrt(128)).masked_fill(triangle, -1e9)
                p = teacher.softmax(-1)
                lp = teacher.log_softmax(-1)
                candidates = {
                    'whole_plane': query[:, coords] @ keys[:, coords].T / math.sqrt(128),
                    'bilinear_rank': (query @ a) @ compressed_keys.T / math.sqrt(128),
                    'fp16_factor_bf16_cache': (query @ paid_a) @ paid_keys.T / math.sqrt(128),
                }
                for name, candidate in candidates.items():
                    candidate = candidate.masked_fill(triangle, -1e9)
                    delta = (candidate - teacher).masked_fill(triangle, 0)
                    centered = delta - (p * delta).sum(-1, keepdim=True)
                    totals[name]['kl'] += float((p * (lp - candidate.log_softmax(-1)).masked_fill(triangle, 0)).sum(-1).mean()) / 16
                    totals[name]['weighted_score_variance'] += float((p * centered.square()).sum(-1).mean()) / 16
        for name in results:
            results[name].append(totals[name])
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        weights = {name: model.get_tensor(f'model.layers.{args.layer}.self_attn.{name}.weight').float()
                   for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    prior_path = finite.DATA / f'rope-exhaustive/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    masks = prior['final_masks']
    ranks = [2 * len(mask) for mask in masks]
    train = finite.projections(finite.load_capture(args.layer, 'train').reshape(8, 256, 1024), weights)
    factors, energy = factor(*train, ranks)
    validation = finite.projections(finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024), weights)
    scores = evaluate(*validation, masks, factors)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image_path = args.output.with_suffix('.npz')
    np.savez_compressed(image_path, **{f'group{group:02d}_{side}': matrix.half().numpy()
                                       for group, (a, b) in enumerate(factors)
                                       for side, matrix in (('query', a), ('key', b))})
    result = {
        'layer': args.layer, 'ranks': ranks, 'train_independent_score_energy_retained': energy,
        'validation': scores, 'masks': masks,
        'observation': 'original-producer BF16 projections/norm, FP32 RoPE and scores, 256-key causal softmax; previously inspected held windows',
        'family': 'real post-RoPE key and query linear factors, shared by two GQA heads; independent uncentered train second-moment squared score optimum, not causal KL optimum',
        'factor_storage_bytes_fp16': 2 * 128 * sum(ranks) * 2,
        'fp16_factor_image': str(image_path), 'fp16_factor_image_sha256': finite.sha(image_path),
        'key_query_projection_products_per_token': [128 * sum(ranks), 256 * sum(ranks)],
        'source_sha256': finite.sha(Path(__file__)), 'model_sha256': finite.sha(finite.MODEL),
        'capture_sha256': prior['capture_sha256'], 'prior_sha256': finite.sha(prior_path),
    }
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'layer': args.layer, 'ranks': ranks, 'train_energy': energy,
                      'held': {name: {key: float(np.mean([w[key] for w in windows]))
                                      for key in ('kl', 'weighted_score_variance')}
                               for name, windows in scores.items()}}, indent=2), flush=True)


if __name__ == '__main__':
    main()
