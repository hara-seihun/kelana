#!/usr/bin/env python3
"""Exact rational rank witnesses for the observed Qwen routed weighted sum."""
import hashlib
import json
from pathlib import Path
import numpy as np

DATA = Path('/path/to/workspace/data/qwen-moe/all-producers')
OUT = Path('/path/to/workspace/data/qwen-moe/score-observation-rank/receipt.json')
PRIMES = (251, 257)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def integer_mod(bits, prime):
    """The exact binary32 value times 2**149, reduced modulo prime."""
    bits = int(bits)
    exponent = (bits >> 23) & 255
    fraction = bits & 0x7fffff
    if exponent == 255:
        raise ValueError('non-finite captured output')
    mantissa = fraction if exponent == 0 else fraction | 0x800000
    value = mantissa * pow(2, max(0, exponent - 1), prime)
    return (-value if bits >> 31 else value) % prime


def determinant_mod(matrix, p):
    a = [[v % p for v in row] for row in matrix]
    det = 1
    for j in range(7):
        pivot = next((i for i in range(j, 7) if a[i][j]), None)
        if pivot is None:
            return 0
        if pivot != j:
            a[j], a[pivot] = a[pivot], a[j]
            det = -det
        x = a[j][j]
        det = det * x % p
        inverse = pow(x, -1, p)
        for i in range(j + 1, 7):
            ratio = a[i][j] * inverse % p
            for k in range(j + 1, 7):
                a[i][k] = (a[i][k] - ratio * a[j][k]) % p
    return det % p


def witness(row):
    bits = row.view(np.uint32)
    # The first 224 output coordinates give 32 disjoint minor attempts.
    for p in PRIMES:
        for start in range(0, 224, 7):
            cols = [[integer_mod(bits[e, c], p) for e in range(8)]
                    for c in range(start, start + 7)]
            mat = [[(v[e] - v[0]) % p for e in range(1, 8)] for v in cols]
            d = determinant_mod(mat, p)
            if d:
                return {'prime': p, 'output_start': start, 'determinant_mod_prime': d}
    return None


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    layers = []
    source_hashes = {}
    all_witnesses = []
    min_score = float('inf')
    max_score_sum_error = 0.0
    for split in ('train', 'held'):
        split_counts = []
        for layer in range(40):
            prefix = f'{split}.layer-{layer}.'
            paths = {name: DATA / (prefix + name + ext) for name, ext in
                     (('ffn_moe_down', '.f32'), ('ffn_moe_weights_norm', '.f32'),
                      ('ffn_moe_topk', '.i32'))}
            for name, path in paths.items():
                source_hashes[f'{split}/{layer}/{name}'] = sha(path)
            outputs = np.fromfile(paths['ffn_moe_down'], dtype='<f4')
            scores = np.fromfile(paths['ffn_moe_weights_norm'], dtype='<f4')
            ids = np.fromfile(paths['ffn_moe_topk'], dtype='<i4')
            assert outputs.size == 64 * 8 * 2048 and scores.size == 64 * 8 and ids.size == 64 * 8
            outputs = outputs.reshape(64, 8, 2048)
            scores = scores.reshape(64, 8)
            ids = ids.reshape(64, 8)
            assert np.isfinite(outputs).all() and np.isfinite(scores).all()
            assert all(len(set(row)) == 8 for row in ids.tolist())
            assert (scores > 0).all()
            min_score = min(min_score, float(scores.min()))
            max_score_sum_error = max(max_score_sum_error,
                                      float(np.max(np.abs(scores.astype(np.float64).sum(axis=1) - 1))))
            witnesses = [witness(row) for row in outputs]
            successes = sum(w is not None for w in witnesses)
            split_counts.append(successes)
            layers.append({'split': split, 'layer': layer, 'rank7_certified': successes,
                           'witnesses': witnesses})
            all_witnesses.extend(witnesses)
    assert max_score_sum_error < 1e-5
    result = {'contract': 'For fixed eight decoded captured down outputs, vary only seven independent positive normalized router scores. Each nonzero 7x7 minor of output differences certifies rational rank seven of the complete weighted-sum observation. FP32 values are interpreted as exact dyadic rationals; this is not a native FP32 reduction identity, complete-model loss, or a speed bound.',
              'source_sha256': sha(Path(__file__)),
              'capture_receipt_sha256': sha(DATA / 'receipt.json'),
              'capture_hashes_sha256': hashlib.sha256(json.dumps(source_hashes, sort_keys=True).encode()).hexdigest(),
              'capture_hashes': source_hashes,
              'total': len(all_witnesses), 'certified': sum(w is not None for w in all_witnesses),
              'prime_counts': {str(p): sum(w is not None and w['prime'] == p for w in all_witnesses) for p in PRIMES},
              'nonzero_minor_count_first_seven': sum(w is not None and w['output_start'] == 0 for w in all_witnesses),
              'minimum_score': min_score, 'maximum_normalized_score_sum_error': max_score_sum_error,
              'layers': layers}
    OUT.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(OUT), 'sha256': sha(OUT), 'certified': result['certified'],
                      'total': result['total'], 'first_seven': result['nonzero_minor_count_first_seven'],
                      'prime_counts': result['prime_counts'], 'minimum_score': min_score,
                      'maximum_score_sum_error': max_score_sum_error}, indent=2))


if __name__ == '__main__':
    main()
