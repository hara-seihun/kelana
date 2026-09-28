#!/usr/bin/env python3
"""Value-aware conserved 15-count attention on sampled frozen Qwen V/O rows."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('parent_mass', SUBBIT/'value-mass-allocation/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
DATA, MODEL, CAPTURES = parent.DATA, parent.MODEL, parent.CAPTURES


def choose_codes(codes, matrix, reference, prefix, sweeps=3):
    """One-for-one response exchanges from the prefix map toward the float response."""
    m = 15
    n = len(codes)
    desired = reference @ matrix @ codes.T
    norm = np.einsum('ij,jk,ik->i', codes, matrix, codes)
    tally = prefix.astype(np.int32).copy()
    response = tally @ codes / m
    for _ in range(sweeps):
        changed = False
        for old in np.repeat(np.flatnonzero(tally), tally[tally > 0]):
            response -= codes[old]/m
            tally[old] -= 1
            gain = 2*(desired - response @ matrix @ codes.T) / m - norm/m**2
            new = int(np.argmax(gain))
            tally[new] += 1
            response += codes[new]/m
            changed |= new != old
        if not changed:
            break
    assert tally.sum() == m and tally.min() >= 0
    return tally, response


def run(layer):
    torch.set_num_threads(8)
    factor = DATA/'value-observer'/f'layer{layer:02d}-joint-r28.npz'
    meta_path = DATA/'value-centered-int4'/f'layer{layer:02d}-8x4.json'
    parent_path = DATA/'value-nibble-255'/f'layer{layer:02d}.json'
    meta = json.loads(meta_path.read_text())
    ancestor = json.loads(parent_path.read_text())
    assert meta['image_sha256'] == parent.sha(factor)
    assert ancestor['factor_sha256'] == parent.sha(factor)
    mask = int(ancestor['train_selected']['mask'], 16)
    # The first head that almost qualified for 15 units under prefix rounding.
    head = {0: 7, 14: 12}[layer]
    assert mask & (1 << head)
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
    metric = (step[:, None]*left.T) @ (left*step[None, :])
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
        result = {'prefix_error': 0., 'value_aware_error': 0., 'sampling_bound': 0., 'energy': 0., 'per_row': [],
                  'selected_nonzero': 0, 'selected_max_nonzero': 0}
        for j in range(windows*4):
            w, pos = divmod(j, 4)
            pos = (63, 127, 191, 255)[pos]
            c = codes[w, :pos+1].astype(np.float64)
            n4095 = ref_n[j, :pos+1]
            n15 = prefix_n[j, :pos+1]
            r = n4095 @ c / 4095.
            p_row = prob[j, :pos+1].double().numpy()
            target = p_row @ c
            variance = float(np.einsum('i,ij,jk,ik->', p_row, c-target, metric, c-target))
            bound = variance/15
            choice, v = choose_codes(c, metric, target, n15)
            a = (n15 @ c)/15. - r
            b = v - r
            prefix = float(a @ metric @ a)
            aware = float(b @ metric @ b)
            energy = float(r @ metric @ r)
            result['prefix_error'] += prefix
            result['value_aware_error'] += aware
            result['energy'] += energy
            result['sampling_bound'] += bound
            support = int(np.count_nonzero(choice))
            result['selected_nonzero'] += support
            result['selected_max_nonzero'] = max(result['selected_max_nonzero'], support)
            result['per_row'].append({'window': w, 'position': pos, 'prefix_sq': prefix,
                                      'value_aware_sq': aware, 'sampling_bound': bound,
                                      'energy': energy, 'support': support})
        result['relative_prefix'] = result['prefix_error']/result['energy']
        result['relative_value_aware'] = result['value_aware_error']/result['energy']
        result['relative_sampling_bound'] = result['sampling_bound']/result['energy']
        records[split] = result
        print(layer, split, result['relative_prefix'], result['relative_value_aware'], flush=True)
    receipt = {'layer': layer, 'head': head, 'mass': 15, 'records': records,
               'model_sha256': parent.sha(MODEL), 'capture_sha256': parent.sha(CAPTURES/f'layer{layer:02d}.npz'),
               'factor_sha256': parent.sha(factor), 'cache_fit_sha256': parent.sha(meta_path),
               'parent_receipt_sha256': parent.sha(parent_path), 'source_sha256': parent.sha(HERE),
               'scope': 'One frozen original-producer Qwen head per layer; eight train and four previously inspected validation windows; four fixed causal positions per window; FP64 metric of frozen FP32 paid output matrix; optimizer targets floating softmax response, error reports against 4095-count signed-nibble response. Not a full-layer post-O result.'}
    dest = DATA/'value-mass-discrepancy'/f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(dest, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
