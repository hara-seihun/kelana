#!/usr/bin/env python3
"""Fit static per-group A7 selector thresholds on the complete binary-factor map."""
import hashlib
import importlib.util
import json
from pathlib import Path
import time
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
PARENT = HERE.parent / 'binary-second-selector/measure.py'
spec = importlib.util.spec_from_file_location('binary_second_selector', PARENT)
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
OUT_DIR = Path('/path/to/workspace/data/kelana-subbit/binary-group-choice')
GRID = np.round(np.arange(.70, .821, .01), 2)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fit(c, signs, post, first, last, sweeps=1):
    thresholds = np.full(c['ratio'].shape[1], first)
    selection = parent.parent.choose(c, thresholds)
    response = parent.second(c, selection, signs, post, last)[0]
    error = np.sum((response - c['truth']) ** 2)
    path = [float(np.sqrt(error / np.sum(c['truth'] ** 2)))]
    changed = 0
    for _ in range(sweeps):
        for g in range(len(thresholds)):
            ratios = c['ratio'][:, g]
            best = (error, thresholds[g], None, None)
            for candidate in GRID:
                new = ratios <= candidate
                rows = np.flatnonzero(new != selection[:, g])
                if not len(rows):
                    continue
                view = {key: value[rows] for key, value in c.items()
                        if isinstance(value, np.ndarray) and value.shape[0] == len(ratios)}
                trial = selection[rows].copy()
                trial[:, g] = new[rows]
                result = parent.second(view, trial, signs, post, last)[0]
                old_loss = np.sum((response[rows] - c['truth'][rows]) ** 2)
                new_loss = np.sum((result - c['truth'][rows]) ** 2)
                proposed = error - old_loss + new_loss
                if proposed < best[0] - 1e-13:
                    best = (proposed, candidate, rows, result)
            if best[2] is not None:
                error, thresholds[g], rows, result = best
                response[rows] = result
                selection[rows, g] = c['ratio'][rows, g] <= thresholds[g]
                changed += 1
        actual = parent.second(c, selection, signs, post, last)[0]
        assert np.allclose(actual, response, rtol=0, atol=0)
        path.append(parent.parent.rms(response, c['truth']))
    return thresholds, path, changed


def main():
    small = sys.argv[1:] == ['--small']
    if sys.argv[1:] and not small:
        raise SystemExit('usage: measure.py [--small]')
    out = OUT_DIR / ('receipt-32.json' if small else 'receipt-128.json')
    entries = []
    for layer in (0, 14):
        image = parent.parent.IMAGES / f'model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
        fixture = parent.parent.FIXTURES / f'layer{layer:02d}-mlp_up_proj.npz'
        with np.load(image) as f:
            n, k, rank = map(int, f['dimensions'])
            v = 2 * np.unpackbits(f['V'], axis=1, count=k, bitorder='little').astype(np.int16) - 1
            u = 2 * np.unpackbits(f['U'], axis=1, count=rank, bitorder='little').astype(np.int16) - 1
            pre, post = f['scale_pre'].astype(np.float64), f['scale_post'].astype(np.float64)
        with np.load(fixture) as f:
            train = (f['train'][:32] if small else f['train'][512:640]).astype(np.float64)
            held = (f['validation'][32:64] if small else f['validation'][512:640]).astype(np.float64)
        tc = parent.parent.first_candidates(train, v, pre, u, post)
        hc = parent.parent.first_candidates(held, v, pre, u, post)
        baseline = {0: (.77, .77), 14: (.78, .77)}[layer]
        start = time.monotonic()
        thresholds, path, changed = fit(tc, u, post, *baseline, sweeps=2 if small else 1)
        cases = {}
        for split, c in [('train', tc), ('held', hc)]:
            cases[split] = {}
            for name, first in [('global', np.full(k // 32, baseline[0])), ('group', thresholds)]:
                selection = parent.parent.choose(c, first)
                response = parent.second(c, selection, u, post, baseline[1])[0]
                cases[split][name] = {'rms': parent.parent.rms(response, c['truth']),
                                      'response_sha256': hashlib.sha256(np.ascontiguousarray(response).tobytes()).hexdigest(),
                                      'lower_choices': int(selection.sum()),
                                      'clipped_choices': int(np.sum(selection & (c['ratio'] > .75)))}
        entries.append({'layer': layer, 'image_sha256': digest(image), 'fixture_sha256': digest(fixture),
                        'global_first_last': baseline, 'first_thresholds': thresholds.tolist(),
                        'train_path': path, 'updated_groups': changed, 'elapsed_seconds': time.monotonic() - start,
                        'cases': cases})
        print(layer, path, changed, cases, flush=True)
    out.parent.mkdir(parents=True, exist_ok=True)
    contract = ('train[0:32], validation[32:64], two sweeps' if small else
                'train[512:640], validation[512:640], one sweep')
    out.write_text(json.dumps({'source_sha256': digest(Path(__file__)), 'parent_sha256': digest(PARENT),
                               'selector_parent_sha256': digest(parent.PARENT),
                               'contract': f'Paid .55 binary mlp_up; {contract}; frozen U/V and second threshold .77. Complete-response coordinate sweep over first-stage per-group .70:.82 grid; FP64 same-image teacher. No native/model-quality claim.',
                               'entries': entries}, indent=2) + '\n')
    print(out)


if __name__ == '__main__':
    main()
