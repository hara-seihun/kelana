#!/usr/bin/env bash
# Single nonwaiting, bounded launch. Never stops/starts resident Bonsai.
set -euo pipefail
cd "$(dirname "$0")"
exec 9>/tmp/kelana-gpu-measure.lock
if ! flock -n -E 75 9; then
  echo 'DENIED: Kelana measurement lock occupied (nonblocking admission, no GPU launch)' >&2
  exit 75
fi
before=$(systemctl --user show bonsai-halo.service -p MainPID --value)
active=$(systemctl --user show bonsai-halo.service -p ActiveState --value)
if [[ "$active" != active || ! "$before" =~ ^[1-9][0-9]*$ ]]; then
  echo "DENIED: Bonsai resident serving unavailable: state=$active pid=$before; preserving requested no-stop/no-restart boundary" >&2
  exit 76
fi
if ! kill -0 "$before" 2>/dev/null; then
  echo "DENIED: Bonsai resident PID $before not live" >&2
  exit 76
fi
printf 'resident_before=%s\n' "$before"
# gpu-run's host budget includes GTT; no waiting or fallback budget.
gpu-run --host-mib 1024 --gtt-mib 512 ./native . > timing.jsonl
second=$(systemctl --user show bonsai-halo.service -p MainPID --value)
active=$(systemctl --user show bonsai-halo.service -p ActiveState --value)
printf 'resident_after=%s state=%s\n' "$second" "$active"
[[ "$second" == "$before" && "$active" == active && -s timing.jsonl ]]
