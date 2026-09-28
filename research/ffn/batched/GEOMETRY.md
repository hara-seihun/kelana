# gfx1151 processor units

The Radeon 8060S has 20 work-group processors, 40 compute units and 80 SIMD32 units.

Evidence on this host:

- HIP `hipDeviceProp_t.multiProcessorCount` returns **20**. On this target it reports WGPs, not CUs.
- `/sys/class/kfd/kfd/topology/nodes/1/properties` reports `simd_count 80`, `simd_per_cu 2`, `cu_per_simd_array 10`, `array_count 4`, `gfx_target_version 110501` and `drm_render_minor 128`.
- The pinned RDNA 3.5 ISA manual defines a CU as half a WGP, containing two SIMD32 units. Workgroup waves can occupy all four SIMD32 units of a WGP. See [manual text](../../../hardware/gfx1151/sources/rdna35-isa.txt), glossary and WGP execution modes.

[geometry.hpp](geometry.hpp) owns this target-specific conversion. It rejects other architectures rather than applying this mapping without evidence.

## Correction to stored probes

The arithmetic and triple-packing rate probes originally multiplied HIP's count by two and printed 40 SIMD32 units. Both therefore used the same incorrect normalization. A stored `waves_per_simd = 8` means four waves per physical SIMD32, and its elapsed-per-wave work-unit time must be divided by four, not eight, to estimate aggregate physical per-SIMD cost.

The arithmetic probe's largest FP16 sample is 47.398 ns per per-wave instruction. The triple probe's corresponding independent-instruction sample is 47.9032 ns. Correctly normalized they are **11.8495 and 11.9758 ns per physical SIMD32**, respectively. The claim that the latter exposed a factor-of-two improvement over the former was a normalization mistake, not evidence of a dependency penalty.

The corrected source sizes launches from 80 SIMD32 units and records geometry explicitly. Existing raw files retain their recorded labels and values as evidence; apply the conversion above when reading them. Earlier bench JSON files with `cus:20` also stored the HIP processor count under the wrong name. New records separate `hip_multiprocessor_count`, `wgps`, `cus` and `simd32_count`.

The earlier `research/ffn/packed-wmma/bench.cpp` already used `CUs = 2 * HIP count` and `SIMDs = 2 * CUs`; its processor conversion was correct.

Whole-device elapsed times, useful-operation TOPS and ratios between matched kernels do not depend on this processor-unit label. The full-FFN interleaved comparisons are unchanged. No nominal clock is used to turn these times into exact cycle counts.
