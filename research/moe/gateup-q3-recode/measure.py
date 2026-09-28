#!/usr/bin/env python3
"""Recode installed Q4_K gate/up to native Q3_K; evaluate real routed sum."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'input-subspace'))
from evaluate import capture, evaluator, image_banks, sha

BASE = Path('/path/to/workspace/data/qwen-moe/gateup-q3-recode')
BLOCK = 256
Q3_BYTES = 110


def part(index, root):
    first, last = index * 32, (index + 1) * 32
    splits = {s: capture(s) for s in ('train', 'held')}
    inventory, model, banks = image_banks()
    library, weight = evaluator(banks)
    lib = ctypes.CDLL(str(library))
    quant = lib.quantize_q3_K
    quant.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64, ctypes.c_int64, ctypes.c_void_p]
    quant.restype = ctypes.c_size_t
    dequant = lib.dequantize_row_q3_K
    dequant.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]
    dequant.restype = None
    sums = {s: {arm: np.zeros((len(data['x']), 2048), np.float64) for arm in ('q4','q3')}
            for s, (_, data) in splits.items()}
    counts = {s: 0 for s in splits}
    root.mkdir(parents=True, exist_ok=True)
    image_path = root / f'image-{index:02d}.bin'
    with image_path.open('wb') as image:
        for expert in range(first, last):
            positions = {s: np.where(data['ids'] == expert) for s, (_, data) in splits.items()}
            counts = {s: counts[s] + int(bool(len(pos[0]))) for s, pos in positions.items()}
            gate, up, down = (weight(name, expert) for name in ('gate','up','down'))
            reduced = []
            for w in (gate, up):
                packed = np.empty(w.size//BLOCK*Q3_BYTES, np.uint8)
                size = quant(w.ctypes.data, packed.ctypes.data, w.shape[0], w.shape[1], None)
                assert size == packed.nbytes
                image.write(packed.tobytes())
                q = np.empty_like(w)
                dequant(packed.ctypes.data, q.ctypes.data, q.size)
                reduced.append(q)
            for split, (_, data) in splits.items():
                row, slot = positions[split]
                if not len(row):
                    continue
                x = np.asarray(data['x'][row], np.float32)
                score = data['scores'][row, slot].astype(np.float64)[:, None]
                for arm, (g, u) in (('q4', (gate, up)), ('q3', reduced)):
                    a = x @ g.T
                    b = x @ u.T
                    h = ((a / (1. + np.exp(-a))) * b).astype(np.float32)
                    output = h @ down.T
                    sums[split][arm][row] += score * output.astype(np.float64)
    array_path = root / f'part-{index:02d}.npz'
    np.savez_compressed(array_path, **{f'{s}_{a}': sums[s][a] for s in sums for a in sums[s]})
    metadata = {
        'index': index, 'experts': [first,last], 'observed_experts': counts,
        'source_sha256': sha(__file__), 'inventory_sha256': sha(inventory),
        'model_sha256': json.loads((model.parent/'acquisition.json').read_text())['sha256'],
        'library_sha256': sha(library),
        'capture_sha256': {s:{key:sha(path) for key,path in paths.items()} for s,(paths,_) in splits.items()},
        'q3_image_bytes': image_path.stat().st_size, 'q3_image_sha256': sha(image_path),
        'partial_output_sha256': sha(array_path),
    }
    (root / f'part-{index:02d}.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps(metadata))


def combine(root):
    metas = [json.loads((root/f'part-{i:02d}.json').read_text()) for i in range(8)]
    assert [m['experts'] for m in metas] == [[i*32,(i+1)*32] for i in range(8)]
    assert len({m['source_sha256'] for m in metas}) == 1
    totals = {}
    for i in range(8):
        with np.load(root/f'part-{i:02d}.npz') as arrays:
            for key in arrays.files:
                totals[key] = totals.get(key, 0) + arrays[key]
    result = {}
    for split in ('train','held'):
        ref, recoded = totals[f'{split}_q4'], totals[f'{split}_q3']
        _, data = capture(split)
        native = np.einsum('te,ted->td', data['scores'].astype(np.float64), data['down'].astype(np.float64))
        error = np.square(recoded-ref).sum(axis=1)
        denom = float(np.square(ref).sum())
        result[split] = {
            'tokens':len(ref), 'relative_rms':float(np.sqrt(error.sum()/denom)),
            'offline_native_relative_rms':float(np.sqrt(np.square(native-ref).sum()/denom)),
            'per_token_squared_error':error.tolist(),
            'reference_squared_norm':denom,
        }
    report = {
        'contract': 'layer-0 decoded installed Q4_K gate/up -> native GGML Q3_K recode, Q5_K down unchanged, actual producer/IDs/scores, FP32 CPU BLAS and SwiGLU, FP64 routed sum; no native bit identity or language loss',
        'parts': metas, 'scores':result,
        'q4_bytes_per_gate_or_up_expert': 2048*512//BLOCK*144,
        'q3_bytes_per_gate_or_up_expert': 2048*512//BLOCK*Q3_BYTES,
        'conditional_40_layer_one_read_saving_bytes':40*8*2*2048*512//BLOCK*(144-Q3_BYTES),
        'modeled_complete_one_read_bytes':2626187904,
    }
    (root/'receipt.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'rms': {s:v['relative_rms'] for s,v in result.items()}, 'conditional_bytes':report['conditional_40_layer_one_read_saving_bytes']}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--part',type=int,choices=range(8))
    parser.add_argument('--combine',action='store_true')
    parser.add_argument('--out',type=Path,default=BASE)
    args = parser.parse_args()
    if args.combine:
        combine(args.out)
    else:
        assert args.part is not None
        part(args.part,args.out)
