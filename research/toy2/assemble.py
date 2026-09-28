#!/usr/bin/env python3
"""Assemble both gfx1151 cores and report their emitted vector instruction counts."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    source = ROOT / "kernels.s"
    with tempfile.TemporaryDirectory(prefix="kelana-toy2-") as temp:
        obj = Path(temp) / "kernels.o"
        subprocess.run(["llvm-mc", "-triple=amdgcn-amd-amdhsa", "-mcpu=gfx1151",
                        "-filetype=obj", str(source), "-o", str(obj)], check=True)
        disassembly = subprocess.check_output(
            ["llvm-objdump", "--disassemble", "--mcpu=gfx1151", str(obj)], text=True)
    functions = {}
    current = None
    for line in disassembly.splitlines():
        label = re.search(r"<([^>]+)>:", line)
        if label:
            current = label.group(1)
            functions[current] = Counter()
        match = re.match(r"\s+(v_\w+)", line)
        if match and current:
            functions[current][match.group(1).removesuffix("_e32")] += 1
    expected = {
        "toy2_baseline": {"v_lshl_or_b32": 4, "v_and_b32": 3,
                          "v_dot8_i32_iu4": 4, "v_mad_u32_u24": 2},
        "toy2_packed": {"v_lshl_or_b32": 4, "v_and_b32": 3, "v_dot8_i32_iu4": 2},
    }
    assert functions == expected, functions
    result = {
        "target": "gfx1151", "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "instructions": functions,
        "instruction_totals": {k: sum(v.values()) for k, v in functions.items()},
        "common_terminator": "s_endpgm, excluded from both core counts",
        "scope": "Real instruction encodings accepted and disassembled; not a GPU timing measurement.",
    }
    text = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
