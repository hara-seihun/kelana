#!/usr/bin/env python3
"""Exact joint-set head-loss greedy at a fixed tied exact-row budget."""
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
from scipy.special import logsumexp

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('gold_row_study', HERE.parent / 'gold-row' / 'study.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
evaluate, rare, codec = prior.evaluate, prior.rare, prior.codec

DATA = Path('/path/to/workspace/data/kelana-subbit/set-greedy')
SOURCE = prior.DATA
COUNT = 1280


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def prepare():
    DATA.mkdir(parents=True, exist_ok=True)
    base = np.load(SOURCE / 'fit-base.npy', mmap_mode='r')
    exact = np.load(SOURCE / 'fit-exact.npy', mmap_mode='r')
    gold = np.load(SOURCE / 'fit-gold.npy')
    with np.load(evaluate.DATA / 'frequency.npz') as z:
        frequency = z['train'].copy()
    order = np.lexsort((np.arange(evaluate.ROWS), -frequency))
    anchor = order[:COUNT]
    single = prior.row_gain(base, exact, gold, anchor)
    # Give set optimization every row from either the original frequent control
    # or the earlier independent-head ranking. The anchor is unchanged.
    pool = np.union1d(order[:2 * COUNT], np.argsort(-single, kind='stable')[:2 * COUNT])
    pool = pool[~np.isin(pool, anchor)]
    zbase = np.asarray(base, dtype=np.float64).copy()
    zbase[:, anchor] = exact[:, anchor]
    offset = zbase.max(axis=1)
    normalizer = np.exp(zbase - offset[:, None]).sum(axis=1)
    delta = np.exp(np.asarray(exact[:, pool], dtype=np.float64) - offset[:, None]) - np.exp(np.asarray(base[:, pool], dtype=np.float64) - offset[:, None])
    gold_gain = np.bincount(gold, weights=(exact[np.arange(len(gold)), gold] - base[np.arange(len(gold)), gold]) / len(gold), minlength=evaluate.ROWS)[pool]
    np.savez(DATA / 'problem.npz', pool=pool, anchor=anchor, delta=delta, normalizer=normalizer, gold_gain=gold_gain, single=single[pool])
    np.savez(DATA / 'progress.npz', selected=np.zeros(0, dtype=np.int32), normalizer=normalizer, remaining=np.ones(len(pool), dtype=bool), trajectory=np.zeros(0))
    print(json.dumps({'pool': len(pool), 'anchor': len(anchor), 'problem_sha256': digest(DATA / 'problem.npz')}))


def step():
    with np.load(DATA / 'problem.npz') as p, np.load(DATA / 'progress.npz') as q:
        pool, anchor, delta, gold_gain = [p[k].copy() for k in ('pool', 'anchor', 'delta', 'gold_gain')]
        z, remaining, selected, trajectory = [q[k].copy() for k in ('normalizer', 'remaining', 'selected', 'trajectory')]
    stop = min(COUNT, len(selected) + 160)
    while len(selected) < stop:
        gain = gold_gain - np.log1p(delta / z[:, None]).mean(axis=0)
        gain[~remaining] = -np.inf
        index = int(np.argmax(gain))
        z += delta[:, index]
        remaining[index] = False
        selected = np.append(selected, index)
        trajectory = np.append(trajectory, gain[index])
    np.savez(DATA / 'progress.npz', selected=selected, normalizer=z, remaining=remaining, trajectory=trajectory)
    print(json.dumps({'selected': len(selected), 'last_gain': trajectory[-1], 'total_gain': trajectory.sum()}))


def assess():
    with np.load(DATA / 'problem.npz') as p, np.load(DATA / 'progress.npz') as q:
        pool, anchor, single = [p[k].copy() for k in ('pool', 'anchor', 'single')]
        selected, trajectory = q['selected'].copy(), q['trajectory'].copy()
    assert len(selected) == COUNT
    with np.load(evaluate.DATA / 'frequency.npz') as z:
        val_counts = z['validation'].copy()
    with np.load(evaluate.DATA / 'codebook256.npz') as z:
        labels = codec.unpack(z['labels'], 64, 8)
        scales, code, unit = z['scales'].copy(), z['code'].copy(), float(z['unit'])
    _, original, held_gold, _, _, weights, bits = evaluate.load()
    plans = {
        'frequent': np.load(SOURCE / 'frequent2560-ids.npy'),
        'single': np.concatenate((anchor, pool[np.lexsort((pool, -single))[:COUNT]])),
        'joint_set': np.concatenate((anchor, pool[selected])),
    }
    measured = {}
    base = {s: np.load(SOURCE / f'{s}-base.npy', mmap_mode='r') for s in ('fit', 'tune', 'held')}
    exact = {s: np.load(SOURCE / f'{s}-exact.npy', mmap_mode='r') for s in base}
    tune_gold = np.load(SOURCE / 'tune-gold.npy')
    denominator = np.sum(val_counts * np.sum(weights.astype(np.float64) ** 2, axis=1))
    for name, ids in plans.items():
        tune = np.array(base['tune']); tune[:, ids] = exact['tune'][:, ids]
        held = np.array(base['held']); held[:, ids] = exact['held'][:, ids]
        adjusted, calibration = rare.calibrate(held, original, tune, tune_gold, ids)
        # Decode only rows occurring in the held corpus. All other rows have zero weight.
        observed = np.flatnonzero(val_counts)
        missing = observed[~np.isin(observed, ids)]
        error = 0.
        for block in np.array_split(missing, max(1, (len(missing) + 2047) // 2048)):
            reconstructed = evaluate.decode_rows(block, labels, scales, code, unit)
            error += np.sum(val_counts[block] * np.sum((weights[block] - reconstructed) ** 2, axis=1))
        fit = np.array(base['fit']); fit[:, ids] = exact['fit'][:, ids]
        fit_gold = np.load(SOURCE / 'fit-gold.npy')
        fit_nll = float(np.mean(logsumexp(fit.astype(np.float64), axis=1) - fit[np.arange(len(fit_gold)), fit_gold]))
        image = DATA / f'{name}-exact.npz'
        np.savez_compressed(image, ids=ids.astype('<u4'), bf16_bits=bits[ids])
        measured[name] = {'fit_nll_uncalibrated': fit_nll, 'head': evaluate.quality(original, adjusted, held_gold),
                          'calibration': calibration, 'embedding_validation_relative_rms': float(np.sqrt(error / denominator)),
                          'held_gold_exact': int(np.isin(held_gold, ids).sum()), 'image_sha256': digest(image),
                          'ids_sha256': hashlib.sha256(ids.astype('<u4').tobytes()).hexdigest()}
        print(name, json.dumps(measured[name]))
    prior_result = json.loads((SOURCE / 'result.json').read_text())
    receipt = {'format': 'tied-exact-set-greedy/1', 'source_sha256': digest(__file__),
               'input_sha256': {f'{s}-{k}': digest(SOURCE / f'{s}-{k}.npy') for s in base for k in ('base', 'exact', 'gold')},
               'problem_sha256': digest(DATA / 'problem.npz'), 'progress_sha256': digest(DATA / 'progress.npz'),
               'candidate_pool': 'union of top 2560 train-frequency IDs and top 2560 single-row gold-NLL-gain IDs, excluding 1280 fixed frequent anchors',
               'selection': 'forward greedy, exact current selected-set log partition, 1280 additions; stable pool order breaks ties',
               'trajectory_gain_sum': float(trajectory.sum()), 'last_gain': float(trajectory[-1]),
               'paid_bytes': prior_result['paid_bytes'], 'paid_bpw': prior_result['paid_bpw'],
               'boundary': 'same fixed original-model train head inputs, separate 32 train calibration inputs, 64 held validation head inputs and validation embedding occurrences as gold-row; no model continuation or native timing',
               'results': measured}
    (DATA / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')

if __name__ == '__main__':
    {'prepare': prepare, 'step': step, 'assess': assess}[sys.argv[1]]()
