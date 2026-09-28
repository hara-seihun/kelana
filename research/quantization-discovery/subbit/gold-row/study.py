#!/usr/bin/env python3
"""Gold-loss and embedding-aware exact-row allocation for the tied K256 image."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from scipy.special import logsumexp

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'tied-head'))
import codec
import evaluate
sys.path.insert(0, str(HERE.parent / 'tied-rare'))
import study as rare

DATA = Path('/path/to/workspace/data/kelana-subbit/gold-row')
SOURCE = evaluate.DATA
TOKENS = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz')


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as file:
        for block in iter(lambda: file.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def capture(split):
    DATA.mkdir(parents=True, exist_ok=True)
    with np.load(SOURCE / 'codebook256.npz') as z:
        labels = codec.unpack(z['labels'], 64, 8)
        scales, code, unit = z['scales'].copy(), z['code'].copy(), float(z['unit'])
    with np.load(SOURCE / 'final-head.npz') as z:
        all_hidden = z['train_hidden'].copy()
        if split == 'held':
            p = z['selected_positions'].copy()
            hidden = z['validation_hidden'][p[:, 0] * 256 + p[:, 1]].copy()
            gold = z['selected_gold'].copy()
        else:
            offsets = {'fit': np.arange(4, 255, 8), 'tune': np.arange(0, 255, 32)}[split]
            hidden = all_hidden[np.concatenate([i * 256 + offsets for i in range(4)])]
            with np.load(TOKENS) as t:
                gold = t['train'][:4, offsets + 1].reshape(-1)
    # The existing 0.625-bit image remains the online consumer. Dense products here
    # are offline row-selection evidence and exact-row head responses, not inference.
    w = evaluate.load()[5]
    scores = evaluate.respond(hidden, labels, scales, code, unit)
    exact = hidden @ w.T
    np.save(DATA / f'{split}-base.npy', scores)
    np.save(DATA / f'{split}-exact.npy', exact)
    np.save(DATA / f'{split}-gold.npy', gold)
    print(json.dumps({'split': split, 'positions': len(gold), 'base_sha256': sha(DATA / f'{split}-base.npy'),
                      'exact_sha256': sha(DATA / f'{split}-exact.npy')}))


def row_gain(base, exact, gold, fixed):
    """Exact single-row NLL gain against a fixed set of already replaced rows."""
    z = base.copy()
    z[:, fixed] = exact[:, fixed]
    logz = logsumexp(z.astype(np.float64), axis=1)
    p = np.exp(exact.astype(np.float64) - logz[:, None])
    q = np.exp(base.astype(np.float64) - logz[:, None])
    gain = -np.log1p(p - q).mean(axis=0)
    np.add.at(gain, gold, (exact[np.arange(len(gold)), gold] - base[np.arange(len(gold)), gold]) / len(gold))
    gain[fixed] = -np.inf
    return gain


def assess():
    base = {s: np.load(DATA / f'{s}-base.npy') for s in ('fit', 'tune', 'held')}
    exact = {s: np.load(DATA / f'{s}-exact.npy') for s in base}
    gold = {s: np.load(DATA / f'{s}-gold.npy') for s in base}
    with np.load(SOURCE / 'frequency.npz') as z:
        counts, val_counts = z['train'].copy(), z['validation'].copy()
    order = np.lexsort((np.arange(evaluate.ROWS), -counts))
    anchor = order[:1280]
    gain = row_gain(base['fit'], exact['fit'], gold['fit'], anchor)
    # Each exact embedding row removes its entire codebook reconstruction error.
    with np.load(SOURCE / 'codebook256.npz') as z:
        labels = codec.unpack(z['labels'], 64, 8)
        scales, code, unit = z['scales'].copy(), z['code'].copy(), float(z['unit'])
    _, original, held_gold, _, _, weights, source_bits = evaluate.load()
    residual = np.zeros(evaluate.ROWS, np.float64)
    for start in range(0, evaluate.ROWS, 2048):
        ids = np.arange(start, min(start + 2048, evaluate.ROWS))
        decoded = evaluate.decode_rows(ids, labels, scales, code, unit)
        residual[ids] = np.sum((weights[ids] - decoded) ** 2, axis=1)
    emb = counts * residual
    emb /= max(emb.sum(), 1)
    # Normalize a gain into per-row units before combining with an embedding
    # objective. Coefficient 0 chooses head; 1 chooses embedding; .5 is joint.
    positive = np.maximum(gain, 0)
    positive[anchor] = 0
    head = positive / max(positive.sum(), 1e-30)
    plans = {'frequent2560': order[:2560], 'gold1280+1280': None,
             'joint1280+1280': None, 'embedding1280+1280': None}
    for name, alpha in [('gold1280+1280', 0.), ('joint1280+1280', .5), ('embedding1280+1280', 1.)]:
        priority = (1 - alpha) * head + alpha * emb
        priority[anchor] = -np.inf
        plans[name] = np.concatenate((anchor, np.lexsort((np.arange(evaluate.ROWS), -priority))[:1280]))
    measurements = {}
    denom = float(np.sum(val_counts * np.sum(weights.astype(np.float64) ** 2, axis=1)))
    for name, ids in plans.items():
        scores = {}
        for split in base:
            scores[split] = base[split].copy()
            scores[split][:, ids] = exact[split][:, ids]
        corrected, calibration = rare.calibrate(scores['held'], original, scores['tune'], gold['tune'], ids)
        metric = evaluate.quality(original, corrected, held_gold)
        remain = residual.copy(); remain[ids] = 0
        measured = {'head': metric, 'calibration': calibration,
                    'fit_uncalibrated_nll': float(np.mean(logsumexp(scores['fit'].astype(np.float64), axis=1) - scores['fit'][np.arange(len(gold['fit'])), gold['fit']])),
                    'embedding_validation_relative_rms': float(np.sqrt(np.sum(val_counts * remain) / denom)),
                    'validation_token_coverage': float(val_counts[ids].sum() / val_counts.sum()),
                    'fit_single_row_gain_sum': float(np.sum(gain[ids[1280:]])) if name != 'frequent2560' else None,
                    'held_gold_exact': int(np.isin(held_gold, ids).sum()),
                    'selected_ids_sha256': hashlib.sha256(ids.astype('<u4').tobytes()).hexdigest()}
        image = DATA / f'{name}-exact.npz'
        np.savez_compressed(image, ids=ids.astype('<u4'), bf16_bits=source_bits[ids])
        measured['exact_image_sha256'] = sha(image)
        measurements[name] = measured
        print(name, json.dumps(measured))
    bytes_ = json.loads((SOURCE / 'codebook256.json').read_text())['total_payload_bytes'] + 2560 * (4 + 2048) + 8
    receipt = {'format': 'gold-row-allocation/1', 'source_sha256': sha(__file__),
               'base_sha256': sha(SOURCE / 'codebook256.npz'),
               'capture_sha256': sha(SOURCE / 'final-head.npz'),
               'frequency_sha256': sha(SOURCE / 'frequency.npz'),
               'fit_positions': '4,12,...,252 per train window; 128 next-token observations',
               'tune_positions': '0,32,...,224 per train window; 32 disjoint observations',
               'held': '64 original-model final-hidden validation positions; no quantized embedding propagation',
               'paid_bytes': bytes_, 'paid_bpw': bytes_ * 8 / (evaluate.ROWS * 1024),
               'online': 'same 64-response table per row and 2560 exact 1024-element BF16 row dots in every plan; same input embedding decode and exact-row lookup',
               'fit_row_gain': 'exact one-row NLL change against fixed 1280 frequent rows; ignores interactions among selected additions',
               'fit_embedding_gain': 'train occurrence times squared embedding reconstruction residual, normalized over rows',
               'mixture_weights_head_embedding': [0., .5, 1.],
               'inputs': {f'{s}_{kind}_sha256': sha(DATA / f'{s}-{kind}.npy') for s in base for kind in ('base', 'exact', 'gold')},
               'results': measurements}
    (DATA / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')

if __name__ == '__main__':
    {'fit': lambda: capture('fit'), 'tune': lambda: capture('tune'),
     'held': lambda: capture('held'), 'assess': assess}[sys.argv[1]]()
