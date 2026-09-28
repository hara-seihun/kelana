#!/usr/bin/env python3
"""Common diagonal coordinate for quantized routed gate/up operands, including the down consumer."""
import ctypes
import hashlib
import json
import time
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
EXPERT = 151
DIM = 2048
GROUP = 32
ALPHAS = (0., .5, 1., 1.5, 2.)


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def capture(split):
    p = BASE / 'route-capture' / split
    n = np.fromfile(str(p) + '.tokens', np.int32).size
    inputs = np.memmap(str(p) + '.0.attn_post_norm-0.bin', np.float32, 'r', shape=(n, DIM))
    ids = np.memmap(str(p) + '.0.ffn_moe_topk-0.bin', np.int32, 'r', shape=(n, 8))
    scores = np.memmap(str(p) + '.0.ffn_moe_weights_norm-0.bin', np.float32, 'r', shape=(n, 8))
    outputs = np.memmap(str(p) + '.0.ffn_moe_down-0.bin', np.float32, 'r', shape=(n, 8, DIM))
    rows, slots = np.where(ids == EXPERT)
    assert len(rows) and np.allclose(scores.sum(axis=1), 1., atol=1e-5)
    return np.array(inputs[rows]), np.asarray(scores[rows, slots], np.float32), np.asarray(
        np.einsum('te,ted->td', scores[rows].astype(np.float64), outputs[rows].astype(np.float64)), np.float32), rows


def weights(expert=EXPERT):
    inventory = BASE / 'traffic.json'
    info = {x['name']: x for x in json.loads(inventory.read_text())['tensors']}
    header = json.loads(inventory.read_text())['header_bytes']
    model = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    libpath = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    lib = ctypes.CDLL(str(libpath))
    result = []
    for tensor, typ, shape in [('ffn_gate_exps', 'q4_K', (512, DIM)),
                               ('ffn_up_exps', 'q4_K', (512, DIM)),
                               ('ffn_down_exps', 'q5_K', (DIM, 512))]:
        meta = info['blk.0.' + tensor + '.weight']
        block = 144 if typ == 'q4_K' else 176
        offset = (header + 31) // 32 * 32 + meta['offset'] + expert * (meta['bytes'] // 256)
        raw = np.memmap(model, np.uint8, 'r', offset=offset, shape=(shape[0] * shape[1] // 256 * block,))
        out = np.empty(shape, np.float32)
        fn = getattr(lib, 'dequantize_row_' + typ)
        fn.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64)
        fn.restype = None
        fn(raw.ctypes.data_as(ctypes.c_void_p), out.ctypes.data_as(ctypes.POINTER(ctypes.c_float)), out.size)
        result.append(out)
    return result, {'gguf': json.loads((BASE / 'acquisition.json').read_text())['sha256'],
                    'inventory': sha(inventory), 'decoder_library': sha(libpath)}


def quant(x, bits):
    qmax = (1 << (bits - 1)) - 1
    shape = x.shape
    groups = x.reshape(*shape[:-1], shape[-1] // GROUP, GROUP)
    scale = (np.max(np.abs(groups), axis=-1, keepdims=True) / qmax).astype(np.float16).astype(np.float32)
    scale = np.maximum(scale, np.finfo(np.float16).tiny)
    codes = np.clip(np.rint(groups / scale), -qmax, qmax).astype(np.int8)
    if bits == 4:
        pairs = codes.reshape(-1, 2)
        packed = ((pairs[:, 0] & 15) | ((pairs[:, 1] & 15) << 4)).astype(np.uint8)
        restored = np.stack(((packed & 15).astype(np.int8), (packed >> 4).astype(np.int8)), axis=1).reshape(codes.shape)
        codes = (restored ^ 8) - 8
        assert packed.nbytes + scale.size * 2 == x.size // 2 + x.size // GROUP * 2
    else:
        assert codes.nbytes + scale.size * 2 == x.size + x.size // GROUP * 2
    return (codes.astype(np.float32) * scale).reshape(shape)


def forward(x, gate, up, down):
    g = x @ gate.T
    u = x @ up.T
    hidden = (g / (1. + np.exp(-g))) * u
    return hidden @ down.T


def ratio_error(candidate, reference, score, native_sum):
    delta = (candidate.astype(np.float64) - reference.astype(np.float64)) * score[:, None]
    return float(np.sqrt(np.square(delta).sum() / np.square(native_sum.astype(np.float64)).sum()))


def main():
    (gate, up, down), provenance = weights()
    train = capture('train')
    held = capture('held')
    w = np.concatenate((gate, up))
    x_max = np.maximum(np.max(np.abs(train[0]), axis=0), 1e-7)
    w_max = np.maximum(np.max(np.abs(w), axis=0), 1e-7)
    log_ratio = np.log2(w_max / x_max)
    centered = log_ratio - np.median(log_ratio)
    results = {}
    for split, (x, score, native_sum, rows) in (('train', train), ('held', held)):
        reference = forward(x, gate, up, down)
        arms = {}
        for bits in (4, 8):
            t0 = time.perf_counter()
            original_x = quant(x, bits)
            t1 = time.perf_counter()
            original_output = forward(original_x, gate, up, down)
            t2 = time.perf_counter()
            arms[f'gguf-weight-q{bits}-input'] = {
                'routed_delta_rms': ratio_error(original_output, reference, score, native_sum),
                'expert_output_rms': float(np.linalg.norm(original_output - reference) / np.linalg.norm(reference)),
                'online_input_encode_ms_per_token': (t1 - t0) * 1000 / len(x),
                'decoded_consumer_ms_per_token': (t2 - t1) * 1000 / len(x)}
        for alpha in ALPHAS:
            exponents = np.clip(np.rint(alpha * centered / 2), -3, 3).astype(np.int8)
            d = np.exp2(exponents.astype(np.float32))
            # Both gate and up consume one token code. Each 32-column row block has its own paid scale.
            t0 = time.perf_counter()
            coded_w = quant(w / d, 4)
            t1 = time.perf_counter()
            coded_x = quant(x * d, 4)
            t2 = time.perf_counter()
            output = forward(coded_x, coded_w[:512], coded_w[512:], down)
            t3 = time.perf_counter()
            arms[str(alpha)] = {'offline_weight_encode_ms': (t1 - t0) * 1000,
                                'online_input_encode_ms_per_token': (t2 - t1) * 1000 / len(x),
                                'decoded_consumer_ms_per_token': (t3 - t2) * 1000 / len(x),
                                'routed_delta_rms': ratio_error(output, reference, score, native_sum),
                                'expert_output_rms': float(np.linalg.norm(output - reference) / np.linalg.norm(reference)),
                                'activation_relative_rms': float(np.linalg.norm(coded_x / d - x) / np.linalg.norm(x)),
                                'weight_relative_rms': float(np.linalg.norm(coded_w * d - w) / np.linalg.norm(w)),
                                'nonzero_exponents': int(np.count_nonzero(exponents)),
                                'min_exponent': int(exponents.min()), 'max_exponent': int(exponents.max())}
        t0 = time.perf_counter()
        q4w = quant(w, 4)
        t1 = time.perf_counter()
        q8x = quant(x, 8)
        t2 = time.perf_counter()
        output = forward(q8x, q4w[:512], q4w[512:], down)
        t3 = time.perf_counter()
        arms['q8-input-q4-weight'] = {'offline_weight_encode_ms': (t1 - t0) * 1000,
                                     'online_input_encode_ms_per_token': (t2 - t1) * 1000 / len(x),
                                     'decoded_consumer_ms_per_token': (t3 - t2) * 1000 / len(x),
                                     'routed_delta_rms': ratio_error(output, reference, score, native_sum),
                                     'expert_output_rms': float(np.linalg.norm(output - reference) / np.linalg.norm(reference))}
        results[split] = {'tokens': len(rows), 'token_indices': rows.tolist(), 'arms': arms,
                          'native_sum_norm': float(np.linalg.norm(native_sum)),
                          'expert_reference_norm': float(np.linalg.norm(reference))}
    selected = min(ALPHAS, key=lambda a: results['train']['arms'][str(a)]['routed_delta_rms'])
    counts = {'weight_code_bytes': 2 * 512 * DIM // 2,
              'weight_fp16_scale_bytes': 2 * 512 * (DIM // GROUP) * 2,
              'common_diagonal_fp16_bytes': DIM * 2,
              'q4_activation_code_bytes_per_token': DIM // 2 + DIM // GROUP * 2,
              'q8_activation_code_bytes_per_token': DIM + DIM // GROUP * 2,
              'original_gate_up_gguf_bytes_per_expert': 2 * 512 * DIM // 256 * 144,
              'unchanged_down_gguf_bytes_per_expert': DIM * 512 // 256 * 176,
              'input_multiply_per_token': DIM,
              'input_quantization_groups_per_token': DIM // GROUP,
              'gate_up_integer_products_per_token': 2 * 512 * DIM,
              'down_float_products_per_token': DIM * 512}
    result = {'source_sha256': sha(__file__), 'provenance': provenance, 'expert': EXPERT,
              'coordinate': 'd_j = 2**clip(round(alpha*(log2(max_r |W_rj| / max_train |x_j|)-median)/2),-3,3); W is stacked gate/up',
              'weight_source': 'decoded GGUF Q4_K gate/up, Q5_K down; gate/up jointly recoded signed symmetric group32 Q4 with FP16 max scales',
              'input_source': 'actual selected layer0 route input; signed symmetric group32 Q4 or Q8, FP16 max scale; shared gate/up code',
              'observer': 'FP32 BLAS gate/up + SiLU*up + unchanged decoded down; delta weighted by actual route score / captured full native routed sum norm',
              'selected_alpha': selected, 'bytes_and_operations': counts, 'results': results}
    path = Path(__file__).with_name('results.json')
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'selected_alpha': selected, 'train': {k:v['routed_delta_rms'] for k,v in results['train']['arms'].items()},
                      'held': {k:v['routed_delta_rms'] for k,v in results['held']['arms'].items()}}, indent=2))


if __name__ == '__main__':
    main()
