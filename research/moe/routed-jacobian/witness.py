#!/usr/bin/env python3
"""Local rank certificate for the complete fixed-route weighted expert sum."""
import argparse
import ctypes
from decimal import Decimal, localcontext
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
N = 2048


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as source:
        for chunk in iter(lambda: source.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--include-shared', action='store_true')
    args = parser.parse_args()
    split = 'held'
    prefix = BASE / 'route-capture' / split
    paths = {name: Path(str(prefix) + '.0.' + node + '-0.bin') for name, node in (
        ('ids', 'ffn_moe_topk'), ('scores', 'ffn_moe_weights_norm'), ('inputs', 'attn_post_norm'))}
    n = paths['ids'].stat().st_size // (8 * 4)
    ids = np.memmap(paths['ids'], np.int32, 'r', shape=(n, 8))[0].copy()
    scores = np.memmap(paths['scores'], np.float32, 'r', shape=(n, 8))[0].copy()
    x = np.memmap(paths['inputs'], np.float32, 'r', shape=(n, 2048))[0].astype(np.float64)
    assert len(set(map(int, ids))) == 8 and np.all(scores > 0) and abs(sum(scores) - 1) < 1e-5
    inventory = BASE / 'traffic.json'
    meta = {t['name']: t for t in json.loads(inventory.read_text())['tensors']}
    header = json.loads(inventory.read_text())['header_bytes']
    model = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    libpath = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    lib = ctypes.CDLL(str(libpath))
    decoders = {}
    for typ in ('q4_K', 'q5_K', 'q8_0'):
        fn = getattr(lib, 'dequantize_row_' + typ)
        fn.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64)
        fn.restype = None
        decoders[typ] = fn
    rng = np.random.default_rng(20260923)
    rows = np.sort(rng.choice(2048, N, replace=False))
    cols = np.sort(rng.choice(2048, N, replace=False))
    gamma_dot = 2048 * np.finfo(np.float64).eps / (1 - 2048 * np.finfo(np.float64).eps)
    router_meta = meta['blk.0.ffn_gate_inp.weight']
    router_bank = np.memmap(model, '<f4', 'r', offset=(header + 31) // 32 * 32 + router_meta['offset'], shape=(256, 2048)).astype(np.float64)
    all_logits = router_bank @ x
    assert set(np.argsort(all_logits)[-8:]) == set(ids), 'real router selects a different route'
    route_margin = float(min(all_logits[ids]) - np.sort(all_logits)[-9])
    assert route_margin > 0
    router = router_bank[ids]
    logits = all_logits[ids]
    shifted = np.exp(logits - max(logits))
    real_scores = shifted / sum(shifted)
    score_error = 2 * gamma_dot * np.max(np.abs(router) @ np.abs(x)) + 1e-13
    jac = np.zeros((N, N), np.float64)
    outputs = np.zeros((N, 8), np.float64)
    output_error = np.zeros((N, 8), np.float64)
    entry_error = np.zeros_like(jac)
    sum_absolute_parts = np.zeros_like(jac)
    gamma_gemm = 512 * np.finfo(np.float64).eps / (1 - 512 * np.finfo(np.float64).eps)
    max_sigmoid_error = 0.
    for slot, (expert, score) in enumerate(zip(ids, real_scores)):
        weights = {}
        for name, stem, typ, shape in (
            ('gate', 'ffn_gate_exps', 'q4_K', (512, 2048)),
            ('up', 'ffn_up_exps', 'q4_K', (512, 2048)),
            ('down', 'ffn_down_exps', 'q5_K', (2048, 512))):
            t = meta[f'blk.0.{stem}.weight']
            stride = t['bytes'] // 256
            source = np.memmap(model, np.uint8, 'r', offset=(header + 31) // 32 * 32 + t['offset'] + int(expert) * stride, shape=(stride,))
            w = np.empty(shape, np.float32)
            decoders[typ](source.ctypes.data_as(ctypes.c_void_p), w.ctypes.data_as(ctypes.POINTER(ctypes.c_float)), w.size)
            weights[name] = w.astype(np.float64)
        gate, up, down = (weights[key] for key in ('gate', 'up', 'down'))
        g, u = gate @ x, up @ x
        dg = gamma_dot * (np.abs(gate) @ np.abs(x))
        du = gamma_dot * (np.abs(up) @ np.abs(x))
        # Decimal.exp is correctly rounded; this cross-check gives a conservative
        # envelope for libm/NumPy sigmoid at the computed FP64 dot midpoint.
        sigmoid = 1. / (1. + np.exp(-g))
        with localcontext() as context:
            context.prec = 50
            for gi, si in zip(g, sigmoid):
                exact_mid = 1 / (1 + (-Decimal(float(gi))).exp())
                max_sigmoid_error = max(max_sigmoid_error, abs(float(exact_mid) - si))
        sigmoid_error = max_sigmoid_error + 1e-14
        silu = g * sigmoid
        derivative = sigmoid + silu * (1 - sigmoid)
        a, b = u * derivative, silu
        # Overestimates derivative Lipschitz and all intermediate rounding.
        eb = (1 + np.abs(g) + dg) * dg + (1 + np.abs(g)) * sigmoid_error + 1e-12
        ea = np.abs(u) * (2 + np.abs(g) + dg) * (dg + sigmoid_error) + (2 + np.abs(g)) * du + 1e-12
        local = a[:, None] * gate[:, cols] + b[:, None] * up[:, cols]
        local_err = ea[:, None] * np.abs(gate[:, cols]) + eb[:, None] * np.abs(up[:, cols]) + 1e-12 * (np.abs(a[:, None] * gate[:, cols]) + np.abs(b[:, None] * up[:, cols]))
        d = down[rows]
        hidden = silu * u
        outputs[:, slot] = d @ hidden
        hidden_error = np.abs(u) * eb + np.abs(silu) * du + 1e-12 * np.abs(hidden)
        output_error[:, slot] = np.abs(d) @ hidden_error + gamma_gemm * (np.abs(d) @ np.abs(hidden))
        part = d @ local
        abs_part = np.abs(d) @ np.abs(local)
        jac += float(score) * part
        sum_absolute_parts += float(score) * np.abs(part)
        entry_error += float(score) * (np.abs(d) @ local_err + gamma_gemm * abs_part)
    # Bound scaling and accumulation by the sum of absolute contributions,
    # not by the possibly cancelled final entry. Double the entire envelope
    # to cover its own floating-point evaluation and interval endpoints.
    entry_error = 2 * (entry_error + (1e-12 + score_error) * sum_absolute_parts)
    score_derivative = real_scores[:, None] * (router - real_scores @ router)
    full_jac = jac + outputs @ score_derivative
    # The router is F32 in the image; its stored entries are exact reals here.
    # Each score differs by at most score_error. For one derivative row,
    # the direct score change contributes 2*delta*max|W| and the eight
    # weighted-mean terms contribute 8*max(score)*delta*max|W|.
    derivative_error = (2 + 8 * (max(real_scores) + score_error)) * score_error * np.max(np.abs(router)) + 1e-12 * np.max(np.abs(score_derivative))
    full_error = entry_error + 2 * (
        output_error @ np.abs(score_derivative)
        + np.abs(outputs).sum(axis=1)[:, None] * derivative_error
        + gamma_gemm * (np.abs(outputs) @ np.abs(score_derivative))
    )
    shared_details = None
    if args.include_shared:
        shared = {}
        for name, shape in (('gate', (512, 2048)), ('up', (512, 2048)), ('down', (2048, 512))):
            t = meta[f'blk.0.ffn_{name}_shexp.weight']
            source = np.memmap(model, np.uint8, 'r', offset=(header + 31) // 32 * 32 + t['offset'], shape=(t['bytes'],))
            w = np.empty(shape, np.float32)
            decoders['q8_0'](source.ctypes.data_as(ctypes.c_void_p), w.ctypes.data_as(ctypes.POINTER(ctypes.c_float)), w.size)
            shared[name] = w.astype(np.float64)
        gate, up, down = (shared[key] for key in ('gate', 'up', 'down'))
        g, u = gate @ x, up @ x
        dg = gamma_dot * (np.abs(gate) @ np.abs(x))
        du = gamma_dot * (np.abs(up) @ np.abs(x))
        sigmoid = 1. / (1. + np.exp(-g))
        with localcontext() as context:
            context.prec = 50
            shared_sigmoid_error = max(abs(float(1 / (1 + (-Decimal(float(gi))).exp())) - si) for gi, si in zip(g, sigmoid))
        sig_err = shared_sigmoid_error + 1e-14
        silu = g * sigmoid
        derivative = sigmoid + silu * (1 - sigmoid)
        a, b = u * derivative, silu
        eb = (1 + np.abs(g) + dg) * dg + (1 + np.abs(g)) * sig_err + 1e-12
        ea = np.abs(u) * (2 + np.abs(g) + dg) * (dg + sig_err) + (2 + np.abs(g)) * du + 1e-12
        local = a[:, None] * gate[:, cols] + b[:, None] * up[:, cols]
        local_err = ea[:, None] * np.abs(gate[:, cols]) + eb[:, None] * np.abs(up[:, cols]) + 1e-12 * (np.abs(a[:, None] * gate[:, cols]) + np.abs(b[:, None] * up[:, cols]))
        d = down[rows]
        hidden = silu * u
        hidden_err = np.abs(u) * eb + np.abs(silu) * du + 1e-12 * np.abs(hidden)
        y = d @ hidden
        y_err = np.abs(d) @ hidden_err + gamma_gemm * (np.abs(d) @ np.abs(hidden))
        part = d @ local
        part_err = np.abs(d) @ local_err + gamma_gemm * (np.abs(d) @ np.abs(local))
        t = meta['blk.0.ffn_gate_inp_shexp.weight']
        w = np.memmap(model, '<f4', 'r', offset=(header + 31) // 32 * 32 + t['offset'], shape=(2048,)).astype(np.float64)
        z = float(w @ x)
        z_err = gamma_dot * float(np.abs(w) @ np.abs(x))
        q = 1. / (1. + np.exp(-z))
        with localcontext() as context:
            context.prec = 50
            gate_sigmoid_error = abs(float(1 / (1 + (-Decimal(z)).exp())) - q)
        q_err = z_err / 4 + gate_sigmoid_error + 1e-14
        q_prime = q * (1 - q)
        q_prime_err = q_err * (1 + 2 * q_err) + 1e-14
        shared_jac = q * part + q_prime * y[:, None] * w[None, cols]
        shared_err = 2 * (q * part_err + q_err * np.abs(part) + q_prime * y_err[:, None] * np.abs(w[None, cols]) + q_prime_err * np.abs(y[:, None] * w[None, cols]) + 1e-12 * np.abs(shared_jac))
        full_jac += shared_jac
        full_error += shared_err
        shared_details = {'gate_logit': z, 'gate_value': q, 'gate_error_bound': q_err,
                          'shared_sigmoid_midpoint_error': shared_sigmoid_error, 'gate_sigmoid_midpoint_error': gate_sigmoid_error,
                          'shared_jacobian_midpoint_sha256': hashlib.sha256(shared_jac.astype('<f8').tobytes()).hexdigest(),
                          'shared_max_entry_error_bound': float(shared_err.max()),
                          'shared_weight_tensors': [f'blk.0.ffn_{key}_shexp.weight' for key in ('gate', 'up', 'down')]}
    inverse = np.linalg.inv(full_jac)
    residual = np.eye(N) - inverse @ full_jac
    # Product-error budget for the certificate multiplication, plus the
    # enclosed uncertainty in the mathematical Jacobian.
    gamma_cert = N * np.finfo(np.float64).eps / (1 - N * np.finfo(np.float64).eps)
    upper = np.linalg.norm(residual, ord=np.inf) + 2 * np.linalg.norm(np.abs(inverse) @ full_error, ord=np.inf) + 2 * gamma_cert * np.linalg.norm(np.abs(inverse) @ np.abs(full_jac), ord=np.inf)
    singular = np.linalg.svd(full_jac, compute_uv=False)
    assert upper < 1, 'local rank certificate failed'
    result = {
        'contract': 'Real-arithmetic local Jacobian of normalized top-eight routed expert sum' + (' plus sigmoid-gated shared expert' if args.include_shared else '') + ', installed Q4_K/Q5_K/Q8_0 and F32 router weights; selected held token 0 route; no native FP32 bit-identity or quality claim',
        'shared_details': shared_details,
        'split': split, 'token': 0, 'expert_ids': [int(v) for v in ids], 'captured_scores': [float(v) for v in scores],
        'real_scores': real_scores.tolist(), 'router_logit_midpoints': logits.tolist(), 'router_route_margin': route_margin, 'score_error_bound': float(score_error),
        'max_captured_real_score_difference': float(np.max(np.abs(scores - real_scores))),
        'minor_seed': 20260923, 'minor_rows': rows.tolist(), 'minor_cols': cols.tolist(),
        'minor_size': N, 'min_singular_midpoint': float(singular[-1]), 'max_singular_midpoint': float(singular[0]),
        'max_entry_error_bound': float(full_error.max()), 'max_sigmoid_midpoint_error': max_sigmoid_error,
        'inverse_residual_inf': float(np.linalg.norm(residual, ord=np.inf)), 'neumann_upper_inf': float(upper),
        'invertible_under_stated_envelope': bool(upper < 1),
        'model_sha256': json.loads((BASE / 'acquisition.json').read_text())['sha256'],
        'inventory_sha256': sha(inventory), 'library_sha256': sha(libpath),
        'capture_sha256': {key: sha(path) for key, path in paths.items()},
        'source_sha256': sha(__file__), 'jacobian_midpoint_sha256': hashlib.sha256(full_jac.astype('<f8').tobytes()).hexdigest(),
    }
    dest = BASE / 'routed-jacobian'
    dest.mkdir(exist_ok=True)
    (dest / ('shared-receipt.json' if args.include_shared else 'full-receipt.json')).write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: result[key] for key in ('expert_ids', 'min_singular_midpoint', 'max_entry_error_bound', 'inverse_residual_inf', 'neumann_upper_inf', 'invertible_under_stated_envelope')}, indent=2))


if __name__ == '__main__':
    main()
