#!/usr/bin/env python3
"""Exhaustive causal allocation of 192 frozen, paid narrow-value coordinates."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention

OUT = Path('/path/to/workspace/data/kelana-subbit/value-observer')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def candidates():
    # Each group discards 0..6 four-coordinate blocks; 8 blocks in total.
    for cut in itertools.product(range(7), repeat=8):
        if sum(cut) == 8:
            yield cut


def pack_image(src, ranks, path, q):
    payload = 0
    image = {}
    for g, rank in enumerate(ranks):
        group = {key: val[g].copy() for key, val in src.items()}
        left = q.decode(group, 'left')
        right = q.decode(group, 'right')
        # Repack codes rather than requantizing any retained coordinate. The
        # left row scales have one group of 128, so discarding columns is exact.
        left_bits = np.unpackbits(group['left_codes'], axis=1, bitorder='little')[:, :56]
        left_bits = left_bits.reshape(2048, 28, 2)[:, :rank].reshape(2048, 2*rank)
        group['left_codes'] = np.packbits(left_bits, axis=1, bitorder='little')
        group['right_codes'] = group['right_codes'][:rank]
        group['right_scales'] = group['right_scales'][:rank]
        group['left_shape'][1] = rank
        group['right_shape'][0] = rank
        assert torch.equal(q.decode(group, 'left'), left[:, :rank])
        assert torch.equal(q.decode(group, 'right'), right[:rank])
        payload += sum(x.nbytes for x in group.values())
        for key, val in group.items():
            image[f'group{g}_{key}'] = val
    np.savez(path, **image)
    return payload


def moments(x, prob, teacher, factors):
    contributions = []
    for g, (left, right) in enumerate(factors):
        z = (x @ right.T).to(torch.bfloat16).float()
        for b in range(7):
            group = torch.zeros_like(teacher)
            for local in range(2):
                head = 2*g+local
                piece = prob[:, head] @ z[:, :, 4*b:4*b+4]
                group += piece @ left[local*1024:(local+1)*1024, 4*b:4*b+4].T
            contributions.append(group)
    c = torch.stack(contributions).reshape(56, -1)
    y = teacher.reshape(-1)
    full = c.sum(0)
    residual = full-y
    # The quadratic describes omission from the full 28-coordinate map.
    gram = (c @ c.T).double().numpy()
    linear = (c @ residual).double().numpy()
    return gram, linear, float(residual.double().square().sum()), float(y.double().square().sum()), c, y


def removed_indices(cut):
    return [g*7+b for g, k in enumerate(cut) for b in range(7-k, 7)]


def score(cut, moment):
    gram, linear, baseline, energy = moment[:4]
    idx = removed_indices(cut)
    return (baseline - 2*linear[idx].sum() + gram[np.ix_(idx, idx)].sum()) / energy


def separate_score(cut, moment):
    gram, linear = moment[:2]
    total = 0.
    for group, dropped in enumerate(cut):
        idx = [group*7+b for b in range(7-dropped, 7)]
        total += -2*linear[idx].sum() + gram[np.ix_(idx, idx)].sum()
    return total


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--layer', type=int, choices=(0, 14), required=True)
    p.add_argument('--threads', type=int, default=8)
    args = p.parse_args()
    torch.set_num_threads(args.threads)
    import importlib.util
    spec = importlib.util.spec_from_file_location('spectral_quant_pinned', SOURCE)
    q = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(q)
    source_image = OUT / f'layer{args.layer:02d}-joint-r28.npz'
    with np.load(source_image) as data:
        src = {key: data[key].copy() for key in data.files}
    factors = []
    for g in range(8):
        group = {key: val[g] for key, val in src.items()}
        factors.append((q.decode(group, 'left'), q.decode(group, 'right')))
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {n: model.get_tensor(f'model.layers.{args.layer}.self_attn.{n}.weight').float()
             for n in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    moments_by_split = {}
    for split, count in (('train', 8), ('validation', 4)):
        x = load_capture(args.layer, split).reshape(count, 256, 1024)
        prob = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        teacher = dense_attention(prob, x, w['v_proj'], w['o_proj'])
        moments_by_split[split] = moments(x, prob, teacher, factors)
    choices = list(candidates())
    best = min(choices, key=lambda cut: (score(cut, moments_by_split['train']), cut))
    independent = min(choices, key=lambda cut: (separate_score(cut, moments_by_split['train']), cut))
    held_oracle = min(choices, key=lambda cut: (score(cut, moments_by_split['validation']), cut))
    controls = {'uniform_24': (1,)*8, 'train_separable': independent,
                'train_causal_optimum': best, 'full_28': (0,)*8}
    scored = {}
    for name, cut in controls.items():
        per_split = {}
        for split, moment in moments_by_split.items():
            predicted = score(cut, moment)
            c, y = moment[4:]
            missing = c[removed_indices(cut)].sum(0) if sum(cut) else torch.zeros_like(y)
            actual = ((c.sum(0)-missing-y).square().sum()/y.square().sum()).item()
            per_split[split] = {'quadratic': predicted, 'direct_float32': actual}
        ranks = [28-4*k for k in cut]
        image_path = OUT / f'layer{args.layer:02d}-causal-{name}.npz'
        size = pack_image(src, ranks, image_path, q)
        scored[name] = {'ranks': ranks, 'payload_bytes': size, 'signed_grid_terms_per_token': 3072*sum(ranks),
                        'logical_BF16_value_bytes_per_token': 2*sum(ranks),
                        'image': str(image_path), 'image_sha256': sha(image_path), 'splits': per_split}
    result = {'layer': args.layer, 'source_sha256': sha(Path(__file__)), 'model_sha256': sha(MODEL),
              'capture_sha256': sha(CAPTURES / f'layer{args.layer:02d}.npz'),
              'source_image_sha256': sha(source_image), 'train_choices_exhausted': len(choices),
              'grammar': 'frozen refined rank-28 code/scale coordinate prefixes; each rank 4..28 in steps of four; total 192; original Q/K causal probabilities',
              'selection': 'minimum train post-O squared error including every cross-group term; validation never selects',
              'held_only_oracle_ranks_not_selected': [28-4*k for k in held_oracle],
              'held_only_oracle_error': score(held_oracle, moments_by_split['validation']),
              'arms': scored}
    receipt = OUT / f'layer{args.layer:02d}-causal-prune.json'
    receipt.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'receipt': str(receipt), 'choices': len(choices),
                      'arms': {name: {'ranks': arm['ranks'], 'bytes': arm['payload_bytes'],
                                      'train': arm['splits']['train']['direct_float32'],
                                      'validation': arm['splits']['validation']['direct_float32']}
                               for name, arm in scored.items()}}), flush=True)


if __name__ == '__main__':
    main()
