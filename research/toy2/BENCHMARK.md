# HIP throughput for the 2×2 ternary MAC

The [proved construction](PROOF.md) runs faster on the Radeon 8060S, gfx1151. This is `D = AB + C` for ternary 2×2 matrices, using native int4 dot instructions, not WMMA.

## Results

Three independently seeded workloads, 11 alternating timing pairs per workload:

| Workload | Elementwise int4 | Packed construction | Paired speedup |
| --- | ---: | ---: | ---: |
| Streaming | 24.9–27.4 billion maps/s | 43.8–44.5 billion maps/s | **1.60–1.78×** |
| Register replay | 334.9–340.8 billion maps/s | 597.5–610.8 billion maps/s | **1.79–1.81×** |

One map means a complete 2×2 multiply-add, producing four exact results in two radix-7 bytes. Rates are not individual scalar products or FLOPS. Each range spans the three run medians. Speedups are medians of adjacent timing ratios, so they need not equal ratios of separately reported medians.

Both implementations passed all **531,441** possible A/B/C combinations on the GPU. Every random streaming output and every register-replay checksum also matched ordinary CPU matrix arithmetic, before and after timing. Zero mismatches.

[benchmark-results.json](benchmark-results.json) contains every sample, seeds, hashes, compiler version, GPU identity and compiled-kernel resource counts. Voice was stopped with the project lead's authorization. Bonsai Halo remained loaded; its journal recorded no request starts or completions during any run.

## What is timed

Both implementations receive the same B/C input, already expanded into eight unsigned int4 trit codes. A's coefficients, biases and orientation are prepared in one host pass. Packing, reference calculation, allocations and host/device transfers are outside timing for both implementations. Neither preparation computes AB or depends jointly on A and B/C.

The measured arithmetic cores are therefore **7 instructions versus 3**, after removing the common six-instruction expansion from the proof's 13 versus 9. Both produce the same packed output. Conversion to another output format is absent from both.

The elementwise baseline uses four `V_DOT8_I32_IU4`, two `V_MAD_U32_U24` and one `V_LSHL_OR_B32`. It already folds C into dot lanes and constants into prepared biases. The packed construction uses two dots and one shift-or. It computes pairs of results directly in radix 7. It still uses int4 instruction operands; this is not an end-to-end dense base-3 execution engine.

### Streaming

Each launch reads 1,048,576 random matrix triples and writes all outputs. A is independently random per case. Arrays use structure-of-arrays layouts for coalesced access.

Prepared coefficient traffic differs. The baseline loads six words per case; the candidate loads three. Including the common input and output word, the logical traffic is **32 versus 20 bytes per map**. Thus the streaming result includes a memory-layout advantage, not just the arithmetic saving. The batch is reused between launches; cache effects are part of this measurement. It is not a cold-memory bandwidth measurement.

### Register replay

32,768 threads each load a random A and eight independently random B/C pairs into registers. They evaluate each pair 256 times, accumulating eight checksums. This executes 67,108,864 maps per launch over 262,144 input cases, sampled with replacement. It measures repeated issue throughput on resident operands, not 67 million newly loaded random inputs.

Both cores use volatile inline assembly so the compiler cannot replace repeated evaluations with one evaluation. The common checksum additions, loop control, initial loads and final stores remain timed. No dummy arithmetic is inserted into either core. The emitted loop contains 32 versus 16 dots per eight maps. Compiler-reported VGPR counts are **32 versus 24**, with no spills. Streaming kernels use 16 versus 10 VGPRs.

### Timing

HIP events measure GPU execution. Each workload warms both kernels for at least 150 ms. An event interval contains 64 streaming launches or 16 register-replay launches. Eleven pairs alternate which implementation runs first. All samples are retained; no slow samples are discarded. Kernel launches, memory instructions and termination remain in the measured intervals. This is observed throughput, not a measurement of physical execution-unit cycles or a proof of global optimality.

## Run it

From the repository root:

```sh
python3 research/toy2/benchmark.py
```

The runner builds [benchmark.cpp](benchmark.cpp), extracts the compressed GPU object from the actual executable, checks the dot and multiply-add counts, checks for spills, then runs three seeds through `gpu-run`. It writes the result JSON plus [disassembly](benchmark-results-disassembly.txt) and [metadata](benchmark-results-metadata.txt). Change the output location or seeds with `--output PATH --seeds N ...`.

[The shared implementation](toy2.hpp) owns preparation and both native arithmetic cores. HIP, LLVM, Python and GPU admission are host-installed tools. The runner reserves 1,024 MiB host demand including 256 MiB GTT, and does not control services. the project lead subsequently requested leaving voice stopped and GPU admission disabled; [the host handbook](../../../../machine/gpu-jobs.md#administrator-runtime-switch) owns those controls.
