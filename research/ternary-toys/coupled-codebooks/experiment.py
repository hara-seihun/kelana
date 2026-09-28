#!/usr/bin/env python3
"""Exact finite-code searches with an FP16 group scale and a composed consumer."""
import itertools
import json
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent
TRITS = np.array([-1, 0, 1], dtype=np.int8)


def scalar_candidates():
    codes = np.array(list(itertools.product(TRITS, repeat=8)), dtype=np.int8)
    return codes.reshape(-1, 2, 4), codes


def pair_candidates():
    ids = np.array(list(itertools.product(range(4), repeat=4)), dtype=np.int8)
    templates = np.array(list(itertools.product(range(4), repeat=2)), dtype=np.int8)
    vectors = []
    labels = []
    for a, b in templates:
        alphabet = np.array([[a, b], [-a, -b], [b, a], [-b, -a]], dtype=np.int8)
        vectors.append(alphabet[ids].transpose(0, 2, 1))
        labels.extend((int(a), int(b), row.tolist()) for row in ids)
    return np.concatenate(vectors), labels


def fit(candidates, target, consumer, inputs):
    # For a fixed code, the objective is a quadratic in the single group scale.
    # The nearest FP16 word and its neighbors contain the discrete minimum.
    mapped = candidates.astype(np.float64) @ inputs
    mapped = consumer @ mapped
    reference = consumer @ target @ inputs
    dot = np.einsum('nct,ct->n', mapped, reference)
    norm = np.einsum('nct,nct->n', mapped, mapped)
    continuous = np.maximum(dot / np.where(norm == 0, 1, norm), 0)
    nearest = continuous.astype(np.float16)
    below = np.nextafter(nearest, np.float16(0))
    above = np.nextafter(nearest, np.float16(np.inf))
    gains = np.stack((below.astype(np.float64), nearest.astype(np.float64), above.astype(np.float64)))
    errors = np.sum(reference * reference) - 2 * gains * dot + gains * gains * norm
    flat = int(np.argmin(errors))
    side, index = np.unravel_index(flat, errors.shape)
    scale = float(gains[side, index])
    return int(index), scale, float(max(errors[side, index], 0))


def loss(candidate, target, consumer, inputs):
    error = consumer @ (candidate - target) @ inputs
    return float(np.mean(np.sum(error * error, axis=0)))


def run():
    rng = np.random.default_rng(230923)
    transform = np.array([[1.7, .3, 0, 0], [.2, .55, .15, 0], [0, .3, 1.1, 0], [.3, 0, -.1, .75]])
    consumer = np.array([[1, .75], [.2, -.85]], dtype=np.float64)
    # One target per group; these are not candidate codes because of the noise.
    ratios = [(1, 2), (1, 3), (2, 3), (1, 2), (1, 3), (2, 3), (1, 2), (1, 3)]
    training = transform @ rng.normal(size=(4, 64))
    held = transform @ rng.normal(size=(4, 1024))
    scalar, scalar_labels = scalar_candidates()
    paired, pair_labels = pair_candidates()
    cases = {'paired_motif': [], 'unstructured': []}
    for group, (a, b) in enumerate(ratios):
        alphabet = np.array([[a, b], [-a, -b], [b, a], [-b, -a]])
        assignment = rng.permutation(4)
        scale = .27 + .065 * group
        target = (alphabet[assignment].T + rng.normal(0, .11, size=(2, 4))) * scale
        cases['paired_motif'].append(dict(target=target, source_ratio=[a, b], source_assignment=assignment.tolist()))
    for group in range(8):
        cases['unstructured'].append(dict(target=rng.normal(0, .6, size=(2, 4))))
    for kind, cases_for_kind in cases.items():
        for group in cases_for_kind:
            target = group.pop('target')
            arms = {}
            for name, candidates, labels in (("scalar", scalar, scalar_labels), ("paired", paired, pair_labels)):
                index, gain, train_sum = fit(candidates, target, consumer, training)
                decoded = gain * candidates[index]
                terms = int(np.count_nonzero(candidates[index]))
                arms[name] = dict(scale=gain, label=labels[index] if name == 'paired' else scalar_labels[index].tolist(),
                                  train_mse=train_sum / training.shape[1], held_mse=loss(decoded, target, consumer, held),
                                  raw_weight_mse=float(np.mean((decoded - target) ** 2)), nonzero_terms=terms)
            group['arms'] = arms
    summary = {kind: {'total_held_mse': {name: sum(g['arms'][name]['held_mse'] for g in groups)
                                           for name in ('scalar', 'paired')},
                      'paired_wins': sum(g['arms']['paired']['held_mse'] < g['arms']['scalar']['held_mse'] for g in groups),
                      'nonzero_terms': {name: sum(g['arms'][name]['nonzero_terms'] for g in groups)
                                        for name in ('scalar', 'paired')}}
               for kind, groups in cases.items()}
    output = dict(seed=230923, train_columns=64, held_columns=1024, consumer=consumer.tolist(),
                  input_transform=transform.tolist(), cases=cases, summary=summary,
                  candidate_counts={'scalar': len(scalar), 'paired': len(paired)},
                  bytes={'scalar_per_group': 4, 'paired_per_group': 4})
    (ROOT / 'results.json').write_text(json.dumps(output, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    run()
