#!/usr/bin/env bash
# Drain a list of jobs under one wall budget. Safe to re-run: each job resumes.
#   ./sweep.sh 45 job1 job2 ...
set -u
budget="$1"; shift
end=$(( $(date +%s) + budget ))
for job in "$@"; do
  left=$(( end - $(date +%s) ))
  [ "$left" -le 3 ] && { echo "budget spent before $job"; break; }
  python3 run_search.py "$job" --budget "$left" --workers 28 ${TMO:+--timeout-ms $TMO} ${RETRY:-} 2>&1 | tail -2
done
