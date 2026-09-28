"""Bounded real-producer nonlinear consumer comparison for joint gate/up codes."""
import hashlib
import json
from pathlib import Path

import numpy as np
from safetensors import safe_open
from scipy.optimize import least_squares

from experiment import SOURCE, quantile_levels, fit_scale_table, one_byte_codes

CAPTURE = Path('/path/to/workspace/data/kelana-subbit/full-model/mlp-quantized-producer-capture.npz')
OUT = Path(__file__).with_name('consumer-results.json')
ROWS = slice(8, 12)
COLUMNS = slice(0, 128)
OUTPUTS = slice(0, 32)


def bf16(bits):
    return (bits.astype(np.uint32) << 16).view(np.float32).astype(np.float64)


def silu(t):
    return t / (1 + np.exp(-t))


def response(x, w, down):
    return (silu(x @ w[:, :, 0].T) * (x @ w[:, :, 1].T)) @ down.T


def rel_rms(pred, target):
    return float(np.linalg.norm(pred - target) / np.linalg.norm(target))


def fit_indices(w, codebook, x, down, target, sweeps):
    flat_w = w.reshape(-1, 2)
    decoded, index = one_byte_codes(flat_w, codebook, np.eye(2))
    decoded = decoded.reshape(w.shape).copy()
    index = index.reshape(w.shape[:2]).copy()
    initial = decoded.copy()
    current_gate = x @ decoded[:, :, 0].T
    current_up = x @ decoded[:, :, 1].T
    current_hidden = silu(current_gate) * current_up
    residual = current_hidden @ down.T - target
    train_start = rel_rms(residual + target, target)
    dnorm = np.sum(down ** 2, axis=0)
    for _ in range(sweeps):
        changed = 0
        for r in range(len(w)):
            d = down[:, r]
            for k in range(w.shape[1]):
                dx = x[:, k]
                dg = codebook[:, 0] - decoded[r, k, 0]
                du = codebook[:, 1] - decoded[r, k, 1]
                change = silu(current_gate[:, r, None] + dx[:, None] * dg[None, :]) * (current_up[:, r, None] + dx[:, None] * du[None, :]) - current_hidden[:, r, None]
                projected = residual @ d
                loss_delta = dnorm[r] * np.sum(change ** 2, axis=0) + 2 * projected @ change
                best = int(np.argmin(loss_delta))
                if loss_delta[best] < -1e-13:
                    delta = change[:, best]
                    residual += delta[:, None] * d[None, :]
                    current_gate[:, r] += dx * dg[best]
                    current_up[:, r] += dx * du[best]
                    current_hidden[:, r] += delta
                    decoded[r, k] = codebook[best]
                    index[r, k] = best
                    changed += 1
        if changed == 0:
            break
    return initial, decoded, index, train_start, rel_rms(residual + target, target)


def fit_response_scale_table(x, down, target, index, patterns, initial):
    groups, labels = np.divmod(index, len(patterns))
    basis = np.zeros((len(initial), *index.shape, 2), dtype=np.float64)
    for j in range(len(initial)):
        basis[j] = (groups == j)[:, :, None] * patterns[labels]
    gate_basis = np.einsum('nk,grk->nrg', x, basis[:, :, :, 0], optimize=True)
    up_basis = np.einsum('nk,grk->nrg', x, basis[:, :, :, 1], optimize=True)

    def residual(table):
        gate = np.einsum('nrg,g->nr', gate_basis, table)
        up = np.einsum('nrg,g->nr', up_basis, table)
        return ((silu(gate) * up) @ down.T - target).ravel()

    fitted = least_squares(residual, initial, bounds=(0, np.inf), max_nfev=25,
                           ftol=1e-7, xtol=1e-7, gtol=1e-7)
    return fitted.x.astype(np.float16).astype(np.float64), int(fitted.nfev)


def main():
    with safe_open(SOURCE, framework='pt', device='cpu') as f:
        gate = f.get_slice('model.layers.0.mlp.gate_proj.weight')[:12, :1024].float().numpy().astype(np.float64)
        up = f.get_slice('model.layers.0.mlp.up_proj.weight')[:12, :1024].float().numpy().astype(np.float64)
        down = f.get_slice('model.layers.0.mlp.down_proj.weight')[OUTPUTS, ROWS].float().numpy().astype(np.float64)
    calibration = np.stack([gate[:8].ravel(), up[:8].ravel()], axis=-1)
    w = np.stack([gate[ROWS, COLUMNS], up[ROWS, COLUMNS]], axis=-1)
    sigma = float(np.float16(np.sqrt(np.mean(calibration ** 2))))
    angles = 2 * np.pi * np.arange(32) / 32
    radii = sigma * np.array([.22, .46, .72, 1.04, 1.46, 2.02, 2.80, 4.0])
    polar = np.stack([np.outer(radii, np.cos(angles)), np.outer(radii, np.sin(angles))], axis=-1).reshape(-1, 2).astype(np.float16).astype(np.float64)
    alphabet = np.array([-3., -1., 1., 3.])
    patterns = np.stack(np.meshgrid(alphabet, alphabet, indexing='ij'), axis=-1).reshape(-1, 2)
    scales = (sigma * np.geomspace(.035, 1.8, 16)).astype(np.float16).astype(np.float64)
    scalar_fixed = (scales[:, None, None] * patterns[None, :, :]).reshape(-1, 2)
    scalar_fitted, fitted_scales = fit_scale_table(calibration, patterns, np.eye(2), scales)
    with np.load(CAPTURE) as f:
        inputs = {
            producer: {'train': bf16(f[f'train_{producer}_input'][320:384, COLUMNS]),
                       'held': bf16(f[f'validation_{producer}_input'][576:704, COLUMNS])}
            for producer in ('teacher', 'damaged')
        }
    results = {
        'format': 'vector-geometry-consumer/1',
        'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'capture_sha256': hashlib.sha256(CAPTURE.read_bytes()).hexdigest(),
        'rows': [8, 12], 'columns': [0, 128], 'down_output_rows': [0, 32],
        'train_capture_rows': [320, 384], 'held_validation_capture_rows': [576, 704],
        'weight_calibration_rows': [0, 8], 'calibration_sigma_fp16': sigma,
        'fitted_scalar_scales_fp16': fitted_scales.tolist(),
        'bytes': {'common_bf16_down': 256, 'polar': {'code': 512, 'gain': 2, 'prepared_f16_table': 1024},
                  'scalar_fixed': {'code': 512, 'gain': 2, 'prepared_f16_scale_table': 32},
                  'scalar_fitted': {'code': 512, 'trained_scale_table': 32, 'prepared_f16_scale_table': 32}},
        'producers': {},
    }
    for producer, panels in inputs.items():
        train_x, held_x = panels['train'], panels['held']
        target_train = response(train_x, w, down)
        target_held = response(held_x, w, down)
        arms = {}
        for name, codebook in [('polar', polar), ('scalar_fixed', scalar_fixed), ('scalar_fitted', scalar_fitted)]:
            initial, assigned, indices, train_start, train_final = fit_indices(w, codebook, train_x, down, target_train, 2)
            arms[name] = {'train_initial_relative_rms': train_start,
                          'train_final_relative_rms': train_final,
                          'held_initial_relative_rms': rel_rms(response(held_x, initial, down), target_held),
                          'held_final_relative_rms': rel_rms(response(held_x, assigned, down), target_held),
                          'held_initial_weight_sse': float(np.mean(np.sum((initial - w) ** 2, axis=-1))),
                          'held_final_weight_sse': float(np.mean(np.sum((assigned - w) ** 2, axis=-1))),
                          'code_sha256': hashlib.sha256(indices.astype(np.uint8).tobytes()).hexdigest(),
                          'used_codes': int(len(np.unique(indices)))}
        initial_case, _, initial_indices, _, _ = fit_indices(w, scalar_fitted, train_x, down, target_train, 1)
        response_scales, evaluations = fit_response_scale_table(train_x, down, target_train, initial_indices, patterns, fitted_scales)
        response_codes = (response_scales[:, None, None] * patterns[None, :, :]).reshape(-1, 2)
        response_initial, response_assigned, response_indices, response_train_initial, response_train_final = fit_indices(w, response_codes, train_x, down, target_train, 2)
        arms['scalar_response_fitted'] = {
            'train_initial_relative_rms': response_train_initial,
            'train_final_relative_rms': response_train_final,
            'held_initial_relative_rms': rel_rms(response(held_x, response_initial, down), target_held),
            'held_final_relative_rms': rel_rms(response(held_x, response_assigned, down), target_held),
            'held_initial_weight_sse': float(np.mean(np.sum((response_initial - w) ** 2, axis=-1))),
            'held_final_weight_sse': float(np.mean(np.sum((response_assigned - w) ** 2, axis=-1))),
            'code_sha256': hashlib.sha256(response_indices.astype(np.uint8).tobytes()).hexdigest(),
            'used_codes': int(len(np.unique(response_indices))),
            'fp16_scale_table': response_scales.tolist(), 'least_squares_evaluations': evaluations,
        }
        results['bytes']['scalar_response_fitted'] = {'code': 512, 'trained_scale_table': 32,
                                                      'prepared_f16_scale_table': 32}
        results['producers'][producer] = {'train_input_sha256': hashlib.sha256(train_x.tobytes()).hexdigest(),
                                         'held_input_sha256': hashlib.sha256(held_x.tobytes()).hexdigest(),
                                         'target_held_norm': float(np.linalg.norm(target_held)), 'arms': arms}
        print(producer)
        for name, case in arms.items():
            print(name, 'train', case['train_initial_relative_rms'], case['train_final_relative_rms'],
                  'held', case['held_initial_relative_rms'], case['held_final_relative_rms'], flush=True)
    OUT.write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
