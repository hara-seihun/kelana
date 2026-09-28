#!/usr/bin/env python3
"""Select a shared second-factor A7 step threshold against the full paid response."""
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
PARENT = Path(__file__).resolve().parents[1] / 'binary-scale-selector/measure.py'
spec = importlib.util.spec_from_file_location('binary_scale_selector', PARENT)
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
OUT = ROOT / 'binary-second-selector/receipt.json'
Q, CAP = parent.Q, parent.CAP


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def second(c, selection, signs, post, threshold):
    first = (c['up'] + c['delta'] * selection[:, None, :]).sum(axis=2).astype(np.int64)
    assert np.abs(first).max() < (1 << 31)
    blocks = first.reshape(len(first), -1, 32)
    local = np.abs(blocks).max(axis=2)
    maximum = np.maximum(local.max(axis=1), 1)
    exponent = np.minimum(np.floor(np.log2(maximum[:, None] / np.maximum(local, 1))).astype(np.int32), CAP)
    upper = maximum[:, None] / (Q * np.exp2(exponent))
    ratio = local / (Q * upper)
    use = (ratio <= threshold) & (exponent < CAP)
    step = np.where(use, .75 * upper, upper)
    coeff = np.where(use, 3 << np.maximum(CAP - 1 - exponent, 0), 1 << (CAP + 1 - exponent)).astype(np.int64)
    codes = np.clip(np.rint(blocks / step[:, :, None]), -64, Q).astype(np.int32)
    groups = signs.reshape(signs.shape[0], -1, 32).astype(np.int32)
    partial = np.einsum('nrg,brg->bnr', groups, codes, optimize=True)
    output = np.einsum('bnr,br->bn', partial, coeff, optimize=True)
    assert np.abs(output).max() < (1 << 31)
    result = output * (c['base'] * maximum / (Q * (1 << (CAP + 1))))[:, None] * post[None, :]
    return result, int(use.sum()), int(np.sum(use & (ratio > .75))), int(np.sum((np.abs(blocks) > 63 * step[:, :, None]) & use[:, :, None]))


def main():
    rows = []
    grid = np.round(np.arange(.70, .861, .01), 2)
    for layer in (0, 14):
        image = parent.IMAGES / f'model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
        fixture = parent.FIXTURES / f'layer{layer:02d}-mlp_up_proj.npz'
        with np.load(image) as f:
            n, k, rank = map(int, f['dimensions'])
            v = 2 * np.unpackbits(f['V'], axis=1, count=k, bitorder='little').astype(np.int16) - 1
            u = 2 * np.unpackbits(f['U'], axis=1, count=rank, bitorder='little').astype(np.int16) - 1
            pre, post = f['scale_pre'].astype(np.float64), f['scale_post'].astype(np.float64)
        with np.load(fixture) as f:
            train = f['train'][:32].astype(np.float64)
            held = f['validation'][32:64].astype(np.float64)
        tc = parent.first_candidates(train, v, pre, u, post)
        hc = parent.first_candidates(held, v, pre, u, post)
        first_grid = np.round(np.arange(.70, .821, .01), 2)
        def fit_first(t):
            return float(first_grid[np.argmin([parent.rms(second(tc, parent.choose(tc, np.full(k // 32, a)), u, post, t)[0], tc['truth']) for a in first_grid])])
        # The joint selection is coordinate descent over the *full* two-factor response,
        # rather than fitting a pre-rounding linear target.
        arms = {}
        for name, first in [('safe_first', .75), ('trained_first', fit_first(.75))]:
            sel = parent.choose(tc, np.full(k // 32, first))
            fit = [parent.rms(second(tc, sel, u, post, t)[0], tc['truth']) for t in grid]
            chosen = float(grid[np.argmin(fit)])
            arms[name] = {'first_threshold': first, 'second_threshold': chosen, 'train_curve': fit}
        arms['joint_second_then_first'] = {'second_threshold': arms['safe_first']['second_threshold']}
        arms['joint_second_then_first']['first_threshold'] = fit_first(arms['joint_second_then_first']['second_threshold'])
        # Enumerate the finite grid rather than assuming coordinate descent found its best pair.
        train_pairs = []
        for first in first_grid:
            sel = parent.choose(tc, np.full(k // 32, first))
            train_pairs.append([parent.rms(second(tc, sel, u, post, last)[0], tc['truth']) for last in grid])
        i, j = np.unravel_index(np.argmin(train_pairs), (len(first_grid), len(grid)))
        arms['full_grid'] = {'first_threshold': float(first_grid[i]), 'second_threshold': float(grid[j]),
                             'train_pair_min': float(train_pairs[i][j]), 'train_pair_sha256': hashlib.sha256(np.asarray(train_pairs, dtype='<f8').tobytes()).hexdigest()}
        for arm in arms.values():
            arm['train'] = {}
            arm['held'] = {}
            for split, c in [('train', tc), ('held', hc)]:
                sel = parent.choose(c, np.full(k // 32, arm['first_threshold']))
                response, selected, clipped_groups, clipped_codes = second(c, sel, u, post, arm['second_threshold'])
                arm[split] = {'rms': parent.rms(response, c['truth']), 'second_lower_groups': selected,
                              'second_clipped_groups': clipped_groups, 'second_clipped_codes': clipped_codes,
                              'response_sha256': hashlib.sha256(np.ascontiguousarray(response).tobytes()).hexdigest()}
        controls = {}
        for first, last, name in [(.75, .75, 'safe'), (arms['trained_first']['first_threshold'], .75, 'trained_first_only')]:
            controls[name] = {}
            for split, c in [('train', tc), ('held', hc)]:
                response, selected, groups, codes = second(c, parent.choose(c, np.full(k // 32, first)), u, post, last)
                controls[name][split] = parent.rms(response, c['truth'])
        rows.append({'layer': layer, 'image_sha256': sha(image), 'fixture_sha256': sha(fixture), 'first_grid': first_grid.tolist(), 'second_grid': grid.tolist(), 'arms': arms, 'controls': controls})
        print(layer, 'controls', controls, 'arms', {n: (a['first_threshold'], a['second_threshold'], a['train']['rms'], a['held']['rms']) for n, a in arms.items()}, flush=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(PARENT), 'contract': 'Paid .55 Qwen mlp_up binary factors, train[0:32] and distinct validation[32:64]; FP64 reference for same image; CPU integer A7 C8 group ladder at both factor boundaries, stage-one fixed/train-fit and coordinate-descent pair, second-stage grid .70:.86, complete-response relative RMS. No native or language quality.', 'entries': rows}, indent=2) + '\n')
    print(OUT)


if __name__ == '__main__':
    main()
