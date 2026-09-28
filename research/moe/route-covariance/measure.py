#!/usr/bin/env python3
"""Train-response/weight-column shrinkage for the actual Qwen layer-0 routed sum."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.linalg import svd

BASE = Path('/path/to/workspace/data/qwen-moe')
CAP = BASE / 'route-capture'
RANKS = (128, 256, 512, 768)


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def capture(split):
    n = np.fromfile(CAP / f'{split}.tokens', dtype='<i4').size
    paths = [CAP / f'{split}.tokens']
    def array(kind, dtype, shape):
        p = CAP / f'{split}.0.{kind}-0.bin'
        paths.append(p)
        return np.memmap(p, mode='r', dtype=dtype, shape=(n, *shape))
    ids = array('ffn_moe_topk', '<i4', (8,))
    scores = array('ffn_moe_weights_norm', '<f4', (8,))
    hidden = array('ffn_moe_swiglu', '<f4', (8, 512))
    down = array('ffn_moe_down', '<f4', (8, 2048))
    assert np.all((ids >= 0) & (ids < 256)) and np.allclose(scores.sum(1), 1, atol=1e-5)
    slots = (scores[:, :, None].astype(np.float64) * down).reshape(-1, 2048)
    sums = slots.reshape(n, 8, 2048).sum(axis=1)
    return ids, scores, hidden, slots, sums, {p.name: sha(p) for p in paths}


def prepare(out, columns, seed):
    train = capture('train')
    traffic_path = BASE / 'traffic.json'
    traffic = json.loads(traffic_path.read_text())
    info = next(t for t in traffic['tensors'] if t['name'] == 'blk.0.ffn_down_exps.weight')
    assert info['shape'] == [512, 2048, 256] and info['type'] == 'Q5_K'
    model = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    offset = ((traffic['header_bytes'] + 31) // 32 * 32) + info['offset']
    bank = np.memmap(model, mode='r', dtype=np.uint8, offset=offset,
                     shape=(256, 2048 * 512 // 256 * 176))
    libpath = BASE / 'runtime/current/bin/libggml-base.so'
    lib = ctypes.CDLL(str(libpath))
    decode = lib.dequantize_row_q5_K
    decode.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64)
    decode.restype = None
    rng = np.random.default_rng(seed)
    features = np.empty((256 * columns, 2048), dtype=np.float32)
    indices = []
    w = np.empty((2048, 512), dtype=np.float32)
    for e in range(256):
        decode(bank[e].ctypes.data_as(ctypes.c_void_p),
               w.ctypes.data_as(ctypes.POINTER(ctypes.c_float)), w.size)
        idx = rng.choice(512, size=columns, replace=False)
        indices.append(idx.tolist())
        features[e*columns:(e+1)*columns] = w[:, idx].T
    out.parent.mkdir(parents=True, exist_ok=True)
    np.save(out, features)
    receipt = {'columns': columns, 'seed': seed, 'indices': indices,
               'source_sha256': sha(Path(__file__)), 'features_sha256': sha(out),
               'bank_sha256': hashlib.sha256(bank).hexdigest(),
               'model_sha256': json.loads((BASE/'acquisition.json').read_text())['sha256'],
               'inputs': train[-1] | {'traffic.json': sha(traffic_path),
                                        'libggml-base.so': sha(libpath.resolve())}}
    out.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'features_sha256': receipt['features_sha256'], 'shape': features.shape}))


def evaluate(features_path, multiplier, output):
    train = capture('train')
    held = capture('held')
    features = np.load(features_path, mmap_mode='r')
    slots = train[3]
    # Each surrogate has unit total Frobenius mass before mixing. Multiplier is
    # its total covariance mass relative to the observed routed-slot covariance.
    scale = np.linalg.norm(slots) / np.linalg.norm(features)
    if multiplier == 0:
        matrix = slots.copy()
    else:
        matrix = np.concatenate((slots, np.asarray(features, dtype=np.float64) *
                                 (scale * np.sqrt(multiplier))), axis=0)
    _, singular, right = svd(matrix, full_matrices=False, lapack_driver='gesdd',
                             overwrite_a=True, check_finite=False)
    result = {'domain': 'pinned Qwen3.6 GGUF Q5_K layer-0, real selected routes, FP64 weighted sums',
              'family': 'fixed rank-r common orthogonal output basis; FP64 projection grants free optimal coefficients',
              'surrogate': 'train weighted routed-slot Gram + multiplier times normalized uniformly sampled full-bank weight-column Gram',
              'multiplier': multiplier, 'surrogate_frobenius_ratio': scale,
              'singular_rank': int(np.count_nonzero(singular > singular[0] * 1e-7)),
              'input_hashes': train[-1] | held[-1] | {features_path.name: sha(features_path),
                                                      'features_receipt': sha(features_path.with_suffix('.json'))},
              'source_sha256': sha(Path(__file__)), 'ranks': {}}
    train_seen = set(np.asarray(train[0]).reshape(-1))
    held_unseen = np.any(~np.isin(held[0], list(train_seen)), axis=1)
    for rank in RANKS:
        if rank > result['singular_rank']:
            continue
        b = right[:rank]
        result['ranks'][str(rank)] = {}
        for name, y in (('train', train[4]), ('held', held[4]),
                        ('held_any_unseen_expert', held[4][held_unseen]),
                        ('held_all_seen_experts', held[4][~held_unseen])):
            result['ranks'][str(rank)][name] = {'tokens': len(y),
                'relative_rms': float(np.linalg.norm(y - (y @ b.T) @ b) / np.linalg.norm(y))}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'multiplier': multiplier, 'rank512': result['ranks']['512']}))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='action', required=True)
    p = sub.add_parser('prepare')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--columns', type=int, default=4)
    p.add_argument('--seed', type=int, default=20260923)
    e = sub.add_parser('evaluate')
    e.add_argument('--features', type=Path, required=True)
    e.add_argument('--multiplier', type=float, required=True)
    e.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.action == 'prepare':
        prepare(args.output, args.columns, args.seed)
    else:
        evaluate(args.features, args.multiplier, args.output)


if __name__ == '__main__':
    main()
