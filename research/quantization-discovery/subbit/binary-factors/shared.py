#!/usr/bin/env python3
"""Matched-rate independent versus jointly fitted first-stage Q/K/V binary factors."""
import argparse
import json
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from compare import MODEL, UPSTREAM, load_upstream, pack_sign, rank_for_rate, response_error

FIXTURES = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')


def export(factor, name, output):
    u = factor['A'].T.sign()
    v = factor['B'].sign()
    u[u == 0] = 1
    v[v == 0] = 1
    pu, pv = pack_sign(u), pack_sign(v)
    pre = factor['scale_pre'].reshape(-1).half().cpu().numpy()
    post = factor['scale_post'].reshape(-1).half().cpu().numpy()
    n, rank = u.shape
    k = v.shape[1]
    path = output / f'{name}.npz'
    np.savez(path, U=pu, V=pv, scale_pre=pre, scale_post=post,
             dimensions=np.array([n, k, rank], dtype=np.int32))
    return path


def decode(path):
    with np.load(path) as img:
        n, k, rank = map(int, img['dimensions'])
        u = torch.from_numpy(np.unpackbits(img['U'], axis=1, bitorder='little')[:, :rank].astype(np.float32)) * 2 - 1
        v = torch.from_numpy(np.unpackbits(img['V'], axis=1, bitorder='little')[:, :k].astype(np.float32)) * 2 - 1
        pre = torch.from_numpy(img['scale_pre'].astype(np.float32))
        post = torch.from_numpy(img['scale_post'].astype(np.float32))
        factor_bytes = img['U'].nbytes + img['V'].nbytes
        scale_bytes = pre.numel() * 2 + post.numel() * 2
    return (u * post[:, None]) @ (v * pre[None, :]), factor_bytes, scale_bytes


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--layer', type=int, choices=[0, 7, 14, 27], required=True)
    p.add_argument('--target', type=float, default=.55)
    p.add_argument('--shared-rank', type=int, help='32-aligned shared rank at a smaller work/rate point')
    p.add_argument('--independent-ranks', type=int, nargs=3, metavar=('Q', 'K', 'V'),
                   help='explicit 32-aligned independent ranks for matched-rate comparisons')
    p.add_argument('--private-residual-rank', type=int, default=0,
                   help='fit an independent signed residual per consumer after the shared stage')
    p.add_argument('--model', type=Path, default=MODEL)
    p.add_argument('--fixtures', type=Path, default=FIXTURES)
    p.add_argument('--upstream', type=Path, default=UPSTREAM)
    p.add_argument('--outer-iters', type=int, default=400)
    p.add_argument('--inner-iters', type=int, default=5)
    p.add_argument('--threads', type=int, default=8)
    p.add_argument('--seed', type=int, default=0)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    torch.set_num_threads(a.threads)
    a.out.mkdir(parents=True, exist_ok=True)
    with np.load(a.fixtures / f'layer{a.layer:02}-self_attn_q_proj.npz') as fx:
        q = torch.from_numpy(fx['weight'].copy())
        train = torch.from_numpy(fx['train'].copy())
        validation = torch.from_numpy(fx['validation'].copy())
    keys = [f'model.layers.{a.layer}.self_attn.{name}_proj.weight' for name in ('q', 'k', 'v')]
    with safe_open(a.model, framework='pt', device='cpu') as f:
        weights = [q] + [f.get_tensor(key).float() for key in keys[1:]]
    names = ('q', 'k', 'v')
    sizes = [w.shape[0] for w in weights]
    k = train.shape[1]
    norm_i = train.square().mean(0)
    norm_i = .6 * norm_i + .4 * norm_i.mean()
    solver = load_upstream(a.upstream)
    separate = {}
    sum_factor_bytes = 0
    sum_scale_bytes = 0
    independent_file_bytes = 0
    total_work = 0
    fit_seconds = 0
    ranks = []
    if a.independent_ranks and any(r <= 0 or r % 32 for r in a.independent_ranks):
        p.error('independent ranks must be positive multiples of 32')
    for index, (name, weight) in enumerate(zip(names, weights)):
        n = weight.shape[0]
        rank = a.independent_ranks[index] if a.independent_ranks else rank_for_rate(n, k, a.target)
        ranks.append(rank)
        torch.manual_seed(a.seed)
        start = time.monotonic()
        factors = solver(weight, norm_i, torch.ones(n), rank,
                         outer_iters=a.outer_iters, inner_iters=a.inner_iters,
                         rho_scheduler='linear', is_transpose=n < k)
        duration = time.monotonic() - start
        fit_seconds += duration
        path = export(factors, f'layer{a.layer:02}_{name}_independent', a.out)
        estimate, bits, scales = decode(path)
        sum_factor_bytes += bits
        sum_scale_bytes += scales
        independent_file_bytes += path.stat().st_size
        total_work += rank * (k + n)
        separate[name] = {'rank': rank, 'fit_seconds': duration,
                          'artifact': str(path), 'factor_bytes': bits, 'scale_bytes': scales,
                          'validation_response': response_error(weight, estimate, validation),
                          'train_response': response_error(weight, estimate, train)}
    budget_bytes = sum_factor_bytes + sum_scale_bytes
    # The shared scales contain one common input transform and three output streams.
    # Select a 32-aligned rank that fits the *actual* independent payload budget.
    scale_bytes_shared = 2 * (k + sum(sizes))
    rank_shared = ((8 * budget_bytes - 8 * scale_bytes_shared) // (k + sum(sizes)) // 32) * 32
    if a.shared_rank is not None:
        if a.shared_rank <= 0 or a.shared_rank % 32 or a.shared_rank > rank_shared:
            p.error('--shared-rank must be a positive multiple of 32 within the independent budget')
        rank_shared = a.shared_rank
    torch.manual_seed(a.seed)
    start = time.monotonic()
    factors = solver(torch.cat(weights, dim=0), norm_i, torch.ones(sum(sizes)), rank_shared,
                     outer_iters=a.outer_iters, inner_iters=a.inner_iters,
                     rho_scheduler='linear')
    shared_seconds = time.monotonic() - start
    path = export(factors, f'layer{a.layer:02}_qkv_shared_rank{rank_shared}', a.out)
    estimate, factor_bytes, scale_bytes = decode(path)
    shared = {}
    hybrid = {}
    private_bytes = 0
    private_file_bytes = 0
    private_work = 0
    private_seconds = 0
    if a.private_residual_rank and (a.private_residual_rank <= 0 or a.private_residual_rank % 32):
        p.error('--private-residual-rank must be a positive multiple of 32')
    for name, weight, part in zip(names, weights, estimate.split(sizes, dim=0)):
        shared[name] = {'validation_response': response_error(weight, part, validation),
                        'train_response': response_error(weight, part, train)}
        if a.private_residual_rank:
            torch.manual_seed(a.seed)
            start = time.monotonic()
            private = solver(weight - part, norm_i, torch.ones(weight.shape[0]),
                             a.private_residual_rank, outer_iters=a.outer_iters,
                             inner_iters=a.inner_iters, rho_scheduler='linear',
                             is_transpose=weight.shape[0] < k)
            private_seconds += time.monotonic() - start
            private_path = export(private, f'layer{a.layer:02}_{name}_private_rank{a.private_residual_rank}', a.out)
            addition, private_factors, private_scales = decode(private_path)
            private_bytes += private_factors + private_scales
            private_file_bytes += private_path.stat().st_size
            private_work += a.private_residual_rank * (k + weight.shape[0])
            hybrid[name] = {'artifact': str(private_path),
                            'validation_response': response_error(weight, part + addition, validation),
                            'train_response': response_error(weight, part + addition, train)}
    answer = {
        'method': 'Upstream NanoQuant ADMM initialization; separate factors versus stacked-QKV common first factor',
        'layer': a.layer, 'rank_selection_target_bpw': a.target, 'input_dim': k,
        'output_dims': dict(zip(names, sizes)),
        'train_tokens': int(train.shape[0]), 'validation_tokens': int(validation.shape[0]),
        'input_norm': 'forward squared mean, 0.4 shrinkage', 'output_norm': 'uniform ones',
        'outer_iters': a.outer_iters, 'inner_iters': a.inner_iters, 'seed': a.seed,
        'threads': a.threads, 'separate': {'ranks': ranks,
            'factor_bytes': sum_factor_bytes, 'scale_bytes': sum_scale_bytes,
            'payload_bytes': budget_bytes, 'serialized_file_bytes': independent_file_bytes,
            'bpw': 8 * budget_bytes / (k * sum(sizes)),
            'signed_accumulations_per_vector': total_work, 'fit_seconds': fit_seconds,
            'projections': separate},
        'shared': {'rank': rank_shared, 'factor_bytes': factor_bytes, 'scale_bytes': scale_bytes,
            'payload_bytes': factor_bytes + scale_bytes,
            'serialized_file_bytes': path.stat().st_size,
            'bpw': 8 * (factor_bytes + scale_bytes) / (k * sum(sizes)),
            'signed_accumulations_per_vector': rank_shared * (k + sum(sizes)),
            'first_stage_accumulations': rank_shared * k,
            'fit_seconds': shared_seconds, 'artifact': str(path), 'projections': shared}}
    if a.private_residual_rank:
        total_bytes = factor_bytes + scale_bytes + private_bytes
        answer['shared_plus_private'] = {
            'private_rank_per_consumer': a.private_residual_rank,
            'payload_bytes': total_bytes,
            'serialized_file_bytes': path.stat().st_size + private_file_bytes,
            'bpw': 8 * total_bytes / (k * sum(sizes)),
            'signed_accumulations_per_vector': rank_shared * (k + sum(sizes)) + private_work,
            'fit_seconds': shared_seconds + private_seconds, 'projections': hybrid}
    report = a.out / f'layer{a.layer:02}_qkv_rank{rank_shared}.json'
    report.write_text(json.dumps(answer, indent=2) + '\n')
    print(json.dumps(answer), flush=True)


if __name__ == '__main__':
    main()
