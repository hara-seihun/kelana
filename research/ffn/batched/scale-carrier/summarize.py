#!/usr/bin/env python3
"""Collect observed equality and timed-window clocks, excluding the ramp."""
import json
from pathlib import Path
from statistics import median

root = Path(__file__).parent / "results"
summary = {}
for layer in (0, 10):
    data = json.loads((root / f"final-layer{layer}.json").read_text())
    traces = {t["rows"]: t["trace"]["samples"] for t in data["telemetry"]}
    lookup = {(r["rows"], r["candidate"]): r for r in data["runs"]}
    rows = []
    for r in data["runs"]:
        windows = [(b["begin_ns"], b["end_ns"]) for b in r["timing_blocks"]]
        samples = [s for s in traces[r["rows"]] if any(
            begin <= (s["begin_ns"] + s["end_ns"]) // 2 <= end for begin, end in windows)]
        clocks = [s["gfx_hz"] / 1e6 for s in samples if s["gfx_hz"] >= 0]
        rows.append({"candidate": r["candidate"], "rows": r["rows"],
                     "ms_median": r["ms_median"], "residual_rel_rms": r["error_vs_engine"]["rel_rms"],
                     "timed_clock_samples": len(clocks),
                     "gfx_mhz_median": median(clocks) if clocks else None,
                     "gfx_mhz_range": [min(clocks), max(clocks)] if clocks else None})
    for n in (32, 128, 256):
        assert lookup[n, "gs-palette1024-iu8-a8"]["output_sha256"] == lookup[n, "gs-absorb1024-iu8-a8"]["output_sha256"]
        assert len({lookup[n, name]["output_sha256"] for name in (
            "gs-global-iu8-a8-tt4", "gs-global-iu8-a8-tt8", "gs-global-iu8-a8-tt8-u2")}) == 1
    summary[str(layer)] = {"palette_hash_matches": True, "whole_K_schedule_hash_matches": True,
                           "timings": rows, "candidate_sources_sha256": data["candidate_sources_sha256"]}
print(json.dumps(summary, indent=2))
