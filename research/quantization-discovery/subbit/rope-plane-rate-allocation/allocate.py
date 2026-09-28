#!/usr/bin/env python3
"""Allocate a fixed RoPE-plane budget across eight real Qwen GQA groups."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from safetensors import safe_open
import torch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'rope-plane-consumer'))
sys.path.insert(0, str(HERE.parent / 'rope-key-orbit'))
from planes import score_gram
from orbit import orbit_covariance


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def error(gram, mask):
    return float(mask @ gram @ mask)


def exchange(gram, mask):
    """Best strict one-for-one exchanges until stable; cache the 64-vector Mx."""
    mask = mask.copy()
    while True:
        product = gram @ mask
        removed = np.flatnonzero(mask)
        added = np.flatnonzero(1 - mask)
        if not len(removed) or not len(added):
            return mask
        delta = (-2 * product[removed, None] + np.diag(gram)[removed, None]
                 + 2 * product[None, added] + np.diag(gram)[None, added]
                 - 2 * gram[np.ix_(removed, added)])
        i, j = np.unravel_index(np.argmin(delta), delta.shape)
        if delta[i, j] >= -1e-12:
            return mask
        mask[removed[i]], mask[added[j]] = 0, 1


def curves(gram, low=4, high=28):
    """Build all counts from the full mask by cheapest deletion, then exchange."""
    mask = np.zeros(64, dtype=np.int8)
    entries = {}
    for count in range(64, low - 1, -1):
        if count <= high:
            mask = exchange(gram, mask)
            entries[count] = dict(error=error(gram, mask), planes=np.flatnonzero(1-mask).tolist())
        if count > low:
            selected = np.flatnonzero(1-mask)
            product = gram @ mask
            # Omitted mask gains one element when a selected plane is deleted.
            delta = 2 * product[selected] + np.diag(gram)[selected]
            mask[selected[np.argmin(delta)]] = 1
    return entries


def allocate(group_curves, total=112, low=4, high=28):
    """Exact group-budget DP conditional on supplied per-group masks."""
    states = {0: (0., ())}
    for group in group_curves:
        next_states = {}
        for used, (loss, choices) in states.items():
            for count in range(low, high+1):
                n = used + count
                candidate = (loss + group[count]['error'], choices + (count,))
                if n <= total and (n not in next_states or candidate[0] < next_states[n][0]):
                    next_states[n] = candidate
        states = next_states
    value, counts = states[total]
    return dict(error=value, counts=list(counts), masks=[group[c]['planes'] for group, c in zip(group_curves, counts)])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    model = args.model / 'model.safetensors'
    config = args.model / 'config.json'
    cfg = json.loads(config.read_text())
    assert (cfg['hidden_size'], cfg['head_dim'], cfg['num_attention_heads'], cfg['num_key_value_heads']) == (1024,128,16,8)
    result = dict(model_sha256=sha(model), config_sha256=sha(config), source_sha256=sha(Path(__file__)),
                  plane_source_sha256=sha(HERE.parent/'rope-plane-consumer'/'planes.py'),
                  orbit_source_sha256=sha(HERE.parent/'rope-key-orbit'/'orbit.py'),
                  horizon=4096, budget=112, minimum=4, maximum=28, layers={})
    with safe_open(model, framework='pt', device='cpu') as file:
        for layer in (0, 14):
            stem = f'model.layers.{layer}.self_attn.'
            kw = file.get_tensor(stem+'k_proj.weight').to(dtype=torch.float64).numpy()
            qw = file.get_tensor(stem+'q_proj.weight').to(dtype=torch.float64).numpy()
            weighted, isotropic = [], []
            full = []
            for g in range(8):
                key = kw[128*g:128*(g+1)]
                query = np.concatenate((qw[256*g:256*g+128], qw[256*g+128:256*(g+1)]), axis=1)/np.sqrt(2)
                gram = score_gram(query, orbit_covariance(key, cfg['rope_theta'], 4096))
                energy = (key**2).sum(axis=1)
                diag = energy[:64] + energy[64:]
                weighted.append(curves(gram))
                # Diagonal score Gram: exact per-group optimum at every count.
                indices = np.argsort(-diag, kind='stable')
                isotropic.append({c: dict(error=float(diag[indices[c:]].sum()),
                                           planes=sorted(indices[:c].tolist())) for c in range(4,29)})
                full.append(float(gram.sum()))
            cases = {}
            for name, group in [('weighted', weighted), ('isotropic', isotropic)]:
                denominator = sum(full) if name == 'weighted' else float(sum((kw[128*g:128*(g+1)]**2).sum() for g in range(8)))
                uniform = dict(error=sum(item[14]['error'] for item in group), counts=[14]*8,
                               masks=[item[14]['planes'] for item in group])
                choices = {'uniform': uniform, 'capped16': allocate(group, high=16),
                           'variable28': allocate(group)}
                for choice in choices.values():
                    choice['retained_fraction'] = 1-choice['error']/denominator
                    choice['key_bytes_logical'] = 4*sum(choice['counts'])
                    choice['key_bytes_64b_padded'] = 64*sum((c+15)//16 for c in choice['counts'])
                cases[name] = dict(denominator=denominator, choices=choices,
                                   per_group_curves=[{str(k):v for k,v in c.items()} for c in group])
            result['layers'][str(layer)] = cases
            for name, case in cases.items():
                print(layer, name, [(key, round(value['retained_fraction'],6), value['counts'],
                                    value['key_bytes_64b_padded']) for key,value in case['choices'].items()], flush=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')


if __name__ == '__main__':
    main()
