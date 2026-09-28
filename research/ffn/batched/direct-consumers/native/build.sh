#!/usr/bin/env bash
# Build the consumer probe, capture its real device assembly, record both runs, and produce paired
# per-round statistics. Every GPU launch goes through ../../hardware-run, which serializes
# participating research workers.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build results/asm results/paired

ARCH=${ARCH:-gfx1151}
FLAGS=(-O3 --offload-arch="$ARCH" -std=c++17 -Wno-unused-value)

hipcc "${FLAGS[@]}" consumer_probe.hip -o build/consumer_probe
hipcc "${FLAGS[@]}" --cuda-device-only -S consumer_probe.hip -o results/asm/consumer_probe.s

# Per-kernel VALU instruction counts, straight out of the emitted assembly.
python3 kernel_ops.py results/asm/consumer_probe.s > results/asm/kernel_ops.json

../../hardware-run ./build/consumer_probe check > results/check.json
../../hardware-run ./build/consumer_probe rate "${ITERS:-8000}" "${ROUNDS:-20}" "${CALLS:-5}" \
    > results/rate.json 2> results/rate-summary.txt

# bench/paired_analysis.py compares candidates within one `rows` group against one baseline, so
# split the consumer groups from the bilinear group and run it once per baseline of interest.
python3 - <<'PY'
import json
d = json.load(open('results/rate.json'))
for name, rows in (('consumers', (2, 8)), ('bilinear', (1,))):
    out = dict(d)
    out['runs'] = [r for r in d['runs'] if r['rows'] in rows]
    out['telemetry'] = [t for t in d['telemetry'] if t['rows'] in rows]
    json.dump(out, open(f'build/rate-{name}.json', 'w'))
PY
for baseline in w-decode-24 w-decode-relu n-decode n-decode-f32 w-poly-decode; do
    python3 ../../bench/paired_analysis.py build/rate-consumers.json \
        --baseline "$baseline" --out "results/paired/$baseline.json" > /dev/null
done
python3 ../../bench/paired_analysis.py build/rate-bilinear.json \
    --baseline bilinear-decode --out results/paired/bilinear-decode.json > /dev/null

echo "wrote results/check.json results/rate.json results/paired/ results/asm/"
