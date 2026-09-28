#!/usr/bin/env python3
"""Shared low-rank producer code through real routed Qwen layer-0 experts."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/qwen-moe')
CAPTURE = ROOT / 'route-capture'
RANKS = (32, 64, 112, 113)


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for part in iter(lambda: f.read(1 << 20), b''):
            h.update(part)
    return h.hexdigest()


def capture(split):
    stem = CAPTURE / split
    n = np.fromfile(str(stem) + '.tokens', np.int32).size
    paths = {key: str(stem) + '.0.' + suffix + '-0.bin' for key, suffix in (
        ('x', 'attn_post_norm'), ('ids', 'ffn_moe_topk'),
        ('scores', 'ffn_moe_weights_norm'), ('down', 'ffn_moe_down'))}
    arrays = {
        'x': np.memmap(paths['x'], np.float32, 'r', shape=(n, 2048)),
        'ids': np.memmap(paths['ids'], np.int32, 'r', shape=(n, 8)),
        'scores': np.memmap(paths['scores'], np.float32, 'r', shape=(n, 8)),
        'down': np.memmap(paths['down'], np.float32, 'r', shape=(n, 8, 2048)),
    }
    return paths, arrays


def basis(x):
    _, singular, vh = np.linalg.svd(np.asarray(x, np.float64), full_matrices=False)
    return singular, vh


def image_banks():
    inventory = ROOT / 'traffic.json'
    raw = json.loads(inventory.read_text())
    tensors = {v['name']: v for v in raw['tensors']}
    header = (raw['header_bytes'] + 31) // 32 * 32
    model = ROOT / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    banks = {}
    for name, tensor, size, typ in (
        ('gate', 'ffn_gate_exps', 144, 'Q4_K'),
        ('up', 'ffn_up_exps', 144, 'Q4_K'),
        ('down', 'ffn_down_exps', 176, 'Q5_K')):
        meta = tensors[f'blk.0.{tensor}.weight']
        assert meta['type'] == typ and meta['bytes'] == 256 * 2048 * 512 // 256 * size
        banks[name] = np.memmap(model, np.uint8, 'r', offset=header + meta['offset'],
                                shape=(256, meta['bytes'] // 256))
    return inventory, model, banks


def evaluator(banks):
    library = (ROOT / 'runtime/current/bin/libggml-base.so').resolve()
    lib = ctypes.CDLL(str(library))
    readers = {}
    for typ in ('q4_K', 'q5_K'):
        fn = getattr(lib, 'dequantize_row_' + typ)
        fn.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64)
        fn.restype = None
        readers[typ] = fn

    def weight(name, expert):
        out = np.empty((512, 2048) if name != 'down' else (2048, 512), np.float32)
        source = banks[name][expert]
        readers['q5_K' if name == 'down' else 'q4_K'](
            source.ctypes.data_as(ctypes.c_void_p),
            out.ctypes.data_as(ctypes.POINTER(ctypes.c_float)), out.size)
        return out
    return library, weight


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    train_paths, train = capture('train')
    held_paths, held = capture('held')
    assert np.all((held['ids'] >= 0) & (held['ids'] < 256))
    assert np.allclose(held['scores'].sum(axis=1), 1., atol=1e-5)
    assert np.all(np.isfinite(held['x'])) and np.all(np.isfinite(train['x']))
    s_train, vt_train = basis(train['x'])
    s_held, vt_held = basis(held['x'])
    calibration_count = len(held['x']) // 2
    s_augmented, vt_augmented = basis(np.concatenate((train['x'], held['x'][:calibration_count])))
    x = np.asarray(held['x'], np.float32)
    variants = {'original': x}
    input_errors = {}
    input_norm2 = float(np.square(x.astype(np.float64)).sum())
    for rank in RANKS:
        v = vt_train[:rank]
        projected = (x.astype(np.float64) @ v.T) @ v
        variants[f'train-pca-{rank}'] = projected.astype(np.float32)
    for rank in (112, 160):
        v = vt_augmented[:rank]
        projected = (x.astype(np.float64) @ v.T) @ v
        variants[f'augmented-pca-{rank}'] = projected.astype(np.float32)
    for rank in (64, 112):
        v = vt_held[:rank]
        projected = (x.astype(np.float64) @ v.T) @ v
        variants[f'held-pca-{rank}'] = projected.astype(np.float32)
    for name, candidate in variants.items():
        input_errors[name] = float(np.sqrt(np.square(candidate.astype(np.float64) - x).sum() / input_norm2))
    inventory, model, banks = image_banks()
    library, weight = evaluator(banks)
    sums = {name: np.zeros((len(x), 2048), np.float64) for name in variants}
    for expert in np.unique(held['ids']):
        row, slot = np.where(held['ids'] == expert)
        gate, up, down = (weight(name, int(expert)) for name in ('gate', 'up', 'down'))
        for name, all_x in variants.items():
            y = all_x[row]
            g = y @ gate.T
            u = y @ up.T
            hidden = ((g / (1. + np.exp(-g))) * u).astype(np.float32)
            out = hidden @ down.T
            sums[name][row] += held['scores'][row, slot].astype(np.float64)[:, None] * out.astype(np.float64)
    reference = sums.pop('original')
    denom = float(np.square(reference).sum())
    native = np.einsum('te,ted->td', held['scores'].astype(np.float64), held['down'].astype(np.float64))
    result = {
        'contract': 'GGUF-dequantized FP32 BLAS gate/up, FP32 SwiGLU/down, FP64 weighted sum; held layer 0 only',
        'train_tokens': len(train['x']), 'held_tokens': len(x), 'ranks': RANKS,
        'augmented_calibration_held_tokens': calibration_count,
        'independent_evaluation_held_tokens': len(x) - calibration_count,
        'source_sha256': sha(__file__), 'inventory_sha256': sha(inventory),
        'model_sha256': json.loads((ROOT / 'acquisition.json').read_text())['sha256'],
        'library_sha256': sha(library),
        'capture_sha256': {key: sha(path) for key, path in {**{'train-'+k: v for k, v in train_paths.items()},
                                                            **{'held-'+k: v for k, v in held_paths.items()}}.items()},
        'bank_sha256': {key: hashlib.sha256(bank).hexdigest() for key, bank in banks.items()},
        'train_singular': s_train.tolist(), 'held_singular': s_held.tolist(),
        'augmented_singular': s_augmented.tolist(),
        'input_relative_rms': input_errors,
        'offline_native_relative_rms': float(np.sqrt(np.square(native-reference).sum() / denom)),
        'routed_sum_relative_rms': {name: float(np.sqrt(np.square(y-reference).sum() / denom))
                                    for name, y in sums.items()},
        'per_token_squared_error': {name: np.square(y-reference).sum(axis=1).tolist() for name, y in sums.items()},
        'independent_half_routed_sum_relative_rms': {
            name: float(np.sqrt(np.square(y[calibration_count:] - reference[calibration_count:]).sum()
                                / np.square(reference[calibration_count:]).sum())) for name, y in sums.items()},
        'reference_squared_norm': denom,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('input_relative_rms', 'routed_sum_relative_rms', 'offline_native_relative_rms')}, indent=2))


if __name__ == '__main__':
    main()
