"""One-byte joint weight codes against paid scalar-scale controls on Qwen3-0.6B."""
import hashlib
import json
import math
from pathlib import Path
from statistics import NormalDist

import numpy as np
from safetensors import safe_open

SOURCE = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
OUT = Path(__file__).with_name('results.json')
S = np.array([[1., 1.], [1., -1.]]) / math.sqrt(2.)


def quantile_levels(n):
    """Conditional means of equal-mass standard-normal cells, including tails."""
    normal = NormalDist()
    bounds = [-math.inf] + [normal.inv_cdf(j / n) for j in range(1, n)] + [math.inf]
    density = lambda x: math.exp(-x * x / 2) / math.sqrt(2 * math.pi)
    return np.array([n * (density(bounds[j]) - density(bounds[j + 1])) for j in range(n)])


def one_byte_codes(w, codes, gram):
    diff = w[:, None, :] - codes[None, :, :]
    loss = np.einsum('nki,ij,nkj->nk', diff, gram, diff, optimize=True)
    idx = np.argmin(loss, axis=1)
    return codes[idx], idx


def continuous_pair_scale(w, patterns, gram):
    """Enumerate all directions; solve their positive scale exactly, round to FP16."""
    dot = w @ gram @ patterns.T
    denom = np.einsum('ki,ij,kj->k', patterns, gram, patterns)
    scales = np.maximum(0., np.divide(dot, denom, out=np.zeros_like(dot), where=denom > 0))
    # Include adjacent half words, so a rounded scale cannot mask a better neighbor.
    f16 = scales.astype(np.float16)
    nearby = np.stack([f16, np.nextafter(f16, np.float16(0)),
                       np.nextafter(f16, np.float16(np.inf))], axis=-1).astype(np.float64)
    approximations = patterns[None, :, None, :] * nearby[:, :, :, None]
    diff = w[:, None, None, :] - approximations
    loss = np.einsum('nkpi,ij,nkpj->nkp', diff, gram, diff, optimize=True)
    best = np.argmin(loss.reshape(len(w), -1), axis=1)
    code, variant = np.divmod(best, 3)
    return approximations[np.arange(len(w)), code, variant], code, nearby[np.arange(len(w)), code, variant]


def fit_scale_table(train, patterns, gram, initial):
    """Train the sixteen actual FP16 scales, with an assigned scalar pattern."""
    scales = initial.copy()
    pattern_norm = np.einsum('ki,ij,kj->k', patterns, gram, patterns)
    for _ in range(16):
        codebook = (scales[:, None, None] * patterns[None, :, :]).reshape(-1, 2)
        _, idx = one_byte_codes(train, codebook, gram)
        scale_id, pattern_id = np.divmod(idx, len(patterns))
        selected = patterns[pattern_id]
        numerator = np.einsum('ni,ij,nj->n', train, gram, selected)
        denominator = pattern_norm[pattern_id]
        total_numerator = np.bincount(scale_id, weights=numerator, minlength=len(scales))
        total_denominator = np.bincount(scale_id, weights=denominator, minlength=len(scales))
        changed = np.divide(total_numerator, total_denominator, out=scales.copy(), where=total_denominator > 0)
        scales = np.maximum(0., changed).astype(np.float16).astype(np.float64)
    return (scales[:, None, None] * patterns[None, :, :]).reshape(-1, 2), scales


def score(w, approx, gram):
    err = w - approx
    return float(np.mean(np.einsum('ni,ij,nj->n', err, gram, err)))


def main():
    with safe_open(SOURCE, framework='pt', device='cpu') as f:
        gate = f.get_slice('model.layers.0.mlp.gate_proj.weight')[:16, :1024].float().numpy().astype(np.float64)
        up = f.get_slice('model.layers.0.mlp.up_proj.weight')[:16, :1024].float().numpy().astype(np.float64)
    train = np.stack([gate[:8].ravel(), up[:8].ravel()], axis=-1)
    held = np.stack([gate[8:].ravel(), up[8:].ravel()], axis=-1)
    global_sigma = float(np.float16(np.sqrt(np.mean(train ** 2))))
    rotated_train = train @ S.T
    rotated_sigma = np.sqrt(np.mean(rotated_train ** 2, axis=0)).astype(np.float16).astype(np.float64)
    levels4 = quantile_levels(4)
    levels16 = quantile_levels(16)
    levels64 = quantile_levels(64)
    polar_radii = np.array([.22, .46, .72, 1.04, 1.46, 2.02, 2.80, 4.0]) * global_sigma
    angles = np.arange(32) * 2 * np.pi / 32
    polar = np.stack([np.outer(polar_radii, np.cos(angles)), np.outer(polar_radii, np.sin(angles))], axis=-1).reshape(-1, 2).astype(np.float16).astype(np.float64)
    cart_levels = (levels16 * global_sigma).astype(np.float16).astype(np.float64)
    cart = np.stack(np.meshgrid(cart_levels, cart_levels, indexing='ij'), axis=-1).reshape(-1, 2)
    scale_grid = (np.geomspace(.035, 1.8, 16) * global_sigma).astype(np.float16).astype(np.float64)
    signed_four = np.array([-3., -1., 1., 3.])
    scalar_vectors = np.stack(np.meshgrid(signed_four, signed_four, indexing='ij'), axis=-1).reshape(-1, 2)
    ternary_vectors = np.stack(np.meshgrid([-1., 0., 1.], [-1., 0., 1.], indexing='ij'), axis=-1).reshape(-1, 2)
    scaled_1byte = (scale_grid[:, None, None] * scalar_vectors[None, :, :]).reshape(-1, 2)
    method_codes = {
        'polar_32x8': polar,
        'cartesian_16x16': cart,
        'scalar_4x4_times_16scales': scaled_1byte,
    }
    for name, nfirst in [('rotated_4plus4', 16), ('rotated_6plus2', 64), ('rotated_2plus6', 4), ('rotated_6plus2_tails', 64), ('rotated_7plus1_tails', 128)]:
        nsecond = 256 // nfirst
        levels_a = quantile_levels(nfirst)
        if name.endswith('tails'):
            tail = [2.0, 2.7, 3.7, 5.5] if nfirst == 64 else [2.05, 2.45, 3.0, 3.8, 5.5]
            levels_a[-len(tail):] = tail
            levels_a[:len(tail)] = -levels_a[-len(tail):][::-1]
        a = (levels_a * rotated_sigma[0]).astype(np.float16).astype(np.float64)
        b = (quantile_levels(nsecond) * rotated_sigma[1]).astype(np.float16).astype(np.float64)
        method_codes[name] = (np.stack(np.meshgrid(a, b, indexing='ij'), axis=-1).reshape(-1, 2) @ S)
    levels256 = quantile_levels(256)
    tail256 = [2.1, 2.5, 3.0, 3.7, 4.5, 5.5, 7.0]
    levels256[-len(tail256):] = tail256
    levels256[:len(tail256)] = -levels256[-len(tail256):][::-1]
    method_codes['rotated_sum_only_8bit'] = np.column_stack([(levels256 * rotated_sigma[0]).astype(np.float16).astype(np.float64), np.zeros(256)]) @ S
    controls = {'scalar_ternary_fp16': ternary_vectors,
                'scalar_four_fp16': scalar_vectors}
    metrics = {'isotropic': np.eye(2),
               'sum_dominant': S.T @ np.diag([1., .0025]) @ S}
    results = {'source': str(SOURCE), 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               'source_slices': ['model.layers.0.mlp.gate_proj.weight', 'model.layers.0.mlp.up_proj.weight'],
               'rows_train': [0, 8], 'rows_held': [8, 16], 'columns': [0, 1024],
               'train_sigma': global_sigma, 'train_rotated_sigmas': rotated_sigma.tolist(),
               'train_max_abs_rotated_sigmas': (np.max(np.abs(rotated_train), axis=0) / rotated_sigma).tolist(),
               'held_max_abs_rotated_sigmas': (np.max(np.abs(held @ S.T), axis=0) / rotated_sigma).tolist(),
               'observations': len(held), 'metrics': {}}
    for metric_name, gram in metrics.items():
        panel = {}
        learned_codes, learned_scales = fit_scale_table(train, scalar_vectors, gram, scale_grid)
        candidates = {**method_codes, 'scalar_4x4_times_16learned': learned_codes}
        for name, codes in candidates.items():
            reconstructed, idx = one_byte_codes(held, codes, gram)
            panel[name] = {'held_expected_consumer_sse_per_pair': score(held, reconstructed, gram),
                           'held_weight_sse_per_pair': score(held, reconstructed, np.eye(2)),
                           'used_codes': int(len(np.unique(idx))),
                           'rotated_axis_mse': np.mean(((held - reconstructed) @ S.T) ** 2, axis=0).tolist()}
        for name, patterns in controls.items():
            reconstructed, idx, scales = continuous_pair_scale(held, patterns, gram)
            panel[name] = {'held_expected_consumer_sse_per_pair': score(held, reconstructed, gram),
                           'held_weight_sse_per_pair': score(held, reconstructed, np.eye(2)),
                           'zero_scales': int(np.count_nonzero(scales == 0)),
                           'used_patterns': int(len(np.unique(idx)))}
        panel['scalar_4x4_times_16learned']['fp16_scale_table'] = learned_scales.tolist()
        results['metrics'][metric_name] = panel
    results['storage'] = {
        'polar_32x8': {'bytes_per_pair': 1, 'global_fp16_gain_bytes': 2, 'fixed_f16_table_bytes': 1024},
        'cartesian_16x16': {'bytes_per_pair': 1, 'global_fp16_gain_bytes': 2, 'fixed_f16_table_bytes': 32},
        'scalar_4x4_times_16scales': {'bytes_per_pair': 1, 'global_fp16_gain_bytes': 2, 'fixed_f16_table_bytes': 32},
        'rotated_sum_only_8bit': {'bytes_per_pair': 1, 'global_fp16_gain_bytes': 2, 'fixed_f16_table_bytes': 512},
        **{name: {'bytes_per_pair': 1, 'global_fp16_gain_bytes': 4, 'fixed_f16_table_bytes': 2 * (n + 256 // n)}
           for name, n in [('rotated_4plus4', 16), ('rotated_6plus2', 64), ('rotated_2plus6', 4), ('rotated_6plus2_tails', 64), ('rotated_7plus1_tails', 128)]},
        'scalar_4x4_times_16learned': {'bytes_per_pair': 1, 'trained_fp16_scale_table_bytes': 32},
        'scalar_ternary_fp16': {'bytes_per_pair': 3, 'global_fp16_gain_bytes': 0},
        'scalar_four_fp16': {'bytes_per_pair': 3, 'global_fp16_gain_bytes': 0},
    }
    OUT.write_text(json.dumps(results, indent=2) + '\n')
    for panel_name, panel in results['metrics'].items():
        print(panel_name)
        for method, values in panel.items():
            print(f"  {method:32} {values['held_expected_consumer_sse_per_pair']:.9g}")


if __name__ == '__main__':
    main()
