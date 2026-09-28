#!/usr/bin/env python3
"""Measure common-output-coordinate capacity on captured Qwen routed sums."""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


KINDS = {
    "ffn_moe_weights_norm": ("<f4", (8,)),
    "ffn_moe_down": ("<f4", (8, 2048)),
    "ffn_moe_topk": ("<i4", (8,)),
}
RANKS = (32, 64, 112, 128, 256, 512, 768, 904)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def capture(root, split):
    tokens = np.fromfile(root / f"{split}.tokens", dtype="<i4")
    n = len(tokens)
    arrays = {}
    hashes = {f"{split}.tokens": digest(root / f"{split}.tokens")}
    for name, (dtype, trailing) in KINDS.items():
        path = root / f"{split}.0.{name}-0.bin"
        arr = np.fromfile(path, dtype=dtype)
        assert arr.size == n * int(np.prod(trailing)), (path, arr.size, n)
        arrays[name] = arr.reshape((n,) + trailing)
        hashes[path.name] = digest(path)
    weights = arrays["ffn_moe_weights_norm"].astype(np.float64)
    outputs = arrays["ffn_moe_down"].astype(np.float64)
    assert np.isfinite(weights).all() and np.isfinite(outputs).all()
    assert (weights >= 0).all() and np.allclose(weights.sum(axis=1), 1, atol=1e-5)
    assert (arrays["ffn_moe_topk"] >= 0).all() and (arrays["ffn_moe_topk"] < 256).all()
    return weights, outputs, np.einsum("te,ted->td", weights, outputs), hashes


def basis(matrix):
    return np.linalg.svd(matrix, full_matrices=False)[2]


def relative_residual(y, right_vectors, rank):
    c = right_vectors[:rank]
    return float(np.linalg.norm(y - (y @ c.T) @ c) / np.linalg.norm(y))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("--traffic", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    wt, dt, yt, train_hashes = capture(args.capture, "train")
    wh, dh, yh, held_hashes = capture(args.capture, "held")
    b_sum = basis(yt)
    b_slots = basis((wt[:, :, None] * dt).reshape(-1, 2048))
    b_plain = basis(dt.reshape(-1, 2048))
    b_held = basis(yh)
    results = {}
    for label, vectors in (("train_sum", b_sum), ("train_weighted_slots", b_slots),
                           ("train_unweighted_slots", b_plain), ("held_sum_oracle", b_held)):
        results[label] = {
            str(r): {"train_rms": relative_residual(yt, vectors, r),
                     "held_rms": relative_residual(yh, vectors, r)}
            for r in RANKS if r <= len(vectors)
        }
    traffic = json.loads(args.traffic.read_text())
    down = traffic["layers"]["0"]["tensors"][0]
    assert down["name"] == "blk.0.ffn_down_exps.weight"
    down_selected = down["bytes"] * 8 // 256
    rank = 512
    # Same bytes/coefficient is conditional: no rounded factor or common basis exists here.
    ratio = rank / 2048 + rank / (256 * 512)
    output = {
        "domain": "layer-0 actual GGUF FP32 expert down outputs and normalized scores; FP64 sum and SVD",
        "source_sha256": digest(Path(__file__)),
        "input_sha256": train_hashes | held_hashes | {"traffic.json": digest(args.traffic)},
        "tokens": {"train": len(yt), "held": len(yh)},
        "ranks": results,
        "rank512_conditional": {
            "direct_down_mac_per_token": 8 * 2048 * 512,
            "factor_plus_common_mac_per_token": 8 * rank * 512 + 2048 * rank,
            "down_bytes_per_token_all_layers": down_selected * 40,
            "down_selected_fraction_of_whole_weight_stream": down_selected * 40 / traffic["one_token_weight_stream_bytes"],
            "equal_coefficient_byte_ratio": ratio,
            "maximum_whole_weight_stream_saving_fraction_if_all_40_layers_behaved_like_layer0":
                down_selected * 40 * (1 - ratio) / traffic["one_token_weight_stream_bytes"],
            "assumption": "equal effective bytes per factor and common-basis coefficient; ignores scale metadata, routing, intermediate, conversion, occupancy and all other computation",
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2) + "\n")
    print(json.dumps({"held_rank512": {k: v.get("512", {}).get("held_rms") for k, v in results.items()},
                      "conditional_max_weight_saving": output["rank512_conditional"]["maximum_whole_weight_stream_saving_fraction_if_all_40_layers_behaved_like_layer0"]}, indent=2))


if __name__ == "__main__":
    main()
