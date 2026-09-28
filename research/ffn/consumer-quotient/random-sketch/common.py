#!/usr/bin/env python3
"""Shared loading and weight-only sketch construction for the random-sketch study.

Nothing here touches activations while building a sketch: every basis is a function
of the down weight matrix and a fixed seed, so it can be prepared offline once.
"""
import hashlib
import json
from pathlib import Path
import sys
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from discrepancy import metric, halo_matrix, D, FF  # noqa: E402

DATA = Path('/path/to/workspace/data/kelana-ffn/ptq1_0')
BATCH = Path('/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench')
BUILD = HERE / 'build'


def load(layer):
    """Return (hidden operand v, scaled ternary down matrix w, weight sha256)."""
    d = DATA / layer / 'r8'
    q = np.fromfile(d / 'xq_ff.i8', dtype=np.int8).reshape(8, FF)
    s = np.fromfile(d / 'xs_ff.f32', dtype=np.float32).reshape(8, FF // 128)
    v = q.astype(np.float32) * np.repeat(s, 128, axis=1)
    halo = BATCH / layer / 'down.halo'
    w, ws = halo_matrix(str(halo), D, FF)
    w = w.astype(np.float32) * np.repeat(ws, 128, axis=1)
    return v, w, hashlib.sha256(halo.read_bytes()).hexdigest()


def quantize(v, levels, clip):
    maxima = np.abs(v.reshape(len(v), -1, 128)).max(axis=2)
    scales = np.repeat(np.maximum(maxima * clip / levels, 1e-30), 128, axis=1)
    q = np.clip(np.rint(v / scales), -levels, levels).astype(np.float32)
    return q, scales


def singular_basis(w, rank, seed):
    """Randomized weight-only top-`rank` left singular subspace, as in sketch.py."""
    rng = np.random.default_rng(seed)
    z = rng.standard_normal((FF, rank + 16), dtype=np.float32)
    u = np.linalg.qr(w @ z, mode='reduced')[0]
    for _ in range(2):
        u = np.linalg.qr(w @ (w.T @ u), mode='reduced')[0]
    projected = u.T @ w
    gram = projected @ projected.T
    eigenvalues, rot = np.linalg.eigh(gram)
    order = np.argsort(eigenvalues)[::-1][:rank]
    return np.ascontiguousarray(rot[:, order].T @ projected)


def oblivious_basis(w, rank, seed, kind):
    """L = S W / sqrt(rank) with S oblivious, so L^T L is an unbiased estimate of W^T W."""
    rng = np.random.default_rng(seed)
    if kind == 'gaussian':
        s = rng.standard_normal((rank, D), dtype=np.float32)
    elif kind == 'rademacher':
        s = rng.integers(0, 2, size=(rank, D)).astype(np.float32) * 2.0 - 1.0
    else:
        raise ValueError(kind)
    return np.ascontiguousarray((s @ w) / np.float32(np.sqrt(rank)))


def hybrid_basis(w, rank, seed, kind, split):
    """`split` exact top singular rows plus `rank-split` oblivious rows of the remainder."""
    top = singular_basis(w, split, seed)
    rest = rank - split
    if rest <= 0:
        return top
    rng = np.random.default_rng(seed + 991)
    if kind == 'hybrid-gaussian':
        s = rng.standard_normal((rest, D), dtype=np.float32)
    else:
        s = rng.integers(0, 2, size=(rest, D)).astype(np.float32) * 2.0 - 1.0
    # Project the oblivious rows onto the complement of the captured subspace so the
    # two parts estimate disjoint pieces of the Gram matrix.
    basis = np.linalg.qr(top.T, mode='reduced')[0]
    low = (s @ w).astype(np.float32)
    low -= (low @ basis) @ basis.T
    return np.ascontiguousarray(np.vstack([top, low / np.float32(np.sqrt(rest))]))


def basis(w, weight_sha, layer, kind, rank, seed, split=0, cache=True):
    """Prepared weight-only sketch, cached under build/ and rejected on a weight change."""
    name = f'{layer}-{kind}-r{rank}-s{seed}' + (f'-t{split}' if split else '')
    path = BUILD / f'{name}.npy'
    meta = BUILD / f'{name}.json'
    if cache and path.exists():
        info = json.loads(meta.read_text())
        if info['weights_sha256'] != weight_sha:
            raise SystemExit(f'cached basis {name} belongs to different weights')
        return np.load(path)
    if kind == 'singular':
        l = singular_basis(w, rank, seed)
    elif kind.startswith('hybrid'):
        l = hybrid_basis(w, rank, seed, kind, split or rank // 2)
    else:
        l = oblivious_basis(w, rank, seed, kind)
    l = np.ascontiguousarray(l.astype(np.float32))
    if cache:
        BUILD.mkdir(parents=True, exist_ok=True)
        np.save(path, l)
        meta.write_text(json.dumps(dict(weights_sha256=weight_sha, kind=kind, rank=rank,
                                        seed=seed, split=split, shape=list(l.shape),
                                        activation_data_used=False), indent=2) + '\n')
    return l


def diagonal(w2, l, mode):
    """Correction so that diag(L^T L + diag(d)) equals the exact diag(W^T W)."""
    d = w2 - (l * l).sum(axis=0)
    if mode == 'clamped':
        d = np.maximum(d, 0.0)
    elif mode == 'none':
        d = np.zeros_like(d)
    return d.astype(np.float32)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
