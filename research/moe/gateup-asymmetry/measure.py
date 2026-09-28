#!/usr/bin/env python3
"""Measure gate-only and up-only Q3_K recoding on complete real routed sums."""
import argparse
import ctypes
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'input-subspace'))
from evaluate import capture, evaluator, image_banks, sha

ROOT = Path('/path/to/workspace/data/qwen-moe/gateup-asymmetry')
IMAGE = Path('/path/to/workspace/data/qwen-moe/gateup-q3-recode')
ONE = 2048 * 512 // 256 * 110
ARMS = ('reference', 'gate3', 'up3', 'both3')


def part(index, root):
    splits = {s: capture(s) for s in ('train', 'held')}
    inventory, model, banks = image_banks()
    library, weight = evaluator(banks)
    lib = ctypes.CDLL(str(library))
    dequant = lib.dequantize_row_q3_K
    dequant.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]
    dequant.restype = None
    image_path = IMAGE / f'image-{index:02d}.bin'
    image = np.memmap(image_path, dtype=np.uint8, mode='r')
    assert image.size == 32 * 2 * ONE
    sums = {s: {a: np.zeros((len(data['x']), 2048), np.float64) for a in ARMS}
            for s, (_, data) in splits.items()}
    for local in range(32):
        expert = index * 32 + local
        gate, up, down = (weight(name, expert) for name in ('gate', 'up', 'down'))
        qgate, qup = np.empty_like(gate), np.empty_like(up)
        for j, output in enumerate((qgate, qup)):
            packed = image[(local * 2 + j) * ONE:(local * 2 + j + 1) * ONE]
            dequant(packed.ctypes.data, output.ctypes.data, output.size)
        for split, (_, data) in splits.items():
            row, slot = np.where(data['ids'] == expert)
            if not len(row):
                continue
            x = np.asarray(data['x'][row], np.float32)
            score = data['scores'][row, slot].astype(np.float64)[:, None]
            g0, g3 = x @ gate.T, x @ qgate.T
            u0, u3 = x @ up.T, x @ qup.T
            for arm, g, u in (('reference', g0, u0), ('gate3', g3, u0),
                              ('up3', g0, u3), ('both3', g3, u3)):
                hidden = ((g / (1. + np.exp(-g))) * u).astype(np.float32)
                sums[split][arm][row] += score * (hidden @ down.T).astype(np.float64)
    root.mkdir(parents=True, exist_ok=True)
    output = root / f'part-{index:02d}.npz'
    np.savez_compressed(output, **{f'{s}_{arm}': sums[s][arm] for s in sums for arm in ARMS})
    meta = {'part': index, 'source_sha256': sha(__file__), 'image_sha256': sha(image_path),
            'library_sha256': sha(library), 'inventory_sha256': sha(inventory),
            'model_sha256': json.loads((model.parent / 'acquisition.json').read_text())['sha256'],
            'capture_sha256': {s: {k: sha(p) for k, p in paths.items()}
                               for s, (paths, _) in splits.items()},
            'output_sha256': sha(output)}
    (root / f'part-{index:02d}.json').write_text(json.dumps(meta, indent=2) + '\n')
    print(json.dumps({'part': index, 'output_sha256': meta['output_sha256']}))


def combine(root):
    parts = [json.loads((root / f'part-{i:02d}.json').read_text()) for i in range(8)]
    assert len({p['source_sha256'] for p in parts}) == 1
    totals = {}
    for i in range(8):
        path = root / f'part-{i:02d}.npz'
        assert sha(path) == parts[i]['output_sha256']
        with np.load(path) as arrays:
            for key in arrays.files:
                totals[key] = totals.get(key, 0) + arrays[key]
    result = {}
    for split in ('train', 'held'):
        ref = totals[f'{split}_reference']
        denominator = float(np.square(ref).sum())
        result[split] = {'tokens': len(ref), 'reference_squared_norm': denominator,
                         'arms': {}}
        for arm in ARMS[1:]:
            delta = totals[f'{split}_{arm}'] - ref
            errors = np.square(delta).sum(axis=1)
            result[split]['arms'][arm] = {
                'relative_rms': float(np.sqrt(errors.sum() / denominator)),
                'per_token_squared_error': errors.tolist()}
        interaction = totals[f'{split}_both3'] - totals[f'{split}_gate3'] - totals[f'{split}_up3'] + ref
        result[split]['interaction_relative_rms'] = float(np.sqrt(np.square(interaction).sum() / denominator))
        for a, b in (('gate3', 'up3'),):
            x, y = totals[f'{split}_{a}'] - ref, totals[f'{split}_{b}'] - ref
            result[split]['gate_up_error_cosine'] = float(np.sum(x*y) / np.sqrt(np.sum(x*x)*np.sum(y*y)))
    q4 = 2048 * 512 // 256 * 144
    receipt = {'contract': 'decoded installed Q4_K reference versus existing native Q3_K image; actual layer-0 producers/routes/scores, FP32 CPU BLAS/SwiGLU and FP64 weighted sum; not whole-model quality or native timing',
               'parts': parts, 'scores': result,
               'bytes_per_expert_gate_or_up_q4': q4,
               'bytes_per_expert_gate_or_up_q3': ONE,
               'conditional_one_bank_40_layer_one_read_saving_bytes': 40*8*(q4-ONE),
               'modeled_complete_one_read_bytes': 2626187904}
    (root / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'rms': {s: {a: r['relative_rms'] for a, r in v['arms'].items()}
                             for s, v in result.items()},
                      'interaction': {s: v['interaction_relative_rms'] for s, v in result.items()},
                      'cosine': {s: v['gate_up_error_cosine'] for s, v in result.items()}}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--part', type=int, choices=range(8))
    parser.add_argument('--combine', action='store_true')
    parser.add_argument('--out', type=Path, default=ROOT)
    args = parser.parse_args()
    combine(args.out) if args.combine else part(args.part, args.out)
