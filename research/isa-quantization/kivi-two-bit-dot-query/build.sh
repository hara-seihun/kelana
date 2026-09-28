#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p emit
(cd emit && hipcc -O3 --offload-arch=gfx1151 -save-temps -c ../consumer.hip -o consumer.o)
cp emit/consumer-hip-amdgcn-amd-amdhsa-gfx1151.s assembly-gfx1151.s
{
 hipcc --version | head -3
 echo 'Complete query/finish device symbols and sizes:'
 llvm-nm -S --size-sort emit/consumer-hip-amdgcn-amd-amdhsa-gfx1151.out | grep -E ' [TtR] '
 echo 'Kernel resource descriptors:'
 rg '^\s*\.amdhsa_(group_segment_fixed_size|private_segment_fixed_size|kernarg_size|next_free_vgpr|next_free_sgpr)' assembly-gfx1151.s
 sha256sum assembly-gfx1151.s
} > compile-receipt.txt
