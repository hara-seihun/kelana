#!/usr/bin/env python3
"""Weight-informed shared-output projection on actual Qwen routed sums."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.linalg import svd

BASE = Path('/path/to/workspace/data/qwen-moe')
LIB = BASE / 'runtime/current/bin/libggml-base.so'
RANKS = (128, 256, 512, 768)


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def capture(root, split):
    count = np.fromfile(root / f'{split}.tokens', dtype='<i4').size
    names = {'ffn_moe_weights_norm': ('<f4', (8,)),
             'ffn_moe_down': ('<f4', (8, 2048)),
             'ffn_moe_topk': ('<i4', (8,)),
             'ffn_moe_swiglu': ('<f4', (8, 512))}
    arrays = {}
    paths = [root / f'{split}.tokens']
    for name, (dtype, shape) in names.items():
        p = root / f'{split}.0.{name}-0.bin'
        arrays[name] = np.memmap(p, mode='r', dtype=dtype, shape=(count, *shape))
        paths.append(p)
    ids, scores = arrays['ffn_moe_topk'], arrays['ffn_moe_weights_norm']
    assert np.all((ids >= 0) & (ids < 256))
    assert np.allclose(scores.sum(axis=1), 1, atol=1e-5)
    y = np.einsum('te,ted->td', scores.astype(np.float64),
                  arrays['ffn_moe_down'].astype(np.float64))
    return arrays, y, {p.name: digest(p) for p in paths}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', type=Path, default=BASE)
    parser.add_argument('--lib', type=Path, default=LIB)
    parser.add_argument('--variant', choices=('uniform', 'route-energy'), required=True)
    parser.add_argument('--columns', type=int, default=4)
    parser.add_argument('--seed', type=int, default=20260923)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert args.columns in (4, 8)
    root = args.base / 'route-capture'
    train, yt, ht = capture(root, 'train')
    held, yh, hh = capture(root, 'held')
    traffic_path = args.base / 'traffic.json'
    traffic = json.loads(traffic_path.read_text())
    info = next(t for t in traffic['tensors'] if t['name'] == 'blk.0.ffn_down_exps.weight')
    assert info['shape'] == [512, 2048, 256] and info['type'] == 'Q5_K'
    model = args.base / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    offset = ((traffic['header_bytes'] + 31) // 32 * 32) + info['offset']
    bank = np.memmap(model, mode='r', dtype=np.uint8, offset=offset,
                     shape=(256, 2048 * 512 // 256 * 176))
    lib = ctypes.CDLL(str(args.lib))
    decode = lib.dequantize_row_q5_K
    decode.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64)
    decode.restype = None
    ids = np.asarray(train['ffn_moe_topk'])
    scores = np.asarray(train['ffn_moe_weights_norm'], dtype=np.float64)
    hidden = np.asarray(train['ffn_moe_swiglu'], dtype=np.float64)
    route_energy = np.zeros((256, 512), dtype=np.float64)
    for row in range(len(ids)):
        for slot in range(8):
            route_energy[ids[row, slot]] += scores[row, slot] ** 2 * hidden[row, slot] ** 2
    rng = np.random.default_rng(args.seed)
    features = np.empty((256 * args.columns, 2048), np.float32)
    w = np.empty((2048, 512), np.float32)
    selected = []
    for expert in range(256):
        raw = bank[expert]
        decode(raw.ctypes.data_as(ctypes.c_void_p),
               w.ctypes.data_as(ctypes.POINTER(ctypes.c_float)), w.size)
        # All experts contribute weight directions, including those absent from train.
        columns = rng.choice(512, size=args.columns, replace=False)
        selected.append(columns.tolist())
        if args.variant == 'uniform':
            amplitudes = np.ones(args.columns)
        else:
            # Train-only diagonal routed-input covariance surrogate, zero for
            # unseen experts. This intentionally omits cross-expert covariance.
            amplitudes = np.sqrt(route_energy[expert, columns] * 512 / args.columns)
        features[expert * args.columns:(expert + 1) * args.columns] = (
            w[:, columns].T * amplitudes[:, None]).astype(np.float32)
    # Thin SVD minimizes the sampled full-bank weight-response surrogate. It is
    # not fit to held outputs. Projection below grants perfect online coefficients.
    _, singular, right = svd(features, full_matrices=False, lapack_driver='gesdd',
                             overwrite_a=True, check_finite=False)
    effective_rank = int(np.count_nonzero(singular > singular[0] * 1e-7))
    result = {'domain': 'Qwen3.6 layer-0 selected mixed-GGUF Q5_K expert down bank, actual routed FP32 outputs and scores, FP64 local sums',
              'family': 'fixed rank-r orthogonal output basis; exact FP64 projection of captured routed sum grants free optimal coefficients',
              'surrogate': 'sampled full-bank columns, uniform or train score-squared times hidden-coordinate-square diagonal; no cross-expert terms',
              'variant': args.variant, 'seed': args.seed, 'columns_per_expert': args.columns,
              'sampled_columns': selected,
              'train_observed_experts': int(np.count_nonzero(route_energy.sum(axis=1))),
              'sampled_surrogate_rank': effective_rank,
              'tokens': {'train': len(yt), 'held': len(yh)},
              'model_sha256': json.loads((args.base / 'acquisition.json').read_text())['sha256'],
              'ranks': {}, 'hashes': {'source': digest(Path(__file__)),
                                    'acquisition': digest(args.base / 'acquisition.json'),
                                    'traffic': digest(traffic_path),
                                    'bank': hashlib.sha256(bank).hexdigest(),
                                    'lib': digest(args.lib.resolve()), **ht, **hh}}
    for rank in RANKS:
        if rank > effective_rank:
            continue
        b = np.asarray(right[:rank], dtype=np.float64)
        result['ranks'][str(rank)] = {
            split: float(np.linalg.norm(y - (y @ b.T) @ b) / np.linalg.norm(y))
            for split, y in (('train', yt), ('held', yh))}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'variant': args.variant, 'ranks': result['ranks']}))


if __name__ == '__main__':
    main()
