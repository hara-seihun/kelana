#!/usr/bin/env bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
compiler=${CLANG:-clang}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

"$compiler" -target amdgcn-amd-amdhsa -mcpu=gfx1151 -S -O3 -nogpulib \
  -x cl "$here/probe_peel3.cl" -o "$tmp/peel3.s"
awk '/^peel3:/{body=1} body{print} /s_endpgm/{exit}' "$tmp/peel3.s" > "$tmp/body.s"

grep -E 'v_(lshl_add|add3|mul|lshr|and)' "$tmp/body.s"
[[ $(grep -c 'v_lshl_add_u32' "$tmp/body.s") == 1 ]]
[[ $(grep -c 'v_lshrrev_b32' "$tmp/body.s") == 1 ]]
[[ $(grep -c 'v_and_b32' "$tmp/body.s") == 2 ]]
if grep -Eq 'v_mul|v_add3' "$tmp/body.s"; then
  printf 'unexpected multiply-by-three lowering\n' >&2
  exit 1
fi
printf 'gfx1151 lowering: multiply by three is one V_LSHL_ADD_U32; stage is four VALU instructions\n'
