#!/usr/bin/env python3
"""Fit pinned NanoQuant ADMM signs and the established four train-response sweeps."""
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
OUT = Path('/path/to/workspace/data/kelana-subbit/size-transfer/factors')
UPSTREAM = ROOT / 'binary-factors/nanoquant_admm.py'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1 << 22), b''):
            h.update(block)
    return h.hexdigest()


def response(weight, inputs, u, v, pre, post):
    target = inputs @ weight.T
    prediction = ((inputs * pre) @ v.T @ u.T) * post
    return ((target - prediction).square().sum() / target.square().sum()).item()


def activation_output_fit(weight, train, u, v, pre, post, sweeps=4):
    features = (train * pre) @ v.T
    reference = train @ weight.T
    gram = features.T @ features / len(train)
    h = reference.T @ features / len(train)
    for _ in range(sweeps):
        current = u @ gram
        for r in range(v.shape[0]):
            score = h[:, r] - post * (current[:, r] - u[:, r] * gram[r, r])
            updated = torch.where(score >= 0, 1., -1.)
            delta = updated - u[:, r]
            u[:, r] = updated
            current += delta[:, None] * gram[r][None, :]
        prediction = features @ u.T
        post = ((reference * prediction).sum(0) /
                prediction.square().sum(0).clamp_min(1e-20)).clamp_min(0).half().float()
    return u, post


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture', type=Path, required=True)
    parser.add_argument('--iterations', type=int, default=400)
    parser.add_argument('--threads', type=int, default=8)
    parser.add_argument('--out', type=Path, default=OUT)
    args = parser.parse_args()
    torch.set_num_threads(args.threads)
    torch.manual_seed(0)
    with np.load(args.fixture) as fixture:
        weight, train, validation = [torch.from_numpy(fixture[key].copy()).float()
                                     for key in ('weight', 'train', 'validation')]
    n, k = weight.shape
    rank = max(32, (int(.55 * n * k / (n + k) - 16) // 32) * 32)
    norm = .6 * train.square().mean(0) + .4 * train.square().mean()
    spec = importlib.util.spec_from_file_location('pinned_nanoquant', UPSTREAM)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    start = time.monotonic()
    result = module.factorize_admm_nanoquant(weight, norm, torch.ones(n), rank,
                                              outer_iters=args.iterations, inner_iters=5,
                                              rho_scheduler='linear', is_transpose=n < k)
    solver_seconds = time.monotonic() - start
    u, v = result['A'].T.sign(), result['B'].sign()
    u[u == 0] = 1
    v[v == 0] = 1
    pre, post = result['scale_pre'].flatten().half().float(), result['scale_post'].flatten().half().float()
    initial = response(weight, validation, u, v, pre, post)
    initial_train = response(weight, train, u, v, pre, post)
    u, post = activation_output_fit(weight, train, u, v, pre, post)
    final = response(weight, validation, u, v, pre, post)
    final_train = response(weight, train, u, v, pre, post)
    args.out.mkdir(parents=True, exist_ok=True)
    image = args.out / f'{args.fixture.stem}-binary.npz'
    u_bytes = np.packbits((u.numpy() > 0).astype(np.uint8), axis=1, bitorder='little')
    v_bytes = np.packbits((v.numpy() > 0).astype(np.uint8), axis=1, bitorder='little')
    np.savez(image, U=u_bytes, V=v_bytes, scale_pre=pre.numpy().astype(np.float16),
             scale_post=post.numpy().astype(np.float16), dimensions=np.array([n, k, rank], dtype=np.int32))
    payload = u_bytes.nbytes + v_bytes.nbytes + 2 * (n + k)
    report = {'fixture': str(args.fixture), 'fixture_sha256': sha(args.fixture),
              'method': 'upstream NanoQuant ADMM initialization; binary signs; four output-response coordinate sweeps',
              'upstream_sha256': sha(UPSTREAM), 'iterations': args.iterations, 'inner_iterations': 5,
              'train_tokens': len(train), 'validation_tokens': len(validation),
              'dimensions': [n, k], 'rank': rank, 'matrix_payload_bytes': payload,
              'matrix_payload_bpw': 8 * payload / (n * k),
              'dimension_descriptor_bytes': 12,
              'matrix_image_bpw_including_descriptor': 8 * (payload + 12) / (n * k),
              'admm_train_response_error': initial_train, 'admm_heldout_response_error': initial,
              'refined_train_response_error': final_train, 'refined_heldout_response_error': final,
              'solver_seconds_cpu': solver_seconds, 'total_seconds_cpu': time.monotonic() - start,
              'online_per_vector': {'signed_terms': rank * (k + n),
                                    'input_lookup_reads': rank * math.ceil(k / 8),
                                    'output_lookup_reads': n * math.ceil(rank / 8),
                                    'table_build_additions': (math.ceil(k / 8) + math.ceil(rank / 8)) * 255,
                                    'table_scratch_bf16_bytes': 2 * 256 * (math.ceil(k / 8) + math.ceil(rank / 8)),
                                    'unfused_intermediate_write_read_bf16_bytes': 4 * rank},
              'image': str(image), 'image_sha256': sha(image), 'serialized_bytes': image.stat().st_size}
    output = args.out / f'{args.fixture.stem}-binary.json'
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
