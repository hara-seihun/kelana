#!/usr/bin/env python3
"""Fit first-factor A7 ladder thresholds to the paid two-factor output response."""
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
IMAGES = ROOT / 'binary-factors/fixtures'
FIXTURES = ROOT / 'fixtures/qwen3-0.6b-wikitext'
OUT = ROOT / 'binary-scale-selector/receipt.json'
CAP = 8
Q = 63


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def first_candidates(xs, v, pre, u, post):
    a = xs * pre
    a32 = a.reshape(len(xs), -1, 32)
    vg = v.reshape(v.shape[0], -1, 32).astype(np.int32)
    max_g = np.max(np.abs(a32), axis=2)
    global_max = np.maximum(max_g.max(axis=1), 1e-30)
    exp = np.minimum(np.floor(np.log2(global_max[:, None] / np.maximum(max_g, 1e-30))).astype(np.int32), CAP)
    upper = global_max[:, None] / (Q * np.exp2(exp))
    lower = upper * .75
    q_up = np.clip(np.rint(a32 / upper[:, :, None]), -64, Q).astype(np.int32)
    q_low = np.clip(np.rint(a32 / lower[:, :, None]), -64, Q).astype(np.int32)
    c_up = (1 << (CAP + 1 - exp)).astype(np.int32)
    c_low = (3 << np.maximum(CAP - 1 - exp, 0)).astype(np.int32)
    hu = np.einsum('rgk,bgk->brg', vg, q_up, optimize=True)
    hl = np.einsum('rgk,bgk->brg', vg, q_low, optimize=True)
    h_up = hu * c_up[:, None, :]
    delta = hl * c_low[:, None, :] - h_up
    base = global_max / (Q * (1 << (CAP + 1)))
    w = u.astype(np.float64) * post[:, None]
    y_up = (h_up.sum(axis=2).astype(np.float64) @ w.T) * base[:, None]
    dy = np.einsum('nr,brg->bgn', w, delta, optimize=True) * base[:, None, None]
    ratio = max_g / (Q * upper)
    ratio[exp == CAP] = 10.
    truth = (a @ v.astype(np.float64).T) @ w.T
    return {'up': h_up, 'delta': delta, 'base': base, 'ratio': ratio, 'y_up': y_up, 'dy': dy, 'truth': truth}


def choose(c, thresholds):
    return c['ratio'] <= thresholds[None, :]


def linear_output(c, selections):
    return c['y_up'] + np.einsum('bg,bgn->bn', selections.astype(np.float64), c['dy'], optimize=True)


def fit(c, sweeps=2):
    groups = c['ratio'].shape[1]
    threshold = np.full(groups, .75)
    selection = choose(c, threshold)
    residual = linear_output(c, selection) - c['truth']
    for _ in range(sweeps):
        for g in range(groups):
            residual -= selection[:, g, None] * c['dy'][:, g, :]
            order = np.argsort(c['ratio'][:, g])
            d = c['dy'][order, g]
            r = residual[order]
            # One threshold serves all input rows. A prefix of sorted local ratios takes the lower step.
            costs = np.concatenate(([np.sum(r * r)], np.cumsum(np.sum(2 * r * d + d * d, axis=1)) + np.sum(r * r)))
            k = int(np.argmin(costs))
            if k == 0:
                threshold[g] = 0.
            elif k == len(order):
                threshold[g] = float(np.nextafter(c['ratio'][order[-1], g], np.inf))
            else:
                threshold[g] = float((c['ratio'][order[k - 1], g] + c['ratio'][order[k], g]) / 2)
            threshold[g] = min(threshold[g], 1.01)
            selection[:, g] = c['ratio'][:, g] <= threshold[g]
            residual += selection[:, g, None] * c['dy'][:, g, :]
    return threshold


def second_output(c, selections, u, post):
    integer = (c['up'] + c['delta'] * selections[:, None, :]).sum(axis=2).astype(np.int64)
    assert np.abs(integer).max() < (1 << 31)
    rank_groups = integer.reshape(len(integer), -1, 32)
    maxima = np.max(np.abs(rank_groups), axis=2)
    maximum = np.maximum(maxima.max(axis=1), 1)
    exp = np.minimum(np.floor(np.log2(maximum[:, None] / np.maximum(maxima, 1))).astype(np.int32), CAP)
    upper = maximum[:, None] / (Q * np.exp2(exp))
    low = upper * .75
    use = (maxima / Q <= low) & (exp < CAP)
    step = np.where(use, low, upper)
    coeff = np.where(use, 3 << (CAP - 1 - exp), 1 << (CAP + 1 - exp)).astype(np.int64)
    q = np.clip(np.rint(rank_groups / step[:, :, None]), -64, Q).astype(np.int32)
    vgroups = u.reshape(u.shape[0], -1, 32).astype(np.int32)
    h = np.einsum('nrg,brg->bnr', vgroups, q, optimize=True)
    out = np.einsum('bnr,br->bn', h, coeff, optimize=True)
    assert np.abs(out).max() < (1 << 31)
    return out * (c['base'] * maximum / (Q * (1 << (CAP + 1))))[:, None] * post[None, :]


def rms(pred, truth):
    return float(np.linalg.norm(pred - truth) / np.linalg.norm(truth))


def main():
    entries = []
    for layer in (0, 14):
        image = IMAGES / f'model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
        fixture = FIXTURES / f'layer{layer:02d}-mlp_up_proj.npz'
        with np.load(image) as f:
            n, k, rank = map(int, f['dimensions'])
            v = 2 * np.unpackbits(f['V'], axis=1, count=k, bitorder='little').astype(np.int16) - 1
            u = 2 * np.unpackbits(f['U'], axis=1, count=rank, bitorder='little').astype(np.int16) - 1
            pre, post = f['scale_pre'].astype(np.float64), f['scale_post'].astype(np.float64)
        with np.load(fixture) as f:
            train = f['train'][:32].astype(np.float64)
            held = f['validation'][32:64].astype(np.float64)
        tc = first_candidates(train, v, pre, u, post)
        hc = first_candidates(held, v, pre, u, post)
        thresholds = fit(tc)
        grid = np.arange(.70, .821, .01)
        train_grid = [rms(second_output(tc, choose(tc, np.full(k // 32, t)), u, post), tc['truth']) for t in grid]
        best = float(grid[int(np.argmin(train_grid))])
        row = {'layer': layer, 'image_sha256': digest(image), 'fixture_sha256': digest(fixture),
               'thresholds': thresholds.tolist(), 'train_rows': [0, 32], 'held_validation_rows': [32, 64],
               'complete_output_threshold_grid': grid.tolist(), 'complete_output_train_rms': train_grid, 'best_global_threshold': best}
        for split, c in (('train', tc), ('held', hc)):
            all_cases = {}
            for name, th in (('no_lower', np.zeros(k // 32)), ('safe_075', np.full(k // 32, .75)), ('fit_linear', thresholds), ('fit_complete_global', np.full(k // 32, best)), ('always_lower', np.full(k // 32, 1.01))):
                selection = choose(c, th)
                linear = linear_output(c, selection)
                final = second_output(c, selection, u, post)
                all_cases[name] = {'first_linear_rms': rms(linear, c['truth']), 'two_factor_rms': rms(final, c['truth']),
                                   'lower_choices': int(selection.sum()), 'clipped_lower_choices': int(np.sum(selection & (c['ratio'] > .75)))}
            row[split] = all_cases
        entries.append(row)
        print(layer, 'linear thresholds', np.round(thresholds, 3).tolist(), 'complete global', best)
        print(layer, {split: {name: case['two_factor_rms'] for name, case in row[split].items()} for split in ('train', 'held')})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': digest(Path(__file__)), 'contract': 'First 32 training activations fit one threshold/group by coordinate descent on the floating two-factor linear output or one global threshold by complete quantized two-factor response. Validation rows 32:64 held. Same frozen paid U/V and second-stage A7 integer ladder, cap 8; output RMS against floating same-image two-factor response. CPU FP64, no native timing or model loss.', 'entries': entries}, indent=2) + '\n')
    print(OUT)


if __name__ == '__main__':
    main()
