#!/usr/bin/env python3
"""Weight-only screen for a cheap separable scale field; no activations used."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np


def scan(path, rows, columns):
    nb = columns // 128
    tiles = np.memmap(path, dtype=np.uint8, mode="r", shape=(rows // 32, nb, 896))
    tails = np.ascontiguousarray(tiles[:, :, 768:].reshape(rows // 32, nb, 32, 4)[..., 2:4])
    scales = tails.view("<f2").reshape(rows // 32, nb, 32).transpose(0, 2, 1).reshape(rows, nb).astype(np.float64)
    means = scales.mean(axis=1, keepdims=True)
    if np.any(means == 0):
        raise ValueError("zero row mean needs a separate convention")
    normalized = scales / means
    norm2 = np.sum(normalized**2)
    eigenvalues = np.maximum(0, np.linalg.eigvalsh(normalized.T @ normalized))[::-1]
    return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "shape": [rows, nb], "normalization": "each row divided by its mean scale",
            "row_mean_relative_frobenius_error": float(np.linalg.norm(normalized - 1) / np.sqrt(norm2)),
            "best_rank_relative_frobenius_error": {
                str(r): float(np.sqrt(max(0, norm2 - eigenvalues[:r].sum()) / norm2)) for r in (1, 2, 4, 8)}}


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("dataset", type=Path)
    args = ap.parse_args()
    result = {name: scan(args.dataset / (name + ".halo"), *shape)
              for name, shape in [("gate", (17408, 5120)), ("up", (17408, 5120)), ("down", (5120, 17408))]}
    print(json.dumps(result, indent=2))
