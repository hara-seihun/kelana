#!/usr/bin/env python3
"""Causal whole-row V label merging under a fixed append-only dictionary capacity."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
SUB = HERE.parent
sys.path.insert(0, str(SUB / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def labels(rows, capacity, projected):
    """First-seen representatives, exact duplicate reuse, then nearest paid-output response."""
    centers = []
    projections = []
    ids = []
    exact = {}
    for row, vector in zip(rows, projected):
        key = row.tobytes()
        if key in exact:
            chosen = exact[key]
        elif len(centers) < capacity:
            chosen = len(centers)
            centers.append(row.copy())
            projections.append(vector)
            exact[key] = chosen
        else:
            delta = np.asarray(projections) - vector
            chosen = int(np.argmin(np.einsum('ki,ki->k', delta, delta)))
            # The same input code has the same assigned label within this block.
            exact[key] = chosen
        ids.append(chosen)
    return np.asarray(centers, dtype=np.int8), np.asarray(ids, dtype=np.uint8), len(exact)


def run(layer):
    torch.set_num_threads(8)
    parent_path = DATA / 'value-int8-consumer' / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    fixture_path = DATA / 'value-cache-mixed-rate' / f'layer{layer:02d}-validation.npz'
    assert sha(MODEL) == parent['model_sha256']
    assert sha(image_path) == parent['image_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == parent['capture_sha256']
    spec = importlib.util.spec_from_file_location('paid_factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    with np.load(fixture_path) as cached:
        p = torch.from_numpy(cached['p'].copy())
        teacher = torch.from_numpy(cached['y'].copy()).reshape(4, 256, 1024)
    scales = json.loads((DATA / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())['scales']
    capacities = (64, 96, 128, 256)
    output = {k: torch.zeros_like(teacher) for k in capacities}
    control = torch.zeros_like(teacher)
    stats = {str(k): [] for k in capacities}
    code_hash = []
    with np.load(image_path) as image:
        for g in range(8):
            packed = {name: image[name][g].copy() for name in image.files}
            right = decoder.decode(packed, 'right')
            left = decoder.decode(packed, 'left')
            z = (x @ right.T).to(torch.bfloat16).float()
            step = torch.tensor(scales[str(g)]['int8_coordinate'], dtype=torch.float16).float()
            code = (z / step).round().clamp(-127, 127).to(torch.int8).numpy()
            code_hash.append(hashlib.sha256(code.tobytes()).hexdigest())
            # One byte-ID shared across all eight groups. A key's output-aware
            # distance sums both paid head maps, with the frozen per-coordinate
            # FP16 cache scale folded into the metric; no teacher labels used.
            # Build all eight groups' metrics once below, outside the group loop.
            if g == 0:
                codes = [None] * 8
                lefts = [None] * 8
                steps = [None] * 8
            codes[g], lefts[g], steps[g] = code, left, step
    assert code_hash == parent['code_sha256_by_group']
    metrics = []
    for g in range(8):
        a = lefts[g].reshape(2, 1024, 28).double().numpy()
        s = steps[g].double().numpy()
        metrics.append(sum((a[h] * s).T @ (a[h] * s) for h in range(2)))
    original = np.concatenate(codes, axis=-1)
    rotations = []
    for block in metrics:
        values, vectors = np.linalg.eigh(block)
        rotations.append(vectors * np.sqrt(np.maximum(values, 0)))
    projected = np.concatenate([original[..., 28*g:28*g+28].astype(np.float64) @ rotations[g]
                                for g in range(8)], axis=-1)
    for window in range(4):
        row = original[window]
        for capacity in capacities:
            centers, ids, distinct = labels(row, capacity, projected[window])
            reconstructed = centers[ids]
            n = len(centers)
            assert n <= capacity
            if capacity == 256:
                assert np.array_equal(reconstructed, row)
            seen = set()
            prefix_uses = 0
            for label in ids:
                seen.add(int(label))
                prefix_uses += len(seen)
            record = dict(window=window, capacity=capacity, distinct_input_codes=distinct,
                          representatives=n, bytes=224*n+256+6,
                          causal_label_uses_per_group=prefix_uses,
                          two_head_label_products=56*prefix_uses,
                          ids_sha256=hashlib.sha256(ids.tobytes()).hexdigest(),
                          centers_sha256=hashlib.sha256(centers.tobytes()).hexdigest(),
                          changed_keys=int(np.count_nonzero(np.any(reconstructed != row, axis=1))))
            stats[str(capacity)].append(record)
            for g in range(8):
                for h in range(2):
                    ah = lefts[g][h*1024:(h+1)*1024]
                    values = torch.from_numpy(reconstructed[:, 28*g:28*g+28].copy()).float() * steps[g]
                    output[capacity][window] += (p[window, 2*g+h] @ values) @ ah.T
        for g in range(8):
            values = torch.from_numpy(codes[g][window].copy()).float() * steps[g]
            for h in range(2):
                ah = lefts[g][h*1024:(h+1)*1024]
                control[window] += (p[window, 2*g+h] @ values) @ ah.T
    def error(y, ref):
        return float((y-ref).square().sum() / ref.square().sum())
    for capacity in capacities:
        for window, item in enumerate(stats[str(capacity)]):
            item['teacher_error'] = error(output[capacity][window], teacher[window])
            item['paid_change_error'] = error(output[capacity][window], control[window])
            item['bytes_per_key'] = item['bytes'] / 256
    receipt = dict(layer=layer, source_sha256=sha(__file__), image_sha256=sha(image_path),
                   model_sha256=sha(MODEL), capture_sha256=sha(CAPTURES / f'layer{layer:02d}.npz'),
                   fixture_sha256=sha(fixture_path), parent_sha256=sha(parent_path), decoder_sha256=sha(SOURCE),
                   code_sha256_by_group=code_hash, base_teacher_error=error(control, teacher),
                   parent_mass4095_teacher_error=parent['scores']['int8_mass4095']['teacher'],
                   arms={str(k): {'bytes_per_key': sum(v['bytes'] for v in stats[str(k)])/1024,
                                   'causal_label_uses_per_group': sum(v['causal_label_uses_per_group'] for v in stats[str(k)]),
                                   'teacher_error': error(output[k], teacher),
                                   'paid_change_error': error(output[k], control),
                                   'per_window': stats[str(k)]} for k in capacities},
                   contract='Exploratory four original-producer held 256-token windows. Append first-seen complete int8 rows until capacity; thereafter use nearest existing row in the two-head paid O Gram with FP16 steps. IDs and rows are immutable. One shared uint8 ID, uint16 count and uint32 arena address per 256-key block. Original floating attention and paid O score the changed cache map; a native integer-mass reader would change rounding. Count products exclude per-query histogram scatter, nearest-center append search, count setup, O and physical traffic. No native reader or full model.')
    dest = DATA / 'value-online-merging' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'receipt': str(dest), 'base': receipt['base_teacher_error'],
                      'arms': {k: {q: v[q] for q in ('bytes_per_key','teacher_error','paid_change_error')} for k,v in receipt['arms'].items()}}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
