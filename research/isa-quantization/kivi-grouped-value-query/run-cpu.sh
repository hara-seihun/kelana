#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
for panel in train held; do
 if [ "$panel" = train ]; then n=8; else n=4; fi
 for ((i=0;i<n;i++)); do /path/to/workspace/data/fish-s2-pro/venv/bin/python cpu.py "$panel" "$i"; done
done
python aggregate.py
