#!/usr/bin/env python3
"""Exact finite phase sweep for a frozen fifteen-count narrow-value response."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('discrepancy', SUBBIT/'value-mass-discrepancy/measure.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
parent = prior.parent
DATA, MODEL, CAPTURES = prior.DATA, prior.MODEL, prior.CAPTURES


def optimal_phase(prob, code, gram, target):
    """Every distinct count vector of floor(15*cumulative+u), 0 <= u < 1."""
    n, d = code.shape
    boundaries = 15*np.cumsum(prob, dtype=np.float64)[:-1]
    base = np.floor(boundaries).astype(np.int64)
    prefix = np.empty(n + 1, dtype=np.int64)
    prefix[0], prefix[-1] = 0, 15
    prefix[1:-1] = base
    counts = np.diff(prefix)
    assert np.all(counts >= 0) and counts.sum() == 15
    changes = code[:-1] - code[1:]
    transformed = changes @ gram
    self_dot = np.einsum('ij,ij->i', changes, transformed)
    residual = counts @ code / 15. - target
    gradient = residual @ gram
    error = float(residual @ gradient)
    best_error, best_counts, best_phase = error, counts.copy(), 0.
    phases = 1 - np.modf(boundaries)[0]
    events = sorted((float(u), i) for i, u in enumerate(phases) if 0 < u < 1)
    # Coincident thresholds must move together, rather than record an
    # unattainable intermediate state in an interval of zero width.
    j = 0
    while j < len(events):
        phase = events[j][0]
        while j < len(events) and events[j][0] == phase:
            i = events[j][1]
            error += 2*float(changes[i] @ gradient)/15 + float(self_dot[i])/225
            gradient += transformed[i]/15
            counts[i] += 1
            counts[i+1] -= 1
            j += 1
        if error < best_error:
            best_error, best_counts, best_phase = error, counts.copy(), phase
    assert np.all(best_counts >= 0) and best_counts.sum() == 15
    # Check actual candidate scores rather than relying on accumulated roundoff.
    checked = float(((best_counts @ code/15. - target) @ gram) @ (best_counts @ code/15. - target))
    assert abs(best_error-checked) < 1e-7*max(1., abs(checked))
    return best_counts, best_phase, len(events), checked


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
        result = {'prefix_error': 0., 'phase_error': 0., 'exchange_error': 0.,
                  'energy': 0., 'per_row': [], 'events': 0, 'phase_support': 0}
        for j in range(windows*4):
            w, index = divmod(j, 4)
            pos = (63, 127, 191, 255)[index]
            c = codes[w, :pos+1].astype(np.float64)
            probability = prob[j, :pos+1].double().numpy()
            reference = (ref_n[j, :pos+1] @ c)/4095.
            target = probability @ c
            prefix = prefix_n[j, :pos+1]
            choice, phase, events, _ = optimal_phase(probability, c, gram, target)
            exchange, _ = prior.choose_codes(c, gram, target, prefix)
            def squared(counts):
                error = counts @ c / 15. - reference
                return float(error @ gram @ error)
            old, new, exchanged = squared(prefix), squared(choice), squared(exchange)
            energy = float(reference @ gram @ reference)
            result['prefix_error'] += old
            result['phase_error'] += new
            result['exchange_error'] += exchanged
            result['energy'] += energy
            result['events'] += events
            result['phase_support'] += int(np.count_nonzero(choice))
            result['per_row'].append({'window': w, 'position': pos, 'phase': phase,
                                      'events': events, 'prefix_sq': old, 'phase_sq': new,
                                      'exchange_sq': exchanged, 'energy': energy,
                                      'phase_support': int(np.count_nonzero(choice))})
        for arm in ('prefix', 'phase', 'exchange'):
            result['relative_'+arm] = result[arm+'_error']/result['energy']
        records[split] = result
        print(layer, split, *(result['relative_'+arm] for arm in ('prefix', 'phase', 'exchange')), flush=True)
    receipt = {'layer': layer, 'head': head, 'mass': 15, 'records': records,
               'model_sha256': parent.sha(MODEL), 'capture_sha256': parent.sha(CAPTURES/f'layer{layer:02d}.npz'),
               'factor_sha256': parent.sha(factor), 'cache_fit_sha256': parent.sha(meta_path),
               'parent_receipt_sha256': parent.sha(parent_path),
               'exchange_source_sha256': parent.sha(prior.HERE), 'source_sha256': parent.sha(HERE),
               'scope': 'One frozen original-producer head per layer; four causal positions per train/inspected validation window. Every query selects its own phase by minimizing FP64 frozen post-O error against floating target. Evaluated against 4095-count response. No train-fitted policy, full-layer budget, native timing or model loss.'}
    dest = DATA/'value-adaptive-phase'/f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(dest, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
