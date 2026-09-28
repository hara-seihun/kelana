#!/usr/bin/env python3
"""Train shared short-vector labels, then consume their responses without unpacking."""
import hashlib
import json
import time
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
FIXTURE = HERE.parents[1] / 'instances/bonsai-layer00-down-block0.npz'
LENGTH = 16
ROWS_TRAIN = 4096
SEED = 27091


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def distances(x, centers):
    x = np.asarray(x, np.float32)
    centers = np.asarray(centers, np.float32)
    return np.maximum(0, (x*x).sum(1)[:, None] + (centers*centers).sum(1)[None, :] - 2*x@centers.T)


def train_kmeans(x, k, rng, steps=12):
    """Lloyd's descent from data samples, with a deterministic empty-cell repair."""
    centers = x[rng.choice(len(x), k, replace=False)].astype(np.float32).copy()
    for _ in range(steps):
        labels = distances(x, centers).argmin(1)
        counts = np.bincount(labels, minlength=k)
        sums = np.zeros((k, LENGTH), np.float32)
        np.add.at(sums, labels, x)
        nonempty = counts != 0
        centers[nonempty] = sums[nonempty] / counts[nonempty, None]
        empty = np.flatnonzero(~nonempty)
        if len(empty):
            far = np.partition(distances(x, centers).min(1), -len(empty))[-len(empty):]
            centers[empty] = x[np.flatnonzero(distances(x, centers).min(1) >= far.min())[:len(empty)]]
    return centers


def train_additive(x, rng):
    """Two 16-entry full-vector codebooks, alternating label and centroid steps."""
    a = train_kmeans(x, 16, rng, 12)
    ia = distances(x, a).argmin(1)
    b = train_kmeans(x-a[ia], 16, rng, 12)
    ib = distances(x-a[ia], b).argmin(1)
    for _ in range(6):
        ia = distances(x-b[ib], a).argmin(1)
        a = centroids(x-b[ib], ia, a)
        ib = distances(x-a[ia], b).argmin(1)
        b = centroids(x-a[ia], ib, b)
    return a, b


def centroids(x, labels, previous):
    counts = np.bincount(labels, minlength=len(previous))
    sums = np.zeros_like(previous)
    np.add.at(sums, labels, x)
    updated = previous.copy()
    mask = counts > 0
    updated[mask] = sums[mask]/counts[mask, None]
    return updated


def quantize(centers):
    # One fixed shared 1/64 coefficient unit. No per-vector floating scale.
    q = np.rint(centers * 64)
    if np.max(np.abs(q)) > 127:
        raise ValueError('codebook coefficient exceeds signed byte')
    return q.astype(np.int8)


def metric(query_train):
    # Four captures cannot estimate a portable 16-dimensional covariance.
    # Keep code assignments isotropic; short.py prices calibration-weighted
    # assignments separately against disjoint held-out inputs.
    variance = np.mean(query_train*query_train)
    return np.eye(LENGTH)*np.sqrt(variance)


def assign(weights, codes, qtrain):
    """Full-vector response distortion for each segment, no held-out inputs."""
    rows, segments, length = weights.shape
    labels = np.empty((rows, segments), np.int32)
    cost = np.empty(segments, np.float64)
    code_f = codes.astype(np.float32) / 64
    for s in range(segments):
        projection = metric(qtrain[:, s])
        x = weights[:, s].astype(np.float32) @ projection
        c = code_f @ projection
        labels[:, s] = distances(x, c).argmin(1)
        delta = (weights[:ROWS_TRAIN, s] - code_f[labels[:ROWS_TRAIN, s]]) @ qtrain[:, s].T
        cost[s] = np.mean(delta*delta)
    return labels, cost


def assign_additive(weights, a, b, qtrain):
    rows, segments, _ = weights.shape
    labels = np.empty((rows, segments), np.int32)
    cost = np.empty(segments, np.float64)
    combined = (a[:, None, :].astype(np.int16) + b[None, :, :].astype(np.int16)).reshape(256, LENGTH)/64
    for s in range(segments):
        projection = metric(qtrain[:, s])
        labels[:, s] = distances(weights[:, s] @ projection, combined @ projection).argmin(1)
        delta = (weights[:ROWS_TRAIN, s] - combined[labels[:ROWS_TRAIN, s]]) @ qtrain[:, s].T
        cost[s] = np.mean(delta*delta)
    return labels, cost


def replay(codes, labels, queries, scales):
    """Online operation: prepare query-specific response tables, then index labels."""
    rows, segments = labels.shape
    result = np.zeros((len(queries), rows), np.int32)
    for s in range(segments):
        table = queries[:, s].astype(np.int32) @ codes.astype(np.int32).T
        result += table[:, labels[:, s]]
    return result.astype(np.float64)/64 * scales[None, :]


def replay_additive(a, b, labels, queries, scales):
    rows, segments = labels.shape
    result = np.zeros((len(queries), rows), np.int32)
    for s in range(segments):
        ta = queries[:, s].astype(np.int32) @ a.astype(np.int32).T
        tb = queries[:, s].astype(np.int32) @ b.astype(np.int32).T
        result += ta[:, labels[:, s] >> 4] + tb[:, labels[:, s] & 15]
    return result.astype(np.float64)/64 * scales[None, :]


def evaluate(estimated, weights, q, scales, row_slice):
    exact = (q.reshape(len(q), -1).astype(np.int32) @ weights.reshape(len(weights), -1).astype(np.int32).T) * scales[None, :]
    e = estimated[:, row_slice] - exact[:, row_slice]
    y = exact[:, row_slice]
    return {'relative_rms': float(np.sqrt(np.mean(e*e)/np.mean(y*y))),
            'relative_max': float(np.max(np.abs(e))/np.sqrt(np.mean(y*y)))}


def main():
    begin = time.perf_counter()
    rng = np.random.default_rng(SEED)
    with np.load(FIXTURE) as z:
        weights = z['trits'].reshape(5120, 8, LENGTH).astype(np.float32)
        queries = z['queries'].reshape(8, 8, LENGTH).astype(np.float32)
        scales = z['scales_fp16'].astype(np.float64)
    # Only first four query captures train labels. The other four and the last
    # 1024 rows are untouched by dictionary fitting and rate selection.
    fitting = weights[:ROWS_TRAIN].reshape(-1, LENGTH)
    fitting = fitting[rng.choice(len(fitting), 8192, replace=False)]
    qtrain = queries[:4]
    models = {}
    for k in (16, 64, 256):
        codes = quantize(train_kmeans(fitting, k, rng))
        labels, cost = assign(weights, codes, qtrain)
        models[f'full{k}'] = (codes, labels, cost)
    a, b = (quantize(c) for c in train_additive(fitting, rng))
    labels_ab, cost_ab = assign_additive(weights, a, b, qtrain)
    models['additive16x16'] = ((a, b), labels_ab, cost_ab)
    synthetic = rng.integers(-127, 128, size=(64, 8, LENGTH), dtype=np.int16).astype(np.int32)
    records = {}
    for name, (codes, labels, cost) in models.items():
        additive = isinstance(codes, tuple)
        consume = (lambda x: replay_additive(*codes, labels, x, scales)) if additive else (lambda x: replay(codes, labels, x, scales))
        bits = 8 if additive else int(np.log2(len(codes)))
        dictionary_bytes = (sum(c.nbytes for c in codes) if additive else codes.nbytes)
        label_bytes = 5120*((8*bits+7)//8)
        record = {'label_bits_per_segment': bits, 'label_bytes': label_bytes,
                  'codebook_bytes': dictionary_bytes, 'retained_fp16_scale_bytes': 10240,
                  'total_bits_per_original_weight': 8*(label_bytes+dictionary_bytes+10240)/(5120*128),
                  'response_table_bytes_int32': 8*(32 if additive else len(codes))*4,
                  'online_table_integer_products': 8*(32 if additive else len(codes))*16,
                  'online_row_table_lookups': 8*(2 if additive else 1),
                  'training_segment_mse': cost.tolist()}
        for label, qq, rows in [('train_query_train_row', queries[:4], slice(0, ROWS_TRAIN)),
                                 ('held_query_held_row', queries[4:], slice(ROWS_TRAIN, None)),
                                 ('synthetic_query_held_row', synthetic, slice(ROWS_TRAIN, None))]:
            record[label] = evaluate(consume(qq.astype(np.int32)), weights, qq.astype(np.int32), scales, rows)
        records[name] = record
    # Same 48 label bits/row as a uniform 6-bit vector code. Dynamic programming
    # chooses each segment's code size under the exact per-row bit budget.
    choices = (('full16', 4), ('full64', 6), ('full256', 8))
    states = {0: (0., ())}
    for segment in range(8):
        next_states = {}
        for spent, (loss, plan) in states.items():
            for name, bits in choices:
                total = spent+bits
                if total > 48:
                    continue
                candidate = (loss+records[name]['training_segment_mse'][segment], plan+(name,))
                if total not in next_states or candidate[0] < next_states[total][0]:
                    next_states[total] = candidate
        states = next_states
    _, plan = min(states.values(), key=lambda item: item[0])
    mix_labels = np.empty_like(labels)
    mix_estimate = np.zeros((4, 5120), np.float64)
    for s, name in enumerate(plan):
        codes, all_labels, _ = models[name]
        mix_labels[:, s] = all_labels[:, s]
        table = queries[4:, s].astype(np.int32) @ codes.astype(np.int32).T
        mix_estimate += table[:, all_labels[:, s]] / 64 * scales[None, :]
    records['variable48'] = {'segment_plan': list(plan), 'label_bytes': 5120*6,
        'codebook_bytes': sum(models[n][0].nbytes for n in set(plan)),
        'held_query_held_row': evaluate(mix_estimate, weights, queries[4:].astype(np.int32), scales, slice(ROWS_TRAIN,None))}
    output = {'format': 'response-codebooks/1', 'fixture_sha256': sha(FIXTURE),
              'script_sha256': sha(Path(__file__)), 'seed': SEED,
              'weights': 'Bonsai layer0 down block0, 5120 rows x 128 trits',
              'dictionary_train_rows': [0, ROWS_TRAIN], 'acceptance_rows': [ROWS_TRAIN, 5120],
              'calibration_query_indices': [0,1,2,3], 'held_query_indices': [4,5,6,7],
              'synthetic_queries': 64, 'synthetic_range': [-127,127],
              'coefficient_unit': '1/64; shared int8 codeword coefficients',
              'metric': 'isotropic; calibration-weighted assignments tested separately in short.py',
              'methods': records, 'elapsed_seconds': time.perf_counter()-begin}
    (HERE/'results.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({n:{'bits':v.get('total_bits_per_original_weight'),
                         'held_rms':v['held_query_held_row']['relative_rms']}
                      for n,v in records.items()},indent=2))


if __name__ == '__main__':
    main()
