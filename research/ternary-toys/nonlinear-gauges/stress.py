#!/usr/bin/env python3
"""Off-manifold teacher and paid FP16 boundary stress test for shared gauges."""
import json
from pathlib import Path

import numpy as np

from experiment import block, candidate, rotation


def fp16_boundary(x, matrices, angle):
    q = rotation(angle).astype(np.float16).astype(np.float64)
    if angle:
        z = (x @ q.T).astype(np.float16).astype(np.float64)
    else:
        z = x
    y = block(z, *matrices)
    if angle:
        return (y @ q).astype(np.float16).astype(np.float64)
    return y


def run_case(g, u, d, train, held):
    angles = range(90)
    gains = np.arange(5, 41) / 10
    families = {'fixed': [(0, 1.)], 'hadamard': [(45, 1.)],
                'rotation_only': [(a, 1.) for a in angles],
                'gain_only': [(0, h) for h in gains],
                'joint': [(a, h) for a in angles for h in gains]}
    true_train = block(train, g, u, d)
    true_held = block(held, g, u, d)
    def relative(pred, reference):
        return float(np.sqrt(np.mean((pred - reference) ** 2) / np.mean(reference ** 2)))
    def score(a, fits, x, y):
        return relative(fp16_boundary(x, fits, a), y)
    result = {}
    for family, choices in families.items():
        options = []
        for a, h in choices:
            weight_sse, fitted, raw = candidate(g, u, d, a, h)
            fitted16 = [np.array(codes) * np.float16(scale).astype(float)
                        for _, codes, scale, _ in raw]
            train_error = score(a, fitted16, train, true_train)
            options.append((weight_sse, train_error, a, float(h), fitted16, raw))
        controls = {}
        for selector, best in (('weight_sse', min(options, key=lambda item: item[0])),
                               ('train_output', min(options, key=lambda item: item[1]))):
            sse, tr, a, h, matrices, raw = best
            controls[selector] = {'angle_degrees': a, 'hidden_up_gain': h,
                                  'weight_sse': sse, 'train_relative_rmse': tr,
                                  'held_relative_rmse': score(a, matrices, held, true_held),
                                  'codes': [r[1] for r in raw],
                                  'fp16_scales': [float(np.float16(r[2])) for r in raw]}
        result[family] = controls
    return result


def main():
    rng = np.random.default_rng(9037)
    q0 = rotation(29)
    g = np.array([[1., 1.], [0., -1.]]) @ q0
    u = np.diag([1 / 2.5, 1.]) @ np.array([[1., -1.], [1., 1.]]) @ q0
    d = q0.T @ np.array([[1., 0.], [-1., 1.]]) @ np.diag([2.5, 1.])
    train = rng.normal(size=(768, 2)) * [2., .3] + [.5, -.25]
    held = rng.normal(size=(2048, 2)) * [.35, 2.] + [-.6, .4]
    # Independent additive perturbations, fixed before searching any gauges.
    perturbed = [w + rng.normal(size=w.shape) * .2 for w in (g, u, d)]
    # A negative-control teacher with no planted shared residual basis.
    independent = [rng.normal(size=(2, 2)) for _ in range(3)]
    _, _, raw = candidate(g, u, d, 29, 2.5)
    planted16 = [np.array(codes) * float(np.float16(scale))
                 for _, codes, scale, _ in raw]
    ideal = block(held, g, u, d)
    finite = fp16_boundary(held, planted16, 29)
    precision_floor = float(np.sqrt(np.mean((finite - ideal) ** 2) / np.mean(ideal ** 2)))
    result = {'seed': 9037, 'perturbation_std_per_weight': .2,
              'train_rows': len(train), 'held_rows': len(held),
              'finite_precision': 'FP16 group scales and FP16 entry/exit Q; FP16 cast after each nonidentity boundary, float64 block arithmetic',
              'planted_exact_gauge_fp16_held_relative_rmse': precision_floor,
              'perturbed': run_case(*perturbed, train, held),
              'independent': run_case(*independent, train, held)}
    Path(__file__).with_name('stress-results.json').write_text(json.dumps(result, indent=2) + '\n')
    print('planted exact gauge FP16 floor:', precision_floor)
    for case in ('perturbed', 'independent'):
        print(case)
        for family, arm in result[case].items():
            print(f'{family:14}', '  '.join(f'{selector}: {v["angle_degrees"]}deg/{v["hidden_up_gain"]:.1f}, train {v["train_relative_rmse"]:.4f}, held {v["held_relative_rmse"]:.4f}' for selector, v in arm.items()))


if __name__ == '__main__':
    main()
