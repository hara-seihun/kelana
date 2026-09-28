#!/usr/bin/env python3
"""Train-only selection of a paid low-rank producer-to-Q3 routed-error map."""
import hashlib
import json
from pathlib import Path
import sys
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'input-subspace'))
from evaluate import capture, sha

ROOT = Path('/path/to/workspace/data/qwen-moe')
PARTS = ROOT / 'q3-scalar-correction'
OUT = ROOT / 'q3-residual-corrector'
RANKS = (8, 32, 64, 112)


def load():
    result = {}
    paths = {}
    for split in ('train', 'held'):
        paths[split], data = capture(split)
        scores = np.asarray(data['scores'], np.float64)
        q3 = np.zeros((len(scores), 2048), np.float64)
        q4 = np.zeros_like(q3)
        for i in range(8):
            with np.load(PARTS / f'part-{i:02d}.npz') as part:
                q3 += np.einsum('ts,tsd->td', scores, part[f'{split}_q3'].astype(np.float64))
                q4 += np.einsum('ts,tsd->td', scores, part[f'{split}_q4'].astype(np.float64))
        result[split] = dict(x=np.asarray(data['x'], np.float64), q3=q3, q4=q4, error=q4-q3)
    return result, paths


def run():
    OUT.mkdir(parents=True, exist_ok=True)
    data, paths = load()
    train, held = data['train'], data['held']
    x, target = train['x'], train['error']
    xh, dh = held['x'], held['error']
    norm = np.linalg.norm(held['q4'])
    _, singular, vt = np.linalg.svd(target, full_matrices=False)
    gram = x @ x.T
    eig, u = np.linalg.eigh(gram)
    eig = np.maximum(eig, 0)
    grid = float(eig[-1]) * np.array([1e-6, 1e-5, 1e-4, 1e-3, .01, .1, 1, 10, 100])
    result = {}
    for rank in RANKS:
        basis = vt[:rank].T
        coords = target @ basis
        best = None
        for lam in grid:
            inverse = (u / (eig + lam)) @ u.T
            alpha = inverse @ coords
            # Diagonal of the inverse gives exact leave-one-out ridge residuals.
            loo = alpha / np.diag(inverse)[:, None]
            score = float(np.square(loo).sum())
            if best is None or score < best[0]:
                best = (score, float(lam), alpha)
        _, lam, alpha = best
        left = (x.T @ alpha).astype('<f2')
        right = basis.T.astype('<f2')
        image = OUT / f'rank-{rank}.f16'
        image.write_bytes(left.tobytes() + right.tobytes())
        correction = (xh @ left.astype(np.float64)) @ right.astype(np.float64)
        train_fit = (x @ left.astype(np.float64)) @ right.astype(np.float64)
        oracle = (dh @ basis) @ basis.T
        result[str(rank)] = dict(lambda_train_loo=lam, train_loo_squared=best[0],
            image_bytes=image.stat().st_size, image_sha256=sha(image),
            train_rms=float(np.linalg.norm(target-train_fit)/np.linalg.norm(train['q4'])),
            held_rms=float(np.linalg.norm(dh-correction)/norm),
            held_free_output_projection_rms=float(np.linalg.norm(dh-oracle)/norm))
    report = dict(contract='Layer-0 decoded installed Q4_K vs frozen Q3_K gate/up, Q5_K down, real producer and router scores, FP64 weighted sum; FP16 rank-r producer-to-complete-error correction selected solely by train leave-one-out. CPU local output only.',
        source_sha256=sha(__file__), source_receipt_sha256=sha(PARTS/'receipt.json'),
        capture_sha256={s:{k:sha(p) for k,p in v.items()} for s,v in paths.items()},
        part_sha256=[sha(PARTS/f'part-{i:02d}.npz') for i in range(8)],
        tokens={s:len(data[s]['x']) for s in data},
        baseline_held_rms=float(np.linalg.norm(dh)/norm),
        baseline_train_rms=float(np.linalg.norm(target)/np.linalg.norm(train['q4'])),
        results=result, modeled_complete_one_read_bytes=2626187904,
        conditional_q3_one_read_saved_bytes_per_token=89128960)
    (OUT/'receipt.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report['results'], indent=2))


if __name__ == '__main__':
    run()
