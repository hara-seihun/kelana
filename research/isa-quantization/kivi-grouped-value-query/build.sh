#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
g++ -O3 -std=c++17 -fPIC -shared reader.cpp -o reader.so
mkdir -p emit
(cd emit && hipcc -O3 --offload-arch=gfx1151 -save-temps -c ../consumer.hip -o consumer.o)
cp emit/consumer-hip-amdgcn-amd-amdhsa-gfx1151.s assembly-gfx1151.s
{
 hipcc --version | head -3
 llvm-nm -S --size-sort emit/consumer-hip-amdgcn-amd-amdhsa-gfx1151.out | grep -E ' [TtR] '
 rg '^\s*\.amdhsa_(group_segment_fixed_size|private_segment_fixed_size|kernarg_size|next_free_vgpr|next_free_sgpr)' assembly-gfx1151.s
 sha256sum assembly-gfx1151.s consumer.hip reader.cpp
} > compile-receipt.txt
