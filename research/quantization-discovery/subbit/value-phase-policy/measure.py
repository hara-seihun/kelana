#!/usr/bin/env python3
"""Score-only phase policy for frozen fifteen-count narrow value attention."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('grid', SUBBIT/'value-phase-grid/measure.py')
grid = importlib.util.module_from_spec(spec)
spec.loader.exec_module(grid)
parent = grid.parent
DATA, MODEL, CAPTURES = grid.DATA, grid.MODEL, grid.CAPTURES
PHASES = 16
POSITIONS = tuple(range(15, 256, 16))


def features(prob):
    # A scan over probabilities and fifteen-unit prefix fractions; no V codes.
    prefix = 15*np.cumsum(prob, dtype=np.float64)[:-1]
    fractions = np.mod(prefix, 1.)
    histogram = np.histogram(fractions, bins=np.linspace(0, 1, 9))[0]/max(1, len(fractions))
    sorted_prob = np.sort(prob)[-4:]
    return np.r_[1., np.log2(len(prob))/8, float(np.max(prob)),
                 float(np.sum(prob*prob)), float(-np.sum(prob*np.log(np.maximum(prob, 1e-30))))/8,
                 sorted_prob, histogram]


def phase_errors(prob, codes, gram, reference):
    boundary = 15*np.cumsum(prob, dtype=np.float64)[:-1]
    prefix = np.empty((PHASES, len(prob)+1), dtype=np.int64)
    prefix[:, 0], prefix[:, -1] = 0, 15
    prefix[:, 1:-1] = np.floor(boundary[None, :] + np.arange(PHASES)[:, None]/PHASES).astype(np.int64)
    counts = np.diff(prefix, axis=1)
    assert np.all(counts >= 0) and np.all(counts.sum(axis=1) == 15)
    residual = counts @ codes / 15 - reference
    return np.einsum('md,df,mf->m', residual, gram, residual)


def ridge_policy(x, y, penalty):
    center = x.mean(axis=0)
    scale = np.maximum(x.std(axis=0), 1e-7)
    scale[0] = 1.
    center[0] = 0.
    standardized = (x-center)/scale
    weights = np.linalg.solve(standardized.T@standardized + penalty*np.diag([0.]+[1.]*(x.shape[1]-1)), standardized.T@y)
    return center, scale, weights


def run(layer):
    torch.set_num_threads(8)
    factor = DATA/'value-observer'/f'layer{layer:02d}-joint-r28.npz'
    meta_path = DATA/'value-centered-int4'/f'layer{layer:02d}-8x4.json'
    meta = json.loads(meta_path.read_text())
    assert meta['image_sha256'] == parent.sha(factor)
    head = {0: 7, 14: 12}[layer]
    decoder_spec = importlib.util.spec_from_file_location('decoder', parent.SOURCE)
    decoder = importlib.util.module_from_spec(decoder_spec)
    decoder_spec.loader.exec_module(decoder)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        weights = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
                   for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    with np.load(factor) as image:
        group = head//2
        arrays = {key: image[key][group].copy() for key in image.files}
        left = decoder.decode(arrays, 'left')[head%2*1024:(head%2+1)*1024].double().numpy()
        right = decoder.decode(arrays, 'right')
    step = np.asarray(meta['metadata'][group]['int4_coordinate']['step'], dtype=np.float64)
    gram = (step[:, None]*left.T) @ (left*step[None, :])
    samples = {}
    for split, windows in [('train', 8), ('validation', 4)]:
        x = parent.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        p = parent.probabilities(x, weights['q_proj'], weights['k_proj'], weights['q_norm'], weights['k_norm'])
        selected = (torch.arange(windows)[:, None], torch.tensor(POSITIONS)[None, :])
        prob = p[selected[0], head, selected[1]].reshape(-1, 256)
        ref = parent.counts(prob, 4095).numpy()
        z = (x @ right.T).to(torch.bfloat16).float()
        codes = (z / torch.tensor(step, dtype=torch.float32)).round().clamp(-7, 7).numpy().reshape(windows, 256, 28)
        rows = []
        for j in range(windows*len(POSITIONS)):
            w, index = divmod(j, len(POSITIONS))
            pos = POSITIONS[index]
            c = codes[w, :pos+1].astype(np.float64)
            probability = prob[j, :pos+1].double().numpy()
            reference = ref[j, :pos+1] @ c/4095
            errors = phase_errors(probability, c, gram, reference)
            rows.append({'window': w, 'position': pos, 'features': features(probability).tolist(),
                         'sq': errors.tolist(), 'energy': float(reference@gram@reference)})
        samples[split] = rows
    train, held = samples['train'], samples['validation']
    xt = np.asarray([r['features'] for r in train]); yt = np.asarray([r['sq'] for r in train])
    # Normalize each row's shape for training; selection needs rankings, not magnitude.
    yt = (yt-yt[:, :1])/np.maximum(yt.max(axis=1)-yt.min(axis=1), 1e-12)[:, None]
    candidates = (0.01, .1, 1., 10., 100., 1000.)
    subsets = {'fraction_histogram': [0, 1]+list(range(9, 17)),
               'moment_top4_histogram': [0, 1, 2, 3]+list(range(5, 17)),
               'all_features': list(range(17))}
    policies = {}
    for name, columns in subsets.items():
        matrix = xt[:, columns]
        checks = {}
        for penalty in candidates:
            total = 0.
            for w in range(8):
                mask = np.array([r['window'] != w for r in train])
                center, scale, weights = ridge_policy(matrix[mask], yt[mask], penalty)
                chosen = np.argmin(((matrix[~mask]-center)/scale)@weights, axis=1)
                total += sum(train[i]['sq'][k] for i, k in zip(np.flatnonzero(~mask), chosen))
            checks[str(penalty)] = total
        penalty = min(candidates, key=lambda p: checks[str(p)])
        center, scale, weights = ridge_policy(matrix, yt, penalty)
        policies[name] = {'columns': columns, 'ridge': penalty, 'train_window_cv_sq': checks,
                          'center': center.tolist(), 'scale': scale.tolist(), 'weights': weights.tolist()}
    best_fixed = int(np.argmin(np.sum([r['sq'] for r in train], axis=0)))
    for split, rows in samples.items():
        x = np.asarray([r['features'] for r in rows])
        for name, policy in policies.items():
            cols = policy['columns']
            chosen = np.argmin(((x[:, cols]-policy['center'])/policy['scale'])@policy['weights'], axis=1)
            for r, k in zip(rows, chosen):
                r[name+'_phase'] = int(k)
        energy = sum(r['energy'] for r in rows)
        index = {'prefix': lambda r: 0, 'fixed_train': lambda r: best_fixed,
                 'grid_oracle': lambda r: int(np.argmin(r['sq']))}
        index.update({name: (lambda r, key=name: r[key+'_phase']) for name in policies})
        relative = {name: sum(r['sq'][select(r)] for r in rows)/energy for name, select in index.items()}
        print(layer, split, relative, flush=True)
        samples[split] = {'rows': rows, 'relative': relative}
    receipt = {'layer': layer, 'head': head, 'positions': POSITIONS, 'phases': PHASES,
               'train_fixed_phase': best_fixed, 'policies': policies,
               'records': samples, 'model_sha256': parent.sha(MODEL),
               'capture_sha256': parent.sha(CAPTURES/f'layer{layer:02d}.npz'),
               'factor_sha256': parent.sha(factor), 'cache_fit_sha256': parent.sha(meta_path),
               'source_sha256': parent.sha(HERE), 'scope': 'Frozen original-producer one-head score-only phase policy. Eight train windows for fit and window CV, four inspected validation windows; 16 positions/window. Errors against 4095-mass response, no native or model loss.'}
    dest = DATA/'value-phase-policy'/f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
