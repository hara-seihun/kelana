#!/usr/bin/env python3
"""Exact optimum of a free-decoder carrier with 25 or 26 states on 27 outputs."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
PARENT = HERE.parent
sys.path.insert(0, str(PARENT))
import trained


def outputs_for(layer, anchor):
    path = trained.DATA / f"layer{layer:02d}"
    chunk, row = divmod(anchor, 8)
    x = np.fromfile(path / f"c{chunk:03d}/x_in.f32", np.float32).reshape(-1, trained.D)[row].astype(np.float64)
    norm = np.fromfile(path / "post_norm_s.f32", np.float32).astype(np.float64)
    rotated = trained.hadamard_1024(x / np.sqrt(np.mean(x*x) + 1e-6) * norm)
    q, scale = trained.quantize(rotated[None, :], 127)
    base = q[0] * np.repeat(scale[0], 128)
    groups = []
    for coords in trained.COORDINATES:
        cols = np.array(coords)
        steps = np.minimum(32, 127 - np.abs(q[0, cols]))
        groups.append((cols, steps * scale[0, cols//128]))
    gate = trained.scaled_weights(path / "gate.halo", trained.FF, trained.D)
    ga = gate @ base
    gd = [gate[:, cols] * amplitude for cols, amplitude in groups]
    del gate
    up = trained.scaled_weights(path / "up.halo", trained.FF, trained.D)
    ua = up @ base
    ud = [up[:, cols] * amplitude for cols, amplitude in groups]
    del up
    down = trained.scaled_weights(path / "down.halo", trained.D, trained.FF)
    signs = np.fromfile(path / "signs_ff.f32", np.float32).astype(np.float64)
    for group, (g_delta, u_delta) in enumerate(zip(gd, ud)):
        g = ga[None, :] + trained.ST @ g_delta.T
        u = ua[None, :] + trained.ST @ u_delta.T
        sigmoid = np.where(g >= 0, 1/(1+np.exp(-np.abs(g))),
                           np.exp(-np.abs(g))/(1+np.exp(-np.abs(g))))
        transformed = trained.hadamard_1024(g * sigmoid * u * signs)
        for levels in (0, 127, 7):
            activation = transformed if levels == 0 else trained.dequantize(transformed, levels)
            yield group, levels, activation @ down.T


def exact_near_full(outputs):
    """All partitions with deficit <=2 have one triple or two disjoint pairs."""
    n = len(outputs)
    if n < 4:
        raise ValueError("at least four outputs required")
    y = outputs - outputs.mean(axis=0)
    energy = float(np.sum(y*y))
    if energy <= 0:
        raise ValueError("zero output variation")
    d = np.maximum(0, np.sum(y*y, axis=1)[:, None] +
                   np.sum(y*y, axis=1)[None, :] - 2*y@y.T)
    pairs = [(float(d[i, j])/2, (i, j)) for i in range(n) for j in range(i+1, n)]
    pairs.sort()
    best26 = (pairs[0][0], [pairs[0][1]])
    best25 = (float('inf'), [])
    for a, (i, j) in pairs:
        for b, (k, l) in pairs:
            if (a+b, ((i, j), (k, l))) >= (best25[0], tuple(best25[1])):
                break
            if len({i, j, k, l}) == 4:
                best25 = (a+b, [(i, j), (k, l)])
                break
    for i in range(n):
        for j in range(i+1, n):
            for k in range(j+1, n):
                cost = float(d[i, j]+d[i, k]+d[j, k])/3
                if cost < best25[0]:
                    best25 = (cost, [(i, j, k)])
    return {str(n-deficit): {"sse_fraction": float(cost/energy),
                             "rel_rms": float(np.sqrt(cost/energy)),
                             "merged_states": [list(cluster) for cluster in clusters]}
            for deficit, (cost, clusters) in ((1, best26), (2, best25))}


def run(layer, anchor):
    original = json.loads((PARENT / "trained-results" /
                           f"layer{layer:02d}-anchor{anchor:03d}.json").read_text())
    result = []
    for (group, levels, outputs), record in zip(outputs_for(layer, anchor), original["cases"], strict=True):
        digest = hashlib.sha256(outputs.tobytes()).hexdigest()
        assert (group, levels, digest) == (record["group"], record["hidden_quantizer_levels"],
                                             record["output_sha256"])
        result.append({"group": group, "hidden_quantizer_levels": levels,
                       "output_sha256": digest, "optima": exact_near_full(outputs)})
    return {"layer": layer, "anchor": anchor,
            "trained_record_sha256": trained.sha(PARENT / "trained-results" /
                                                    f"layer{layer:02d}-anchor{anchor:03d}.json"),
            "cases": result}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--layer", type=int, choices=(0, 10), required=True)
    p.add_argument("--anchor", type=int, choices=(0, 127), required=True)
    args = p.parse_args()
    print(json.dumps(run(args.layer, args.anchor), indent=2))
