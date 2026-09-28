#!/usr/bin/env python3
"""Recode installed Q5_K expert down weights to Q4_K on real routed inputs."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
CAP = BASE / 'route-capture'
ARMS = ('q4-reference', 'q4-train-weighted')


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as file:
        for block in iter(lambda: file.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def capture(split):
    n = np.fromfile(CAP / f'{split}.tokens', '<i4').size
    return (np.memmap(CAP / f'{split}.0.ffn_moe_topk-0.bin', '<i4', 'r', shape=(n, 8)),
            np.memmap(CAP / f'{split}.0.ffn_moe_weights_norm-0.bin', '<f4', 'r', shape=(n, 8)),
            np.memmap(CAP / f'{split}.0.ffn_moe_swiglu-0.bin', '<f4', 'r', shape=(n, 8, 512)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--first', type=int, required=True)
    ap.add_argument('--last', type=int, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    assert 0 <= args.first < args.last <= 256
    inventory = BASE / 'traffic.json'
    tensor = next(x for x in json.loads(inventory.read_text())['tensors'] if x['name'] == 'blk.0.ffn_down_exps.weight')
    assert tensor['type'] == 'Q5_K' and tensor['bytes'] == 256 * 2048 * 512 // 256 * 176
    offset = (json.loads(inventory.read_text())['header_bytes'] + 31) // 32 * 32 + tensor['offset']
    image = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    bank = np.memmap(image, np.uint8, 'r', offset=offset, shape=(256, tensor['bytes'] // 256))
    library = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    lib = ctypes.CDLL(str(library))
    for name in ('dequantize_row_q5_K', 'dequantize_row_q4_K'):
        fun = getattr(lib, name)
        fun.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]
        fun.restype = None
    quant = lib.quantize_q4_K
    quant.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64, ctypes.c_int64, ctypes.c_void_p]
    quant.restype = ctypes.c_size_t
    splits = {s: capture(s) for s in ('train', 'held')}
    sums = {s: {a: np.zeros((len(v[0]), 2048), np.float64) for a in (*ARMS, 'q5')} for s, v in splits.items()}
    counts = {'train': 0, 'held': 0, 'both': 0}
    for expert in range(args.first, args.last):
        positions = {s: np.where(v[0] == expert) for s, v in splits.items()}
        if not any(len(p[0]) for p in positions.values()):
            continue
        counts['train'] += bool(len(positions['train'][0]))
        counts['held'] += bool(len(positions['held'][0]))
        counts['both'] += bool(len(positions['train'][0]) and len(positions['held'][0]))
        w = np.empty((2048, 512), np.float32)
        lib.dequantize_row_q5_K(bank[expert].ctypes.data, w.ctypes.data, w.size)
        trained = splits['train']
        row, slot = positions['train']
        if len(row):
            h = np.asarray(trained[2][row, slot], dtype=np.float64)
            score = np.asarray(trained[1][row, slot], dtype=np.float64)
            energy = (h * h * (score * score)[:, None]).sum(axis=0) / (score * score).sum()
            weights = np.sqrt(energy).astype(np.float32)
            weights = np.maximum(weights, np.mean(weights) * .1)
            weights /= np.mean(weights)
        else:
            weights = np.ones(512, np.float32)
        packed = np.empty(2048 * 512 // 256 * 144, np.uint8)
        for arm, weight in (('q4-reference', None), ('q4-train-weighted', weights)):
            ptr = weight.ctypes.data if weight is not None else None
            size = quant(w.ctypes.data, packed.ctypes.data, 2048, 512, ptr)
            assert size == packed.nbytes
            q = np.empty_like(w)
            lib.dequantize_row_q4_K(packed.ctypes.data, q.ctypes.data, q.size)
            for split, (ids, scores, hidden) in splits.items():
                row, slot = positions[split]
                if not len(row):
                    continue
                x = np.asarray(hidden[row, slot], np.float32)
                y = x @ q.T
                sums[split][arm][row] += scores[row, slot].astype(np.float64)[:, None] * y.astype(np.float64)
        for split, (ids, scores, hidden) in splits.items():
            row, slot = positions[split]
            if len(row):
                x = np.asarray(hidden[row, slot], np.float32)
                y = x @ w.T
                sums[split]['q5'][row] += scores[row, slot].astype(np.float64)[:, None] * y.astype(np.float64)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(args.output, **{f'{s}_{a}': sums[s][a] for s in splits for a in sums[s]})
    receipt = {'source_sha256': sha(Path(__file__)), 'model_acquisition_sha256': sha(BASE / 'acquisition.json'),
               'inventory_sha256': sha(inventory), 'capture_receipt_sha256': sha(CAP / 'receipt.json'),
               'library_sha256': sha(library), 'expert_range': [args.first, args.last], 'observed_experts': counts,
               'quantizer': 'native GGML Q4_K reference or native weighted Q4_K; per-expert train-only weighted hidden-coordinate RMS with 10% mean floor; Q5_K installed decoded input',
               'comparison': 'FP32 CPU BLAS products, FP64 weighted accumulation in expert ID order; no native bit equality',
               'arrays_sha256': sha(args.output)}
    args.output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'range': receipt['expert_range'], 'observed': counts, 'array_sha256': receipt['arrays_sha256']}))


if __name__ == '__main__':
    main()
