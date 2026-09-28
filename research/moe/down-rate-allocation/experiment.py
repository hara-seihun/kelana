#!/usr/bin/env python3
"""Actual-route mixed Q4_K/Q5_K down-bank allocation on installed Qwen layer 0."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'down-route-quant'))
from experiment import capture, sha


def shard(first, last, output):
    inventory = BASE / 'traffic.json'
    tensor = next(t for t in json.loads(inventory.read_text())['tensors'] if t['name'] == 'blk.0.ffn_down_exps.weight')
    assert tensor['type'] == 'Q5_K'
    offset = (json.loads(inventory.read_text())['header_bytes'] + 31) // 32 * 32 + tensor['offset']
    bank = np.memmap(BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf', np.uint8, 'r', offset=offset,
                     shape=(256, tensor['bytes'] // 256))
    library = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    lib = ctypes.CDLL(str(library))
    for name in ('dequantize_row_q5_K', 'dequantize_row_q4_K'):
        fn = getattr(lib, name)
        fn.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]
        fn.restype = None
    quant = lib.quantize_q4_K
    quant.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64, ctypes.c_int64, ctypes.c_void_p]
    quant.restype = ctypes.c_size_t
    splits = {s: capture(s) for s in ('train', 'held')}
    # Each slot holds one score-weighted change from the installed Q5_K image.
    delta = {s: np.zeros((len(v[0]), 8, 2048), np.float32) for s, v in splits.items()}
    w = np.empty((2048, 512), np.float32)
    q = np.empty_like(w)
    packed = np.empty(2048 * 512 // 256 * 144, np.uint8)
    for expert in range(first, last):
        positions = {s: np.where(v[0] == expert) for s, v in splits.items()}
        if not any(len(p[0]) for p in positions.values()):
            continue
        lib.dequantize_row_q5_K(bank[expert].ctypes.data, w.ctypes.data, w.size)
        train = splits['train']
        row, slot = positions['train']
        if len(row):
            h = np.asarray(train[2][row, slot], np.float64)
            scores = np.asarray(train[1][row, slot], np.float64)
            energy = (h * h * (scores * scores)[:, None]).sum(axis=0) / (scores * scores).sum()
            weights = np.sqrt(energy).astype(np.float32)
            weights = np.maximum(weights, weights.mean() * .1)
            weights /= weights.mean()
        else:
            weights = np.ones(512, np.float32)
        assert quant(w.ctypes.data, packed.ctypes.data, 2048, 512, weights.ctypes.data) == packed.nbytes
        lib.dequantize_row_q4_K(packed.ctypes.data, q.ctypes.data, q.size)
        difference = q - w
        for split, (ids, scores, hidden) in splits.items():
            row, slot = positions[split]
            if len(row):
                result = np.asarray(hidden[row, slot], np.float32) @ difference.T
                delta[split][row, slot] = scores[row, slot, None] * result
    output.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(output, first=first, last=last, **delta)
    receipt = {'source_sha256': sha(Path(__file__)), 'parent_source_sha256': sha(Path(__file__).resolve().parents[1] / 'down-route-quant/experiment.py'),
               'model_acquisition_sha256': sha(BASE / 'acquisition.json'), 'inventory_sha256': sha(inventory),
               'capture_receipt_sha256': sha(BASE / 'route-capture/receipt.json'), 'library_sha256': sha(library),
               'expert_range': [first, last], 'arrays_sha256': sha(output)}
    output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'range': [first, last], 'sha256': receipt['arrays_sha256']}))


def summarize():
    paths = sorted((BASE / 'down-rate-allocation').glob('part-*.npz'))
    assert len(paths) == 4
    splits = {s: capture(s) for s in ('train', 'held')}
    delta = {s: np.zeros((len(v[0]), 8, 2048), np.float32) for s, v in splits.items()}
    covered = set()
    for path in paths:
        receipt = json.loads(path.with_suffix('.json').read_text())
        assert sha(path) == receipt['arrays_sha256'] and receipt['source_sha256'] == sha(Path(__file__))
        with np.load(path) as part:
            first, last = int(part['first']), int(part['last'])
            assert not covered.intersection(range(first, last))
            covered.update(range(first, last))
            for split, (ids, _, _) in splits.items():
                delta[split] += part[split]
    assert covered == set(range(256))
    metrics = {}
    for split, (ids, scores, hidden) in splits.items():
        d = delta[split].astype(np.float64)
        energy = np.zeros(256)
        count = np.zeros(256, np.int64)
        for slot in range(8):
            np.add.at(energy, ids[:, slot], (d[:, slot] ** 2).sum(axis=1))
            np.add.at(count, ids[:, slot], 1)
        metrics[split] = {'energy': energy, 'count': count}
    receipt = {'source_sha256': sha(Path(__file__)), 'shards': {p.name: sha(p) for p in paths},
               'metric': 'sqrt(sum_t ||sum_selected score*(Q4_K-Q5_K)@post_swiglu||^2 / sum_t ||Q5_K routed sum||^2); CPU FP32 products, FP64 sum',
               'panels': []}
    # Baseline Q5 sum from the existing experiment, whose capture and library coincide.
    q5 = {}
    for split in splits:
        q5[split] = sum((np.load(BASE / 'down-route-quant' / p.name)[f'{split}_q5'] for p in paths))
    for retain in (0, 32, 64, 128, 192, 224, 256):
        for policy in ('train-energy', 'train-frequency', 'held-energy-oracle'):
            key_split = 'held' if policy == 'held-energy-oracle' else 'train'
            key = 'count' if policy == 'train-frequency' else 'energy'
            ranking = np.lexsort((np.arange(256), -metrics[key_split][key]))
            q4 = np.ones(256, bool)
            q4[ranking[:retain]] = False
            result = {'q5_experts': retain, 'q4_experts': 256 - retain, 'policy': policy,
                      'layer_down_bytes': int(retain * 720896 + (256 - retain) * 589824)}
            for split, (ids, _, _) in splits.items():
                d = delta[split].astype(np.float64)
                e = (d * q4[ids, None]).sum(axis=1)
                result[split] = {'relative_rms': float(np.sqrt(np.sum(e * e) / np.sum(q5[split] * q5[split]))),
                                 'q4_assignments': int(q4[ids].sum())}
            receipt['panels'].append(result)
    out = BASE / 'down-rate-allocation/receipt.json'
    out.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt['panels'], indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--first', type=int)
    parser.add_argument('--last', type=int)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--summarize', action='store_true')
    args = parser.parse_args()
    if args.summarize:
        summarize()
    else:
        assert args.first is not None and args.last is not None and args.output
        shard(args.first, args.last, args.output)
