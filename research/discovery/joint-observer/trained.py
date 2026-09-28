#!/usr/bin/env python3
"""Test carriers against fixed trained FFN regions, not constructed source weights.

All 27 perturbations are evaluated. This CPU float64 semantic experiment starts
at a fixed-scale A8 input interface and observes the entire 5120-wide FFN update.
It is not a native timing or an end-to-end quality experiment.
"""
import os
os.environ.setdefault("OPENBLAS_NUM_THREADS", "4")
os.environ.setdefault("OMP_NUM_THREADS", "4")
import argparse
import hashlib
import itertools
import json
from pathlib import Path
from time import monotonic

import numpy as np

from discover import STATES, CODES, candidates, producer
from capacity import capacity_bounds
import sys
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "research/ffn/batched/deferred-carrier"))
from carrier_scan import halo_matrix, hadamard_1024, D, FF

DATA = Path("/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench")
COORDINATES = ((2, 17, 93), (129, 167, 230), (37, 1729, 4091))
ST = np.asarray(STATES, dtype=np.float64)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def quantize(x, levels):
    blocks = x.reshape(-1, x.shape[-1]//128, 128)
    scales = np.abs(blocks).max(axis=-1, keepdims=True)/levels
    scales = np.where(scales > 0, scales, 1.0)
    codes = np.clip(np.rint(blocks/scales), -levels, levels)
    return codes.reshape(x.shape), scales[..., 0]


def dequantize(x, levels):
    q, s = quantize(x, levels)
    return q*np.repeat(s, 128, axis=-1)


def scaled_weights(path, rows, k):
    w, s = halo_matrix(str(path), rows, k)
    result = w.astype(np.float64)
    result.reshape(rows, k//128, 128)[:] *= s[..., None]
    return result


def centered_basis(features):
    a = np.asarray(features, dtype=np.float64)
    a = a-a.mean(axis=0, keepdims=True)
    norms = np.linalg.norm(a, axis=0)
    a = a[:, norms > 0] / norms[norms > 0]
    if not a.shape[1]:
        return np.zeros((a.shape[0], 0))
    u, s, _ = np.linalg.svd(a, full_matrices=False)
    return u[:, s > s[0]*1e-12]


def family_basis(h):
    return centered_basis(np.column_stack([h**p for p in (1, 3, 5, 7, 9)] +
                                          [(h != 0)+2*(np.abs(h) == 5)]))


def fiber_basis(h):
    return centered_basis(np.column_stack([h == v for v in np.unique(h)]))


def residual_energy(gram, basis):
    return max(0.0, float(np.trace(gram)-np.sum(basis*(gram@basis))))


def relative_error(gram, basis):
    return (residual_energy(gram, basis)/np.trace(gram))**0.5


def maps():
    orientations = []
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product((-1, 1), repeat=3):
            coordinates = ST[:, perm]*signs
            q = (coordinates+1)@np.array([1, 3, 9])
            h = np.array([producer(int(v)) for v in q], dtype=np.float64)
            orientations.append({"permutation": perm, "signs": signs, "h": h,
                                 "family": family_basis(h), "fiber": fiber_basis(h)})
    seen, atlas = set(), []
    for spec, values in candidates():
        key = tuple(tuple(i for i, y in enumerate(values) if y == x) for x in values)
        if key in seen or not 2 <= len(set(values)) <= 16:
            continue
        seen.add(key)
        h = np.array(values)
        atlas.append({"spec": spec, "states": len(set(values)), "basis": fiber_basis(h)})
    return orientations, atlas


def witness(h, outputs):
    best = None
    for i in range(len(h)):
        for j in range(i):
            if h[i] != h[j]:
                continue
            delta = outputs[i]-outputs[j]
            col = int(np.argmax(np.abs(delta)))
            gap = float(abs(delta[col]))
            if best is None or gap > best["absolute_gap"]:
                best = {"first_input": STATES[j], "second_input": STATES[i],
                        "carrier": float(h[i]), "output_coordinate": col,
                        "first_output": float(outputs[j, col]), "second_output": float(outputs[i, col]),
                        "absolute_gap": gap}
    return best


def score(outputs, orientations, atlas):
    y = outputs-outputs.mean(axis=0, keepdims=True)
    gram = y@y.T
    energy = float(np.trace(gram))
    base_h = np.array([producer(q) for q in CODES], dtype=np.float64)
    b, f = family_basis(base_h), fiber_basis(base_h)
    eb, ef = residual_energy(gram, b), residual_energy(gram, f)
    best = min(orientations, key=lambda o: residual_energy(gram, o["family"]))
    frontier = []
    for capacity in (2, 3, 4, 8, 11, 16):
        eligible = [a for a in atlas if a["states"] <= capacity]
        a = min(eligible, key=lambda a: residual_energy(gram, a["basis"]))
        frontier.append({"capacity": capacity, "states": a["states"], "producer": a["spec"],
                         "best_arbitrary_decoder_rel_rms": relative_error(gram, a["basis"])})
    polynomial = {}
    for degree in (1, 2, 3):
        exponents = [p for p in itertools.product(range(3), repeat=3) if 1 <= sum(p) <= degree]
        basis = centered_basis(np.column_stack([np.prod(ST**p, axis=1) for p in exponents]))
        polynomial[str(degree)] = {"dimension": basis.shape[1],
                                   "rel_rms": float(np.linalg.norm(y-basis@(basis.T@y))/np.sqrt(energy))}
    singular_energy = np.maximum(np.linalg.eigvalsh(gram)[::-1], 0)
    return {"variation_rms": float(np.sqrt(energy/y.size)),
            "variation_over_total_rms": float(np.sqrt(energy/np.sum(outputs**2))),
            "computed_distinct_output_vectors": len({row.tobytes() for row in outputs}),
            "selected_carrier": {"states": 11, "family_rel_rms": (eb/energy)**0.5,
                                 "family_rel_rms_over_full_update": float(np.sqrt(eb/np.sum(outputs**2))),
                                 "arbitrary_decoder_rel_rms": (ef/energy)**0.5,
                                 "additional_family_squared_error_fraction": max(0, eb-ef)/energy,
                                 "collision": witness(base_h, outputs)},
            "best_orientation": {"permutation": best["permutation"], "signs": best["signs"],
                                 "family_rel_rms": relative_error(gram, best["family"]),
                                 "arbitrary_decoder_rel_rms": relative_error(gram, best["fiber"]),
                                 "collision": witness(best["h"], outputs)},
            "grammar_fiber_frontier": frontier, "polynomial_controls": polynomial,
            "any_carrier_capacity_lower_bounds": capacity_bounds(gram, (2, 3, 4, 8, 11, 16, 26, 27)),
            "output_variation_energy_at_rank": {str(k): float(singular_energy[:k].sum()/energy)
                                                 for k in (1, 2, 3, 6, 10, 19, 26)}}


def run(layer, anchor):
    start = monotonic()
    path = DATA/f"layer{layer:02d}"
    chunk, row = divmod(anchor, 8)
    input_path = path/f"c{chunk:03d}/x_in.f32"
    output_path = path/f"c{chunk:03d}/x_out.f32"
    x = np.fromfile(input_path, np.float32).reshape(-1, D)[row].astype(np.float64)
    reference = np.fromfile(output_path, np.float32).reshape(-1, D)[row].astype(np.float64)-x
    norm = np.fromfile(path/"post_norm_s.f32", np.float32).astype(np.float64)
    rotated = hadamard_1024(x/np.sqrt(np.mean(x*x)+1e-6)*norm)
    q, scale = quantize(rotated[None, :], 127)
    base = q[0]*np.repeat(scale[0], 128)
    groups, coordinate_records = [], []
    for coords in COORDINATES:
        cols = np.array(coords)
        steps = np.minimum(32, 127-np.abs(q[0, cols])).astype(int)
        if np.any(steps == 0):
            raise ValueError(f"selected coordinate at code endpoint: {coords}")
        amplitudes = steps*scale[0, cols//128]
        groups.append((cols, amplitudes))
        coordinate_records.append({"coordinates": coords, "base_codes": q[0, cols].astype(int).tolist(),
                                   "code_steps": steps.tolist(), "amplitudes": amplitudes.tolist()})
    gate = scaled_weights(path/"gate.halo", FF, D)
    ga = gate@base
    gd = [gate[:, cols]*amplitudes for cols, amplitudes in groups]
    del gate
    up = scaled_weights(path/"up.halo", FF, D)
    ua = up@base
    ud = [up[:, cols]*amplitudes for cols, amplitudes in groups]
    del up
    down = scaled_weights(path/"down.halo", D, FF)
    signs = np.fromfile(path/"signs_ff.f32", np.float32).astype(np.float64)
    orientations, atlas = maps()
    cases = []
    for index, (g_delta, u_delta) in enumerate(zip(gd, ud)):
        g = ga[None, :]+ST@g_delta.T
        u = ua[None, :]+ST@u_delta.T
        # exp(-abs(g)) avoids overflow and preserves the SiLU definition.
        sigmoid = np.where(g >= 0, 1/(1+np.exp(-np.abs(g))),
                           np.exp(-np.abs(g))/(1+np.exp(-np.abs(g))))
        hidden = g*sigmoid*u
        transformed = hadamard_1024(hidden*signs)
        for levels in (0, 127, 7):
            activation = transformed if levels == 0 else dequantize(transformed, levels)
            outputs = activation@down.T
            record = {"group": index, "coordinates": coordinate_records[index],
                      "hidden_quantizer_levels": levels, "output_sha256": hashlib.sha256(outputs.tobytes()).hexdigest(),
                      **score(outputs, orientations, atlas)}
            if levels == 127:
                record["zero_perturbation_vs_captured_update_rel_rms"] = float(
                    np.linalg.norm(outputs[13]-reference)/np.linalg.norm(reference))
            cases.append(record)
    return {"format": "kelana-trained-observer/1", "layer": layer, "anchor_position": anchor,
            "input_states": 27, "observed_outputs": D, "cases": cases,
            "semantics": "CPU float64; fixed-scale A8 input codes with three +/- step perturbations; trained projections, SiLU, signed normalized Hadamard, optional hidden quantization, full down projection. No residual added.",
            "fit_contract": "All finite states enumerated. Fits include a free intercept. Coefficients and best carrier may differ per case: optimistic information screen, not an online implementation or held-out quality result.",
            "normalization": "Errors divided by norm of output variation about its mean over 27 states, not by the large unchanged background.",
            "search": {"orientations": len(orientations), "distinct_fiber_partitions_capacity_at_most_16": len(atlas),
                       "scope": "Grid from inverse_labels.candidates; fiber frontier allows arbitrary unpriced decoders."},
            "provenance": {"dataset": str(path), "manifest_sha256": sha(path/"manifest.json"),
                           "files_sha256": {str(p.relative_to(path)): sha(p) for p in
                                            [input_path, output_path]+[path/n for n in
                                             ("gate.halo", "up.halo", "down.halo", "signs_ff.f32", "post_norm_s.f32")]},
                           "source_sha256": sha(__file__), "capacity_source_sha256": sha(HERE/"capacity.py"),
                           "dependencies_sha256": {
                               str(p.relative_to(ROOT)): sha(p) for p in
                               [HERE/"discover.py", HERE.parent/"observer-search/inverse_labels.py",
                                ROOT/"research/ffn/batched/deferred-carrier/carrier_scan.py"]},
                           "numpy": np.__version__,
                           "blas_threads_env": os.environ.get("OPENBLAS_NUM_THREADS")},
            "elapsed_seconds": monotonic()-start}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--layer", type=int, choices=(0, 10), required=True)
    parser.add_argument("--anchor", type=int, choices=(0, 127), required=True)
    args = parser.parse_args()
    result = run(args.layer, args.anchor)
    destination = HERE/"trained-results"/f"layer{args.layer:02d}-anchor{args.anchor:03d}.json"
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(result, indent=2)+"\n")
    print(destination)
    for case in result["cases"]:
        print(case["group"], case["hidden_quantizer_levels"],
              "family", round(case["selected_carrier"]["family_rel_rms"], 4),
              "fiber", round(case["selected_carrier"]["arbitrary_decoder_rel_rms"], 4),
              "best orientation", round(case["best_orientation"]["family_rel_rms"], 4),
              "linear", round(case["polynomial_controls"]["1"]["rel_rms"], 4))
    print("seconds", result["elapsed_seconds"])
