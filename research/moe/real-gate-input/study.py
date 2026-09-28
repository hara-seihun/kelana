#!/usr/bin/env python3
"""Actual-route common input code through both GGUF gate/up and the down sum."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
ARMS = ('q4-max', 'q4-075', 'q8-max')


def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def quant(x, bits, clip):
    groups = x.reshape(-1, 64, 32)
    qmax = (1 << (bits - 1)) - 1
    scale = (np.max(np.abs(groups), axis=2, keepdims=True) * clip / qmax).astype(np.float16).astype(np.float32)
    scale = np.maximum(scale, np.finfo(np.float16).tiny)
    return (np.clip(np.rint(groups / scale), -qmax, qmax) * scale).reshape(-1, 2048).astype(np.float32)


def swiglu(z):
    gate, up = z[:, :512], z[:, 512:]
    return ((gate / (1. + np.exp(-gate))) * up).astype(np.float32)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--split', choices=('train', 'held'), required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    split = args.split
    capture = BASE / 'route-capture'
    prefix = capture / split
    n = np.fromfile(str(prefix) + '.tokens', np.int32).size
    files = {key: str(prefix) + '.0.' + node + '-0.bin' for key, node in (
        ('ids', 'ffn_moe_topk'), ('scores', 'ffn_moe_weights_norm'),
        ('inputs', 'attn_post_norm'), ('hidden', 'ffn_moe_swiglu'), ('down', 'ffn_moe_down'))}
    ids = np.memmap(files['ids'], np.int32, 'r', shape=(n, 8))
    scores = np.memmap(files['scores'], np.float32, 'r', shape=(n, 8))
    inputs = np.memmap(files['inputs'], np.float32, 'r', shape=(n, 2048))
    native_hidden = np.memmap(files['hidden'], np.float32, 'r', shape=(n, 8, 512))
    native_down = np.memmap(files['down'], np.float32, 'r', shape=(n, 8, 2048))
    assert np.all((ids >= 0) & (ids < 256)) and np.allclose(scores.sum(axis=1), 1, atol=1e-5)
    assert all(np.all(np.isfinite(a)) for a in (inputs, native_hidden, native_down))
    inventory = BASE / 'traffic.json'
    info = {x['name']: x for x in json.loads(inventory.read_text())['tensors']}
    header = json.loads(inventory.read_text())['header_bytes']
    model = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    offset = (header + 31) // 32 * 32
    spec = [('gate', 'ffn_gate_exps', 144), ('up', 'ffn_up_exps', 144), ('down', 'ffn_down_exps', 176)]
    banks = {}
    for name, tensor, block in spec:
        meta = info[f'blk.0.{tensor}.weight']
        assert meta['type'] == ('Q5_K' if name == 'down' else 'Q4_K')
        assert meta['bytes'] == 256 * (2048 * 512 // 256) * block
        banks[name] = np.memmap(model, np.uint8, mode='r', offset=offset + meta['offset'],
                                shape=(256, meta['bytes'] // 256))
    libpath = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    lib = ctypes.CDLL(str(libpath))
    readers = {}
    for typ in ('q4_K', 'q5_K'):
        fn = getattr(lib, 'dequantize_row_' + typ)
        fn.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64)
        fn.restype = None
        readers[typ] = fn
    def weight(name, expert):
        w = np.empty((512, 2048) if name != 'down' else (2048, 512), np.float32)
        source = banks[name][expert]
        readers['q5_K' if name == 'down' else 'q4_K'](
            source.ctypes.data_as(ctypes.c_void_p), w.ctypes.data_as(ctypes.POINTER(ctypes.c_float)), w.size)
        return w
    decoded = {'exact': np.asarray(inputs, np.float32),
               'q4-max': quant(inputs, 4, 1.),
               'q4-075': quant(inputs, 4, .75),
               'q8-max': quant(inputs, 8, 1.)}
    sums = {arm: np.zeros((n, 2048), np.float64) for arm in decoded}
    hidden_sse = {arm: 0. for arm in decoded}
    hidden_den = 0.
    per_token = {arm: np.zeros(n, np.float64) for arm in ARMS}
    for expert in np.unique(ids):
        row, slot = np.where(ids == expert)
        gate, up, down = (weight(name, expert) for name in ('gate', 'up', 'down'))
        # Keep each expert's FP32 products and nonlinear operator fixed across the arms.
        for arm, all_x in decoded.items():
            x = all_x[row]
            hidden = swiglu(np.concatenate((x @ gate.T, x @ up.T), axis=1))
            if arm == 'exact':
                hidden_den += float(np.square(np.asarray(native_hidden[row, slot], np.float64)).sum())
            hidden_sse[arm] += float(np.square(hidden.astype(np.float64) - native_hidden[row, slot].astype(np.float64)).sum())
            outputs = hidden @ down.T
            sums[arm][row] += scores[row, slot].astype(np.float64)[:, None] * outputs.astype(np.float64)
    native = np.einsum('te,ted->td', scores.astype(np.float64), native_down.astype(np.float64))
    ref = sums['exact']
    denom = np.square(ref).sum()
    errors = {arm: np.square(sums[arm] - ref).sum(axis=1) for arm in ARMS}
    for arm in ARMS:
        per_token[arm] = errors[arm]
    selected = min(ARMS[:2], key=lambda arm: errors[arm].sum()) if split == 'train' else None
    best = np.minimum(errors['q4-max'], errors['q4-075'])
    result = {'split': split, 'tokens': n, 'expert_slots': n * 8,
              'contract': 'FP32 BLAS dequantized GGUF matvec/SwiGLU, FP64 score-weighted sum; not native bit identity or language quality',
              'model_sha256': json.loads((BASE / 'acquisition.json').read_text()).get('sha256'),
              'source_sha256': digest(__file__), 'inventory_sha256': digest(inventory), 'library_sha256': digest(libpath),
              'inputs_sha256': {key: digest(path) for key, path in files.items()},
              'weight_banks_sha256': {name: hashlib.sha256(bank).hexdigest() for name, bank in banks.items()},
              'quantizer': 'signed symmetric group-32, nearest-even integer, per-group FP16-rounded scale; same input code across all eight experts and gate/up',
              'bytes_per_token_input_code': {'q4': 2048 // 2 + 64 * 2, 'q8': 2048 + 64 * 2},
              'native_vs_offline_rms': float(np.sqrt(np.square(native - ref).sum() / denom)),
              'native_hidden_relative_rms': {arm: float(np.sqrt(sse / hidden_den)) for arm, sse in hidden_sse.items()},
              'routed_sum_rms': {arm: float(np.sqrt(err.sum() / denom)) for arm, err in errors.items()},
              'q4_ideal_two_clip_oracle_rms': float(np.sqrt(best.sum() / denom)),
              'q4_ideal_two_clip_oracle_counts': {'max': int((errors['q4-max'] <= errors['q4-075']).sum()),
                                                   '075': int((errors['q4-max'] > errors['q4-075']).sum())},
              'train_selected_clip': selected,
              'denominator_sse': float(denom), 'arm_sse': {arm: float(err.sum()) for arm, err in errors.items()},
              'q4_oracle_sse': float(best.sum())}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'split': split, 'rms': result['routed_sum_rms'], 'oracle': result['q4_ideal_two_clip_oracle_rms'],
                      'native_vs_offline': result['native_vs_offline_rms']}, indent=2))


if __name__ == '__main__':
    main()
