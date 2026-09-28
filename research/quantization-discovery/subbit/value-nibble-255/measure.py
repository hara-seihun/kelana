#!/usr/bin/env python3
"""Two packed-nibble probability digits against the frozen narrow value cache."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('mass_allocation', SUBBIT / 'value-mass-allocation/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
DATA, MODEL, CAPTURES = parent.DATA, parent.MODEL, parent.CAPTURES
sha, counts, probabilities, load_capture = parent.sha, parent.counts, parent.probabilities, parent.load_capture


def run_split(layer, split, image, metadata, weights, decoder):
    x = load_capture(layer, split).reshape(-1, 256, 1024)[:8 if split == 'train' else 4]
    p = probabilities(x, weights['q_proj'], weights['k_proj'], weights['q_norm'], weights['k_norm'])
    reference, candidate = counts(p, 4095), counts(p, 255)
    assert torch.equal((candidate & 15) + 16*(candidate >> 4), candidate)
    assert candidate.max() <= 255
    outputs = [[], []]
    with np.load(image) as factors:
        for group in range(8):
            arrays = {key: factors[key][group].copy() for key in factors.files}
            left = decoder.decode(arrays, 'left')
            right = decoder.decode(arrays, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            step = torch.tensor(metadata['metadata'][group]['int4_coordinate']['step'])
            codes = (z / step).round().clamp(-7, 7).float()
            for local in range(2):
                head = 2*group + local
                matrix = left[local*1024:(local+1)*1024]
                for idx, (n, mass) in enumerate(((reference, 4095), (candidate, 255))):
                    outputs[idx].append(((n[:, head].float() @ codes) * (step/mass)) @ matrix.T)
            print(layer, split, group, flush=True)
    return torch.stack(outputs[0]), torch.stack(outputs[1]), reference, candidate


def slot_panel(n):
    length = n.shape[-1]
    causal = torch.ones(length, length, dtype=torch.bool).tril()
    out = []
    for digit in (n & 15, n >> 4):
        count = ((digit != 0) & causal).sum(-1)
        out.append({'nonzero_pairs': int(count.sum()), 'max_keys_per_row': int(count.max()),
                    'four_lane_pairs': int(((count+3)//4*4).sum()),
                    'eight_lane_pairs': int(((count+7)//8*8).sum())})
    return {'digits': out, 'four_lane_dot8_slots': 4*sum(v['four_lane_pairs'] for v in out),
            'eight_lane_dot8_slots': 4*sum(v['eight_lane_pairs'] for v in out)}


def parent_4095_slots(n):
    length = n.shape[-1]
    causal = torch.ones(length, length, dtype=torch.bool).tril()
    return 4*sum(int(((((n >> shift) & 15) != 0) & causal).sum(-1).add(3).div(4, rounding_mode='floor').mul(4).sum())
                 for shift in (0, 4, 8))


def run(layer):
    torch.set_num_threads(8)
    image = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    prior = DATA / 'value-centered-int4' / f'layer{layer:02d}-8x4.json'
    metadata = json.loads(prior.read_text())
    assert sha(image) == metadata['image_sha256']
    spec = importlib.util.spec_from_file_location('decoder', parent.SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        weights = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
                   for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    train_ref, train_alt, train_n, _ = run_split(layer, 'train', image, metadata, weights, decoder)
    base = train_ref.sum(0)
    delta = (train_alt - train_ref).reshape(16, -1).double()
    gram = (delta @ delta.T).numpy()
    best = parent.select(gram, float(base.square().sum()))
    del train_ref, train_alt, train_n, delta
    held_ref, held_alt, held_reference, held_n = run_split(layer, 'validation', image, metadata, weights, decoder)
    size = max(i for i, (err, _) in enumerate(best) if err <= 1e-4)
    def score(mask):
        alt = torch.stack([held_alt[i] if mask & (1 << i) else held_ref[i] for i in range(16)]).sum(0)
        ref = held_ref.sum(0)
        return {'relative_rounding_error': float((alt-ref).square().sum()/ref.square().sum()),
                'per_window_rounding_error': [float((alt[i]-ref[i]).square().sum()/ref[i].square().sum()) for i in range(ref.shape[0])]}
    mask = best[size][1]
    short_heads = [i for i in range(16) if mask & (1 << i)]
    long_heads = [i for i in range(16) if not mask & (1 << i)]
    short_slots = slot_panel(held_n[:, short_heads])['four_lane_dot8_slots'] if short_heads else 0
    long_slots = parent_4095_slots(held_reference[:, long_heads]) if long_heads else 0
    receipt = {'layer': layer, 'masses': [255, 4095],
               'selected_four_lane_dot8_slots': short_slots + long_slots,
               'selected_slot_components': {'255': short_slots, '4095': long_slots},
               'all_255': score(65535), 'train_selected': {'heads': size, 'mask': f'{best[size][1]:04x}',
                   'train_rounding_error': best[size][0], 'held': score(best[size][1])},
               'held_255_digit_slots': slot_panel(held_n),
               'held_4095_dot8_slots': parent_4095_slots(held_reference),
               'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES/f'layer{layer:02d}.npz'),
               'factor_sha256': sha(image), 'cache_fit_sha256': sha(prior),
               'source_sha256': sha(HERE), 'domain': 'frozen original-producer Q/K and signed-nibble rank-28 V/O, eight 256-token train and four repeatedly inspected validation windows; floating O replay after integer-count attention'}
    dest = DATA / 'value-nibble-255'/f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'receipt': str(dest), 'all': receipt['all_255'], 'selected': receipt['train_selected'], 'slots': receipt['held_255_digit_slots']}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
