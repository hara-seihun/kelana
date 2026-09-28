#!/usr/bin/env python3
"""Frequency-bucket head-logit correction on fixed Qwen3 tied-head captures."""
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.optimize import minimize
from scipy.special import logsumexp

DATA = Path('/path/to/workspace/data/kelana-subbit')
CAP = DATA / 'gold-row'
OUT = DATA / 'tied-bias'
OUT.mkdir(exist_ok=True)
ROWS = 151936
EXACT = 2560
CUTS = (2560, 5120, 10240, 20480, 40960, 81920, ROWS)


def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


with np.load(DATA / 'tied-head/frequency.npz') as f:
    counts = f['train'].copy()
order = np.lexsort((np.arange(ROWS), -counts))
groups = np.empty(ROWS, np.uint8)
for g, (lo, hi) in enumerate(zip(CUTS[:-1], CUTS[1:])):
    groups[order[lo:hi]] = g + 1
groups[order[:EXACT]] = 0
assert np.bincount(groups, minlength=len(CUTS)).tolist() == [2560, 2560, 5120, 10240, 20480, 40960, 70016]
packed_groups = np.packbits(((groups[:, None] >> np.arange(3)) & 1).reshape(-1), bitorder='little')
(OUT / 'groups.u3').write_bytes(packed_groups.tobytes())
with open(DATA / 'tied-head/tune256-2560.json') as f:
    temperature = json.load(f)['temperature_rare']


def samples(split):
    base = np.load(CAP / f'{split}-base.npy')
    exact = np.load(CAP / f'{split}-exact.npy', mmap_mode='r')
    gold = np.load(CAP / f'{split}-gold.npy')
    base[:, groups == 0] = exact[:, groups == 0]
    base[:, groups != 0] *= temperature
    return base, gold


def collapsed(scores):
    return np.stack([logsumexp(scores[:, groups == g].astype(np.float64), axis=1)
                     for g in range(len(CUTS))], axis=1)


train = [samples(s) for s in ('fit', 'tune')]
held, held_gold = samples('held')
train_partition = np.concatenate([collapsed(s) for s, _ in train])
held_partition = collapsed(held)
train_gold = np.concatenate([g for _, g in train])
train_score = np.concatenate([s[np.arange(len(g)), g] for s, g in train])
train_group = groups[train_gold]
teacher_mass = []
for split in ('fit', 'tune'):
    exact = np.load(CAP / f'{split}-exact.npy', mmap_mode='r')
    teacher_parts = np.stack([logsumexp(exact[:, groups == g].astype(np.float64), axis=1)
                              for g in range(len(CUTS))], axis=1)
    teacher_mass.append(np.exp(teacher_parts - logsumexp(teacher_parts, axis=1)[:, None]))
teacher_mass = np.concatenate(teacher_mass)


def optimize(parts, gold_group, gold_score, bucket, kl_weight):
    n = len(gold_group)
    # Class 0 is the exact-row group. The all-rare offset has one learned scalar;
    # the frequency-bucket arm has six additional degrees of freedom.
    def objective(b):
        bias = np.r_[0., b[0] if not bucket else b]
        if not bucket:
            bias = np.r_[0., np.repeat(b[0], len(CUTS) - 1)]
        z = parts + bias
        mass = np.exp(z - logsumexp(z, axis=1)[:, None])
        loss = np.mean(logsumexp(z, axis=1) - gold_score - bias[gold_group])
        loss += kl_weight * np.mean(logsumexp(z, axis=1) - np.sum(teacher_mass * bias, axis=1))
        target = (np.bincount(gold_group, minlength=len(CUTS)) / n + kl_weight * teacher_mass.mean(axis=0))
        grad = (1 + kl_weight) * mass.mean(axis=0) - target
        return loss, grad[1:] if bucket else np.array([grad[1:].sum()])
    fit = minimize(objective, np.zeros(len(CUTS) - 1 if bucket else 1), jac=True,
                   method='L-BFGS-B', options={'maxiter': 150, 'ftol': 1e-12})
    if not fit.success:
        raise RuntimeError(fit.message)
    return fit.x, fit.fun


with np.load(DATA / 'tied-head/final-head.npz') as capture:
    reference = capture['selected_logits'].astype(np.float64)
    positions = capture['selected_positions'].copy()
reference_logz = logsumexp(reference, axis=1)
reference_prob = np.exp(reference - reference_logz[:, None])
reference_top = reference.argmax(axis=1)


def metrics(scores, gold, parts, biases):
    z = parts + np.r_[0., biases]
    score = scores[np.arange(len(gold)), gold] + np.r_[0., biases][groups[gold]]
    candidate = scores.astype(np.float64) + np.r_[0., biases][groups]
    logz = logsumexp(z, axis=1)
    nll = logz - score
    kl = np.sum(reference_prob * (reference - candidate), axis=1) + logz - reference_logz
    return {'nll': float(nll.mean()), 'nll_by_window': [float(nll[positions[:, 0] == w].mean()) for w in (0, 1)],
            'teacher_kl': float(kl.mean()), 'top_matches': int(np.sum(reference_top == candidate.argmax(axis=1))),
            'top_count': len(gold)}

results = {}
for kl_weight in (0., 0.5, 2.):
    for bucket in (False, True):
        fitted, _ = optimize(train_partition, train_group, train_score, bucket, kl_weight)
        bias = fitted if bucket else np.repeat(fitted[0], len(CUTS) - 1)
        result = {'bias': bias.tolist(), 'temperature_rare': temperature,
                  'kl_weight': kl_weight, 'held': metrics(held, held_gold, held_partition, bias),
                  'extra_bytes': (2 * (len(CUTS) - 1) + (ROWS * 3 + 7) // 8) if bucket else 4,
                  'online': ('one FP32 add per rare logit, plus packed 3-bit row group read' if bucket
                             else 'one FP32 add per rare logit') + '; no embedding change'}
        if bucket:
            rounded = bias.astype(np.float16).astype(np.float64)
            image = OUT / f'bias-kl{kl_weight}.f16'
            image.write_bytes(bias.astype('<f2').tobytes())
            result['bias_image_sha256'] = digest(image)
            result['held_fp16'] = metrics(held, held_gold, held_partition, rounded)
        results[f'{"bucket" if bucket else "global"}-kl{kl_weight}'] = result

receipt = {'format': 'tied-head-frequency-bias/1', 'source_sha256': digest(__file__),
           'inputs': {f'{s}-{kind}': digest(CAP / f'{s}-{kind}.npy')
                      for s in ('fit', 'tune', 'held') for kind in ('base', 'exact', 'gold')},
           'frequency_sha256': digest(DATA / 'tied-head/frequency.npz'),
           'base_image_sha256': digest(DATA / 'tied-head/codebook256.npz'),
           'exact_ids_sha256': hashlib.sha256(order[:EXACT].astype('<u4').tobytes()).hexdigest(),
           'fixed_original_hidden': True, 'fit_positions': 160, 'held_positions': 64,
           'groups': CUTS, 'group_sizes': np.bincount(groups).tolist(),
           'groups_image_sha256': digest(OUT / 'groups.u3'),
           'groups_image_bytes': (OUT / 'groups.u3').stat().st_size,
           'fixed_temperature_source': 'tied-head/tune256-2560.json, fit on 128 train positions; overlaps these train windows',
           'fit_objective': 'gold NLL plus lambda times KL of dense FP32 original-head responses; group-constant biases, temperature fixed; convex in biases',
           'base_paid_bytes_without_calibration': 17412100, 'results': results}
(OUT / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(results, indent=2))
