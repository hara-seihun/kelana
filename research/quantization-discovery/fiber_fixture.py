#!/usr/bin/env python3
"""Capture the full layer00 down/block0 fiber fixture on the CPU."""

import hashlib
import importlib.util
import io
import json
import math
import zipfile
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPOSITORY = HERE.parent.parent
BASE = Path("/path/to/workspace/data/kelana-ffn/ptq1_0/layer00")
DECODER = REPOSITORY / "research/ffn/batched/deferred-carrier/carrier_scan.py"
REFERENCE = HERE / "instances/bonsai-layer00-block0.json"
TARGET = HERE / "instances/bonsai-layer00-down-block0.npz"
PROVENANCE = TARGET.with_suffix(".json")
ROWS = 5120
KDIM = 17408
BLOCK = 128
TOKENS = 8


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_decoder():
    spec = importlib.util.spec_from_file_location("kelana_carrier_scan", DECODER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load decoder {DECODER}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def save_deterministic_npz(path: Path, arrays: dict[str, np.ndarray]) -> None:
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for key, value in arrays.items():
            payload = io.BytesIO()
            np.lib.format.write_array(payload, value, allow_pickle=False)
            member = zipfile.ZipInfo(f"{key}.npy", date_time=(1980, 1, 1, 0, 0, 0))
            member.compress_type = zipfile.ZIP_DEFLATED
            member.external_attr = 0o600 << 16
            archive.writestr(member, payload.getvalue(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def capture() -> None:
    weights_path = BASE / "down.halo"
    queries_path = BASE / "r8/xq_ff.i8"
    manifest_path = BASE / "manifest.json"

    decoder = load_decoder()
    weights, decoded_scales = decoder.halo_matrix(weights_path, ROWS, KDIM)
    trits = np.ascontiguousarray(weights[:, :BLOCK], dtype=np.int8)
    scales_fp16 = np.ascontiguousarray(decoded_scales[:, 0], dtype="<f2")
    scale_bits = np.ascontiguousarray(scales_fp16.view("<u2"))
    if not np.array_equal(scales_fp16.astype(np.float32), decoded_scales[:, 0]):
        raise AssertionError("decoded FP16 scale did not round-trip through float32")
    del weights, decoded_scales

    queries = np.fromfile(queries_path, dtype=np.int8).reshape(TOKENS, KDIM)[:, :BLOCK].copy()
    reference = json.loads(REFERENCE.read_text())
    reference_trits = np.asarray(reference["source_trits"], dtype=np.int8)
    reference_queries = np.asarray(reference["captured_integer_inputs"], dtype=np.int8)
    dots = queries.astype(np.int32) @ trits[0].astype(np.int32)
    reference_dots = np.asarray(reference["target"] + reference["heldout_target"], dtype=np.int32)
    row0_agreement = {
        "fixture": str(REFERENCE.relative_to(REPOSITORY)),
        "trits_exact": bool(np.array_equal(trits[0], reference_trits)),
        "queries_exact": bool(np.array_equal(queries, reference_queries)),
        "scale_exact": bool(float(scales_fp16[0]) == reference["input_provenance"]["common_weight_scale"]),
        "dot_products_exact": bool(np.array_equal(dots, reference_dots)),
        "dot_products": dots.tolist(),
    }
    if not all(value for key, value in row0_agreement.items() if key.endswith("_exact")):
        raise AssertionError(f"row0 disagrees with {REFERENCE}: {row0_agreement}")

    arrays = {
        "trits": trits,
        "scales_fp16": scales_fp16,
        "scale_bits": scale_bits,
        "queries": queries,
    }
    save_deterministic_npz(TARGET, arrays)

    counts = np.bincount((trits.reshape(-1) + 1).astype(np.uint8), minlength=3)
    probabilities = counts / counts.sum()
    entropy = -sum(float(p) * math.log2(float(p)) for p in probabilities if p)
    scale_bytes = scale_bits.astype("<u2", copy=False).tobytes()
    source_paths = [manifest_path, weights_path, queries_path]
    provenance = {
        "format": "kelana-fiber-fixture/1",
        "name": "bonsai-layer00-down-block0",
        "scope": "All 5120 down-projection output rows at input block 0, with eight captured hidden integer query blocks.",
        "arrays": {
            key: {"shape": list(value.shape), "dtype": value.dtype.str}
            for key, value in arrays.items()
        },
        "array_semantics": {
            "trits": "Down-projection ternary coefficients in {-1,0,1}; axis order is output row, input coordinate.",
            "scales_fp16": "Original per-row block-0 weight scale, retained as IEEE binary16.",
            "scale_bits": "Bit-identical uint16 view of scales_fp16.",
            "queries": "Eight captured r8/xq_ff.i8 hidden vectors at input block 0; axis order is token, input coordinate.",
        },
        "source": {
            "manifest": json.loads(manifest_path.read_text()),
            "sha256": {str(path): sha256(path) for path in source_paths},
            "weight_rows": ROWS,
            "weight_kdim": KDIM,
            "input_block": 0,
            "block_width": BLOCK,
            "query_row_stride": KDIM,
        },
        "decoder": {
            "algorithm": "research/ffn/batched/deferred-carrier/carrier_scan.py:halo_matrix",
            "sha256": sha256(DECODER),
        },
        "generator": {
            "path": str(Path(__file__).resolve().relative_to(REPOSITORY)),
            "sha256": sha256(Path(__file__).resolve()),
        },
        "original_storage_baseline": {
            "bytes_per_row_block": 28,
            "rows": ROWS,
            "bytes": ROWS * 28,
            "derivation": "One 896-byte HALO tile block stores 32 rows, so each row block occupies 28 bytes.",
        },
        "original_scale_bit_patterns": {
            "encoding": "5120 consecutive little-endian uint16 values, hex encoded",
            "count": int(scale_bits.size),
            "little_endian_hex": scale_bytes.hex(),
            "sha256": hashlib.sha256(scale_bytes).hexdigest(),
        },
        "row0_reference_agreement": row0_agreement,
        "trit_diagnostics": {
            "histogram": {str(value): int(counts[value + 1]) for value in (-1, 0, 1)},
            "total": int(counts.sum()),
            "entropy_bits_per_trit": entropy,
        },
        "fixture": {
            "path": str(TARGET.relative_to(REPOSITORY)),
            "bytes": TARGET.stat().st_size,
            "sha256": sha256(TARGET),
        },
    }
    PROVENANCE.write_text(json.dumps(provenance, indent=2) + "\n")
    print(json.dumps({
        "fixture": provenance["fixture"],
        "keys": list(arrays),
        "row0_reference_agreement": row0_agreement,
        "trit_diagnostics": provenance["trit_diagnostics"],
        "original_storage_bytes": ROWS * 28,
    }, indent=2))


if __name__ == "__main__":
    capture()
