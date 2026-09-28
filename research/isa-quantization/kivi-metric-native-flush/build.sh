#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
clang++ -O3 -std=c++20 encode_cpu.cpp -o encode_cpu
hipcc -O3 --offload-arch=gfx1151 -save-temps -c encoder.hip -o encoder.o
cp encoder-hip-amdgcn-amd-amdhsa-gfx1151.s assembly-gfx1151.s
{
  printf '%s\n' 'Command: clang++ -O3 -std=c++20 encode_cpu.cpp -o encode_cpu'
  printf '%s\n' 'Command: hipcc -O3 --offload-arch=gfx1151 -save-temps -c encoder.hip -o encoder.o'
  clang++ --version
  hipcc --version
  llvm-objdump --syms encoder-hip-amdgcn-amd-amdhsa-gfx1151.o | grep 'g     [FO]' | grep -E 'flush_key|\.kd'
  grep -E 'amdhsa_group_segment_fixed_size|amdhsa_private_segment_fixed_size|amdhsa_next_free_(vgpr|sgpr)' assembly-gfx1151.s
} > compile-receipt.txt
