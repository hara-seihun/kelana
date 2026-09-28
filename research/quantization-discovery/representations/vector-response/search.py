#!/usr/bin/env python3
"""Discrete pair-index search against complete nonlinear MLP response."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time

import numpy as np

FULL = Path(__file__).resolve().parent.parent / 'vector-full'
sys.path.insert(0, str(FULL))
from codec import load_image, pack_codes, sha256
from quality import DATA, inputs, packed_projection, response, source_weights

OUT = DATA / 'vector-response'


def silu(g):
    s = 1 / (1 + np.exp(-np.clip(g, -80, 80)))
    return g * s


def rms(prediction, target):
    return float(np.linalg.norm((prediction - target).astype(np.float64)) / np.linalg.norm(target.astype(np.float64)))


def fit(codes, table, down, x, target, check_x, check_target, sweeps, columns):
    table = table.astype(np.float32)
    initial = codes.copy()
    pair = table[codes]
    g, u = x @ pair[:, :, 0].T, x @ pair[:, :, 1].T
    hidden = silu(g) * u
    residual = hidden @ down.T - target
    norm = float(np.sum(target.astype(np.float64) ** 2))
    down_norm = np.sum(down * down, axis=0)
    x_energy = np.maximum(np.sum(x * x, axis=0), 1e-12)

    def check():
        pair = table[codes]
        return rms(response(check_x, pair[:, :, 0], pair[:, :, 1], down), check_target)

    best_check = check()
    best_codes = codes.copy()
    history = [dict(sweep=0, train_relative_rms=float(np.sqrt(np.sum(residual.astype(np.float64) ** 2) / norm)),
                    check_relative_rms=best_check, accepted=0, chosen=True)]
    for sweep in range(sweeps):
        accepted = 0
        start = time.monotonic()
        for h in range(len(codes)):
            gh, uh = g[:, h], u[:, h]
            sh = 1 / (1 + np.exp(-np.clip(gh, -80, 80)))
            projected = residual @ down[:, h]
            dg = 2 * projected * uh * (sh + gh * sh * (1 - sh))
            du = 2 * projected * gh * sh
            gradient_g, gradient_u = dg @ x, du @ x
            priority = (gradient_g ** 2 + gradient_u ** 2) / x_energy
            nominees = np.argsort(priority, kind='stable')[-columns:][::-1]
            best_delta = 0.
            proposal = None
            for col in nominees:
                current = table[codes[h, col]]
                gs = gh[:, None] + x[:, col, None] * (table[None, :, 0] - current[0])
                us = uh[:, None] + x[:, col, None] * (table[None, :, 1] - current[1])
                delta = silu(gs) * us - hidden[:, h, None]
                objective = 2 * np.sum(projected[:, None] * delta, axis=0, dtype=np.float64)
                objective += float(down_norm[h]) * np.sum(delta * delta, axis=0, dtype=np.float64)
                index = int(np.argmin(objective))
                if objective[index] < best_delta - 1e-9:
                    best_delta = float(objective[index])
                    proposal = (int(col), index, gs[:, index].copy(), us[:, index].copy(), delta[:, index].copy())
            if proposal is not None:
                col, index, new_g, new_u, delta = proposal
                codes[h, col] = index
                g[:, h], u[:, h] = new_g, new_u
                hidden[:, h] += delta
                residual += delta[:, None] * down[:, h][None, :]
                accepted += 1
        # Recompute from the actual image, not the incremental cache, at selection boundaries.
        pair = table[codes]
        g, u = x @ pair[:, :, 0].T, x @ pair[:, :, 1].T
        hidden = silu(g) * u
        residual = hidden @ down.T - target
        check_score = check()
        chosen = check_score < best_check
        if chosen:
            best_check, best_codes = check_score, codes.copy()
        row = dict(sweep=sweep + 1, train_relative_rms=float(np.sqrt(np.sum(residual.astype(np.float64) ** 2) / norm)),
                   check_relative_rms=check_score, accepted=accepted, chosen=chosen, seconds=time.monotonic() - start)
        history.append(row)
        print(json.dumps(row), flush=True)
    return best_codes, history, int(np.count_nonzero(best_codes != initial))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layer', type=int, default=0)
    parser.add_argument('--width', type=int, choices=[3, 4, 6, 8], default=8)
    parser.add_argument('--sweeps', type=int, default=2)
    parser.add_argument('--columns', type=int, default=4)
    parser.add_argument('--name', required=True)
    parser.add_argument('--train-per-window', type=int, default=16)
    parser.add_argument('--check-per-window', type=int, default=16)
    args = parser.parse_args()
    if (not 0 <= args.layer < 28 or args.sweeps < 1 or not 1 <= args.columns <= 1024
            or min(args.train_per_window, args.check_per_window) < 1
            or args.train_per_window + args.check_per_window > 256):
        parser.error('invalid search dimensions')
    import torch
    torch.set_num_threads(2)
    start = time.monotonic()
    OUT.mkdir(parents=True, exist_ok=True)
    destination = OUT / (args.name + '.npz')
    if destination.exists() or destination.with_suffix('.json').exists():
        raise FileExistsError(destination)
    source = DATA / f'vector-full/images/layer{args.layer:02}-learned_pair-{args.width}bit.npz'
    source_receipt = json.loads(source.with_suffix('.json').read_text())
    if sha256(source) != source_receipt['image_sha256']:
        raise ValueError('source image changed')
    codes, table = load_image(source)
    original, teacher_down = source_weights(args.layer)
    down, down_path = packed_projection(args.layer, 'down')
    per_window = args.train_per_window + args.check_per_window
    all_x, capture, positions = inputs(args.layer, 'train', positions_per_window=per_window)
    indices = np.arange(4 * per_window).reshape(4, per_window)
    train_ids = indices[:, :args.train_per_window].ravel()
    check_ids = indices[:, args.train_per_window:].ravel()
    x, check_x = all_x[train_ids], all_x[check_ids]
    teacher = response(all_x, original[:, :, 0], original[:, :, 1], teacher_down)
    target, check_target = teacher[train_ids], teacher[check_ids]
    new_codes, history, changed = fit(codes.copy(), table, down, x, target, check_x, check_target, args.sweeps, args.columns)
    with np.load(source) as image:
        arrays = {k: image[k].copy() for k in image.files}
    arrays['codes' if args.width == 8 else 'packed'] = new_codes if args.width == 8 else pack_codes(new_codes, args.width)
    with destination.open('xb') as file:
        np.savez(file, **arrays)
    receipt = dict(source_receipt, file=str(destination), image_sha256=sha256(destination),
                   method='response-discrete-learned-pair', source_image=str(source),
                   source_image_sha256=sha256(source), source_receipt_sha256=sha256(source.with_suffix('.json')),
                   capture_sha256=sha256(capture), script_sha256=sha256(Path(__file__)),
                   train_positions=positions[train_ids].tolist(), check_positions=positions[check_ids].tolist(),
                   down_sha256=sha256(down_path), selection='lowest separate TRAIN-check complete-response RMS; includes unchanged source',
                   sweeps=args.sweeps, nominated_columns=args.columns, changed_codes=changed,
                   history=history, npz_container_bytes=destination.stat().st_size)
    # Held inputs are first read after the actual export and train-only selection.
    held, held_capture, held_positions = inputs(args.layer, 'validation')
    held_target = response(held, original[:, :, 0], original[:, :, 1], teacher_down)
    for name, indices in [('source', codes), ('selected', new_codes)]:
        weights = table.astype(np.float32)[indices]
        receipt[name + '_held_relative_rms'] = rms(response(held, weights[:, :, 0], weights[:, :, 1], down), held_target)
    receipt.update(held_capture_sha256=sha256(held_capture), held_positions=held_positions.tolist(), seconds=time.monotonic() - start)
    for field in ['mean_pair_weight_sse']:
        receipt.pop(field, None)
    receipt['physical_bytes'] = sum(v.nbytes for v in arrays.values())
    if receipt['physical_bytes'] != source_receipt['physical_bytes']:
        raise ValueError('paid image bytes changed')
    destination.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt), flush=True)


if __name__ == '__main__':
    main()
