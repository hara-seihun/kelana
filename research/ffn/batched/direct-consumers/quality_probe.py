#!/usr/bin/env python3
"""One-FFN quality of candidate nonlinear consumers, anchored to native G/U.

This does not benchmark a packed implementation. It distinguishes the activation
approximation from coarse gate quantization before paying to build a producer.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lossy"))
from probe import Gguf, effective_weight, hadamard, stats


def quantize_hidden(h, signs):
    rotated = hadamard(h * signs)
    blocks = rotated.reshape(len(h), -1, 128)
    amax = np.max(abs(blocks), axis=-1, keepdims=True)
    inv = np.divide(127., amax, out=np.zeros_like(amax), where=amax != 0)
    q = np.rint(blocks * inv).astype(np.int8)
    return (q * (amax / 127)).reshape(h.shape)


def run(dataset):
    start = time.monotonic()
    m = json.loads((dataset / "manifest.json").read_text())
    case = next(c for c in m["cases"] if c["nrows"] == 8)
    n, ff, d = 8, m["FF"], m["D"]
    def load(key, shape):
        return np.fromfile(dataset / case[key], dtype="<f4").astype(float).reshape(shape)
    g, u = load("gate", (n, ff)), load("up", (n, ff))
    residual = load("x_out", (n, d))
    signs = np.fromfile(dataset / m["weights"]["signs_ff"], dtype="<f4")
    silu = lambda x: x / (1 + np.exp(-np.clip(x, -700, 700)))
    h0 = silu(g) * u
    q0 = quantize_hidden(h0, signs)
    candidates = {
        "relu_product": np.maximum(g, 0) * u,
        "bilinear_half": .5*g*u,
        "taylor_degree2": (g/2 + g*g/4)*u,
        "taylor_degree4": (g/2 + g*g/4 - g**4/48)*u,
        "taylor_degree6": (g/2 + g*g/4 - g**4/48 + g**6/480)*u,
    }
    # This polynomial is chosen on a fixed interval, without fitting these data.
    # The form has the exact odd part g/2 and vanishes at zero.
    x = np.linspace(-3.5, 3.5, 4097)
    basis = np.stack([x**2, x**4, x**6], axis=1)
    coefficients = np.linalg.lstsq(basis, silu(x)-x/2, rcond=None)[0]
    poly = lambda x: x/2 + sum(a*x**k for a,k in zip(coefficients, (2,4,6)))
    candidates["interval_fit_degree6"] = poly(g)*u
    for limit in (3, 7, 15, 31, 127):
        # Fixed physical range; isolates precision from the activation formula.
        gq = np.clip(np.rint(g*limit/3.5), -limit, limit)*3.5/limit
        candidates[f"gate_grid_{2*limit+1}_levels_exact_silu"] = silu(gq)*u
    errors = []
    records = []
    for name, h in candidates.items():
        errors.append(quantize_hidden(h, signs)-q0)
        records.append({"name": name, "hidden_error": stats(h-h0, h0)})
    model = Gguf(m["model"])
    wd = effective_weight(model, f"blk.{m['layer']}.ffn_down.weight")
    out_error = np.concatenate(errors) @ wd.T
    model.f.close()
    for i, r in enumerate(records):
        r["residual_error"] = stats(out_error[i*n:(i+1)*n], residual)
    return {"layer": m["layer"], "dataset": str(dataset),
            "manifest_sha256": hashlib.sha256((dataset/"manifest.json").read_bytes()).hexdigest(),
            "gate_sha256": hashlib.sha256((dataset/case["gate"]).read_bytes()).hexdigest(),
            "up_sha256": hashlib.sha256((dataset/case["up"]).read_bytes()).hexdigest(),
            "gate_quantiles": np.quantile(g, [0,.01,.1,.5,.9,.99,1]).tolist(),
            "interval_fit_even_coefficients": coefficients.tolist(),
            "interval_fit": "unweighted least squares on 4097 fixed points in [-3.5,3.5], not a uniform error proof",
            "scope": "8 captured rows, one FFN, float64 perturbation propagation through Hadamard, int8 quantization and down; not whole-model quality or a native packed candidate",
            "seconds": time.monotonic()-start, "candidates": records}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--dataset", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    a = p.parse_args()
    result = run(a.dataset)
    result["source_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    result["shared_probe_sha256"] = hashlib.sha256((Path(__file__).resolve().parents[1]/"lossy/probe.py").read_bytes()).hexdigest()
    a.out.write_text(json.dumps(result, indent=2)+"\n")
    for r in result["candidates"]:
        print(r["name"], "hidden", r["hidden_error"]["relative_rms"],
              "residual", r["residual_error"]["relative_rms"])
