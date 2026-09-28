#!/usr/bin/env python3
"""First-factor affine A7 cells, charged as an integer correction to packed signs."""
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
OUT = ROOT / 'binary-input-affine/receipt.json'


def digest(data):
    return hashlib.sha256(np.ascontiguousarray(data).tobytes()).hexdigest()


def file_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rms(y, target):
    return float(np.linalg.norm(y - target) / np.linalg.norm(target))


def first_codes(x, mode):
    b = x.reshape(len(x), -1, 32)
    magnitude = np.abs(b).max(axis=2)
    maximum = np.maximum(magnitude.max(axis=1), 1e-30)
    exponent = np.clip(np.floor(np.log2(maximum[:, None] / np.maximum(magnitude, 1e-30))).astype(np.int32), 0, 8)
    upper = maximum[:, None] / 63 * np.exp2(-exponent)
    use_three = (magnitude / 63 <= .77 * upper) & (exponent < 8)
    step = np.where(use_three, .75 * upper, upper)
    weight = np.where(use_three, 3 << np.maximum(7 - exponent, 0), 1 << (9 - exponent)).astype(np.int32)
    if mode == 'symmetric':
        z = np.zeros(step.shape, dtype=np.int32)
    elif mode == 'midrange':
        z = np.clip(np.rint((b.max(axis=2) + b.min(axis=2)) / (2 * step) + .5), -8, 8).astype(np.int32)
    elif mode == 'local_sse':
        candidates = [0, *range(1, 9), *range(-1, -9, -1)]
        best = np.full(step.shape, np.inf)
        z = np.zeros(step.shape, dtype=np.int32)
        for offset in candidates:
            q = np.clip(np.rint(b / step[:, :, None] - offset), -64, 63)
            loss = np.sum((b - (q + offset) * step[:, :, None]) ** 2, axis=2)
            select = loss < best - 1e-24
            z[select] = offset
            best = np.minimum(best, loss)
    else:
        raise ValueError(mode)
    q = np.clip(np.rint(b / step[:, :, None] - z[:, :, None]), -64, 63).astype(np.int32)
    return q, z, weight, maximum / (63 * 512)


def first_response(signs, q, z, weight):
    grouped = signs.reshape(signs.shape[0], -1, 32)
    partial = np.einsum('ngc,bgc->bng', grouped, q, optimize=True)
    sums = grouped.sum(axis=2)
    corrected = partial + z[:, None, :] * sums[None, :, :]
    return np.einsum('bng,bg->bn', corrected, weight, optimize=True).astype(np.int32), sums


def second_response(signs, h):
    b = h.reshape(len(h), -1, 32)
    magnitude = np.abs(b).max(axis=2)
    maximum = np.maximum(magnitude.max(axis=1), 1)
    exponent = np.clip(np.floor(np.log2(maximum[:, None] / np.maximum(magnitude, 1))).astype(np.int32), 0, 8)
    upper = maximum[:, None] / (63 * np.exp2(exponent))
    use_three = (magnitude / 63 <= .77 * upper) & (exponent < 8)
    step = np.where(use_three, .75 * upper, upper)
    weight = np.where(use_three, 3 << np.maximum(7 - exponent, 0), 1 << (9 - exponent)).astype(np.int32)
    q = np.clip(np.rint(b / step[:, :, None]), -64, 63).astype(np.int32)
    partial = np.einsum('ngc,bgc->bng', signs.reshape(signs.shape[0], -1, 32), q, optimize=True)
    return np.einsum('bng,bg->bn', partial, weight, optimize=True), maximum / (63 * 512)


def run(layer):
    image = ROOT / f'binary-factors/fixtures/model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
    fixture = ROOT / f'fixtures/qwen3-0.6b-wikitext/layer{layer:02d}-mlp_up_proj.npz'
    with np.load(image) as f:
        k = int(f['dimensions'][1]); rank = int(f['dimensions'][2])
        vs = (2 * np.unpackbits(f['V'], axis=1, count=k, bitorder='little').astype(np.int32) - 1)
        us = (2 * np.unpackbits(f['U'], axis=1, count=rank, bitorder='little').astype(np.int32) - 1)
        pre, post = f['scale_pre'].astype(np.float64), f['scale_post'].astype(np.float64)
    with np.load(fixture) as f:
        x = np.concatenate((f['train'][576:640], f['validation'][576:704])).astype(np.float64) * pre
    truth = ((x @ vs.T.astype(np.float64)) @ us.T.astype(np.float64)) * post
    arms = {}
    reference_codes, _, reference_weight, _ = first_codes(x, 'symmetric')
    reference_h, _ = first_response(vs, reference_codes, np.zeros(reference_weight.shape, dtype=np.int32), reference_weight)
    for mode in ('symmetric', 'midrange', 'local_sse'):
        q, z, weight, scale1 = first_codes(x, mode)
        h, sums = first_response(vs, q, z, weight)
        yi, scale2 = second_response(us, h)
        y = yi.astype(np.float64) * (scale1 * scale2)[:, None] * post
        delta = q + z[:, :, None] - reference_codes
        changed = delta != 0
        sparse_h = reference_h.astype(np.int64).copy()
        for row, group, position in np.argwhere(changed):
            sparse_h[row] += int(delta[row, group, position] * weight[row, group]) * vs[:, group * 32 + position]
        assert np.array_equal(sparse_h, h)
        if mode == 'symmetric':
            assert not np.any(changed)
        arms[mode] = {
            'held_sparse_replay_sha256': digest(sparse_h[64:]),
            'held_changed_activation_cells': int(changed[64:].sum()),
            'held_changed_activation_groups': int(np.any(changed[64:], axis=2).sum()),
            'held_signed_correction_terms_if_sparse': int(changed[64:].sum() * vs.shape[0]),
            'held_changed_delta_range': [int(delta[64:].min()), int(delta[64:].max())],
            'train_rms': rms(y[:64], truth[:64]), 'held_rms': rms(y[64:], truth[64:]),
            'held_wins_against_symmetric': None,
            'nonzero_centers': int(np.count_nonzero(z)), 'held_nonzero_centers': int(np.count_nonzero(z[64:])),
            'held_centers_sha256': digest(z[64:].astype('<i2')),
            'held_effective_codes_sha256': digest((q + z[:, :, None])[64:].astype('<i2')),
            'held_first_sha256': digest(h[64:]), 'held_final_sha256': digest(yi[64:]),
            'max_first_abs': int(np.max(np.abs(h))), 'max_final_abs': int(np.max(np.abs(yi))),
        }
        arms[mode]['held_per_row'] = [rms(a, b) for a, b in zip(y[64:], truth[64:])]
    for mode in ('midrange', 'local_sse'):
        arms[mode]['held_wins_against_symmetric'] = sum(a < b for a, b in zip(arms[mode]['held_per_row'], arms['symmetric']['held_per_row']))
    for arm in arms.values():
        del arm['held_per_row']
    return {'layer': layer, 'image': str(image), 'image_sha256': file_hash(image), 'fixture_sha256': file_hash(fixture),
            'first_group_sign_sums_sha256': digest(sums.astype('<i1')), 'dimensions': [len(x), vs.shape[0], k, us.shape[0]], 'arms': arms}


def main():
    entries = [run(layer) for layer in (0, 7, 14, 27)]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'source_sha256': file_hash(Path(__file__)), 'numpy_version': np.__version__,
        'contract': 'Paid .55 binary mlp_up U/V, 64 train[576:640] and 128 disjoint held validation[576:704] original-producer rows. Both stages A7 C8 threshold .77. The first stage selects one integer group center z in [-8,8] dynamically; signed A7 codes round(x/step-z), with exactly reconstructed integer response sum(weight*(dot(q,V)+z*sum(V))). Second stage symmetric. FP64 paid-image unrounded response target. No GPU, model loss or native time.',
        'entries': entries}, indent=2) + '\n')
    for e in entries:
        print(e['layer'], [(k, round(a['train_rms'], 7), round(a['held_rms'], 7), a['held_wins_against_symmetric'], a['held_nonzero_centers']) for k, a in e['arms'].items()], flush=True)
    print(OUT)


if __name__ == '__main__':
    main()
