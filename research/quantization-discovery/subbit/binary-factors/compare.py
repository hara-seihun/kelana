#!/usr/bin/env python3
"""Bounded, upstream-ADMM-only NanoQuant matrix comparator on pinned BF16 weights."""
import argparse
import importlib.util
import json
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
UPSTREAM = Path(__file__).with_name('nanoquant_admm.py')
DEFAULT_KEY = 'model.layers.0.self_attn.k_proj.weight'


def load_upstream(path):
    spec = importlib.util.spec_from_file_location('nanoquant_admm_pinned', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.factorize_admm_nanoquant


def load_array(path):
    if path is None:
        return None
    data = np.load(path)
    if isinstance(data, np.lib.npyio.NpzFile):
        with data:
            if 'x' not in data.files:
                raise ValueError(f'{path} must have an x array')
            data = data['x']
    return torch.from_numpy(np.asarray(data).reshape(-1, data.shape[-1]).copy()).float()


def rank_for_rate(n, k, target):
    # Upstream calculate_ranks: rank is rounded down to 32, with 16-bit pre/post scales.
    rank = max(32, (int(target * n * k / (n + k) - 16) // 32) * 32)
    return min(rank, min(n, k))


def pack_sign(t):
    # A contiguous row-major 1-bit image, low-order bit first. Each row is byte-padded.
    return np.packbits((t.detach().cpu().numpy() > 0).astype(np.uint8), axis=1, bitorder='little')


def response_error(weight, estimate, x):
    if x is None:
        return None
    if x.shape[-1] != weight.shape[-1]:
        raise ValueError(f'activation width {x.shape[-1]} != matrix input width {weight.shape[-1]}')
    with torch.no_grad():
        y = x @ weight.T
        delta = x @ (estimate - weight).T
        return {'samples': int(x.shape[0]), 'relative_squared_error': (delta.square().sum() / y.square().sum()).item(),
                'relative_rms_error': (delta.square().sum() / y.square().sum()).sqrt().item()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', type=Path, default=MODEL)
    parser.add_argument('--upstream', type=Path, default=UPSTREAM)
    parser.add_argument('--key', default=DEFAULT_KEY)
    parser.add_argument('--fixture', type=Path, help='Paired weight/train/validation NPZ from pinned Qwen fixtures')
    parser.add_argument('--rates', type=float, nargs='+', default=[.55, .8, 1.])
    parser.add_argument('--outer-iters', type=int, default=4)
    parser.add_argument('--inner-iters', type=int, default=5)
    parser.add_argument('--threads', type=int, default=8)
    parser.add_argument('--seed', type=int, default=0)
    parser.add_argument('--train-activations', type=Path)
    parser.add_argument('--heldout-activations', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(args.threads)
    if args.fixture is not None:
        if args.train_activations or args.heldout_activations:
            parser.error('--fixture supplies both activation splits; do not pass separate activation paths')
        with np.load(args.fixture) as fixture:
            weight = torch.from_numpy(fixture['weight'].copy()).float()
            train = torch.from_numpy(fixture['train'].copy()).float()
            heldout = torch.from_numpy(fixture['validation'].copy()).float()
        layer, projection = args.fixture.stem.split('-', 1)
        projection = projection.replace('self_attn_', 'self_attn.').replace('mlp_', 'mlp.')
        args.key = f'model.layers.{int(layer[5:])}.{projection}.weight'
    else:
        with safe_open(args.model, framework='pt', device='cpu') as f:
            weight = f.get_tensor(args.key).float()
        train = load_array(args.train_activations)
        heldout = load_array(args.heldout_activations)
    if weight.ndim != 2:
        raise ValueError(f'{args.key} is not a matrix')
    n, k = weight.shape
    if train is not None and train.shape[-1] != k:
        raise ValueError('training activation width mismatch')
    if train is None:
        i_norm = torch.ones(k)
    else:
        i_norm = train.square().mean(0)
        i_norm = .6 * i_norm + .4 * i_norm.mean()
    o_norm = torch.ones(n)  # No calibration loss gradients supplied.
    factorize = load_upstream(args.upstream)
    args.out.mkdir(parents=True, exist_ok=True)
    entries = []
    for rate in args.rates:
        rank = rank_for_rate(n, k, rate)
        torch.manual_seed(args.seed)
        start = time.monotonic()
        result = factorize(weight, i_norm, o_norm, rank, outer_iters=args.outer_iters,
                           inner_iters=args.inner_iters, rho_scheduler='linear',
                           is_transpose=n < k)
        elapsed = time.monotonic() - start
        # Exactly NanoQuantLinear's no-training forward, including binary_ste(sign),
        # not the upstream ADMM W_final (which still contains continuous magnitudes).
        u = result['A'].T.sign()
        v = result['B'].sign()
        u[u == 0] = 1
        v[v == 0] = 1
        pre = result['scale_pre'].reshape(-1).float()
        post = result['scale_post'].reshape(-1).float()
        pu, pv = pack_sign(u), pack_sign(v)
        pre = pre.half().float()
        post = post.half().float()
        # Evaluate the actual packed image and rounded scales, not latent ADMM values.
        u_dec = torch.from_numpy(np.unpackbits(pu, axis=1, bitorder='little')[:, :rank].astype(np.float32)) * 2 - 1
        v_dec = torch.from_numpy(np.unpackbits(pv, axis=1, bitorder='little')[:, :k].astype(np.float32)) * 2 - 1
        estimate = (u_dec * post[:, None]) @ (v_dec * pre[None, :])
        # Scale values are BF16 in NanoQuantLinear and FP16 in its GEMV kernel.
        scale_bytes = 2 * (n + k)
        bit_bytes = pu.nbytes + pv.nbytes
        name = args.key.replace('.', '_') + f'_{rate:g}'
        artifact = args.out / f'{name}.npz'
        np.savez(artifact, U=pu, V=pv, scale_pre=pre.numpy().astype(np.float16),
                 scale_post=post.numpy().astype(np.float16), dimensions=np.array([n, k, rank], dtype=np.int32))
        err = (estimate - weight).square().sum() / weight.square().sum()
        entry = {'target_matrix_bpw': rate, 'rank': rank, 'dimensions': [n, k], 'seed': args.seed,
                 'outer_iters': args.outer_iters, 'inner_iters': args.inner_iters,
                 'seconds_cpu': elapsed, 'upstream_float_weight_relative_squared_error':
                 ((result['W_final'] - weight).square().sum() / weight.square().sum()).item(),
                 'exported_binary_weight_relative_squared_error': err.item(),
                 'heldout_response': response_error(weight, estimate, heldout),
                 'factor_bytes': bit_bytes, 'scale_bytes': scale_bytes,
                 'matrix_payload_bpw': 8 * (bit_bytes + scale_bytes) / (n * k),
                 'decode_work_per_vector': {'signed_accumulations': rank * (k + n),
                  'pre_post_scale_multiplications': k + n,
                  'minimum_packed_factor_reads_bytes': bit_bytes,
                  'minimum_bf16_vector_io_bytes': 2 * (k + 2 * rank + n),
                  'scale_reads_bytes': scale_bytes},
                 'serialized_file_bytes': artifact.stat().st_size,
                 'artifact': str(artifact)}
        entries.append(entry)
        print(json.dumps(entry), flush=True)
    report = {'method': 'NanoQuant upstream ADMM initialization, binary sign and two-scales; no block/model tuning',
              'weight': str(args.model), 'fixture': str(args.fixture) if args.fixture else None,
              'key': args.key, 'upstream': str(args.upstream),
              'input_norm': '0.4-shrunk forward-activation squared mean' if train is not None else 'uniform ones',
              'output_norm': 'uniform ones, not upstream loss gradients',
              'train_activations': str(args.train_activations or args.fixture) if train is not None else None,
              'heldout_activations': str(args.heldout_activations or args.fixture) if heldout is not None else None,
              'threads': args.threads, 'entries': entries}
    (args.out / f'{args.key.replace(".", "_")}.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
