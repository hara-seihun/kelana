#!/usr/bin/env bash
set -euo pipefail

llvm_mc=${LLVM_MC:-llvm-mc}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

assemble() {
  local cpu=$1
  local wave=$2
  local input=$3
  local output=$4
  "$llvm_mc" -arch=amdgcn -mcpu="$cpu" -mattr="+wavefrontsize$wave" \
    --show-encoding "$input" >"$output"
}

assemble gfx1151 32 "$here/wmma-wave32.s" "$tmp/gfx1151-w32"
assemble gfx1151 64 "$here/wmma-wave64.s" "$tmp/gfx1151-w64"
assemble gfx1100 32 "$here/wmma-wave32.s" "$tmp/gfx1100-w32"
assemble gfx1100 64 "$here/wmma-wave64.s" "$tmp/gfx1100-w64"

diff -u "$tmp/gfx1100-w32" "$tmp/gfx1151-w32"
diff -u "$tmp/gfx1100-w64" "$tmp/gfx1151-w64"

for opcode in 40 41 42 43 44 45; do
  count=$(grep -c "0x$opcode,0xcc" "$tmp/gfx1151-w32")
  [[ $count == 1 ]] || {
    printf 'expected one gfx1151 opcode 0x%s, found %s\n' "$opcode" "$count" >&2
    exit 1
  }
done

reject() {
  local instruction=$1
  if printf '%s\n' "$instruction" |
    "$llvm_mc" -arch=amdgcn -mcpu=gfx1151 --show-encoding \
      >"$tmp/rejected.stdout" 2>"$tmp/rejected.stderr"; then
    printf 'gfx1151 unexpectedly accepted: %s\n' "$instruction" >&2
    exit 1
  fi
}

reject 'v_wmma_f32_16x16x16_fp8_fp8 v[16:23], v[0:1], v[2:3], v[16:23]'
reject 'v_swmmac_f32_16x16x32_f16 v[16:23], v[0:7], v[8:23], v[16:23], v0'
reject 'v_wmma_f32_16x16x16_f16_w32 v[16:23], v[0:7], v[8:15], v[16:23]'

"$llvm_mc" --version | head -4
printf 'gfx1151: six WMMA mnemonics accepted in wave32 and wave64 modes\n'
printf 'gfx1151 and gfx1100 emitted identical bytes for this WMMA set\n'
printf 'gfx12 FP8 WMMA, SWMMAC, and an assembly _w32 suffix were rejected\n'
