#!/usr/bin/env python3
"""Transfer selected paid trit arrays while keeping every other source image field."""
import argparse
import json
import shutil
import tempfile
from pathlib import Path

import numpy as np

from pilot import ROOT, sha


def splice(base: str, donor: str, name: str, layer: int):
    source, changed, destination = (ROOT / part for part in (base, donor, name))
    if destination.exists() or name in (base, donor):
        raise ValueError("destination must be a new image")
    base_manifest = json.loads((source / "manifest.json").read_text())
    donor_manifest = json.loads((changed / "manifest.json").read_text())
    donors = {row["key"]: row for row in donor_manifest["matrices"]}
    if base_manifest["payload_bytes"] != donor_manifest["payload_bytes"]:
        raise ValueError("source and donor must have equal paid bytes")
    with tempfile.TemporaryDirectory(prefix=f".{name}-", dir=ROOT) as temp:
        out = Path(temp)
        records = []
        changes = {}
        for record in base_manifest["matrices"]:
            key = record["key"]
            filename = key.replace(".", "_") + ".npz"
            src, dst = source / filename, out / filename
            if sha(src) != record["sha256"]:
                raise ValueError(f"source image changed: {key}")
            donor_record = donors[key]
            transfer = key.startswith(f"model.layers.{layer}.")
            if transfer:
                donor_file = changed / filename
                if sha(donor_file) != donor_record["sha256"]:
                    raise ValueError(f"donor image changed: {key}")
                with np.load(src) as original, np.load(donor_file) as candidate:
                    for field in ("shape", "signs", "rotation_block"):
                        if not np.array_equal(original[field], candidate[field]):
                            raise ValueError(f"{key}: {field} changed")
                    arrays = {field: original[field].copy() for field in original.files}
                    arrays["codes"] = candidate["codes"].copy()
                    changes[key] = int(sum((a != b).sum() for a, b in zip(
                        np.unpackbits(original["codes"]), np.unpackbits(candidate["codes"]))))
                np.savez(dst, **arrays)
            else:
                shutil.copy2(src, dst)
            row = dict(record, sha256=sha(dst), file_bytes=dst.stat().st_size,
                       source_image_sha256=record["sha256"], method="splice-paid-codes" if transfer else record["method"])
            records.append(row)
            (out / filename).with_suffix(".json").write_text(json.dumps(row, indent=2) + "\n")
        shutil.copy2(source / "norms.npz", out / "norms.npz")
        manifest = dict(base_manifest, matrices=records, source_manifest_sha256=sha(source / "manifest.json"),
                        donor_manifest_sha256=sha(changed / "manifest.json"), code_transfer_layer=layer,
                        changed_packed_bits=changes)
        (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        out.rename(destination)
    print(json.dumps({"image": str(destination), "bpw": manifest["bpw"], "changed_packed_bits": changes}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--donor", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--layer", type=int, required=True)
    args = parser.parse_args()
    splice(args.base, args.donor, args.name, args.layer)
