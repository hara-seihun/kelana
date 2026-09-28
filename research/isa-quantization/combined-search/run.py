#!/usr/bin/env python3
"""Compile the bounded search, compare all frontiers, and measure isolated arms."""
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent


def run():
    with tempfile.TemporaryDirectory(prefix="kelana-joint-search-") as temporary:
        binary = Path(temporary) / "search"
        command = ["c++", "-O3", "-std=c++20", str(HERE / "experiment.cpp"), "-o", str(binary)]
        subprocess.run(command, check=True, timeout=45)
        subprocess.run([str(binary), str(HERE / "results.json")], check=True, timeout=45)
        oracle = json.loads((HERE / "results.json").read_text())
        signature = lambda arm: sorted((p["bytes"], p["work"], p["sse_units"]) for p in arm["frontier"])
        arms = []
        for mode in range(9):
            samples = []
            for _ in range(3):
                receipt = Path(temporary) / "receipt.json"
                subprocess.run([str(binary), str(receipt), str(mode)], check=True, timeout=45)
                value = json.loads(receipt.read_text())
                for actual, expected in zip(value["teachers"], oracle["teachers"], strict=True):
                    assert actual["target"] == expected["target"]
                    assert signature(actual["arms"][0]) == signature(expected["arms"][0])
                samples.append({
                    "elapsed_ms": value["elapsed_ms"],
                    "query_ms": sum(t["arms"][0]["ms"] for t in value["teachers"]),
                    "build_ms": value["index_build_ms"],
                    "peak_rss_kib": value["peak_rss_kib"],
                })
            arms.append({"mode": mode, "samples": samples,
                         "median": {key: statistics.median(s[key] for s in samples) for key in samples[0]}})
        result = {"compiler": subprocess.check_output(["c++", "--version"], text=True).splitlines()[0],
                  "platform": platform.platform(), "logical_cpus": os.cpu_count(),
                  "source_sha256": hashlib.sha256((HERE / "experiment.cpp").read_bytes()).hexdigest(),
                  "method": "Three foreground fresh processes per arm; process RSS includes executable/runtime; same single CPU search; no native inference timing.",
                  "arms": arms}
        (HERE / "timings.json").write_text(json.dumps(result, indent=2) + "\n")
        for arm in arms:
            print(arm["mode"], arm["median"])


if __name__ == "__main__":
    run()
