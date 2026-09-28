#!/usr/bin/env python3
"""Train-only exchange search for non-prefix frozen V/O coordinate blocks."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from causal_prune import OUT, sha, moments, removed_indices, candidates, score
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention


def objective(removed, moment):
    gram, linear, base, energy = moment[:4]
    idx = np.flatnonzero(removed)
    return (base - 2 * linear[idx].sum() + gram[np.ix_(idx, idx)].sum()) / energy


def search(moment, starts, seed):
    gram, linear, base, energy = moment[:4]
    # The symmetric part is what enters a quadratic even if BLAS rounding
    # makes the two halves slightly unequal.
    gram = (gram + gram.T) * .5
    rng = np.random.default_rng(seed)
    best = None
    traces = []
    for start in range(starts):
        selected = np.zeros(56, dtype=bool)
        if start == 0:
            cut = min(candidates(), key=lambda c: (score(c, moment), c))
            selected[removed_indices(cut)] = True
        else:
            for _ in range(8):
                legal = [i for i in range(56) if not selected[i] and selected.reshape(8, 7)[i//7].sum() < 6]
                selected[rng.choice(legal)] = True
        initial = objective(selected, moment)
        exchanges = 0
        while True:
            idx = np.flatnonzero(selected)
            gradients = -2 * linear + 2 * gram[:, idx].sum(axis=1)
            choice = None
            delta_min = -1e-11 * energy
            for i in idx:
                for j in np.flatnonzero(~selected):
                    if i // 7 != j // 7 and selected.reshape(8, 7)[j//7].sum() >= 6:
                        continue
                    delta = -gradients[i] + gradients[j] + gram[i, i] + gram[j, j] - 2 * gram[i, j]
                    if delta < delta_min:
                        delta_min = delta
                        choice = (int(i), int(j))
            if choice is None:
                break
            selected[choice[0]] = False
            selected[choice[1]] = True
            exchanges += 1
        final = objective(selected, moment)
        traces.append({'initial': initial, 'final': final, 'exchanges': exchanges})
        key = (final, tuple(np.flatnonzero(selected)))
        if best is None or key < best[0]:
            best = (key, selected.copy())
    return best[1], traces


def pack(src, retained, path, q):
    image = {}
    payload = 0
    for g in range(8):
        group = {key: value[g].copy() for key, value in src.items()}
        indices = np.flatnonzero(retained[g*7:(g+1)*7]).repeat(4)*4 + np.tile(np.arange(4), int(retained[g*7:(g+1)*7].sum()))
        left = q.decode(group, 'left')[:, indices]
        right = q.decode(group, 'right')[indices]
        bits = np.unpackbits(group['left_codes'], axis=1, bitorder='little').reshape(2048, 28, 2)
        group['left_codes'] = np.packbits(bits[:, indices].reshape(2048, -1), axis=1, bitorder='little')
        group['right_codes'] = group['right_codes'][indices]
        group['right_scales'] = group['right_scales'][indices]
        group['left_shape'][1] = len(indices)
        group['right_shape'][0] = len(indices)
        assert torch.equal(q.decode(group, 'left'), left)
        assert torch.equal(q.decode(group, 'right'), right)
        payload += sum(a.nbytes for a in group.values())
        image.update({f'group{g}_{key}': value for key, value in group.items()})
    # This is a per-group seven-bit original-coordinate map. A consumer needs
    # it only when composing an existing basis; a standalone packed image can
    # treat the retained columns as its own coordinate system.
    image['original_block_mask'] = np.packbits(retained.reshape(8, 7), axis=1, bitorder='little').reshape(8)
    payload += image['original_block_mask'].nbytes
    np.savez(path, **image)
    return payload


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--starts', type=int, default=12)
    args = parser.parse_args()
    torch.set_num_threads(8)
    import importlib.util
    spec = importlib.util.spec_from_file_location('spectral_quant_pinned', SOURCE)
    q = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(q)
    source_image = OUT / f'layer{args.layer:02d}-joint-r28.npz'
    with np.load(source_image) as data:
        src = {key: data[key].copy() for key in data.files}
    factors = [(q.decode({key: val[g] for key, val in src.items()}, 'left'),
                q.decode({key: val[g] for key, val in src.items()}, 'right')) for g in range(8)]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {n: model.get_tensor(f'model.layers.{args.layer}.self_attn.{n}.weight').float()
             for n in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    moments_by_split = {}
    for split, count in (('train', 8), ('validation', 4)):
        x = load_capture(args.layer, split).reshape(count, 256, 1024)
        prob = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        teacher = dense_attention(prob, x, w['v_proj'], w['o_proj'])
        moments_by_split[split] = moments(x, prob, teacher, factors)
    prefix = np.zeros(56, dtype=bool)
    prefix[removed_indices(min(candidates(), key=lambda c: (score(c, moments_by_split['train']), c)))] = True
    chosen, traces = search(moments_by_split['train'], args.starts, 9217 + args.layer)
    scores = {}
    for name, removed in (('prefix', prefix), ('free', chosen)):
        per_split = {}
        for split, moment in moments_by_split.items():
            c, y = moment[4:]
            direct = ((c.sum(0) - c[removed].sum(0) - y).square().sum() / y.square().sum()).item()
            per_split[split] = {'quadratic': objective(removed, moment), 'direct_float32': direct}
        scores[name] = {'omitted_blocks': np.flatnonzero(removed).tolist(), 'ranks': (4 * (~removed).reshape(8, 7).sum(1)).tolist(), 'splits': per_split}
    image_path = OUT / f'layer{args.layer:02d}-free-mask.npz'
    payload = pack(src, ~chosen, image_path, q)
    result = {'layer': args.layer, 'source_sha256': sha(Path(__file__)), 'model_sha256': sha(MODEL),
              'capture_sha256': sha(CAPTURES / f'layer{args.layer:02d}.npz'), 'source_image_sha256': sha(source_image),
              'search': 'deterministic best-improving one-block exchanges from exact prefix optimum and random feasible starts; each group retains >=1 block',
              'starts': args.starts, 'seed': 9217 + args.layer, 'traces': traces, 'arms': scores,
              'payload_bytes': payload, 'image': str(image_path), 'image_sha256': sha(image_path)}
    path = OUT / f'layer{args.layer:02d}-free-mask.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'payload_bytes': payload, 'arms': scores}), flush=True)


if __name__ == '__main__':
    main()
