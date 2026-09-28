#!/usr/bin/env bash
# Record what the installed gfx1151 assembler does with each assembly form listed in
# forms.txt, and write eligibility.json. Architecture inventory and gfx1151 toolchain
# eligibility are different claims; this file carries the second one.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
forms="$here/forms.txt"
out="$here/eligibility.json"
mc="${LLVM_MC:-llvm-mc}"

version="$("$mc" --version | sed -n '1,2p' | tr -d '\r' | paste -sd' ' - | sed 's/  */ /g')"

python3 - "$forms" "$out" "$mc" "$version" <<'PY'
import json, subprocess, sys

forms_path, out_path, mc, version = sys.argv[1:5]
entries = []
for line in open(forms_path, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    instruction, _, form = line.partition("\t")
    form = form.strip()
    run = subprocess.run(
        [mc, "-arch=amdgcn", "-mcpu=gfx1151", "-show-encoding"],
        input=form + "\n", capture_output=True, text=True)
    accepted = run.returncode == 0
    if accepted:
        encoding = [part.split("encoding:")[1].strip()
                    for part in run.stdout.splitlines() if "encoding:" in part]
        detail = encoding[0] if encoding else run.stdout.strip()
    else:
        diagnostic = [l.split("error:", 1)[1].strip()
                      for l in run.stderr.splitlines() if "error:" in l]
        detail = diagnostic[0] if diagnostic else run.stderr.strip()
    entries.append({"instruction": instruction.strip(), "form": form,
                    "accepted": accepted, "detail": detail})

json.dump({
    "target": "gfx1151",
    "assembler": version,
    "command": "hardware/gfx1151/lean/probe-eligibility.sh",
    "probes": entries,
}, open(out_path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
open(out_path, "a", encoding="utf-8").write("\n")
print(f"{len(entries)} probes -> {out_path}")
PY
