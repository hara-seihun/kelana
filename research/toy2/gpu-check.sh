#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
hipcc -O3 --offload-arch=gfx1151 "$here/gpu_check.cpp" -o "$tmp/check"
gpu-run --host-mib 1024 --gtt-mib 256 "$tmp/check"
