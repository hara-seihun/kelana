"""Fit the paid sixteen FP16 scales to the complete layer-0 MLP response.

Disjoint train positions fit scales and select regularization. Held validation
positions 0:32 are read only after the packed image is frozen.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from scipy.optimize import minimize

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'vector-full'))
from codec import decode_image, load_image, sha256
from quality import SOURCE, bf16, packed_projection, physical_ternary_bytes, relative, response, source_weights

DATA = Path('/path/to/workspace/data/kelana-subbit/vector-full')
SOURCE_IMAGE = DATA / 'images/layer00-scalar_scale-8bit.npz'
DESTINATION = DATA / 'images/layer00-scalar_response-8bit.npz'
REPORT = HERE / 'scalar-results.json'


def panel(split: str, first: int, last: int):
    offset = 464 if split == 'train' else 8
    path = DATA / f'capture/ternary-{split}-{offset}-4.npz'
    with np.load(path) as capture:
        bits = capture['layer00']
        positions = np.concatenate([np.arange(i * 256 + first, i * 256 + last) for i in range(4)])
        x = bf16(bits[positions]).copy()
    return x, path, positions


def silu(g):
    return g / (1. + np.exp(-np.clip(g, -80, 80)))


def basis_for(x, groups, signs):
    xt = torch.from_numpy(x)
    result = np.empty((2, x.shape[0], groups.shape[0], 16), dtype=np.float32)
    for scale in range(16):
        selected = groups == scale
        w = np.concatenate([np.where(selected, signs[:, :, side], 0).astype(np.float32)
                            for side in range(2)], axis=0)
        projection = (xt @ torch.from_numpy(w).T).numpy()
        result[0, :, :, scale] = projection[:, :groups.shape[0]]
        result[1, :, :, scale] = projection[:, groups.shape[0]:]
    return result


def optimize(basis, down, target, initial, penalty):
    gate_basis, up_basis = basis
    denom = np.sum(target.astype(np.float64) ** 2)
    down_t = down.T.copy()
    calls = 0

    def objective(ratio):
        nonlocal calls
        calls += 1
        scale = initial * ratio
        gate = np.einsum('nhs,s->nh', gate_basis, scale, optimize=True)
        up = np.einsum('nhs,s->nh', up_basis, scale, optimize=True)
        act = silu(gate)
        delta = act * up @ down_t - target
        backward = (delta @ down) * (2. / denom)
        sig = 1. / (1. + np.exp(-np.clip(gate, -80, 80)))
        derivative = sig * (1. + gate * (1. - sig))
        slope = backward[:, :, None] * (derivative[:, :, None] * up[:, :, None] * gate_basis
                                        + act[:, :, None] * up_basis)
        grad = np.sum(slope, axis=(0, 1), dtype=np.float64) * initial
        displacement = ratio - 1.
        cost = float(np.sum(delta.astype(np.float64) ** 2) / denom + penalty * np.mean(displacement ** 2))
        grad += 2. * penalty / len(ratio) * displacement
        return cost, grad

    fitted = minimize(objective, np.ones(16, dtype=np.float64), jac=True, method='L-BFGS-B',
                      bounds=[(.45, 1.8)] * 16, options={'maxiter': 30, 'ftol': 1e-10})
    return (initial * fitted.x).astype('<f2'), {'iterations': int(fitted.nit), 'calls': calls,
                                                 'success': bool(fitted.success), 'objective': float(fitted.fun)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fit-positions', type=int, default=16)
    parser.add_argument('--check-positions', type=int, default=16)
    args = parser.parse_args()
    if args.fit_positions < 1 or args.check_positions < 1 or args.fit_positions + args.check_positions > 256:
        parser.error('fit and check positions must be disjoint within each 256-token train window')
    large = args.fit_positions == 128 and args.check_positions == 32
    if (args.fit_positions, args.check_positions) not in ((16, 16), (128, 32)):
        parser.error('only the predeclared 16/16 and 128/32 panels are supported')
    destination = DESTINATION.with_name('layer00-scalar_response-fit128-8bit.npz') if large else DESTINATION
    report = REPORT.with_name('scalar-fit128-results.json') if large else REPORT
    torch.set_num_threads(2)
    start = time.monotonic()
    source_receipt = json.loads(SOURCE_IMAGE.with_suffix('.json').read_text())
    if sha256(SOURCE_IMAGE) != source_receipt['image_sha256']:
        raise ValueError('source image changed')
    if destination.exists() or report.exists():
        raise FileExistsError('frozen destination already exists')
    codes, table = load_image(SOURCE_IMAGE)
    with np.load(SOURCE_IMAGE) as image:
        initial = image['scales'].astype(np.float64)
        gain, width, shape = image['gain'].copy(), image['width'].copy(), image['shape'].copy()
    patterns = np.stack(np.meshgrid(np.array([-3., -1., 1., 3.], dtype=np.float32),
                                     np.array([-3., -1., 1., 3.], dtype=np.float32), indexing='ij'), axis=-1).reshape(16, 2)
    groups = codes // 16
    signs = patterns[codes % 16]
    weights, original_down = source_weights(0)
    down, down_path = packed_projection(0, 'down')
    panels = {}
    for name, split, first, last in [('fit', 'train', 0, args.fit_positions),
                                          ('check', 'train', args.fit_positions, args.fit_positions + args.check_positions)]:
        x, path, positions = panel(split, first, last)
        panels[name] = {'x': x, 'path': path, 'positions': positions,
                        'target': response(x, weights[:, :, 0], weights[:, :, 1], original_down)}
    basis = basis_for(panels['fit']['x'], groups, signs)
    candidates = []
    for penalty in ((0., .03) if large else (0., .003, .03, .3)):
        scales, info = optimize(basis, down, panels['fit']['target'], initial, penalty)
        gate = (scales[groups].astype(np.float32) * signs[:, :, 0]).astype('<f2').astype(np.float32)
        up = (scales[groups].astype(np.float32) * signs[:, :, 1]).astype('<f2').astype(np.float32)
        candidates.append({'penalty': penalty, 'scales': scales, 'info': info, 'gate': gate, 'up': up,
                           'fit': relative(response(panels['fit']['x'], gate, up, down), panels['fit']['target']),
                           'check': relative(response(panels['check']['x'], gate, up, down), panels['check']['target'])})
        print(json.dumps({k: candidate for k, candidate in candidates[-1].items() if k in ('penalty','fit','check','info')}), flush=True)
    best = min([{'penalty': None, 'scales': initial.astype('<f2'), 'gate': table[codes, 0].astype(np.float32),
                 'up': table[codes, 1].astype(np.float32), 'info': {'iterations': 0, 'calls': 0},
                 'fit': relative(response(panels['fit']['x'], table[codes, 0].astype(np.float32),
                                          table[codes, 1].astype(np.float32), down), panels['fit']['target']),
                 'check': relative(response(panels['check']['x'], table[codes, 0].astype(np.float32),
                                            table[codes, 1].astype(np.float32), down), panels['check']['target'])}]
               + candidates, key=lambda candidate: candidate['check'])
    np.savez(destination, codes=codes, scales=best['scales'], gain=gain, width=width, shape=shape)
    new_gate, new_up = decode_image(destination)
    if not (np.array_equal(new_gate, best['gate']) and np.array_equal(new_up, best['up'])):
        raise ValueError('export does not decode fitted values')
    with np.load(destination) as image, np.load(SOURCE_IMAGE) as old:
        assert np.array_equal(image['codes'], old['codes'])
        assert {k: image[k].nbytes for k in image.files} == {k: old[k].nbytes for k in old.files}
    image_receipt = dict(source_receipt, method='scalar_response', file=str(destination),
                         image_sha256=sha256(destination), npz_container_bytes=destination.stat().st_size,
                         mean_pair_weight_sse=float(np.mean(np.sum((weights - np.stack((new_gate, new_up), axis=-1)) ** 2, axis=-1))),
                         parent_image_sha256=source_receipt['image_sha256'],
                         selection=f'train windows 464-467 positions {args.fit_positions}:{args.fit_positions + args.check_positions}; validation never selects scales',
                         fitted_scales_fp16=best['scales'].astype(float).tolist())
    destination.with_suffix('.json').write_text(json.dumps(image_receipt, indent=2) + '\n')
    x, path, positions = panel('validation', 0, 32)
    panels['validation'] = {'x': x, 'path': path, 'positions': positions,
                            'target': response(x, weights[:, :, 0], weights[:, :, 1], original_down)}
    result = {'format': 'vector-response-scalar/1', 'layer': 0,
              'source_image': str(SOURCE_IMAGE), 'source_image_sha256': source_receipt['image_sha256'],
              'image': str(destination), 'image_sha256': image_receipt['image_sha256'],
              'image_receipt_sha256': sha256(destination.with_suffix('.json')),
              'source_checkpoint_sha256': sha256(SOURCE), 'down_image_sha256': sha256(down_path),
              'down_image': str(down_path), 'physical_bytes': image_receipt['physical_bytes'],
              'common_down_bytes': physical_ternary_bytes(down_path),
              'initial_scales_fp16': initial.tolist(), 'fitted_scales_fp16': best['scales'].astype(float).tolist(),
              'fit_candidates': [{'penalty': c['penalty'], 'fit': c['fit'], 'check': c['check'], **c['info']}
                                 for c in candidates], 'selected_penalty': best['penalty'], 'panels': {}}
    for name, panel_data in panels.items():
        x, target = panel_data['x'], panel_data['target']
        result['panels'][name] = {'capture_sha256': sha256(panel_data['path']),
                                  'positions': panel_data['positions'].tolist(),
                                  'source_relative_rms': relative(response(x, table[codes, 0].astype(np.float32),
                                                                             table[codes, 1].astype(np.float32), down), target),
                                  'response_relative_rms': relative(response(x, new_gate, new_up, down), target)}
    result['seconds'] = time.monotonic() - start
    report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'report': str(report), 'selected_penalty': best['penalty'],
                      'source_validation': result['panels']['validation']['source_relative_rms'],
                      'fitted_validation': result['panels']['validation']['response_relative_rms'],
                      'seconds': result['seconds']}), flush=True)


if __name__ == '__main__':
    main()
