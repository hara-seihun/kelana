#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec 9>/tmp/kelana-gpu-measure.lock
if ! flock -n -E 75 9; then
  echo 'DENIED: Kelana measurement lock occupied; no GPU launch' >&2
  exit 75
fi
before=$(systemctl --user show bonsai-halo.service -p MainPID --value)
active=$(systemctl --user show bonsai-halo.service -p ActiveState --value)
if [[ "$active" != active || ! "$before" =~ ^[1-9][0-9]*$ ]] || ! kill -0 "$before" 2>/dev/null; then
  echo "DENIED: Bonsai resident unavailable state=$active pid=$before; no GPU launch" >&2
  exit 76
fi
printf 'resident_before=%s state=%s\n' "$before" "$active"
set +e
gpu-run --host-mib 1024 --gtt-mib 512 ./native . ../kivi-two-bit-dot-native > timing.jsonl
result=$?
set -e
second=$(systemctl --user show bonsai-halo.service -p MainPID --value)
active=$(systemctl --user show bonsai-halo.service -p ActiveState --value)
printf 'gpu_run_exit=%s resident_after=%s state=%s\n' "$result" "$second" "$active"
[[ "$second" == "$before" && "$active" == active ]] || exit 77
exit "$result"
