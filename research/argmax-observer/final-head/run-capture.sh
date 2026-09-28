#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
model=${1:-/path/to/workspace/data/bonsai2/PTQ1_0.gguf}
output=${2:-$here/build/captures}
/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 42s \
    --exec python3 "$here/package.py" capture "$model" "$here/prompts.txt" "$output"
# Retain the executable named by the run receipt, not whatever a later build makes.
zstd -q -f "$here/build/capture" -o "$here/capture.zst"
