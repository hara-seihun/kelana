#!/usr/bin/env python3
"""Fit route-sum gains for the actual Q5_K down bank of Qwen3.6 layer 0."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
LIB = Path('/path/to/workspace/work/clones/bonsai-hip/build-hip/bin/libggml-base.so')
GGUF = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def bf16(path, shape):
    data = np.memmap(path, mode='r', dtype='<u2', shape=shape)
    return (np.asarray(data, dtype=np.uint32) << 16).view(np.float32)


def rms(delta, original):
    return float(np.sqrt(np.sum(np.square(delta, dtype=np.float64)) /
                         np.sum(np.square(original, dtype=np.float64))))


def load_q5(traffic, gguf, libpath, experts):
    info = next(t for t in traffic['tensors'] if t['name'] == 'blk.0.ffn_down_exps.weight')
    assert info['type'] == 'Q5_K' and info['shape'] == [512, 2048, 256]
    blob_bytes = experts * info['bytes'] // 256
    with gguf.open('rb') as stream:
        stream.seek((traffic['header_bytes'] + 31) // 32 * 32 + info['offset'])
        blob = stream.read(blob_bytes)
    assert len(blob) == blob_bytes and blob_bytes == experts * 2048 * 512 // 256 * 176
    lib = ctypes.CDLL(str(libpath))
    decode = lib.dequantize_row_q5_K
    decode.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64)
    decode.restype = None
    out = np.empty((experts, 2048, 512), dtype=np.float32)
    source = ctypes.create_string_buffer(blob, len(blob))
    decode(source, out.ctypes.data_as(ctypes.POINTER(ctypes.c_float)), out.size)
    return out, hashlib.sha256(blob).hexdigest()


def panel(w, down, qdown, rng, count):
    ne = len(w)
    x = rng.standard_normal((2048, count), dtype=np.float32)
    scores = rng.standard_normal((8, count), dtype=np.float32)
    scores -= scores.max(axis=0)
    a = np.exp(scores)
    a /= a.sum(axis=0)
    chosen = np.stack([rng.permutation(ne)[:8] for _ in range(count)], axis=1)
    route = np.zeros((ne, count), dtype=np.float32)
    np.put_along_axis(route, chosen, a, axis=0)
    original = np.empty((ne, 2048, count), dtype=np.float32)
    quantized = np.empty_like(original)
    for e in range(ne):
        gate = w[e, :512] @ x
        up = w[e, 512:] @ x
        h = (gate / (1 + np.exp(-gate))) * up
        original[e] = down[e] @ h
        quantized[e] = qdown[e] @ h
    return original, quantized, route


def evaluate(panel_data, gains):
    original, quantized, route = panel_data
    y = np.einsum('es,eds->ds', route, original, optimize=True)
    yhat = np.einsum('es,eds,e->ds', route, quantized, gains, optimize=True)
    return rms(yhat - y, y)


def cancellation(panel_data):
    original, quantized, route = panel_data
    weighted_error = route[:, None, :] * (quantized - original)
    diagonal = np.sum(np.square(weighted_error, dtype=np.float64))
    total = np.sum(np.square(np.sum(weighted_error, axis=0, dtype=np.float64)))
    return {'total_over_independent_error_energy': float(total / diagonal),
            'cross_error_fraction_of_total': float((total - diagonal) / total)}


def fit(train):
    original, quantized, route = train
    # Observations are whole routed down outputs, not the individual expert vectors.
    v = (quantized * route[:, None, :]).reshape(len(route), -1).astype(np.float64)
    y = np.einsum('es,eds->ds', route, original, optimize=True).ravel().astype(np.float64)
    gram = v @ v.T
    rhs = v @ y
    joint = np.linalg.solve(gram, rhs)
    independent = np.sum(quantized * original * route[:, None, :], axis=(1, 2), dtype=np.float64) / np.sum(
        quantized * quantized * route[:, None, :], axis=(1, 2), dtype=np.float64)
    return joint, independent, float(np.linalg.cond(gram))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--base', type=Path, default=BASE)
    p.add_argument('--lib', type=Path, default=LIB)
    p.add_argument('--train', type=int, default=96)
    p.add_argument('--held', type=int, default=96)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    fixture = args.base / 'experts/layer-0-0-16'
    wfile, dfile = fixture / 'gate_up_proj.bf16', fixture / 'down_proj.bf16'
    traffic = json.loads((args.base / 'traffic.json').read_text())
    w = bf16(wfile, (16, 1024, 2048))
    down = bf16(dfile, (16, 2048, 512))
    qdown, bankhash = load_q5(traffic, args.base / GGUF.name, args.lib, 16)
    weight_rms = rms(qdown - down, down)
    rng = np.random.default_rng(20260923)
    train = panel(w, down, qdown, rng, args.train)
    held = panel(w, down, qdown, rng, args.held)
    joint, independent, cond = fit(train)
    arms = {'q5': np.ones(16),
            'independent_fp64_oracle': independent, 'routed_joint_fp64_oracle': joint,
            'independent_fp16': independent.astype(np.float16).astype(np.float32),
            'routed_joint_fp16': joint.astype(np.float16).astype(np.float32)}
    result = {
        'model_revision': '995ad96eacd98c81ed38be0c5b274b04031597b0',
        'gguf_revision': 'a483e9e6cbd595906af30beda3187c2663a1118c',
        'gguf_sha256': json.loads((args.base / 'acquisition.json').read_text()).get('sha256'),
        'q5_bank_first16_sha256': bankhash, 'gate_up_sha256': sha(wfile), 'down_sha256': sha(dfile),
        'libggml_base_sha256': sha(args.lib.resolve()), 'source_sha256': sha(Path(__file__)),
        'seed': 20260923, 'train': args.train, 'held': args.held, 'experts': 16,
        'route': 'uniform eight without replacement from sixteen, independent Gaussian-softmax scores',
        'inputs': 'shared normal FP32 input per sample, no model producer or actual router',
        'down_image': 'GGUF layer-0 Q5_K first sixteen experts, dequantized by pinned libggml-base',
        'q5_to_bf16_weight_rms': weight_rms, 'joint_gram_condition': cond,
        'error_cancellation': {'train': cancellation(train), 'held': cancellation(held)},
        'arms': {name: {'train_route_rms': evaluate(train, gains),
                        'held_route_rms': evaluate(held, gains), 'gain_min': float(gains.min()),
                        'gain_max': float(gains.max()), 'gains': gains.tolist()} for name, gains in arms.items()},
        'stored_added_bytes_layer0_full256_fp16': 512,
        'added_work_per_token': 'eight route-score multiplications if the selected expert scalar gains are folded into a_e; no extra down product',
        'gain_representation': 'FP16 gain arms pay 512 bytes for all 256 experts per layer; FP64 oracle arms are not paid images',
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'q5_to_bf16_weight_rms': weight_rms, 'joint_gram_condition': cond,
                      'rms': {name: [a['train_route_rms'], a['held_route_rms']] for name, a in result['arms'].items()}}, indent=2))


if __name__ == '__main__':
    main()
