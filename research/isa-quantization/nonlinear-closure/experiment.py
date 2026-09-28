"""Exact finite-gate closure and controls on a six-bit SwiGLU region."""
import itertools
import json
from pathlib import Path

import numpy as np

N, H, O = 6, 48, 4
BITS = np.array(list(itertools.product((-1., 1.), repeat=N)))
TERMS = [()] + [(i,) for i in range(N)] + list(itertools.combinations(range(N), 2)) + list(itertools.combinations(range(N), 3))
PHI = np.column_stack([np.prod(BITS[:, t], axis=1) for t in TERMS])
assert PHI.shape == (64, 42) and np.array_equal(PHI.T @ PHI, 64 * np.eye(42))


def silu(x):
    return x / (1. + np.exp(-np.clip(x, -40, 40)))


def response(x, g, u, d):
    return (silu(x @ g.T) * (x @ u.T)) @ d.T


def relative(a, b):
    return float(np.linalg.norm(a - b) / np.linalg.norm(b))


def quantize_rows(a, maximum):
    """Independent row scale; search 81 steps, rounded FP16, and refit codes."""
    rows = []
    for row in a:
        bound = np.max(np.abs(row)) / maximum
        best = None
        for factor in np.linspace(.55, 1.6, 81):
            scale = np.float16(max(bound * factor, 1e-7))
            q = np.clip(np.rint(row / float(scale)), -maximum, maximum).astype(np.int8)
            error = np.sum((row - float(scale) * q) ** 2)
            if best is None or error < best[0]:
                best = (error, q, float(scale))
        rows.append(best)
    return np.array([v[1] * v[2] for v in rows])


def polynomial(x, coeff):
    return np.column_stack([np.prod(x[:, t], axis=1) for t in TERMS]) @ coeff


def one(seed, kind):
    rng = np.random.default_rng(seed)
    g = np.zeros((H, N))
    if kind == 'gaussian':
        g = rng.normal(0, .7, (H, N))
    else:
        for h in range(H):
            i, j = rng.choice(N, size=2, replace=False)
            a = rng.uniform(.45, .9)
            g[h, [i, j]] = a * rng.choice([-1, 1], size=2)
        if kind == 'perturbed':
            g += rng.normal(0, .08, (H, N))
    u = rng.normal(0, .65, (H, N))
    d = rng.normal(0, 1 / np.sqrt(H), (O, H))
    y = response(BITS, g, u, d)
    # Nearest equal-magnitude two-support row for the complete binary input box.
    snap = np.zeros_like(g)
    for h in range(H):
        top = np.argsort(np.abs(g[h]))[-2:]
        snap[h, top] = np.sign(g[h, top]) * np.mean(np.abs(g[h, top]))
    snapped = response(BITS, snap, u, d)
    snapped_coeff = quantize_rows((PHI.T @ snapped / len(BITS)).T, 127).T
    # Walsh coefficients are an exact orthogonal projection, not a Taylor fit.
    coeff = PHI.T @ y / len(BITS)
    qcoeff = quantize_rows(coeff.T, 127).T
    qtable = quantize_rows(y.T, 127).T
    qg, qu, qd = (quantize_rows(m, 7) for m in (g, u, d))
    q4 = response(BITS, qg, qu, qd)
    held = rng.normal(0, .8, (512, N))
    wide = rng.normal(0, 2.3, (512, N))
    result = {}
    for name, x in [('binary', BITS), ('held_real', held), ('wide_real', wide)]:
        t = response(x, g, u, d)
        result[name] = {
            'cubic_fp64': relative(polynomial(x, coeff), t),
            'cubic_int8': relative(polynomial(x, qcoeff), t),
            'snapped_cubic_int8': relative(polynomial(x, snapped_coeff), t),
            'scalar_q4': relative(q4 if name == 'binary' else response(x, qg, qu, qd), t),
        }
        if name == 'binary':
            result[name]['full_table_int8'] = relative(qtable, t)
    # Residual of the unrestricted Walsh map: no claim of exact closure from a small fit.
    full_basis = np.column_stack([np.prod(BITS[:, t], axis=1)
                                  for k in range(N + 1) for t in itertools.combinations(range(N), k)])
    high = full_basis[:, 42:].T @ y / len(BITS)
    result['high_degree_fraction'] = float(np.linalg.norm(high) / np.linalg.norm(full_basis.T @ y / len(BITS)))
    return result


def main():
    out = {
        'shape': {'input': N, 'hidden': H, 'output': O, 'binary_states': len(BITS), 'cubic_features': len(TERMS)},
        'image_bytes': {'cubic_int8': 42 * O + 2 * O, 'full_table_int8': 64 * O + 2 * O,
                        'scalar_q4_row_scales': (H * N * 2 + O * H) // 2 + 2 * (2 * H + O)},
        'seeds': {},
    }
    for kind in ('pair_gate', 'perturbed', 'gaussian'):
        out['seeds'][kind] = {str(s): one(s, kind) for s in range(8)}
        out[kind + '_median'] = {
            panel: {method: float(np.median([out['seeds'][kind][str(s)][panel][method] for s in range(8)]))
                    for method in (('cubic_fp64', 'cubic_int8', 'snapped_cubic_int8', 'scalar_q4', 'full_table_int8')
                           if panel == 'binary' else ('cubic_fp64', 'cubic_int8', 'snapped_cubic_int8', 'scalar_q4'))}
            for panel in ('binary', 'held_real', 'wide_real')
        }
        out[kind + '_median']['high_degree_fraction'] = float(np.median([
            out['seeds'][kind][str(s)]['high_degree_fraction'] for s in range(8)]))
    path = Path(__file__).with_name('results.json')
    path.write_text(json.dumps(out, indent=2) + '\n')
    print(json.dumps({k: v for k, v in out.items() if k.endswith('_median')}, indent=2))


if __name__ == '__main__':
    main()
