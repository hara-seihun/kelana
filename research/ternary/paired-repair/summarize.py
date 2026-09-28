#!/usr/bin/env python3
"""Summarize frozen panels and paid image changes without GPU work."""
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from compare_images import compare
from pilot import ROOT, sha

DATA = ROOT / "paired-repair"
SOURCE = ROOT / "expanded-scale384"


def panel(arm, split):
    if split == "validation":
        paths = [DATA / f"{arm}-validation-0-8.json"]
    elif arm == "baseline":
        paths = [DATA / "baseline-test-0-32.json"]
    else:
        paths = [DATA / f"{arm}-test-{offset}-8.json" for offset in (0, 8, 16, 24)]
    receipts = [json.loads(path.read_text()) for path in paths]
    rows = [row for receipt in receipts for row in receipt["windows"]]
    if [row["index"] for row in rows] != list(range(8 if split == "validation" else 32)):
        raise ValueError("incomplete or reordered held panel")
    if len({receipt["image_manifest_sha256"] for receipt in receipts}) != 1:
        raise ValueError("image changed between chunks")
    return dict(nll=sum(row["nll"] for row in rows) / len(rows),
                predictions=sum(row["predictions"] for row in rows),
                receipt_sha256=[sha(path) for path in paths],
                manifest_sha256=receipts[0]["image_manifest_sha256"])


def main():
    search = json.loads((DATA / "search.json").read_text())
    result = dict(source_manifest_sha256=sha(SOURCE / "manifest.json"),
                  fixture_sha256=search["fixture_sha256"],
                  search_receipt_sha256=sha(DATA / "search.json"),
                  proposal_baseline=search["proposal_baseline"],
                  check_baseline=search["check_baseline"], arms={})
    for arm in ("baseline", "pair", "code", "scale"):
        record = dict(validation=panel(arm, "validation"), test=panel(arm, "test"))
        if arm != "baseline":
            comparison = compare(SOURCE, DATA / arm)
            record.update(image_manifest_sha256=comparison["candidate_manifest_sha256"],
                          payload_bytes=comparison["candidate_payload_bytes"],
                          changed_trits=comparison["changed_trits"],
                          changed_scales=comparison["changed_scales"],
                          winner=search["winners"][arm])
        result["arms"][arm] = record
    for arm in ("pair", "code", "scale"):
        for split in ("validation", "test"):
            result["arms"][arm][split]["delta_nll"] = (
                result["arms"][arm][split]["nll"] - result["arms"]["baseline"][split]["nll"])
    output = Path(__file__).with_name("results.json")
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({arm: {split: result["arms"][arm][split]["nll"] for split in ("validation", "test")}
                      for arm in result["arms"]}))


if __name__ == "__main__":
    main()
