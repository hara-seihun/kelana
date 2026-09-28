#!/usr/bin/env python3
"""Exact discrete rank allocation for the continuous shared GQA response surrogate."""
import argparse
import hashlib
import json
from pathlib import Path

import torch
from safetensors import safe_open
from fit import MODEL, CAPTURES, load_capture

OUT = Path('/path/to/workspace/data/kelana-subbit/value-observer')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def allocate(curves, budget):
    # The eight groups have independent response targets and the same rank cost.
    states = {0: (0., ())}
    for curve in curves:
        next_states = {}
        for used, (loss, ranks) in states.items():
            for rank, error in curve.items():
                total = used + rank
                if total > budget:
                    continue
                candidate = (loss + error, ranks + (rank,))
                if total not in next_states or candidate < next_states[total]:
                    next_states[total] = candidate
        states = next_states
    return states[budget]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--threads', type=int, default=8)
    args = parser.parse_args()
    torch.set_num_threads(args.threads)
    ranks = range(4, 65, 4)
    with safe_open(MODEL, framework='pt', device='cpu') as source:
        v = source.get_tensor(f'model.layers.{args.layer}.self_attn.v_proj.weight').float()
        o = source.get_tensor(f'model.layers.{args.layer}.self_attn.o_proj.weight').float()
    x_train = load_capture(args.layer, 'train')
    x_val = load_capture(args.layer, 'validation')
    train_curves, val_curves, energies = [], [], []
    for group in range(8):
        vg = v[group*128:(group+1)*128]
        a = torch.cat([o[:, h*128:(h+1)*128] for h in (2*group, 2*group+1)], dim=0)
        train_values = x_train @ vg.T
        val_values = x_val @ vg.T
        # QR avoids squaring the condition number of the train response.
        _, r = torch.linalg.qr(train_values, mode='reduced')
        gram = a.T @ a
        spectrum, u = torch.linalg.eigh(r @ gram @ r.T)
        spectrum = spectrum.flip(0).clamp_min(0)
        u = u.flip(1)
        c_val = val_values.T @ val_values
        train_energy = spectrum.sum().item()
        val_energy = torch.sum(c_val * gram).item()
        train_curves.append({k: spectrum[k:].sum().item() for k in ranks})
        validation = {}
        for k in ranks:
            p = torch.linalg.solve_triangular(r, u[:, :k], upper=True) @ (u[:, :k].T @ r)
            residual = torch.eye(128) - p
            error = torch.trace(c_val @ residual @ gram @ residual.T).item()
            validation[k] = max(error, 0.)
        val_curves.append(validation)
        energies.append({'train': train_energy, 'validation': val_energy})
    _, selected = allocate(train_curves, 224)
    uniform = [28]*8
    def summary(choice):
        return {'ranks': choice, 'train_relative_group_response_error':
                sum(train_curves[i][k] for i,k in enumerate(choice))/sum(e['train'] for e in energies),
                'validation_relative_group_response_error':
                sum(val_curves[i][k] for i,k in enumerate(choice))/sum(e['validation'] for e in energies),
                'paid_two_bit_payload_bytes': sum(784*k+4128 for k in choice),
                'signed_grid_terms_per_token': sum(3072*k for k in choice),
                'BF16_value_bytes_per_token': sum(2*k for k in choice)}
    result = {'layer': args.layer, 'source_sha256': digest(Path(__file__)),
              'model_sha256': digest(MODEL),
              'capture_sha256': digest(CAPTURES / f'layer{args.layer:02d}.npz'),
              'train_vectors': len(x_train), 'validation_vectors': len(x_val),
              'rank_grammar': 'each group rank in 4,8,...,64; sum=224; two-bit left and right with existing group-128 scales',
              'group_energies': energies,
              'train_curves': train_curves, 'validation_curves': val_curves,
              'uniform': summary(uniform), 'train_optimal': summary(selected)}
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f'layer{args.layer:02d}-rank-allocation.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'uniform': result['uniform'], 'train_optimal': result['train_optimal']}))


if __name__ == '__main__':
    main()
