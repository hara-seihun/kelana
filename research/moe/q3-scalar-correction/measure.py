#!/usr/bin/env python3
"""Fit paid expert response gains on frozen Q3 gate/up images and actual routes."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'input-subspace'))
from evaluate import capture, evaluator, image_banks, sha

SOURCE = Path('/path/to/workspace/data/qwen-moe/gateup-q3-recode')
OUT = Path('/path/to/workspace/data/qwen-moe/q3-scalar-correction')
Q3_SIZE = 512 * 2048 // 256 * 110


def produce(index, root):
    first, last = index * 32, (index + 1) * 32
    splits = {s: capture(s) for s in ('train', 'held')}
    _, _, banks = image_banks()
    library, weight = evaluator(banks)
    dequant = ctypes.CDLL(str(library)).dequantize_row_q3_K
    dequant.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64)
    dequant.restype = None
    image = np.memmap(SOURCE / f'image-{index:02d}.bin', np.uint8, 'r')
    assert image.size == 32 * 2 * Q3_SIZE
    outputs = {s: np.zeros((len(data['x']), 8, 2048), np.float32) for s, (_, data) in splits.items()}
    reference = {s: np.zeros_like(outputs[s]) for s in splits}
    for expert in range(first, last):
        positions = {s: np.where(data['ids'] == expert) for s, (_, data) in splits.items()}
        if not any(len(row) for row, _ in positions.values()):
            continue
        gate, up, down = (weight(name, expert) for name in ('gate', 'up', 'down'))
        recoded = []
        for bank in range(2):
            offset = ((expert-first)*2 + bank)*Q3_SIZE
            q = np.empty((512, 2048), np.float32)
            dequant(image[offset:offset+Q3_SIZE].ctypes.data, q.ctypes.data, q.size)
            recoded.append(q)
        for s, (_, data) in splits.items():
            row, slot = positions[s]
            if not len(row):
                continue
            x = np.asarray(data['x'][row], np.float32)
            for dest, (g, u) in ((reference[s], (gate, up)), (outputs[s], recoded)):
                a, b = x @ g.T, x @ u.T
                h = ((a / (1 + np.exp(-a))) * b).astype(np.float32)
                dest[row, slot] = h @ down.T
    root.mkdir(parents=True, exist_ok=True)
    path = root / f'part-{index:02d}.npz'
    np.savez_compressed(path, **{f'{s}_{arm}': v for s in splits for arm, v in
                                  (('q4', reference[s]), ('q3', outputs[s]))})
    meta = {'index': index, 'source_sha256': sha(__file__), 'library_sha256': sha(library),
            'q3_image_sha256': sha(SOURCE / f'image-{index:02d}.bin'),
            'outputs_sha256': sha(path)}
    (root / f'part-{index:02d}.json').write_text(json.dumps(meta, indent=2)+'\n')
    print(json.dumps(meta))


def evaluate(root):
    ids = {}; scores = {}; outputs = {}; references = {}; captures = {}
    for s in ('train', 'held'):
        paths, data = capture(s)
        captures[s] = {k: sha(v) for k, v in paths.items()}
        ids[s] = np.asarray(data['ids'])
        scores[s] = np.asarray(data['scores'], np.float64)
        outputs[s] = np.zeros((len(ids[s]), 8, 2048), np.float32)
        references[s] = np.zeros_like(outputs[s])
    metas = [json.loads((root / f'part-{i:02d}.json').read_text()) for i in range(8)]
    assert [m['index'] for m in metas] == list(range(8))
    assert len({m['source_sha256'] for m in metas}) == 1
    for i, m in enumerate(metas):
        path = root / f'part-{i:02d}.npz'
        assert sha(path) == m['outputs_sha256']
        with np.load(path) as d:
            for s in ids:
                outputs[s] += d[f'{s}_q3']
                references[s] += d[f'{s}_q4']
    # Each expert is represented in exactly one shard; a changed routing mask must fail.
    original = json.loads((SOURCE / 'receipt.json').read_text())
    for s in ids:
        assert np.all(np.linalg.norm(outputs[s], axis=2) > 0)
        for arm, full in (('q4', references[s]), ('q3', outputs[s])):
            assembled = np.einsum('te,ted->td', scores[s], full.astype(np.float64))
            original_parts = sum((np.load(SOURCE / f'part-{i:02d}.npz')[f'{s}_{arm}']
                                  for i in range(8)))
            assert np.max(np.abs(assembled-original_parts)) < 1e-7
            if arm == 'q4':
                assert abs(np.square(assembled).sum()-original['scores'][s]['reference_squared_norm']) < 1e-7
    terms = {s: scores[s][..., None] * outputs[s].astype(np.float64) for s in ids}
    target = {s: np.einsum('te,ted->td', scores[s], references[s].astype(np.float64)) for s in ids}
    ref = {s: np.sum(terms[s], axis=1) for s in ids}
    # Ridge shrinks each independently calibrated expert gain toward unity. All
    # norms and errors are for the complete weighted routed sum, not gate fit.
    train_ids = ids['train'].reshape(-1)
    t = terms['train'].reshape(-1, 2048)
    r = (scores['train'][..., None] * references['train'].astype(np.float64)).reshape(-1, 2048)
    dot = np.bincount(train_ids, weights=np.einsum('ij,ij->i', t, r), minlength=256)
    norm = np.bincount(train_ids, weights=np.einsum('ij,ij->i', t, t), minlength=256)
    gain = np.ones(256, np.float64)
    np.divide(dot, norm, out=gain, where=norm > 0)
    packed_gain = gain.astype('<f2')
    (root / 'gains.f16').write_bytes(packed_gain.tobytes())
    paid = packed_gain.astype(np.float64)
    global_gain = float(np.einsum('ij,ij->', ref['train'], target['train']) / np.square(ref['train']).sum())

    def predicted(s, g):
        return np.einsum('te,ted->td', g[ids[s]] * scores[s], outputs[s].astype(np.float64))

    def rms(s, y):
        return float(np.sqrt(np.square(y-target[s]).sum() / np.square(target[s]).sum()))

    results = {}
    for s in ids:
        v = terms[s]; y = target[s]; z = ref[s]
        token_scalar = np.einsum('ij,ij->i', z, y) / np.einsum('ij,ij->i', z, z)
        oracle_scalar = z * token_scalar[:, None]
        oracle_expert = np.empty_like(y)
        for row in range(len(y)):
            g = np.linalg.lstsq(v[row].T, y[row], rcond=None)[0]
            oracle_expert[row] = v[row].T @ g
        results[s] = {'tokens': len(y), 'reference_squared_norm': float(np.square(y).sum()),
                      'q3': rms(s, z), 'global_train_gain': rms(s, z * global_gain),
                      'expert_train_gain_fp16': rms(s, predicted(s, paid)),
                      'free_token_sum_gain': rms(s, oracle_scalar),
                      'free_token_eight_gains': rms(s, oracle_expert),
                      'unseen_expert_slots': int(np.count_nonzero(norm[ids[s]] == 0))}
    report = {'contract': 'Decoded installed Q4 vs frozen native GGML Q3 gate/up; original Q5 down, real layer-0 producer and router scores, CPU FP32 BLAS/SwiGLU, FP64 weighted sum. Train-fitted FP16 expert gains, held local response only.',
              'original_receipt_sha256': sha(SOURCE / 'receipt.json'), 'capture_sha256': captures,
              'parts': metas, 'source_sha256': sha(__file__),
              'gain_fp16_bytes': 512, 'gain_fp16_sha256': sha(root / 'gains.f16'),
              'global_gain': global_gain, 'trained_experts': int(np.count_nonzero(norm)),
              'gain_min_max': [float(gain.min()), float(gain.max())], 'results': results,
              'conditional_complete_one_read_saved_bytes': 89128960 - 40*512,
              'modeled_complete_one_read_bytes': 2626187904}
    (root / 'receipt.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report['results'], indent=2))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--part', type=int, choices=range(8))
    p.add_argument('--combine', action='store_true')
    p.add_argument('--out', type=Path, default=OUT)
    a = p.parse_args()
    evaluate(a.out) if a.combine else produce(a.part, a.out)
