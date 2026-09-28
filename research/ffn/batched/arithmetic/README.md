# Batched arithmetic maps

What a ternary FFN should compute with at 32–256 tokens, measured on gfx1151.

The short answer: **the win at batch comes from the activation width, not from pairing.** Halving
activations from eight bits to four is worth about 1.4x on the whole FFN. Paired ternary
coefficients are one way to spend that; the native IU4 instruction is another, and the two land
within 15% of each other. The exact two-plane paired map, which won at eight tokens, is the worst
candidate here — three to four times slower than plain IU8 on the same kernels.

## The instruction rate that decides it

[`rate_probe.hip`](rate_probe.hip) times the three WMMA operand classes with register-resident
operands and two accumulator chains. The stored probe mislabeled HIP's 20 work-group processors as CUs and assumed 40 SIMD32 units; this device has 40 CUs and 80 SIMD32 units. Thus the stored `waves/SIMD` labels below are twice the physical value. The printed ns values are elapsed time per per-wave instruction, not aggregate per-SIMD issue cost. At the largest row, FP16 is `47.398 / 4 = 11.8495 ns` per physical SIMD. The later independent-instruction probe gives `47.9032 / 4 = 11.9758 ns`, agreeing rather than improving by a factor of two. Both probes now use [geometry.hpp](../geometry.hpp).

| waves/SIMD (probe's count) | f16 | iu8 | iu4 | iu4 / f16 |
| --- | ---: | ---: | ---: | ---: |
| 1 | 12.007 ns | 12.006 ns | 6.157 ns | 0.513 |
| 2 | 12.098 | 12.052 | 6.195 | 0.512 |
| 4 | 23.988 | 23.925 | 12.072 | 0.503 |
| 8 | 47.398 | 47.252 | 23.973 | 0.506 |

`v_wmma_i32_16x16x16_iu4` takes approximately half the time of the FP16 and IU8 forms in this probe. The FP16/IU8
equality confirms the earlier [packed-wmma measurement](../../packed-wmma/NOTES.md); the IU4 half
cost was previously only quoted from AMD's discrete-RDNA3 table, and now it is measured here.

All three instructions compute 16x16x16. So per unit of issue time the hardware offers, at 16 real
tokens per B tile:

| map | logical rows per instruction | activation width | MACs per issue slot |
| --- | ---: | --- | ---: |
| IU8, one row per matrix row | 16 | 8 bit | 4096 |
| paired FP16, two exact digit planes | 32 (two instructions) | 8 bit | 4096 |
| paired FP16, one four-bit plane | 32 | 4 bit | 8192 |
| IU4, one row per matrix row | 16 (half-cost instruction) | 4 bit | 8192 |

That table is the whole finding. Pairing buys a factor of two over IU8 only when the activation
fits in one plane, and IU4 reaches the same factor with no pairing at all.

**Two is the ceiling inside this family, which is fixed-radix packing of independent channels into
one operand.** A packed coefficient `g + R*u` whose channels are recovered independently after
accumulation needs `R > 2*max|sum g_j b_j|`. With at most 127 nonzeros per 128-block and four-bit
digits that is `R >= 2033`, and FP16 represents integers exactly only to 2048, so `R = 2047` fits
exactly one pair and a third channel at `R^2` has no room. Packing tokens rather than rows fails
the same bound: `a + 2048*b` with `b` up to 7 reaches 14343, where FP16 spacing is already 8. An
int8 or int4 operand has no room for any radix.

The scope matters. This argument fixes one radix, requires every channel to survive the whole
128-term accumulation, and recovers each channel on its own. It says nothing about maps that let
channels cancel, that decode at a shorter accumulation length, that carry a coarse channel
alongside a packed one (the [guided-packing](../../full-map/README.md) shape), or that leave this
representation altogether. Those are open, and the lookup and spanning directories are looking at
some of them. What is settled is that within fixed-radix FP16 packing, 32 logical rows per
instruction is the maximum reached, and four-bit activations are the only rung below eight-bit that
this family gets paid for.

**Six-bit activations have no speed rung in the measured digit-splitting family.** Six bits still
needs two planes under the radix bound above, so it lands on the 1x rung alongside eight bits. That
is a statement about splitting an activation into fixed-width digit planes for these instructions,
not a universal claim about representing six-bit activations.

## Component measurement: the gate/up projection

[`proj_probe.hip`](proj_probe.hip) computes the real projection shape (D = 5120, FF = 17408,
178.3 M ternary weights) with weights streamed from memory every pass, FP16 scale per
(row, 128-block) and FP32 scale per (token, 128-block). `./build/proj_probe check` verifies all five
maps against a CPU integer reference; worst relative deviation is 2.8e-6, from FP16 scale rounding.

Weight images: paired 45.16 MB, two-bit 42.50 MB, four-bit nibbles 85.00 MB.

| tokens | paired1 (a4) | paired2 (a8 exact) | iu8 (a8) | iu4 nibble (a4) | iu4 two-bit (a4) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 16 | 0.274 ms | 0.399 | 0.613 | 0.619 | 0.417 |
| 32 | 0.392 | 0.891 | 0.587 | 0.697 | 0.531 |
| 64 | 0.557 | 1.415 | 0.761 | 0.744 | 0.630 |
| 128 | 1.046 | 3.650 | 1.405 | 1.317 | 1.065 |
| 256 | 2.120 | 7.467 | 2.719 | 2.535 | 1.937 |

Storing ternary weights as two bits and expanding to int4 nibbles in registers beats storing the
nibbles directly at every size, by 23% at 256 tokens: ten VALU operations per sixteen weights cost
less than the second half of the weight image.

## Whole FFN through the common interface

[`candidates/arith_maps.hip`](candidates/arith_maps.hip) registers six candidates with
[`api.hpp`](../api.hpp), measured by [`bench`](../bench/README.md) on 256 real contextual rows of
one document. Four kernels per call: producer, gate/up with fused SiLU, hidden producer, down with
the residual. Everything input-dependent is inside `run`.

Name `X/Y` means map `X` at the gate/up input and map `Y` at the down projection's activation.
Errors are against the residual the deployed engine produced for those rows. Full samples in
[`results/arith-layer0.json`](results/arith-layer0.json).

| rows | deployed | paired-a4 | iu4-a4 | iu8-a8 | paired-a8 | iu4-a4/a8-down |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 32 | 4.042 ms | **0.895** | 1.030 | 1.140 | 2.098 | 1.058 |
| 64 | 7.024 | **0.995** | 1.158 | 1.364 | 3.453 | 1.214 |
| 128 | 14.057 | **1.537** | 1.701 | 2.267 | 6.005 | 1.863 |
| 256 | 29.142 | **3.274** | 3.324 | 4.580 | 13.529 | 3.693 |

| rows | rel RMS error vs engine, a4 everywhere | a4 input only | a8 (both) |
| ---: | ---: | ---: | ---: |
| 32 | 1.237% | 0.845% | 0.014% |
| 64 | 1.134% | 0.779% | 0.013% |
| 128 | 1.065% | 0.718% | 0.013% |
| 256 | 0.965% | 0.652% | 0.012% |

The 0.012% of the eight-bit candidates is not quantisation, it is a different summation order from
the deployed kernel over the same integers. The bias term stays at 1e-7 and the worst single row is
about twice the batch RMS.

What the numbers say:

- **Four-bit activations are worth 1.27x–1.47x on the whole FFN** against the same kernels, same
  tiling, same producers and same epilogue at eight bits. At the configuration main's full-model
  evaluation actually measured — four-bit at the FFN input, eight-bit at the down activation — the
  gain is 1.08x at 32 rows and 1.24x at 256.
- **Pairing adds 5–15% over native IU4, not a factor.** `paired-a4` beats `iu4-a4` on the whole FFN
  because one paired A fragment feeds 32 logical rows from one load and one decode, while IU4 pays
  two loads and two expansions; the component probe, whose gate/up stage stores both projections
  separately, ranks them the other way at 256 tokens. Both reach the same instruction rung. Anyone
  choosing between them should choose IU4: it accumulates exact integers, while the paired map
  depends on an FP16 WMMA whose deviation on integer operands has no proved hardware bound.
- **The exact two-plane paired map is the wrong shape at batch.** At eight tokens both planes shared
  one matrix tile. At 16 or more real tokens they need two tiles, two accumulators, double the
  activation traffic and a doubled epilogue, which is why `paired-a8` is 3x slower than `iu8-a8`
  rather than equal to it.
- Against the deployed engine all six candidates win, but that comparison mostly measures the
  deployed schedule's eight-row weight re-read, not arithmetic. `iu8-a8` is the honest control.

## The quantiser

Deterministic, symmetric, per (row, 128-block), applied identically at the FFN input and at the
hidden activation. There is no stochastic component and no seed: main's full-model result found
seeded stochastic rounding worse per inference (mean KL 0.0180 against 0.00867 deterministic), and
its bias through SiLU is a real effect, so this directory ships the deterministic quantiser only.

```
amax   = max |v| over the 128-element block          (warp reduction, as the deployed producer does)
scale  = amax / 7                                    (amax / 127 for the eight-bit controls)
q      = clamp(round_to_nearest_even(v / scale), -7, +7)
```

This rounds the transformed float directly at `amax/7`. That is **not** the same map as rounding the
deployed eight-bit code, `q4 = round(q8 * 7 / 127)`: the two disagree near rounding boundaries,
where the second has already committed to an eight-bit grid point. A quality result measured on one
of them does not transfer to the other without checking. Main's full-model evaluation used the
`q8 * 7 / 127` form and is extending its native intervention to this direct quantiser.

The quantiser runs after the same RMS norm, folded sign and 1024-point Hadamard as the deployed
`prep_chunk_r`, and writes WMMA B fragments directly — there is no int8 buffer for a later kernel
to re-read. Clamping to ±7 rather than the representable −8 keeps the map symmetric and keeps the
paired radix margin at `127*7 = 889` against the bound of 1023.

Weights are never approximated: they stay the deployed ternary values with their deployed FP16
block scales.

## Register cost

No spills in any candidate kernel. Four token tiles per wave costs 209–228 VGPRs and 6–7 waves per
SIMD; two tiles costs 123–137 and 10 waves; one tile costs 87–95 and 16 waves. Eight token tiles
was tried and rejected: 256 VGPRs with 70–82 spilled and a 2.8x whole-FFN regression at 256 rows.

The producer kernels use 16 waves per SIMD.

## What is left

The projections reach about 41% of their instruction rate at 128 rows. The gap is weight re-reads
per token group and the per-block epilogue, not occupancy or spills. Two levels of tiling with LDS
staging of the activation fragments, and more than one row tile per wave, are the obvious next
step; they change the constant, not the ranking above.

The FP16 accumulation error bound remains open, which is an argument for the IU4 route rather than
a defect to be fixed in the paired one.

## Run

```sh
cd research/ffn/batched/arithmetic
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value rate_probe.hip -o build/rate_probe
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value proj_probe.hip -o build/proj_probe
../hardware-run ./build/rate_probe
../hardware-run ./build/proj_probe check      # correctness against the CPU integer reference
../hardware-run ./build/proj_probe run 20     # throughput at 16..256 tokens

cd ../bench && make build/batch-bench         # globs ../arithmetic/candidates/*.hip
../hardware-run ./build/batch-bench --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
    --rows 32,64,128,256 --iters 40 --warmup 10 --json ../arithmetic/results/arith-layer0.json
```

`KELANA_ARITH_STAGES=1` prints per-stage times to stderr. It synchronises between stages, so leave
it unset for a timed run.
