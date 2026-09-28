#!/usr/bin/env python3
"""Fit smaller output-sign alphabets against paid first-factor responses."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/kelana-subbit')
DEST = BASE / 'binary-orbit-fit'
CAPS = (128, 112, 96, 64)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def codes(bits):
    packed = np.packbits(bits.reshape(bits.shape[0], -1, 8), axis=2, bitorder='little')[:, :, 0]
    return (packed >> 1) ^ np.where(packed & 1, 0, 127).astype(np.uint8)


def alphabet_distances(h):
    signs = 2 * ((np.arange(128)[:, None] >> np.arange(7)) & 1).astype(np.float64) - 1
    forms = np.concatenate((np.ones((128, 1)), signs), axis=1)
    covariance = h.T @ h / len(h)
    differences = forms[:, None, :] - forms[None, :, :]
    return np.maximum(np.einsum('abi,ij,abj->ab', differences, covariance, differences, optimize=True), 0)


def remove_to_cap(distance, frequency, cap):
    """Delete the representative with least increase in optimal fixed-alphabet local distortion."""
    live = np.ones(128, dtype=bool)
    while np.count_nonzero(live) > cap:
        labels = np.flatnonzero(live)
        ranked = np.argsort(distance[:, labels], axis=1, kind='stable')[:, :2]
        nearest = labels[ranked[:, 0]]
        first = distance[np.arange(128), nearest]
        second = distance[np.arange(128), labels[ranked[:, 1]]]
        surcharge = np.bincount(nearest, weights=frequency * (second - first), minlength=128)
        live[labels[np.argmin(surcharge[labels])]] = False
    labels = np.flatnonzero(live)
    return labels[np.argmin(distance[:, labels], axis=1)].astype(np.uint8)


def rms(y, target):
    return float(np.linalg.norm(y - target) / np.linalg.norm(target))


def signs_from_codes(u, labels):
    n, rank = u.shape
    basis = np.concatenate((np.ones((128, 1), dtype=np.int8),
                            2 * ((np.arange(128)[:, None] >> np.arange(7)) & 1).astype(np.int8) - 1), axis=1)
    anchor = 2 * u.reshape(n, -1, 8)[:, :, 0].astype(np.int8) - 1
    return (basis[labels] * anchor[:, :, None]).reshape(n, rank).astype(np.float32)


def fit_teacher_rows(labels, u, first, post, target):
    """One exact row/block conditional least-squares pass over the allowed orbit labels."""
    n, chunks = labels.shape
    result = labels.copy()
    current = (first @ signs_from_codes(u, result).T) * post
    anchor = 2 * u.reshape(n, chunks, 8)[:, :, 0].astype(np.int8) - 1
    basis = np.concatenate((np.ones((128, 1), dtype=np.float32),
                            2 * ((np.arange(128)[:, None] >> np.arange(7)) & 1).astype(np.float32) - 1), axis=1)
    for j in range(chunks):
        allowed = np.unique(result[:, j])
        response = first[:, j*8:(j+1)*8] @ basis[allowed].T
        old_response = first[:, j*8:(j+1)*8] @ basis[result[:, j]].T
        residual = (target - current) / post[None, :] + anchor[:, j][None, :] * old_response
        # Rows choose independently. Squared error omits the row-constant norm of residual.
        candidates = response.T @ residual
        cost = np.sum(response ** 2, axis=0)[:, None] - 2 * candidates * anchor[:, j][None, :]
        next_labels = allowed[np.argmin(cost, axis=0)]
        new_response = response[:, np.searchsorted(allowed, next_labels)]
        current += (new_response - old_response) * (post * anchor[:, j])[None, :]
        result[:, j] = next_labels
    return result


def measure(layer):
    image = BASE / f'binary-factors/fixtures/model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
    fixture = BASE / f'fixtures/qwen3-0.6b-wikitext/layer{layer:02d}-mlp_up_proj.npz'
    with np.load(image) as a:
        n, k, rank = map(int, a['dimensions'])
        u = np.unpackbits(a['U'], axis=1, count=rank, bitorder='little')
        v = 2 * np.unpackbits(a['V'], axis=1, count=k, bitorder='little').astype(np.float32) - 1
        pre, post = a['scale_pre'].astype(np.float32), a['scale_post'].astype(np.float32)
    with np.load(fixture) as f:
        train = f['train'][:512].copy()
        held = f['validation'][:128].copy()
        teacher = f['weight'].copy()
    old = codes(u)
    signs = (2 * u.astype(np.float32) - 1)
    first_train = (train * pre) @ v.T
    first_held = (held * pre) @ v.T
    frozen = (first_held @ signs.T) * post
    original = held @ teacher.T
    train_teacher = train @ teacher.T
    arrays = {cap: old.copy() for cap in CAPS}
    occupancy = []
    for j in range(rank // 8):
        word = old[:, j]
        frequency = np.bincount(word, weights=post.astype(np.float64) ** 2, minlength=128)
        d = alphabet_distances(first_train[:, 8*j:8*j+8].astype(np.float64))
        occupancy.append(int(np.count_nonzero(np.bincount(word, minlength=128))))
        for cap in CAPS:
            mapping = remove_to_cap(d, frequency, cap)
            arrays[cap][:, j] = mapping[word]
    result = {'layer': layer, 'image': str(image), 'image_sha256': sha(image),
              'fixture': str(fixture), 'fixture_sha256': sha(fixture),
              'train_rows': 512, 'held_rows': 128, 'n': n, 'k': k, 'rank': rank,
              'frozen_vs_teacher_rms': rms(frozen, original),
              'first_stage_used_entries': None, 'output_old_entries': sum(occupancy), 'caps': {}}
    for cap in CAPS:
        new = arrays[cap]
        changed = int(np.count_nonzero(new != old))
        prediction = (first_held @ signs_from_codes(u, new).T) * post
        row_fit = None
        if cap in (128, 112, 96):
            fitted = fit_teacher_rows(new, u, first_train, post, train_teacher)
            fit_held = (first_held @ signs_from_codes(u, fitted).T) * post
            fit_train = (first_train @ signs_from_codes(u, fitted).T) * post
            fitted_u = np.packbits((signs_from_codes(u, fitted) > 0).astype(np.uint8), axis=1, bitorder='little')
            output_path = DEST / f'layer{layer}-cap{cap}-teacher-fit.npz'
            output_path.parent.mkdir(parents=True, exist_ok=True)
            np.savez_compressed(output_path, U=fitted_u, scale_pre=pre, scale_post=post,
                                original_image_sha256=sha(image))
            row_fit = {'train_vs_teacher_rms': rms(fit_train, train_teacher),
                       'held_vs_teacher_rms': rms(fit_held, original),
                       'held_vs_frozen_rms': rms(fit_held, frozen),
                       'changed_chunks': int(np.count_nonzero(fitted != old)),
                       'output_used_entries': int(sum(np.count_nonzero(np.bincount(fitted[:, j], minlength=128)) for j in range(rank // 8))),
                       'packed_output_sha256': hashlib.sha256(fitted_u.tobytes()).hexdigest(),
                       'image_path': str(output_path), 'image_sha256': sha(output_path)}
        result['caps'][str(cap)] = {
            'output_used_entries': int(sum(np.count_nonzero(np.bincount(new[:, j], minlength=128)) for j in range(rank // 8))),
            'changed_chunks': changed, 'all_chunks': int(new.size),
            'output_half_table_entries_upper': int(cap * (rank // 8)),
            'output_gray_updates_upper': int((cap - 1) * (rank // 8)),
            'against_frozen_rms': rms(prediction, frozen),
            'against_teacher_rms': rms(prediction, original),
            'per_input_against_frozen_rms': [rms(p, q) for p, q in zip(prediction, frozen)],
            'packed_output_sha256': hashlib.sha256(np.packbits((signs_from_codes(u, new) > 0).astype(np.uint8), axis=1, bitorder='little').tobytes()).hexdigest(),
            'teacher_row_fit': row_fit,
        }
    return result


def main():
    layer = int(sys.argv[1])
    r = measure(layer)
    DEST.mkdir(parents=True, exist_ok=True)
    output = DEST / f'layer{layer}.json'
    output.write_text(json.dumps({'source_sha256': sha(Path(__file__)), 'record': r}, indent=2) + '\n')
    print(layer, 'frozen vs teacher', r['frozen_vs_teacher_rms'])
    for cap, record in r['caps'].items():
        print(cap, record['changed_chunks'], record['against_frozen_rms'], record['against_teacher_rms'], record['teacher_row_fit'])
    print(output)


if __name__ == '__main__':
    main()
