#!/usr/bin/env python3
"""Assemble the online cores for gfx1151 and report their opcode counts."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
EXPECTED = {
    "toy2_incumbent_online": {"v_dot8_i32_iu4": 2, "v_lshl_or_b32": 1},
    "toy2_fused_online": {"v_dot4_i32_iu8": 1, "v_dot8_i32_iu4": 1},
    "toy2_single_online": {"v_dot4_i32_iu8": 1},
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    source = ROOT / "kernels.s"
    with tempfile.TemporaryDirectory(prefix="kelana-toy2-opt-") as temp:
        obj = Path(temp) / "kernels.o"
        subprocess.run(["llvm-mc", "-triple=amdgcn-amd-amdhsa", "-mcpu=gfx1151",
                        "-filetype=obj", str(source), "-o", str(obj)], check=True)
        disassembly = subprocess.check_output(
            ["llvm-objdump", "--disassemble", "--mcpu=gfx1151", str(obj)], text=True)
    functions, current = {}, None
    for line in disassembly.splitlines():
        label = re.search(r"<([^>]+)>:", line)
        if label:
            current = label.group(1)
            functions[current] = Counter()
        match = re.match(r"\s+(v_\w+)", line)
        if match and current:
            functions[current][match.group(1).removesuffix("_e32")] += 1
    assert {k: dict(v) for k, v in functions.items()} == EXPECTED, functions
    result = {
        "target": "gfx1151",
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "instructions": {k: dict(v) for k, v in functions.items()},
        "online_totals": {k: sum(v.values()) for k, v in functions.items()},
        "scope": "Encodings accepted and disassembled by LLVM; not a timing measurement.",
    }
    text = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
