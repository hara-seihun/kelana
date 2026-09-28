#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p emit
(cd emit && hipcc -O3 --offload-arch=gfx1151 -save-temps -c ../reader.hip -o reader.o)
cp emit/reader-hip-amdgcn-amd-amdhsa-gfx1151.s assembly-gfx1151.s
cp emit/reader-host-x86_64-unknown-linux-gnu.s assembly-host.s
{
  hipcc --version | head -3
  printf '\nDevice symbols (complete per-kernel body/helper/descriptor):\n'
  llvm-nm -S --size-sort emit/reader-hip-amdgcn-amd-amdhsa-gfx1151.out | grep -E ' [TtR] '
  printf '\nHost symbols (preparation, transfer/allocation and launch wrappers):\n'
  llvm-nm -S --size-sort emit/reader.o | grep -E ' [Tt] (prepare|release|launch)'
  printf '\nDevice resources in corresponding kernel order original/direct/prepared:\n'
  rg '^\s*\.amdhsa_(group_segment_fixed_size|private_segment_fixed_size|kernarg_size|next_free_vgpr|next_free_sgpr)' assembly-gfx1151.s
  printf '\nAssembly SHA256:\n'
  sha256sum assembly-gfx1151.s assembly-host.s
} > compile-receipt.txt
