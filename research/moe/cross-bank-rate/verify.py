#!/usr/bin/env python3
"""Recompute selected down recodes on the same offline Q4 gate/up producer as Q3."""
import argparse
import ctypes
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/qwen-moe')
OUT = ROOT / 'cross-bank-rate'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'input-subspace'))
from evaluate import capture as full_capture, evaluator, image_banks
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'down-route-quant'))
from experiment import capture as hidden_capture


def candidate_ids():
    rows = json.loads((OUT / 'receipt.json').read_text())['results']
    return sorted(set().union(*(set(r['q4_down_ids']) for r in rows if r['q4_down_experts'] in (32, 64, 128))))


def calculate(first, last):
    _, _, banks = image_banks()
    library, weight = evaluator(banks)
    lib = ctypes.CDLL(str(library))
    quant = lib.quantize_q4_K
    quant.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64, ctypes.c_int64, ctypes.c_void_p]
    quant.restype = ctypes.c_size_t
    dequant = lib.dequantize_row_q4_K
    dequant.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]
    dequant.restype = None
    source = {s: full_capture(s)[1] for s in ('train', 'held')}
    native = {s: hidden_capture(s) for s in source}
    result = {s: np.zeros((last-first, len(source[s]['x']), 2048), np.float32) for s in source}
    ids = candidate_ids()
    saved = []
    for path in sorted((ROOT/'down-rate-allocation').glob('part-*.npz')):
        with np.load(path) as part:
            saved.append((int(part['first']), int(part['last']), {s: part[s] for s in source}))
    max_native_difference = 0.
    for expert in ids:
        if not first <= expert < last:
            continue
        gate, up, down = (weight(name, expert) for name in ('gate', 'up', 'down'))
        row, slot = np.where(native['train'][0] == expert)
        if len(row):
            h = np.asarray(native['train'][2][row, slot], np.float64)
            scores = np.asarray(native['train'][1][row, slot], np.float64)
            energy = (h*h*(scores*scores)[:, None]).sum(axis=0)/(scores*scores).sum()
            weights = np.sqrt(energy).astype(np.float32)
            weights = np.maximum(weights, weights.mean()*.1)
            weights /= weights.mean()
        else:
            weights = np.ones(512, np.float32)
        packed = np.empty(2048*512//256*144, np.uint8)
        assert quant(down.ctypes.data, packed.ctypes.data, 2048, 512, weights.ctypes.data) == packed.size
        recoded = np.empty_like(down)
        dequant(packed.ctypes.data, recoded.ctypes.data, down.size)
        difference = recoded-down
        for split, (native_ids, native_scores, native_hidden) in native.items():
            native_row, native_slot = np.where(native_ids == expert)
            if len(native_row):
                replay = native_scores[native_row, native_slot, None] * (np.asarray(native_hidden[native_row, native_slot], np.float32) @ difference.T)
                recorded = next(arrays[split][native_row, native_slot] for lo, hi, arrays in saved if lo <= expert < hi)
                mismatch = np.linalg.norm(replay.astype(np.float64)-recorded.astype(np.float64))/max(np.linalg.norm(recorded.astype(np.float64)),1e-20)
                max_native_difference = max(max_native_difference, float(mismatch))
                assert mismatch < 2e-5, (expert, split, mismatch)
        for split, data in source.items():
            row, slot = np.where(data['ids'] == expert)
            if not len(row):
                continue
            x = np.asarray(data['x'][row], np.float32)
            a, b = x @ gate.T, x @ up.T
            h = ((a / (1.+np.exp(-a))) * b).astype(np.float32)
            delta = h @ difference.T
            result[split][expert-first, row] = (data['scores'][row, slot].astype(np.float64)[:, None]*delta.astype(np.float64)).astype(np.float32)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f'offline-down-{first:03d}-{last:03d}.npz'
    np.savez_compressed(path, **result)
    path.with_suffix('.json').write_text(json.dumps({'source_sha256':sha(Path(__file__)), 'library_sha256': sha(library), 'payload_sha256':sha(path), 'expert_range':[first,last], 'included_experts':[e for e in ids if first <= e < last], 'max_native_recode_replay_relative_difference':max_native_difference, 'parent_down_receipt_sha256':sha(ROOT/'down-rate-allocation/receipt.json')},indent=2)+'\n')
    print(path, sha(path), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--first',type=int,required=True)
    p.add_argument('--last',type=int,required=True)
    a = p.parse_args()
    calculate(a.first,a.last)
