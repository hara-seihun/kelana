#!/usr/bin/env python3
"""Train-only code-label corrections for the pinned tied-head image."""
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.optimize import minimize
from scipy.special import logsumexp

DATA = Path('/path/to/workspace/data/kelana-subbit')
CAP = DATA / 'gold-row'
OUT = DATA / 'tied-code-bias'
OUT.mkdir(exist_ok=True)
ROWS, EXACT = 151936, 2560
SEGMENTS = (0, 16, 32, 48)
WEIGHT = 2.
RIDGE = 0.01


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


with np.load(DATA / 'tied-head/frequency.npz') as f:
    counts = f['train'].copy()
order = np.lexsort((np.arange(ROWS), -counts))
exact = np.zeros(ROWS, bool)
exact[order[:EXACT]] = True
with np.load(DATA / 'tied-head/codebook256.npz') as f:
    labels = f['labels'][:, SEGMENTS].copy()
with open(DATA / 'tied-head/tune256-2560.json') as f:
    temperature = json.load(f)['temperature_rare']


def capture(split):
    scores = np.load(CAP / f'{split}-base.npy')
    original = np.load(CAP / f'{split}-exact.npy', mmap_mode='r')
    scores[:, exact] = original[:, exact]
    scores[:, ~exact] *= temperature
    gold = np.load(CAP / f'{split}-gold.npy')
    teacher = np.asarray(original, dtype=np.float64)
    tp = np.exp(teacher - logsumexp(teacher, axis=1)[:, None])
    return scores, gold, tp


captures = {s: capture(s) for s in ('fit', 'tune', 'held')}
with np.load(DATA / 'tied-head/final-head.npz') as f:
    reference = f['selected_logits'].astype(np.float64)
    positions = f['selected_positions'].copy()
reference_logz = logsumexp(reference, axis=1)
reference_p = np.exp(reference - reference_logz[:, None])


def partition(scores, teacher, group):
    n = len(scores)
    part = np.empty((n, 257))
    teacher_part = np.empty_like(part)
    for i in range(n):
        shift = scores[i].max()
        mass = np.bincount(group, weights=np.exp(scores[i].astype(np.float64) - shift), minlength=257)
        part[i] = np.log(np.maximum(mass, 1e-300)) + shift
        teacher_part[i] = np.bincount(group, weights=teacher[i], minlength=257)
    return part, teacher_part


def fit(parts, group_gold, gold_score, teacher_mass, global_only=False):
    n = len(parts)
    gold_target = np.bincount(group_gold, minlength=257) / n
    target = gold_target + WEIGHT * teacher_mass.mean(axis=0)

    def objective(b):
        bias = np.r_[0., np.repeat(b[0], 256) if global_only else b]
        z = parts + bias
        prob = np.exp(z - logsumexp(z, axis=1)[:, None])
        loss = np.mean(logsumexp(z, axis=1) - gold_score - bias[group_gold])
        loss += WEIGHT * np.mean(logsumexp(z, axis=1) - (teacher_mass * bias).sum(axis=1))
        grad = (1 + WEIGHT) * prob.mean(axis=0) - target
        if not global_only:
            loss += RIDGE * np.mean(b * b)
            grad[1:] += 2 * RIDGE * b / len(b)
        return loss, np.array([grad[1:].sum()]) if global_only else grad[1:]

    result = minimize(objective, np.zeros(1 if global_only else 256), jac=True, method='L-BFGS-B',
                      options={'maxiter': 600, 'gtol': 1e-7, 'ftol': 1e-10})
    if not result.success and np.max(np.abs(result.jac)) > 1e-5:
        raise RuntimeError(result.message)
    return np.repeat(result.x[0], 256) if global_only else result.x


def objective_on(part, group, scores, gold, teacher_mass, bias):
    b = np.r_[0., bias]
    logz = logsumexp(part + b, axis=1)
    nll = logz - scores[np.arange(len(gold)), gold] - b[group[gold]]
    return float(np.mean(nll + WEIGHT * (logz - (teacher_mass * b).sum(axis=1))) + RIDGE * np.mean(bias * bias))


def held_metrics(scores, gold, parts, group, bias):
    b = np.r_[0., bias]
    candidate = scores.astype(np.float64) + b[group][None, :]
    logz = logsumexp(parts + b, axis=1)
    nll = logz - candidate[np.arange(len(gold)), gold]
    kl = np.sum(reference_p * (reference - candidate), axis=1) + logz - reference_logz
    return {'nll': float(nll.mean()), 'nll_by_window': [float(nll[positions[:, 0] == w].mean()) for w in (0, 1)],
            'teacher_kl': float(kl.mean()), 'top_matches': int((candidate.argmax(axis=1) == reference.argmax(axis=1)).sum()),
            'top_count': len(gold)}


results = {}
for col, segment in enumerate(SEGMENTS):
    group = np.where(exact, 0, labels[:, col].astype(np.int16) + 1)
    collapsed = {s: partition(v[0], v[2], group) for s, v in captures.items()}
    fit_scores, fit_gold, _ = captures['fit']
    tune_scores, tune_gold, _ = captures['tune']
    trained = fit(collapsed['fit'][0], group[fit_gold], fit_scores[np.arange(len(fit_gold)), fit_gold], collapsed['fit'][1])
    tune_loss = objective_on(collapsed['tune'][0], group, tune_scores, tune_gold, collapsed['tune'][1], trained)
    train_scores = np.concatenate((fit_scores, tune_scores))
    train_gold = np.concatenate((fit_gold, tune_gold))
    joint = fit(np.concatenate((collapsed['fit'][0], collapsed['tune'][0])), group[train_gold],
                train_scores[np.arange(len(train_gold)), train_gold],
                np.concatenate((collapsed['fit'][1], collapsed['tune'][1])))
    bias = joint.astype('<f2')
    (OUT / f'segment-{segment}.f16').write_bytes(bias.tobytes())
    held_score, held_gold, _ = captures['held']
    results[str(segment)] = {'tune_objective_fit_only': tune_loss,
                             'held': held_metrics(held_score, held_gold, collapsed['held'][0], group, bias.astype(np.float64)),
                             'bias_sha256': sha(OUT / f'segment-{segment}.f16'),
                             'largest_abs_bias': float(np.max(np.abs(joint))),
                             'rare_group_sizes': np.bincount(group[~exact], minlength=257)[1:].tolist()}
    if segment == SEGMENTS[0]:
        baseline = fit(np.concatenate((collapsed['fit'][0], collapsed['tune'][0])), group[train_gold],
                       train_scores[np.arange(len(train_gold)), train_gold],
                       np.concatenate((collapsed['fit'][1], collapsed['tune'][1])), global_only=True)
        results['global'] = held_metrics(held_score, held_gold, collapsed['held'][0], group, baseline)
        fit_global = fit(collapsed['fit'][0], group[fit_gold], fit_scores[np.arange(len(fit_gold)), fit_gold],
                         collapsed['fit'][1], global_only=True)
        results['global']['tune_objective_fit_only'] = objective_on(collapsed['tune'][0], group,
                                            tune_scores, tune_gold, collapsed['tune'][1], fit_global)
    print(f'segment {segment}: tune {tune_loss:.6f}, held {results[str(segment)]["held"]["nll"]:.6f}', flush=True)

best_label = min(SEGMENTS, key=lambda seg: results[str(seg)]['tune_objective_fit_only'])
selected = min(('global', *[str(s) for s in SEGMENTS]), key=lambda arm: results[arm]['tune_objective_fit_only'])
receipt = {'format': 'tied-code-bias/1', 'source_sha256': sha(__file__),
           'input_sha256': {str(p.relative_to(DATA)): sha(p) for p in
                            [DATA / 'tied-head/codebook256.npz', DATA / 'tied-head/frequency.npz',
                             DATA / 'tied-head/tune256-2560.json', DATA / 'tied-head/final-head.npz'] +
                            [CAP / f'{split}-{kind}.npy' for split in captures for kind in ('base', 'exact', 'gold')]},
           'fit_positions': 128, 'tune_positions': 32, 'held_positions': 64, 'fixed_original_hidden': True,
           'lambda_teacher': WEIGHT, 'ridge_mean_square': RIDGE, 'temperature_rare': temperature,
           'candidate_segments': SEGMENTS, 'selection': 'lowest fit-only model objective on tune split',
           'selected': selected, 'best_label_only': best_label, 'extra_bytes_if_label_arm': 512,
           'base_paid_bytes_without_calibration': 17412100,
           'online': 'one existing eight-bit code label indexes an FP16 bias table, one add per rare logit; no new per-row ID stream',
           'results': results}
(OUT / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')
print('selected', selected, results[selected])
