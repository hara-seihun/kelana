#!/usr/bin/env python3
"""Train a cached, one-byte-per-key code sketch for fifteen-count phase selection."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('policy', SUBBIT/'value-phase-policy/measure.py')
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)
parent = policy.parent
DATA, MODEL, CAPTURES = policy.DATA, policy.MODEL, policy.CAPTURES


def gather(layer):
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
    eigenvalue, eigenvector = np.linalg.eigh(gram)
    projection = eigenvector[:, -1]
    if projection[np.argmax(np.abs(projection))] < 0:
        projection = -projection
    samples = {}
    for split, windows in [('train', 8), ('validation', 4)]:
        x = parent.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        p = parent.probabilities(x, weights['q_proj'], weights['k_proj'], weights['q_norm'], weights['k_norm'])
        selected = (torch.arange(windows)[:, None], torch.tensor(policy.POSITIONS)[None, :])
        prob = p[selected[0], head, selected[1]].reshape(-1, 256)
        ref = parent.counts(prob, 4095).numpy()
        z = (x @ right.T).to(torch.bfloat16).float()
        codes = (z / torch.tensor(step, dtype=torch.float32)).round().clamp(-7, 7).numpy().reshape(windows, 256, 28)
        rows = []
        for j in range(windows*len(policy.POSITIONS)):
            w, index = divmod(j, len(policy.POSITIONS))
            pos = policy.POSITIONS[index]
            c = codes[w, :pos+1].astype(np.float64)
            probability = prob[j, :pos+1].double().numpy()
            reference = ref[j, :pos+1] @ c/4095
            errors = policy.phase_errors(probability, c, gram, reference)
            rows.append({'window': w, 'position': pos, 'p': probability,
                         'codes': c, 'sq': errors, 'energy': float(reference@gram@reference),
                         'score_features': policy.features(probability)[[0, 1]+list(range(9, 17))]})
        samples[split] = rows
    return samples, projection, gram, {'model': parent.sha(MODEL),
                                'capture': parent.sha(CAPTURES/f'layer{layer:02d}.npz'),
                                'factor': parent.sha(factor), 'cache_fit': parent.sha(meta_path)}


def sketch_features(row, projection, byte):
    c = row['codes']
    sketch = c @ projection
    step = 1.
    if byte:
        step = 7*float(np.abs(projection).sum())/127
        sketch = np.clip(np.rint(sketch/step), -127, 127)
    p = row['p']
    boundaries = 15*np.cumsum(p)[:-1]
    frac = np.mod(boundaries, 1.)
    delta = sketch[:-1]-sketch[1:]
    prefix = np.r_[0, np.floor(boundaries), 15]
    counts0 = np.diff(prefix)
    base = counts0 @ sketch / 15
    floating = p @ sketch
    bins = np.minimum(15, np.floor(16*frac).astype(np.int64))
    histogram = np.bincount(bins, weights=delta, minlength=16)
    jumps = np.r_[0., np.cumsum(histogram[:0:-1])]/15
    residual = (base+jumps-floating)*step
    return np.column_stack([residual, residual**2])


def normalize(x, mean=None, scale=None):
    if mean is None:
        mean = x.mean(axis=0)
        scale = np.maximum(x.std(axis=0), 1e-7)
        mean[0], scale[0] = 0., 1.
    return (x-mean)/scale, mean, scale


def train_policy(rows, projection, penalty, byte):
    # A shared two-feature code-response correction to the score-only sixteen-way policy.
    # Each phase retains its own score-histogram coefficients; the sketch coefficients
    # are common across phases to keep the learned state and the fit small.
    score = np.stack([r['score_features'] for r in rows])
    sketch = np.stack([sketch_features(r, projection, byte) for r in rows])
    normalized_score, center_s, scale_s = normalize(score)
    normalized_sketch, center_k, scale_k = normalize(sketch.reshape(-1, 2))
    normalized_sketch = normalized_sketch.reshape(len(rows), 16, 2)
    x = np.concatenate([np.tile(normalized_score[:, None, :], (1, 16, 1)), normalized_sketch], axis=2)
    target = np.stack([r['sq'] for r in rows])
    target = (target-target[:, :1])/np.maximum(target.max(axis=1)-target.min(axis=1), 1e-12)[:, None]
    # Score features are independently weighted by phase; sketch coefficients shared.
    matrix = np.zeros((len(rows)*16, 16*score.shape[1]+2))
    for phase in range(16):
        matrix[phase::16, phase*score.shape[1]:(phase+1)*score.shape[1]] = normalized_score
    matrix[:, -2:] = normalized_sketch.reshape(-1, 2)
    regularizer = np.ones(matrix.shape[1]); regularizer[::score.shape[1]][:16] = 0
    coeff = np.linalg.solve(matrix.T@matrix + penalty*np.diag(regularizer), matrix.T@target.ravel())
    return {'score_center': center_s, 'score_scale': scale_s, 'sketch_center': center_k,
            'sketch_scale': scale_k, 'coeff': coeff, 'penalty': penalty}


def decide(rows, projection, fitted, byte):
    score = (np.stack([r['score_features'] for r in rows])-fitted['score_center'])/fitted['score_scale']
    sketch = np.stack([sketch_features(r, projection, byte) for r in rows])
    sketch = (sketch-fitted['sketch_center'])/fitted['sketch_scale']
    rank = score @ fitted['coeff'][:-2].reshape(16, -1).T + sketch @ fitted['coeff'][-2:]
    return np.argmin(rank, axis=1)


def run(layer):
    samples, projection, gram, hashes = gather(layer)
    train = samples['train']
    score_receipt_path = DATA/'value-phase-policy'/f'layer{layer:02d}.json'
    score_receipt = json.loads(score_receipt_path.read_text())
    assert score_receipt['model_sha256'] == hashes['model']
    assert score_receipt['capture_sha256'] == hashes['capture']
    assert score_receipt['factor_sha256'] == hashes['factor']
    assert score_receipt['cache_fit_sha256'] == hashes['cache_fit']
    fixed = int(np.argmin(np.stack([r['sq'] for r in train]).sum(axis=0)))
    assert fixed == score_receipt['train_fixed_phase']
    penalty_grid = (.1, 1., 10., 100., 1000.)
    outcomes = {}
    for byte in (False, True):
        checks = {}
        for penalty in penalty_grid:
            total = 0.
            for w in range(8):
                fitting = [r for r in train if r['window'] != w]
                withheld = [r for r in train if r['window'] == w]
                model = train_policy(fitting, projection, penalty, byte)
                chosen = decide(withheld, projection, model, byte)
                total += sum(r['sq'][k] for r, k in zip(withheld, chosen))
            checks[str(penalty)] = total
        selected = min(penalty_grid, key=lambda x: checks[str(x)])
        model = train_policy(train, projection, selected, byte)
        arms = {}
        for split, rows in samples.items():
            chosen = decide(rows, projection, model, byte)
            energy = sum(r['energy'] for r in rows)
            old_rows = score_receipt['records'][split]['rows']
            assert [(r['window'], r['position']) for r in rows] == [(r['window'], r['position']) for r in old_rows]
            assert np.allclose([r['sq'] for r in rows], [r['sq'] for r in old_rows], rtol=1e-5, atol=1e-10)
            score_choices = [r['fraction_histogram_phase'] for r in old_rows]
            metrics = {name: sum(r['sq'][k] for r, k in zip(rows, picks))/energy for name, picks in {
                'sketch': chosen, 'score_only': score_choices, 'fixed': [fixed]*len(rows),
                'prefix': [0]*len(rows), 'oracle': [int(np.argmin(r['sq'])) for r in rows]}.items()}
            arms[split] = {'relative': metrics, 'choices': chosen.tolist(),
                           'selected_sq': [float(r['sq'][k]) for r, k in zip(rows, chosen)],
                           'energy': [r['energy'] for r in rows],
                           'window_relative': [{name: sum(rows[i]['sq'][k] for i, k in enumerate(picks) if rows[i]['window'] == w)/sum(r['energy'] for r in rows if r['window'] == w)
                                                for name, picks in {'sketch': chosen, 'score_only': score_choices, 'fixed': [fixed]*len(rows)}.items()} for w in range(max(r['window'] for r in rows)+1)]}
            print(layer, 'byte' if byte else 'real', split, metrics, flush=True)
        outcomes['byte' if byte else 'real'] = {'cv_sq': checks, 'selected_penalty': selected, 'results': arms,
                                                   'fit': {key: value.tolist() if isinstance(value, np.ndarray) else value for key, value in model.items()}}
    receipt = {'layer': layer, 'head': {0:7,14:12}[layer], 'projection': projection.tolist(), 'projection_eigenvalue': float(projection @ gram @ projection),
               'train_fixed_phase': fixed, 'hashes': hashes, 'score_only_receipt_sha256': parent.sha(score_receipt_path), 'source_sha256': parent.sha(HERE), 'outcomes': outcomes,
               'scope': 'Frozen original-producer one-head panel; sixteen positions per eight train and four previously inspected validation windows. Shared one-dimensional leading paid-O metric eigenvector computed from frozen factor. Per-key byte sketch is a hypothetical appended state; no fresh model loss, native time, or selected consumer.'}
    dest = DATA/'value-phase-sketch'/f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(dest, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
