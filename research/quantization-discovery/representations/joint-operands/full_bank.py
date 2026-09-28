#!/usr/bin/env python3
"""Paid shared input coordinate across all layer-0 routed experts; CPU split/reduce experiment.

Run scan and evaluate in 32-expert foreground shards; combine only after all shards exist.
Intermediate arrays live outside Git under the Qwen MoE data owner.
"""
import argparse
import json
from pathlib import Path

import numpy as np

from study import BASE, DIM, ALPHAS, forward, quant, sha, weights
from shared_routes import capture

OUT = BASE / 'full-bank-coordinate'
SHARDS = range(0, 256, 32)
ARMS = ('gguf-q8', 'gguf-q4', 'q4w-q8x') + tuple(str(a) for a in ALPHAS)


def save_array(path, data):
    np.save(path, data)


def scan(first):
    maximum = np.zeros(DIM, np.float32)
    hashes = []
    for expert in range(first, first + 32):
        (gate, up, _), provenance = weights(expert)
        maximum = np.maximum(maximum, np.maximum(np.abs(gate).max(axis=0), np.abs(up).max(axis=0)))
        hashes.append(provenance)
    assert all(h == hashes[0] for h in hashes)
    save_array(OUT / f'max-{first:03}.npy', maximum)
    print(f'scanned {first}..{first+31}, max {maximum.max():.6g}')


def coordinate():
    train = capture('train')
    maxima = [np.load(OUT / f'max-{first:03}.npy') for first in SHARDS]
    wmax = np.maximum.reduce(maxima)
    xmax = np.maximum(np.max(np.abs(train['x']), axis=0), 1e-7)
    logratio = np.log2(np.maximum(wmax, 1e-7) / xmax)
    centered = logratio - np.median(logratio)
    exponents = np.stack([np.clip(np.rint(a * centered / 2), -3, 3).astype(np.int8) for a in ALPHAS])
    save_array(OUT / 'exponents.npy', exponents)
    print('nonzero coordinates', [int(np.count_nonzero(row)) for row in exponents])


def evaluate(first):
    exponents = np.load(OUT / 'exponents.npy')
    diagonals = {str(a): np.exp2(exponents[i].astype(np.float32)) for i, a in enumerate(ALPHAS)}
    x = {s: capture(s) for s in ('train', 'held')}
    coded = {s: {arm: quant(np.asarray(data['x']) * diagonals[arm], 4) for arm in diagonals}
             for s, data in x.items()}
    for s, data in x.items():
        coded[s]['gguf-q8'] = coded[s]['q4w-q8x'] = quant(np.asarray(data['x']), 8)
        coded[s]['gguf-q4'] = coded[s]['0.0']
    result = {s: {arm: np.zeros((len(data['x']), DIM), np.float64) for arm in ('reference',) + ARMS}
              for s, data in x.items()}
    counts = {s: np.zeros(32, np.int32) for s in x}
    provenance = None
    for expert in range(first, first + 32):
        selected = {s: np.where(data['ids'] == expert) for s, data in x.items()}
        if not any(len(rows) for rows, slots in selected.values()):
            continue
        (gate, up, down), provenance = weights(expert)
        w = np.concatenate((gate, up))
        repacked = {'q4w-q8x': quant(w, 4)}
        repacked.update({str(a): quant(w / diagonals[str(a)], 4) for a in ALPHAS})
        for s, data in x.items():
            rows, slots = selected[s]
            if not len(rows):
                continue
            counts[s][expert - first] = len(rows)
            score = np.asarray(data['scores'][rows, slots], np.float64)[:, None]
            baseline = forward(np.asarray(data['x'][rows]), gate, up, down).astype(np.float64)
            native = np.asarray(data['native_down'][rows, slots], np.float64)
            result[s]['reference'][rows] += score * (baseline - native)
            for arm in ARMS:
                gw, uw = (gate, up) if arm.startswith('gguf') else (repacked[arm][:512], repacked[arm][512:])
                output = forward(coded[s][arm][rows], gw, uw, down).astype(np.float64)
                result[s][arm][rows] += score * (output - baseline)
    for s, arms in result.items():
        save_array(OUT / f'{s}-{first:03}.npz', np.stack([arms[a] for a in ('reference',) + ARMS]))
    (OUT / f'counts-{first:03}.json').write_text(json.dumps({s: v.tolist() for s, v in counts.items()}) + '\n')
    print(f'evaluated {first}..{first+31}; train/held slots {counts["train"].sum()}/{counts["held"].sum()}')


def summarize():
    x = {s: capture(s) for s in ('train', 'held')}
    out = {'source_sha256': sha(__file__), 'study_sha256': sha(Path(__file__).with_name('study.py')),
           'shared_routes_sha256': sha(Path(__file__).with_name('shared_routes.py')),
           'model_sha256': json.loads((BASE / 'acquisition.json').read_text())['sha256'],
           'inventory_sha256': sha(BASE / 'traffic.json'),
           'decoder_sha256': sha((BASE / 'runtime/current/bin/libggml-base.so').resolve()),
           'captures_sha256': {}, 'exponents_sha256': sha(OUT / 'exponents.npy'),
           'maxima_sha256': {str(first): sha(OUT / f'max-{first:03}.npy') for first in SHARDS},
           'shard_sha256': {str(first): {name: sha(OUT / name) for name in
               (f'train-{first:03}.npz.npy', f'held-{first:03}.npz.npy', f'counts-{first:03}.json')}
               for first in SHARDS}, 'split': {},
           'arms': ARMS, 'alpha_values': ALPHAS,
           'image_bytes': {'gguf_gate_up_256': 256 * 1179648, 'repacked_gate_up_256': 256 * 1179648,
                           'shared_diagonal_fp16': DIM * 2, 'q4_code_per_token': 1152,
                           'q8_code_per_token': 2176},
           'work_per_token': {'input_coordinate_products': DIM, 'input_group_reductions': 64,
                              'gate_up_integer_terms_per_slot': 2 * 512 * DIM,
                              'down_terms_per_slot': DIM * 512}}
    exponents = np.load(OUT / 'exponents.npy')
    out['nonzero_exponents'] = {str(a): int(np.count_nonzero(exponents[i])) for i, a in enumerate(ALPHAS)}
    for s, data in x.items():
        stem = BASE / 'route-capture' / s
        out['captures_sha256'][s] = {suffix: sha(Path(str(stem) + suffix)) for suffix in (
            '.tokens', '.0.attn_post_norm-0.bin', '.0.ffn_moe_topk-0.bin',
            '.0.ffn_moe_weights_norm-0.bin', '.0.ffn_moe_down-0.bin')}
        native_sum = np.einsum('te,ted->td', data['scores'].astype(np.float64), data['native_down'].astype(np.float64))
        pieces = [np.load(OUT / f'{s}-{first:03}.npz.npy') for first in SHARDS]
        complete = sum(pieces)
        ref = native_sum + complete[0]
        denom = np.square(ref).sum()
        slot_counts = sum(np.array(json.loads((OUT / f'counts-{first:03}.json').read_text())[s]) for first in SHARDS)
        metrics = {arm: float(np.sqrt(np.square(complete[i+1]).sum() / denom)) for i, arm in enumerate(ARMS)}
        out['split'][s] = {'tokens': len(data['x']), 'selected_slots': int(slot_counts.sum()),
                           'observed_experts': int(np.count_nonzero(slot_counts)),
                           'reference_routed_sum_norm': float(np.sqrt(denom)),
                           'complete_routed_sum_delta_rms': metrics,
                           'per_expert_slot_counts': slot_counts.tolist()}
    out['selected_alpha'] = min(ALPHAS, key=lambda a: out['split']['train']['complete_routed_sum_delta_rms'][str(a)])
    (OUT / 'receipt.json').write_text(json.dumps(out, indent=2) + '\n')
    print(json.dumps({'selected_alpha': out['selected_alpha'], 'train': out['split']['train']['complete_routed_sum_delta_rms'],
                      'held': out['split']['held']['complete_routed_sum_delta_rms']}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=('scan', 'coordinate', 'evaluate', 'summarize'))
    parser.add_argument('--first', type=int, choices=SHARDS)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if args.stage in ('scan', 'evaluate'):
        assert args.first is not None
        (scan if args.stage == 'scan' else evaluate)(args.first)
    else:
        (coordinate if args.stage == 'coordinate' else summarize)()
