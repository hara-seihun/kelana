#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=${BONSAI_ROOT:-/path/to/workspace/projects/bonsai-halo}
llama=${BONSAI_LLAMA:-/path/to/workspace/work/clones/bonsai-hip/build-hip/bin}
cd "$here"
mkdir -p build
rm -f build/capture-build.json build/capture
# Keep the link order in the same source as the receipt's object hashes.
mapfile -t objects < <(python3 "$here/package.py" list-objects)
[[ ${#objects[@]} -eq 18 ]] || { echo 'missing linked object list' >&2; exit 1; }
python3 "$here/package.py" record-inputs "$root"
hipcc --offload-arch=gfx1151 -O2 -std=c++17 -I"$root/src" -I"$root/kernels" \
    -c capture.cpp -o build/capture.o
for i in "${!objects[@]}"; do objects[i]="$root/${objects[i]}"; done
# The .cpp compile sets HIP input language; -x none restores object-file linking.
hipcc --offload-arch=gfx1151 -o build/capture -x none \
    build/capture.o "${objects[@]}" -L"$llama" -lllama -lggml -lggml-base \
    -Wl,-rpath,"$llama" -lpthread
python3 "$here/package.py" record-build "$root"
sha256sum "$here/build/capture"
