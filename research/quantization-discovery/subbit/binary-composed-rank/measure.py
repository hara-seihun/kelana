#!/usr/bin/env python3
"""Zero-rate rank swaps fitted to the complete paid binary-factor A7 response."""
import hashlib
import json
import runpy
from pathlib import Path

import numpy as np

PARENT_PATH = Path(__file__).resolve().parents[1] / 'binary-rank-gauge/measure.py'
PARENT = runpy.run_path(str(PARENT_PATH))
ROOT = Path('/path/to/workspace/data/kelana-subbit')
OUT = ROOT / 'binary-composed-rank/receipt.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def codes(values, global_max, threshold):
    n = values.shape[0]
    grouped = values.reshape(n, -1, 32)
    peak = np.max(np.abs(grouped), axis=2)
    exponent = np.clip(np.floor(np.log2(global_max[:, None] / np.maximum(peak, 1e-30))).astype(np.int32), 0, 8)
    upper = global_max[:, None] / 63 * np.exp2(-exponent.astype(np.float64))
    three = (peak / 63 <= upper * threshold) & (exponent < 8)
    step = np.where(three, upper * .75, upper)
    weight = np.where(three, 3 << (7 - exponent), 1 << (9 - exponent))
    return (np.clip(np.rint(grouped / step[:, :, None]), -64, 63) * weight[:, :, None]).reshape(n, -1).astype(np.int32)


def prepared(h, b1, hreal, u, post, perm, threshold, ntrain):
    global_max = np.maximum(np.max(np.abs(h), axis=1), 1e-30)
    b2 = global_max / 63 * 2.0 ** -9
    scale = b1 * b2
    rank_codes = np.zeros_like(h)
    rank_codes[:, perm] = codes(h[:, perm], global_max, threshold)
    # U.T @ diag(post**2) @ U is the complete output observer's metric.
    weighted_u = u.astype(np.float64) * post[:, None]
    gram = weighted_u.T @ weighted_u
    residual = rank_codes[:ntrain] * scale[:ntrain, None] - hreal[:ntrain]
    return global_max, scale, rank_codes, gram, residual, residual @ gram


def objective(residual, gram):
    return float(np.einsum('ni,ij,nj->', residual, gram, residual, optimize=True))


def fit(h, global_max, scale, perm, rank_codes, gram, residual, projected, threshold, attempts, seed):
    rng = np.random.default_rng(seed)
    perm = perm.copy()
    rank_codes = rank_codes.copy()
    current = objective(residual, gram)
    start = current
    accepted = 0
    for _ in range(attempts):
        a, b = rng.integers(0, perm.size, size=2)
        ga, gb = a // 32, b // 32
        if ga == gb:
            continue
        perm[a], perm[b] = perm[b], perm[a]
        slots = np.r_[np.arange(ga * 32, ga * 32 + 32), np.arange(gb * 32, gb * 32 + 32)]
        ranks = perm[slots]
        proposed = codes(h[:len(residual), ranks], global_max[:len(residual)], threshold)
        delta = (proposed - rank_codes[:len(residual), ranks]) * scale[:len(residual), None]
        change = 2 * np.sum(delta * projected[:, ranks]) + np.sum((delta @ gram[np.ix_(ranks, ranks)]) * delta)
        if change < -1e-10:
            rank_codes[:, ranks] = codes(h[:, ranks], global_max, threshold)
            residual[:, ranks] += delta
            projected += delta @ gram[ranks, :]
            current += float(change)
            accepted += 1
        else:
            perm[a], perm[b] = perm[b], perm[a]
    assert abs(objective(residual, gram) - current) < 1e-5 * start
    return perm, rank_codes, start, current, accepted


def arm(perm, rank_codes, scale, hreal, u, post, ntrain, vs):
    # Reading the rank codes in packed factor order must match the original-rank scatter.
    up = np.packbits(((u[:, perm] + 1) // 2).astype(np.uint8), axis=1, bitorder='little')
    vp = np.packbits(((vs[perm] + 1) // 2).astype(np.uint8), axis=1, bitorder='little')
    predicted = ((rank_codes.astype(np.float64) * scale[:, None]) @ u.astype(np.float64).T) * post
    truth = (hreal @ u.astype(np.float64).T) * post
    return {
        'train_rms': PARENT['error'](predicted[:ntrain], truth[:ntrain]),
        'held_rms': PARENT['error'](predicted[ntrain:], truth[ntrain:]),
        'held_per_input': PARENT['split_errors'](predicted[ntrain:], truth[ntrain:]),
        'held_integer_sha256': hashlib.sha256(np.ascontiguousarray(rank_codes[ntrain:, perm]).tobytes()).hexdigest(),
        'packed_v_sha256': hashlib.sha256(vp.tobytes()).hexdigest(),
        'packed_u_sha256': hashlib.sha256(up.tobytes()).hexdigest(),
        'permutation_sha256': hashlib.sha256(perm.astype('<i4').tobytes()).hexdigest(),
    }


def run(layer, attempts, train_start, train_count, held_start, held_count):
    image = ROOT / f'binary-factors/fixtures/model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
    fixture = ROOT / f'fixtures/qwen3-0.6b-wikitext/layer{layer:02d}-mlp_up_proj.npz'
    with np.load(image) as data:
        v, u = data['V'], data['U']
        pre, post = data['scale_pre'].astype(np.float64), data['scale_post'].astype(np.float64)
    vs = 2 * np.unpackbits(v, axis=1, count=1024, bitorder='little').astype(np.int32) - 1
    us = 2 * np.unpackbits(u, axis=1, count=384, bitorder='little').astype(np.int32) - 1
    with np.load(fixture) as data:
        x = np.concatenate((data['train'][train_start:train_start + train_count],
                            data['validation'][held_start:held_start + held_count])).astype(np.float64) * pre
    first = .77 if layer == 0 else .78
    h, b1 = PARENT['stage'](vs, x, first)
    hreal = x @ vs.T.astype(np.float64)
    rank = np.argsort(-np.mean(h[:train_count].astype(np.float64)**2, axis=0), kind='stable')
    max_h, scale, rc, gram, residual, projected = prepared(h, b1, hreal, us, post, rank, .77, train_count)
    before = arm(rank, rc, scale, hreal, us, post, train_count, vs)
    fitted, new_codes, initial, final, accepted = fit(h, max_h, scale, rank, rc, gram, residual, projected, .77, attempts, 931 + layer)
    after = arm(fitted, new_codes, scale, hreal, us, post, train_count, vs)
    # This independent full output replay also catches a misplaced rank scatter.
    full, second_base = PARENT['stage'](us[:, fitted], h[:, fitted], .77)
    assert np.array_equal(full, new_codes[:, fitted] @ us[:, fitted].T)
    assert np.array_equal(second_base, max_h / 63 * 2.0 ** -9)
    return {'layer': layer, 'train_rows': [train_start, train_start + train_count],
            'held_rows': [held_start, held_start + held_count],
            'attempts': attempts, 'image_sha256': sha(image), 'fixture_sha256': sha(fixture),
            'first_integer_sha256': hashlib.sha256(np.ascontiguousarray(h).tobytes()).hexdigest(),
            'accepted_swaps': accepted, 'train_output_sse_before': initial, 'train_output_sse_after': final,
            'sorted': before, 'composed_fit': after}


def main():
    entries = [run(layer, 2400, 512, 64, 512, 64) for layer in (0, 14)]
    entries += [run(layer, 1200, 1024, 256, 768, 128) for layer in (0, 14)]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(PARENT_PATH),
        'numpy_version': np.__version__,
        'contract': 'Frozen paid Qwen3-0.6B mlp_up binary factors; disjoint train and validation spans per entry. Fixed first-stage thresholds .77/.78 and second .77, 32-rank A7 ladder. Train objective is complete post-scaled two-factor response SSE. Same-image FP64 real response. Rank permutation repacks V rows and U columns, preserving weight bits and direct-reader work. Original-producer CPU only, no model NLL or native time.',
        'entries': entries}, indent=2) + '\n')
    for entry in entries:
        print(entry['layer'], 'swaps', entry['accepted_swaps'], 'train', entry['sorted']['train_rms'], entry['composed_fit']['train_rms'], 'held', entry['sorted']['held_rms'], entry['composed_fit']['held_rms'], flush=True)
    print(OUT)


if __name__ == '__main__':
    main()
