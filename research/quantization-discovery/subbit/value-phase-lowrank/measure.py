#!/usr/bin/env python3
"""Train-fixed low-rank paid-output metric for per-query fifteen-unit phase selection."""
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
phase, parent = grid.phase, grid.parent
DATA, MODEL, CAPTURES = phase.DATA, phase.MODEL, phase.CAPTURES
RANKS = (1, 2, 4, 8, 16, 28)


def choices(prob, codes, transform, reference, gram):
    n = len(prob)
    boundaries = 15*np.cumsum(prob, dtype=np.float64)[:-1]
    grid_phases = np.arange(16, dtype=np.float64)/16
    prefixes = np.empty((16, n+1), dtype=np.int64)
    prefixes[:, 0], prefixes[:, -1] = 0, 15
    prefixes[:, 1:-1] = np.floor(boundaries[None, :] + grid_phases[:, None]).astype(np.int64)
    counts = np.diff(prefixes, axis=1)
    assert np.all(counts >= 0) and np.all(counts.sum(axis=1) == 15)
    projected = codes @ transform
    target = prob @ projected
    scores = np.sum((counts @ projected / 15 - target)**2, axis=1)
    chosen = int(np.argmin(scores))
    residual = counts[chosen] @ codes / 15 - reference
    return chosen, float(residual @ gram @ residual)


def run(layer):
    torch.set_num_threads(8)
    factor = DATA/'value-observer'/f'layer{layer:02d}-joint-r28.npz'
    meta_path = DATA/'value-centered-int4'/f'layer{layer:02d}-8x4.json'
    parent_path = DATA/'value-nibble-255'/f'layer{layer:02d}.json'
    meta, ancestor = json.loads(meta_path.read_text()), json.loads(parent_path.read_text())
    assert meta['image_sha256'] == parent.sha(factor)
    assert ancestor['factor_sha256'] == parent.sha(factor)
    head = {0: 7, 14: 12}[layer]
    assert int(ancestor['train_selected']['mask'], 16) & (1 << head)
    decoder_spec = importlib.util.spec_from_file_location('decoder', parent.SOURCE)
    decoder = importlib.util.module_from_spec(decoder_spec)
    decoder_spec.loader.exec_module(decoder)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        weights = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
                   for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    with np.load(factor) as image:
        group = head // 2
        arrays = {key: image[key][group].copy() for key in image.files}
        left = decoder.decode(arrays, 'left')[head % 2*1024:(head % 2+1)*1024].double().numpy()
        right = decoder.decode(arrays, 'right')
    step = np.asarray(meta['metadata'][group]['int4_coordinate']['step'], dtype=np.float64)
    gram = (step[:, None]*left.T) @ (left*step[None, :])
    eigenvalues, eigenvectors = np.linalg.eigh(gram)
    eigenvalues = eigenvalues[::-1].copy()
    eigenvectors = eigenvectors[:, ::-1].copy()
    transforms = {'spectral': {r: eigenvectors[:, :r]*np.sqrt(np.maximum(eigenvalues[:r], 0)) for r in RANKS}}
    result = {'layer': layer, 'head': head, 'ranks': RANKS,
              'metric_eigenvalues': eigenvalues.tolist(), 'records': {}}
    inputs = {}
    for split, windows in [('train', 8), ('validation', 4)]:
        x = parent.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        p = parent.probabilities(x, weights['q_proj'], weights['k_proj'], weights['q_norm'], weights['k_norm'])
        selected = (torch.arange(windows)[:, None], torch.tensor([63, 127, 191, 255])[None, :])
        prob = p[selected[0], head, selected[1]].reshape(-1, 256)
        ref_n = parent.counts(prob, 4095).numpy()
        prefix_n = parent.counts(prob, 15).numpy()
        z = (x @ right.T).to(torch.bfloat16).float()
        codes = (z / torch.tensor(step, dtype=torch.float32)).round().clamp(-7, 7).numpy().reshape(windows, 256, 28)
        inputs[split] = (prob, ref_n, prefix_n, codes)
    # Fit the metric's output subspace to train response *errors*, rather than
    # its unconditioned output energy. Validation never enters the fit.
    train_prob, _, _, train_codes = inputs['train']
    residuals = []
    for j in range(32):
        w, slot = divmod(j, 4)
        pos = (63, 127, 191, 255)[slot]
        c = train_codes[w, :pos+1].astype(np.float64)
        probability = train_prob[j, :pos+1].double().numpy()
        bounds = 15*np.cumsum(probability, dtype=np.float64)[:-1]
        prefixes = np.empty((16, pos+2), dtype=np.int64)
        prefixes[:, 0], prefixes[:, -1] = 0, 15
        prefixes[:, 1:-1] = np.floor(bounds[None, :] + np.arange(16)[:, None]/16).astype(np.int64)
        residuals.append(np.diff(prefixes, axis=1) @ c/15 - probability @ c)
    square_root = eigenvectors @ np.diag(np.sqrt(np.maximum(eigenvalues, 0))) @ eigenvectors.T
    _, singular, right = np.linalg.svd(np.concatenate(residuals) @ square_root, full_matrices=False)
    transforms['error_fitted'] = {r: square_root @ right[:r].T for r in RANKS}
    result['train_error_singular_values'] = singular.tolist()
    for split, windows in [('train', 8), ('validation', 4)]:
        prob, ref_n, prefix_n, codes = inputs[split]
        rows = []
        for j in range(windows*4):
            w, index = divmod(j, 4)
            pos = (63, 127, 191, 255)[index]
            c = codes[w, :pos+1].astype(np.float64)
            probability = prob[j, :pos+1].double().numpy()
            reference = ref_n[j, :pos+1] @ c/4095
            baseline_residual = prefix_n[j, :pos+1] @ c/15 - reference
            row = {'window': w, 'position': pos, 'energy': float(reference @ gram @ reference),
                   'prefix_sq': float(baseline_residual @ gram @ baseline_residual), 'choices': {}}
            for family, ranks in transforms.items():
                row['choices'][family] = {}
                for rank, transform in ranks.items():
                    chosen, error = choices(probability, c, transform, reference, gram)
                    row['choices'][family][str(rank)] = {'index': chosen, 'sq': error}
            rows.append(row)
        energy = sum(row['energy'] for row in rows)
        result['records'][split] = {'rows': rows, 'relative_prefix': sum(row['prefix_sq'] for row in rows)/energy,
            'relative': {family: {str(rank): sum(row['choices'][family][str(rank)]['sq'] for row in rows)/energy for rank in RANKS}
                         for family in transforms},
            'agreement_with_full': {family: {str(rank): sum(row['choices'][family][str(rank)]['index'] == row['choices']['spectral']['28']['index'] for row in rows)
                                            for rank in RANKS} for family in transforms}}
        print(layer, split, result['records'][split]['relative'], flush=True)
    result.update({'model_sha256': parent.sha(MODEL), 'capture_sha256': parent.sha(CAPTURES/f'layer{layer:02d}.npz'),
        'factor_sha256': parent.sha(factor), 'cache_fit_sha256': parent.sha(meta_path),
        'parent_receipt_sha256': parent.sha(parent_path), 'source_sha256': parent.sha(HERE),
        'scope': 'Frozen original-producer one-head sixteen-phase grid; spectral metric or train-only response-error PCA metric; actual error against 4095-count response. CPU original-producer inspected windows, not native timing or model loss.'})
    dest = DATA/'value-phase-lowrank'/f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2)+'\n')
    print(dest, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
