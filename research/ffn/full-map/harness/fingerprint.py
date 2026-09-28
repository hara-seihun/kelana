#!/usr/bin/env python3
"""Stamp the benchmark with the source bytes used for this build."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

here = Path(__file__).resolve().parent
bonsai = Path(sys.argv[1]).resolve()
roots = [here.parent, bonsai / "kernels", bonsai / "src"]
files = set()
for root in roots:
    files.update(p for p in root.rglob("*") if p.is_file() and
                 (p.suffix in {".h", ".hpp", ".hip", ".cpp"} or p.name == "Makefile")
                 and p.name != "build-info.h")
files.add(Path(__file__).resolve())
hash_ = hashlib.sha256()
for p in sorted(files):
    owner = next((r for r in roots if p.is_relative_to(r)), here)
    hash_.update(str(p.relative_to(owner)).encode() + b"\0" + p.read_bytes() + b"\0")
revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=here, text=True).strip()
compiler = subprocess.check_output(["hipcc", "--version"], text=True)
hash_.update(compiler.encode())
text = "#pragma once\n#define KFFN_SOURCE_SHA256 " + json.dumps(hash_.hexdigest()) + "\n"
text += "#define KFFN_SOURCE_REVISION " + json.dumps(revision) + "\n"
text += "#define KFFN_COMPILER " + json.dumps(compiler.strip()) + "\n"
out = here / "build-info.h"
if not out.exists() or out.read_text() != text:
    out.write_text(text)
