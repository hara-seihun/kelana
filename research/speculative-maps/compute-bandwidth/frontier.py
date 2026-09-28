#!/usr/bin/env python3
"""Exact greedy-logit certificate frontier on a finite synthetic head."""
import json
import random


def evaluate(weights, contexts, order):
    vocab = len(weights)
    width = len(order)
    bounds = [[sum(abs(weights[t][j]) for j in order[k:]) for k in range(width + 1)]
              for t in range(vocab)]
    histogram = [0] * (width + 1)
    for x in contexts:
        sums = [0] * vocab
        winner = None
        for k, j in enumerate(order, 1):
            for t in range(vocab):
                sums[t] += weights[t][j] * x[j]
            candidate = max(range(vocab), key=lambda t: (sums[t], -t))
            if all(sums[candidate] - bounds[candidate][k] >
                   sums[t] + bounds[t][k] for t in range(vocab) if t != candidate):
                winner = candidate
                histogram[k] += 1
                break
        if winner is None:
            winner = max(range(vocab), key=lambda t: (sums[t], -t))
            histogram[width] += 1
        full = [sum(w * z for w, z in zip(row, x)) for row in weights]
        assert winner == max(range(vocab), key=lambda t: (full[t], -t))
    return histogram


def main():
    rng = random.Random(271828)
    vocab, width, count = 8, 16, 4096
    scales = [max(1, 256 >> (j // 2)) for j in range(width)]
    weights = [[rng.randrange(-4, 5) * scale for scale in scales] for _ in range(vocab)]
    contexts = [[rng.choice((-1, 0, 1)) for _ in range(width)] for _ in range(count)]
    natural = list(range(width))
    shuffled = natural.copy()
    rng.shuffle(shuffled)
    orders = {'descending_scale': natural, 'random': shuffled,
              'ascending_scale': natural[::-1]}
    outcomes = {}
    for name, order in orders.items():
        histogram = evaluate(weights, contexts, order)
        features = sum(k * n for k, n in enumerate(histogram))
        outcomes[name] = {'histogram': histogram, 'mean_features': features / count,
                          'weight_bytes_if_int16': features * vocab * 2,
                          'full_weight_bytes': count * width * vocab * 2,
                          'saved_fraction': 1 - features / (count * width),
                          'mean_extra_comparisons_upper_bound':
                              sum(k * n * (vocab - 1) for k, n in enumerate(histogram)) / count}
    print(json.dumps({'seed': 271828, 'contexts': count, 'vocab': vocab, 'features': width,
                      'input_domain': [-1, 0, 1], 'orders': outcomes}, indent=2))


if __name__ == '__main__':
    main()
