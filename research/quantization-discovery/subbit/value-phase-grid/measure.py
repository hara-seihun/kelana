#!/usr/bin/env python3
"""Per-query finite-grid phase search against the exact systematic-phase oracle."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('phase', SUBBIT/'value-adaptive-phase/measure.py')
phase = importlib.util.module_from_spec(spec)
spec.loader.exec_module(phase)
parent = phase.parent
DATA, MODEL, CAPTURES = phase.DATA, phase.MODEL, phase.CAPTURES


def grid_choice(prob, codes, gram, target, size):
    """Evaluate a fixed uniform phase grid, including zero, without a sorted event list."""
    n = len(prob)
    boundaries = 15*np.cumsum(prob, dtype=np.float64)[:-1]
    grid = np.arange(size, dtype=np.float64)/size
    prefix = np.zeros((size, n+1), dtype=np.int64)
    prefix[:, -1] = 15
    prefix[:, 1:-1] = np.floor(boundaries[None, :] + grid[:, None]).astype(np.int64)
    counts = np.diff(prefix, axis=1)
    assert np.all(counts >= 0) and np.all(counts.sum(axis=1) == 15)
    response = counts @ codes / 15.
    residual = response - target
    errors = np.einsum('md,df,mf->m', residual, gram, residual)
    best = int(np.argmin(errors))
    return counts[best], float(grid[best]), float(errors[best])


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
    records = {}
    for split, windows in [('train', 8), ('validation', 4)]:
        x = parent.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
        p = parent.probabilities(x, weights['q_proj'], weights['k_proj'], weights['q_norm'], weights['k_norm'])
        selected = (torch.arange(windows)[:, None], torch.tensor([63, 127, 191, 255])[None, :])
        prob = p[selected[0], head, selected[1]].reshape(-1, 256)
        ref_n = parent.counts(prob, 4095).numpy()
        prefix_n = parent.counts(prob, 15).numpy()
        z = (x @ right.T).to(torch.bfloat16).float()
        codes = (z / torch.tensor(step, dtype=torch.float32)).round().clamp(-7, 7).numpy().reshape(windows, 256, 28)
        sums = {str(k): 0. for k in ('prefix', 'exact', 2, 4, 8, 16, 32)}
        rows = []
        energy = 0.
        for j in range(windows*4):
            w, index = divmod(j, 4)
            pos = (63, 127, 191, 255)[index]
            c = codes[w, :pos+1].astype(np.float64)
            probability = prob[j, :pos+1].double().numpy()
            reference = (ref_n[j, :pos+1] @ c)/4095.
            target = probability @ c
            exact, exact_phase, events, _ = phase.optimal_phase(probability, c, gram, target)
            row = {'window': w, 'position': pos, 'exact_phase': exact_phase, 'events': events}
            for name, counts in [('prefix', prefix_n[j, :pos+1]), ('exact', exact)]:
                residual = counts @ c/15. - reference
                row[name] = float(residual @ gram @ residual)
                sums[name] += row[name]
            for size in (2, 4, 8, 16, 32):
                chosen, u, _ = grid_choice(probability, c, gram, target, size)
                residual = chosen @ c/15. - reference
                row[str(size)] = float(residual @ gram @ residual)
                row[f'phase_{size}'] = u
                sums[str(size)] += row[str(size)]
            energy += float(reference @ gram @ reference)
            rows.append(row)
        records[split] = {'rows': rows, 'energy': energy,
                          'relative': {k: v/energy for k, v in sums.items()}}
        print(layer, split, records[split]['relative'], flush=True)
    receipt = {'layer': layer, 'head': head, 'records': records,
               'model_sha256': parent.sha(MODEL), 'capture_sha256': parent.sha(CAPTURES/f'layer{layer:02d}.npz'),
               'factor_sha256': parent.sha(factor), 'cache_fit_sha256': parent.sha(meta_path),
               'parent_receipt_sha256': parent.sha(parent_path),
               'oracle_source_sha256': parent.sha(phase.HERE), 'source_sha256': parent.sha(HERE),
               'scope': 'Frozen original-producer single head; four positions per eight train and four repeatedly inspected validation windows. Every query independently minimizes FP64 post-O squared error against floating code response on a uniform phase grid. Error relative to 4095-count response. No fitted model, full-layer budget, native timing or fresh model loss.'}
    dest = DATA/'value-phase-grid'/f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(dest, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
