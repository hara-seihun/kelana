#!/usr/bin/env python3
"""Finite-field rank witness for Qwen layer-0's complete packed gate expert axis."""
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
P = 65521


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def integers_mod_prime(values):
    """Map exact float32 values times 2**149 into F_p, without FP arithmetic."""
    bits = values.view(np.uint32).astype(np.int64)
    exponent = (bits >> 23) & 255
    assert np.all(exponent != 255)
    mantissa = (bits & ((1 << 23) - 1)) | ((exponent != 0).astype(np.int64) << 23)
    signed = np.where((bits >> 31) == 0, mantissa, -mantissa)
    powers = np.array([pow(2, max(0, int(e) - 1), P) for e in exponent.flat], dtype=np.int64).reshape(exponent.shape)
    return (signed * powers) % P


def determinant_mod_prime(matrix):
    a = matrix.copy()
    det = 1
    swaps = 0
    pivots = []
    for col in range(a.shape[1]):
        candidates = np.flatnonzero(a[col:, col])
        if len(candidates) == 0:
            return 0, pivots, swaps
        row = col + int(candidates[0])
        if row != col:
            a[[col, row]] = a[[row, col]]
            swaps += 1
        pivot = int(a[col, col])
        pivots.append(pivot)
        det = det * pivot % P
        if col + 1 < a.shape[0]:
            factors = (a[col + 1:, col] * pow(pivot, -1, P)) % P
            a[col + 1:] = (a[col + 1:] - factors[:, None] * a[col]) % P
    return (det * (-1 if swaps % 2 else 1)) % P, pivots, swaps


def main():
    inventory = BASE / 'traffic.json'
    model = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    meta = json.loads(inventory.read_text())
    gate = next(t for t in meta['tensors'] if t['name'] == 'blk.0.ffn_gate_exps.weight')
    assert gate['type'] == 'Q4_K' and gate['bytes'] == 256 * 2048 * 512 // 256 * 144
    data_offset = (meta['header_bytes'] + 31) // 32 * 32 + gate['offset']
    stride = gate['bytes'] // 256
    bank = np.memmap(model, np.uint8, mode='r', offset=data_offset, shape=(256, stride))
    libpath = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    lib = ctypes.CDLL(str(libpath))
    decode = lib.dequantize_row_q4_K
    decode.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64)
    decode.restype = None
    block = np.empty((256, 256), dtype=np.float32)
    first_row = np.empty((256, 256), dtype=np.float32)
    decoded = np.empty((256, 2048), dtype=np.float32)
    for expert in range(256):
        source = bank[expert, :256 * 1152]
        decode(source.ctypes.data_as(ctypes.c_void_p), decoded.ctypes.data_as(ctypes.POINTER(ctypes.c_float)), decoded.size)
        block[expert] = decoded[:, 0]
        first_row[expert] = decoded[0, :256]
    first_field = integers_mod_prime(first_row)
    _, first_pivots, _ = determinant_mod_prime(first_field)
    field = integers_mod_prime(block)
    det, pivots, swaps = determinant_mod_prime(field)
    print(f'rank={len(pivots)} det={det} distinct_rows={np.unique(field, axis=0).shape[0]} nonzero={np.count_nonzero(field)}')
    assert det != 0 and len(pivots) == 256
    output = {
        'contract': 'exact rational values of decoded GGUF float32 gate weights, scaled by 2^149; unrestricted 2048-dimensional input; real linear expert-axis basis',
        'witness': 'first input coordinate of gate output rows 0..255 for all 256 layer-0 experts',
        'prime': P, 'determinant_mod_prime': det, 'row_swaps': swaps, 'pivots': pivots,
        'failed_first_row_rank': len(first_pivots),
        'failed_first_row_zero_experts': int(np.count_nonzero(~np.any(first_row, axis=1))),
        'failed_first_row_float32_le_sha256': hashlib.sha256(first_row.tobytes()).hexdigest(),
        'model_sha256': json.loads((BASE / 'acquisition.json').read_text())['sha256'],
        'inventory_sha256': sha(inventory), 'library_sha256': sha(libpath),
        'source_sha256': sha(__file__), 'sample_float32_le_sha256': hashlib.sha256(block.tobytes()).hexdigest(),
        'sample_field_u16_le_sha256': hashlib.sha256(field.astype('<u2').tobytes()).hexdigest(),
        'tensor_offset': data_offset, 'expert_stride': stride,
    }
    destination = BASE / 'full-axis-rank'
    destination.mkdir(exist_ok=True)
    (destination / 'receipt.json').write_text(json.dumps(output, indent=2) + '\n')
    print(json.dumps({k: output[k] for k in ('prime', 'determinant_mod_prime', 'row_swaps', 'sample_float32_le_sha256', 'sample_field_u16_le_sha256')}))


if __name__ == '__main__':
    main()
