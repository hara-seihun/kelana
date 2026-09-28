#!/usr/bin/env python3
"""Actual-route forty-layer finite train-span projection oracle (CPU, no model execution)."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe/all-producers')
RANKS = (64, 128, 256, 512)


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def load(split, layer, receipt, hashes):
    arrays = []
    for suffix, shape in (('ffn_moe_down.f32', (64, 8, 2048)),
                          ('ffn_moe_weights_norm.f32', (64, 8))):
        p = BASE / f'{split}.layer-{layer}.{suffix}'
        digest = sha(p)
        assert digest == receipt['splits'][split]['files_sha256'][p.name]
        hashes[p.name] = digest
        arrays.append(np.memmap(p, dtype='<f4', mode='r', shape=shape).astype(np.float64))
    down, score = arrays
    assert np.isfinite(down).all() and np.isfinite(score).all()
    assert np.all(score > 0)
    return (down * score[:, :, None]).reshape(512, 2048), (down * score[:, :, None]).sum(axis=1)


def layer_result(layer, capture, hashes):
    train, train_sum = load('train', layer, capture, hashes)
    held, held_sum = load('held', layer, capture, hashes)
    # SVD through a 512x512 Gram; train-slot PCA is the best fixed rank-r
    # linear output coordinate for squared train-slot error. QR of the full
    # train-slot span is the optimistic floor for every such coordinate
    # constrained to directions observed in this split.
    gram = train @ train.T
    values, vectors = np.linalg.eigh(gram)
    values = np.maximum(values[::-1], 0)
    vectors = vectors[:, ::-1]
    tol = values[0] * 1e-12
    rank = int(np.count_nonzero(values > tol))
    assert rank >= 256, (layer, rank)
    basis = (vectors[:, :rank].T @ train) / np.sqrt(values[:rank, None])
    # Floating eigensolver noise at smallest eigenvalue is kept visible via
    # the independently computed projected residual, not subtracted norms.
    proj_train = train_sum @ basis.T
    proj_held = held_sum @ basis.T
    panels = {}
    for n in RANKS:
        r = min(n, rank)
        train_err = np.linalg.norm(train_sum - proj_train[:, :r] @ basis[:r]) ** 2
        held_err = np.linalg.norm(held_sum - proj_held[:, :r] @ basis[:r]) ** 2
        panels[str(n)] = {'rank': r, 'train_error_sq': float(train_err),
                          'held_error_sq': float(held_err)}
    return {'layer': layer, 'train_sum_norm_sq': float(np.sum(train_sum ** 2)),
            'held_sum_norm_sq': float(np.sum(held_sum ** 2)), 'train_slot_rank': rank,
            'eigen_ratio_min_to_max': float(values[rank - 1] / values[0]), 'panels': panels}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--start', type=int, required=True)
    p.add_argument('--stop', type=int, required=True)
    p.add_argument('--out', type=Path, required=True)
    args = p.parse_args()
    assert 0 <= args.start < args.stop <= 40
    path = BASE / 'receipt.json'
    capture = json.loads(path.read_text())
    hashes = {}
    results = []
    for layer in range(args.start, args.stop):
        row = layer_result(layer, capture, hashes)
        results.append(row)
        print(layer, row['train_slot_rank'],
              (row['panels']['512']['held_error_sq'] / row['held_sum_norm_sq']) ** .5, flush=True)
    result = {'contract': 'FP64 weighted GGUF captured down vectors. Best orthogonal projection into the rank-r train weighted-slot PCA subspace, same basis per layer for all routes; full train-slot span is a lower bound on error for any such basis. Held prompt producers are disjoint. Not a native FP32 map or complete-model quality.',
              'source_sha256': sha(Path(__file__)), 'capture_receipt_sha256': sha(path),
              'model_sha256': capture['model_sha256'], 'files_sha256': hashes, 'layers': results}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + '\n')
    print(args.out)


if __name__ == '__main__':
    main()
