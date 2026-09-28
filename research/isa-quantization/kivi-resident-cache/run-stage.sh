#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
phase=${1:?accept or timing}; window=${2:?held-0..3}
[[ "$phase" == accept || "$phase" == timing ]]
[[ "$window" =~ ^held-[0-3]$ ]]
receipt="attempt-$phase-$window.txt"
if [[ -e "$receipt" ]]; then
  echo "This frozen stage already has an attempt receipt: $receipt" >&2
  exit 79
fi
if [[ "$phase" == timing ]]; then
  python3 gate.py
fi
exec > "$receipt" 2>&1
printf 'stage=%s window=%s utc=%s\n' "$phase" "$window" "$(date -u +%FT%TZ)"
exec 9>/tmp/kelana-gpu-measure.lock
if ! flock -n -E 75 9; then echo 'admission=denied lock occupied'; exit 75; fi
before=$(systemctl --user show bonsai-halo.service -p MainPID --value)
active=$(systemctl --user show bonsai-halo.service -p ActiveState --value)
if [[ "$active" != active || ! "$before" =~ ^[1-9][0-9]*$ ]] || ! kill -0 "$before" 2>/dev/null; then
  echo "admission=denied resident=$before state=$active"; exit 76
fi
printf 'resident_before=%s state=%s\n' "$before" "$active"
sha256sum native state.hip step_bits.hpp native.hip
set +e
timeout --signal=TERM --kill-after=3s 45s gpu-run --host-mib 1024 --gtt-mib 512 \
  ./native "$window" "../kivi-value-intern/$window-events.bin" "$window-snapshots.bin" "$phase" \
  > "$phase-$window.jsonl"
result=$?
set -e
after=$(systemctl --user show bonsai-halo.service -p MainPID --value)
active=$(systemctl --user show bonsai-halo.service -p ActiveState --value)
printf 'gpu_run_exit=%s resident_after=%s state=%s\n' "$result" "$after" "$active"
[[ "$after" == "$before" && "$active" == active ]] || exit 77
flock -u 9
[[ "$result" == 0 ]] || exit "$result"
if [[ "$phase" == accept ]]; then
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
    audit.py "$window" "$window-snapshots.bin" > "audit-$window.json"
fi
python3 stage-receipt.py "$phase" "$window"
