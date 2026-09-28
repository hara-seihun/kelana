#!/usr/bin/env python3
"""CPU perturbation model for coarse activations through a complete real FFN.

Native gate/up outputs anchor the reference. Perturbations use real-valued linear
maps, float64 SiLU/Hadamard and the deployed quantizer formula. This is a quality
probe, not a native candidate or a throughput benchmark.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "transformed-weights"))
from gguf_read import Gguf


def hadamard(x):
    y = np.array(x, dtype=np.float64, copy=True).reshape(-1, 1024)
    for step in (1, 2, 4, 8, 16, 32, 64, 128, 256, 512):
        z = y.reshape(-1, 1024 // (2*step), 2, step)
        a, b = z[:, :, 0].copy(), z[:, :, 1].copy()
        z[:, :, 0], z[:, :, 1] = a+b, a-b
    return y.reshape(x.shape) / 32


def hidden_quant(g, u, signs):
    sigmoid = 1/(1+np.exp(-np.clip(g, -700, 700)))
    h = g * sigmoid * u
    rotated = hadamard(h*signs)
    blocks = rotated.reshape(*rotated.shape[:-1], -1, 128)
    amax = np.max(np.abs(blocks), axis=-1, keepdims=True)
    inv = np.divide(127., amax, out=np.zeros_like(amax), where=amax != 0)
    q = np.rint(blocks * inv).astype(np.int8)
    scales = amax/127
    dequant = (q * scales).reshape(rotated.shape)
    return h, q, scales, dequant


def stats(error, reference):
    e = np.asarray(error, dtype=np.float64)
    rms = float(np.sqrt(np.mean(e*e)))
    rr = float(np.sqrt(np.mean(np.asarray(reference, dtype=np.float64)**2)))
    return {"rms": rms, "relative_rms": rms/rr if rr else None,
            "mean": float(np.mean(e)), "max_abs": float(np.max(np.abs(e))), "reference_rms": rr}


def repeat_stats(error, reference):
    s = stats(error, reference)
    n = len(error)
    mean = error.mean(axis=0)
    variance = error.var(axis=0, ddof=1) if n > 1 else np.zeros_like(mean)
    s["replicates"] = n
    s["mean_error_rms"] = float(np.sqrt(np.mean(mean*mean)))
    s["mc_bias_rms_debiased"] = float(np.sqrt(max(0, np.mean(mean*mean)-np.mean(variance)/n))) if n > 1 else None
    return s


def effective_weight(model, name):
    shape = model.tensors[name][0]
    trits, scales = model.rows_ptq1_0(name, 0, shape[1])
    weight = trits.astype(np.float64).reshape(shape[1], -1, 128)
    weight *= scales[:, :, None]
    return weight.reshape(shape[1], shape[0])


def run(dataset, trials, seed, clipping=()):
    started = time.monotonic()
    manifest = json.loads((dataset / "manifest.json").read_text())
    case = next(c for c in manifest["cases"] if c["nrows"] == 8)
    n, width, ff = case["nrows"], manifest["D"], manifest["FF"]
    def load(key, dtype, shape):
        return np.fromfile(dataset / case[key], dtype=dtype).reshape(shape)
    q8 = load("xq_d", np.int8, (n, width)).astype(np.float64)
    scales = load("xs_d", "<f4", (n, width//128)).astype(np.float64)
    sx = np.repeat(scales, 128, axis=1)
    gref = load("gate", "<f4", (n, ff)).astype(np.float64)
    uref = load("up", "<f4", (n, ff)).astype(np.float64)
    residual = load("x_out", "<f4", (n, width)).astype(np.float64)
    native_q = load("xq_ff", np.int8, (n, ff//128, 128))
    native_s = load("xs_ff", "<f4", (n, ff//128, 1)).astype(np.float64)
    signs = np.fromfile(dataset / manifest["weights"]["signs_ff"], dtype="<f4").astype(np.float64)
    configs, perturbations = [], []
    rng = np.random.default_rng(seed)
    for bits in (4, 5, 6, 7):
        limit = 2**(bits-1)-1
        target = q8 * (limit/127.)
        step = 127./limit
        for mode in ("nearest", "stochastic"):
            count = trials if mode == "stochastic" else 1
            if mode == "nearest":
                quant = np.rint(target)[None]
            else:
                low = np.floor(target)
                quant = low[None] + (rng.random((count, *target.shape)) < (target-low)[None])
            error = (quant*step-q8[None])*sx[None]
            begin = len(perturbations)
            perturbations.extend(error)
            configs.append({"bits": bits, "rounding": mode, "begin": begin, "count": count,
                            "activation_error": repeat_stats(error, q8*sx)})
    for ratio in clipping:
        limit = 7
        step = 127.*ratio/limit
        quant = np.clip(np.rint(q8/step), -limit, limit)[None]
        error = (quant*step-q8[None])*sx[None]
        begin = len(perturbations)
        perturbations.extend(error)
        configs.append({"bits": 4, "rounding": "nearest_clipped", "clip_ratio": ratio,
                        "begin": begin, "count": 1, "activation_error": repeat_stats(error, q8*sx)})
    dx = np.asarray(perturbations).reshape(-1, width)
    model = Gguf(manifest["model"])
    layer = manifest["layer"]
    wg = effective_weight(model, f"blk.{layer}.ffn_gate.weight")
    dg = dx @ wg.T
    gate_anchor = stats((q8*sx) @ wg.T-gref, gref)
    del wg
    wu = effective_weight(model, f"blk.{layer}.ffn_up.weight")
    du = dx @ wu.T
    up_anchor = stats((q8*sx) @ wu.T-uref, uref)
    del wu
    repeats = len(perturbations)
    g = np.tile(gref, (repeats, 1)) + dg
    u = np.tile(uref, (repeats, 1)) + du
    h0, q0, s0, deq0 = hidden_quant(gref, uref, signs)
    h, q, s, deq = hidden_quant(g, u, signs)
    dhq = deq-np.tile(deq0, (repeats, 1))
    wd = effective_weight(model, f"blk.{layer}.ffn_down.weight")
    dout = dhq @ wd.T
    del wd
    model.f.close()
    for c in configs:
        a, b = c.pop("begin"), c["count"]
        sl = slice(a*n, (a+b)*n)
        c["gate_error"] = repeat_stats(dg[sl].reshape(b,n,ff), gref)
        c["up_error"] = repeat_stats(du[sl].reshape(b,n,ff), uref)
        c["silu_product_error"] = repeat_stats((h[sl]-np.tile(h0,(b,1))).reshape(b,n,ff), h0)
        c["hidden_dequant_error"] = repeat_stats(dhq[sl].reshape(b,n,ff), deq0)
        c["residual_error"] = repeat_stats(dout[sl].reshape(b,n,width), residual)
        c["hidden_code_changed_fraction"] = float(np.mean(q[sl] != np.tile(q0,(b,1,1))))
        c["hidden_scale_error"] = stats(s[sl]-np.tile(s0,(b,1,1)), s0)
    return {"dataset": str(dataset), "manifest_sha256": hashlib.sha256((dataset/"manifest.json").read_bytes()).hexdigest(),
            "layer": layer, "tokens": case["tokens"], "seed": seed, "stochastic_trials": trials,
            "scope": "One full FFN, input quantization changed only; float64 perturbation model anchored at native gate/up. Not a multilayer or native candidate acceptance result.",
            "reference_gate_rounding_difference": gate_anchor, "reference_up_rounding_difference": up_anchor,
            "modeled_reference_hidden_code_mismatches": int(np.count_nonzero(q0 != native_q)),
            "modeled_reference_hidden_scale_error": stats(s0-native_s,native_s),
            "seconds": time.monotonic()-started, "configurations": configs}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--dataset", type=Path, required=True)
    p.add_argument("--trials", type=int, default=16)
    p.add_argument("--seed", type=int, default=812735)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--clipping", default="", help="Comma-separated A4 max-range fractions")
    args = p.parse_args()
    result = run(args.dataset, args.trials, args.seed, [float(v) for v in args.clipping.split(',') if v])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+"\n")
    for c in result["configurations"]:
        print(c["bits"], c["rounding"], "input", round(c["activation_error"]["relative_rms"],5),
              "hidden", round(c["silu_product_error"]["relative_rms"],5),
              "residual", round(c["residual_error"]["relative_rms"],5),
              "bias", c["residual_error"]["mc_bias_rms_debiased"])
    print("seconds",result["seconds"],"reference code mismatches",result["modeled_reference_hidden_code_mismatches"])
