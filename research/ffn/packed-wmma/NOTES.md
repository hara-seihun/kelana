# Packed FP16 WMMA for the Bonsai 32x128x8 ternary tile — native gfx1151 results

Hardware construction, correctness and cost for the candidate that replaces Bonsai's two
`V_WMMA_I32_16X16X16_IU8` per K16 slice with one `V_WMMA_F32_16X16X16_F16`. Measured on the
Radeon 8060S (gfx1151, 40 CU / 80 SIMD32), ROCm `hipcc`, wave32.

Files: [`packed.hpp`](packed.hpp) (construction), [`bench.cpp`](bench.cpp) (layout probe, decoder
scan, correctness, timing, activation preprocessing), [`errscan.cpp`](errscan.cpp) (accumulator
exactness campaign), [`results.txt`](results.txt) (captured run), and [`integer_probe.cpp`](integer_probe.cpp)
(main-thread reduction of the numerical discrepancy). [Compiled kernel assembly](compiled-kernels.txt)
retains the worker's instruction-count artifact. `kernels.s` is regenerated with
`hipcc --cuda-device-only -S`.

```sh
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value bench.cpp -o bench
./bench layout ; ./bench decode ; ./bench check -v ; ./bench bench
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value errscan.cpp -o errscan && ./errscan 3000
```

## Headline

The candidate is correct on every case tried and **1.54x–1.60x faster** than a faithful IU8
baseline on the whole core, including decode, cross-lane traffic and scaled output accumulation.
Deferring the plane recombination out of the inner loop (it is linear, see below) gives
**1.80x–1.83x**.

The reason it wins is a measured hardware fact, not the packing alone: **on gfx1151 the IU8 WMMA
has no rate advantage over the FP16 WMMA.** Both issue at 11.9–12.1 ns per instruction per wave at
one wave per SIMD (~35 cycles at the boosted clock), i.e. 83–84 instructions/SIMD/us for both.
This equal-rate result agrees with AMD's [RDNA 3 WMMA throughput table](https://gpuopen.com/learn/wmma_on_rdna3/),
which lists 512 operations/clock/CU for both FP16 and IU8 on RX 7900 XTX. IU4 is listed at 1024.
The earlier claim that discrete RDNA 3 doubles IU8 relative to FP16 was incorrect.
Halving the instruction count halves the measured matrix-instruction work in this experiment.

## Two defects in the construction as specified

**1. FP32 accumulation is not exact.** The premise "every possible partial accumulation is bounded
by 2048*1023 < 2^21, so FP32 arithmetic is exact irrespective of reduction order" does not hold on
this hardware. `V_WMMA_F32_16X16X16_F16` is not bit-exact even on exactly representable small
integer operands: 25% of accumulators come back non-integral, worst observed deviation
**0.043** from the exact integer p (768,000 accumulators, 3,000 random tiles, magnitudes to
|p| = 802,528; a single K16 WMMA with 16 products already deviates by 1 ulp of its own result).
The deviation is not bounded by any documented internal precision — the ISA only states that WMMA
rounds to nearest even for float types, not what the internal dot accumulates in.

The tested decoder also rounds the recovered low component:
`u = p - 2047v` inherits the observed error. The high-component rounding boundary has a
worst-case margin of only `2047/2 - 1023 = 0.5` in p, not 1023. Multiplication by the rounded
reciprocal has its own rounding error and must be included in a proof:

```c
v = rintf(p * (1.0f/2047.0f));            // v_mul_f32 + v_rndne_f32
u = rintf(fmaf(-2047.0f, v, p));          // v_fma_f32  + v_rndne_f32
```

This restores exact integers in the recorded tests and costs one extra VALU per accumulator,
8 per K128 tile, included in every timing below. Measured worst error 0.043 is below the
half-integer boundary, but there is no proved instruction-error bound. At maximum
|p| = 2,095,104, one FP32 ulp is 0.125. Splitting K128 into two K64 accumulators could reduce
absolute error at additional decode cost; it does not establish a hardware-independent bound.

Main-thread isolation reproduced the discrepancy with device-input conversions checked exactly.
For every physical row and column, set A's first two entries to [-1,-1], B's to [1,0], and
all other entries and C to zero. Native WMMA returns `-0x1.000002p+0`, or
-1.00000011920928955078125, rather than -1. Clearing A's second entry makes that isolated
product exact. The broader probe distinguishes complete reductions, single WMMAs, B-only
isolation and isolation of both operands. Thus this is not merely accumulated error over K128.
The cause and a sufficient error bound remain open. Build and run `integer_probe.cpp` with the
same HIP flags above; its optional numeric argument offsets activation digits for diagnosis.

**2. The "exceptional" normalization is routine, not exotic.** The high-plane L1 = 1024 case fires
for any 128-block whose values all sit in [120,127] or [-128,-121] — which includes plain
`X = 127`, `X = -128`, `X = -121`, and alternating extremes. Seven of the thirteen correctness
cases below run with `fH = 8`. It is not only an arbitrary-int8 contract artifact; an implementation
that skips it is wrong on real max-scaled blocks that happen to saturate. The low-plane case
(all q ≡ 8 mod 16) is the rare one.

Everything else in the construction checks out. Nine coefficient values −2048…2048 are exact FP16;
products a·d ≤ 16384 and all partial sums are exactly representable in FP32 (the error above is a
hardware property, not a representation overflow); `l = ((q+8) mod 16) − 8 ∈ [−8,7]`,
`h = (q−l)/16 ∈ [−8,8]`, `q = f_L·L + 16·f_H·H`; decoding then recombining with
`u_L·f_L + u_H·(16 f_H)` reproduces the integer block result exactly.

## Lane geometry (measured, `./bench layout`)

`V_WMMA_*_16X16X16_*_w32`: A fragment lane `l` supplies matrix row `l%16`, B fragment lane `l`
supplies column `l%16`, both replicated across lane halves; D element `r` of lane `l` is
`D[2r + l/16][l%16]`. This matches the ownership comment in bonsai-halo `kernels/phases.hpp`
`mvw_rows` (lines 286-372), whose `permlanex16` trick exploits the unreplicated-A behaviour to get
32 rows out of two instructions. The candidate uses documented replicated A, so 16 physical rows
carry 32 logical rows through the radix packing and no weight swap is needed.

Plane partners are lane `l` and `l^8`, one `v_mov_b32_dpp` with `DPP_ROW_XMASK` (`dpp_ctrl 0x168`)
per value — no LDS, no `ds_bpermute`.

## Correctness

`./bench check -v`: 13 cases x 512 decoded values, all exact against an integer CPU reference, and
the IU8 baseline checked against the same reference in the same run. Cases: random ternary W with
random int8 X; X = 127; X = −128; X = 8 (low plane L1 = 1024); X = 0; alternating 127/−128;
W = 1 with low plane L1 = 1023; high plane L1 = 1024 and 1023; W = 1 with X = 127; W = −1 with
X = −128; X = −121; a second random pair. The L1 = 1023 case reaches the exact bound
|p| = 2,095,104 = 2048·1023.

`./bench decode`: all 4,190,209 integers p in [−2095104, 2095104] decode correctly on the GPU with
`v_mul_f32` by float32(1/2047) plus `v_rndne_f32` — zero mismatches, independent of main's Lean
argument.

`./errscan 3000`: 768,000 accumulators from the full digit pipeline over five X distributions
(uniform int8, top-clustered, both extremes, |q| in [120,127], wide two-digit spread) with dense
±1 and sparse ternary weights: zero rounded-decode failures, zero end-to-end mismatches, error
statistics as above.

## Cost

Whole core per K128 tile of 32 logical rows x 8 activation columns: fragments resident in registers
(free static weight packing, free digit packing, as agreed), fresh zero accumulator per tile, the
variant's decode, then the common epilogue `y[i] += value * (row_scale[i] * column_scale)`.
Best of 5, 2000 tiles per wave.

| waves/SIMD | baseline 16xIU8 | candidate 8xF16 | deferred 8xF16 |
| --- | --- | --- | --- |
| 1 | 232.5 ns/tile | 151.2 ns (1.54x) | 129.4 ns (1.80x) |
| 2 | 454.3 ns/tile | 283.5 ns (1.60x) | 249.4 ns (1.82x) |
| 4 | 904.8 ns/tile | 565.7 ns (1.60x) | 497.5 ns (1.82x) |

At 2 waves/SIMD that is 23.1 TOPS baseline, 37.0 TOPS candidate, 42.1 TOPS deferred on this tile
shape (2 ops per MAC, 32768 MACs per tile). Raw WMMA issue cost per wave is 11.98 ns (IU8) versus
12.11 ns (FP16) at one wave per SIMD, so the baseline pays 16 x 11.98 = 192 ns and the candidate
8 x 12.11 = 97 ns of matrix time; the remainder is each variant's VALU work.

**Deferred recombination.** `y` accumulates linearly over blocks, and both planes of one activation
column share the same row scale and the same column scale, so the plane factor folds into the
per-block scale multiplier and the `lane ^ 8` sum moves out of the inner loop into the cross-wave
reduction `ph_matvec_w` already performs (the pass loop over `red[]`, phases.hpp lines 396-420,
where lanes 8-15 are currently idle because `col < nrows`). That removes 16 DPP moves and 32
recombination ops per tile. It costs one extra FP32 rounding per plane per block relative to
"recover the full integer block result, then scale" — the same class of rounding Bonsai's per-block
float accumulation already performs, not a new integer error.

Source accounting from the compiled loop bodies (`kernels.s`, counted per K128 tile):

| | baseline | candidate | deferred |
| --- | ---: | ---: | ---: |
| WMMA | 16 | 8 | 8 |
| `v_permlanex16_b32` | 32 | 0 | 0 |
| `v_mov_b32_dpp` | 0 | 16 | 0 |
| `v_rndne_f32` | 0 | 16 | 16 |
| `v_cvt_f32_i32` | 16 | 0 | 0 |
| `v_sub_nc_u32` | 16 | 0 | 0 |
| mul/fma/mov | ~59 | ~82 | ~52 |
| loop total | 123 | 122 | 76 |

The baseline's `v_cvt_f32_i32` and `v_sub_nc_u32` are Bonsai's own epilogue (int accumulator to
float, `xsum` correction for the +1 offset encoding of trits); the candidate needs neither, because
its operands are signed and its accumulator is already float. This is instruction accounting for
provenance, not a timing claim — the timings above are wall-clock.

Register cost: candidate core 178-182 VGPRs versus 134 for the baseline, because a replicated
16-row FP16 fragment is 8 VGPRs per K16 slice against 4 for 32 unreplicated IU8 rows. Identical
distinct weight bytes in memory (4 KB per 32x128 tile either way), twice the per-lane footprint.
Both fit 8 waves/SIMD on gfx1151.

## Activation preprocessing, measured separately

One wave prepares one 128x8 activation block: lane `l` owns activation column `l&7` and digit plane
`(l>>3)&1`, reads that column's 128 contiguous int8 with eight `uint4` loads, forms the plane's
digits, detects the L1 = 1024 edge, normalizes and packs eight `v16h` fragments plus the lane's
plane factor. No cross-lane traffic: one lane owns a whole column. Fragments stay in registers,
which is how a fused kernel consumes them; charging the benchmark for writing them to memory would
bill this core for traffic an integrated kernel never performs.

Measured 1.61 us per activation block per wave at 1 wave/SIMD (0.62 us per block per SIMD at 4
waves/SIMD, where the loads are hidden), ~1390 VALU instructions. Against a 4096-row matrix
(128 row tiles of 32 rows, 16.6 us of deferred core work on the same block) that is **9.7%** — and
it is unoptimized straight-line C++ (11 ops per value); packed 16-bit math should cut it several
fold, and gate/up share one prepared activation block. The honest delta against Bonsai is smaller
still: the baseline already pays a per-block activation pass for `xsum` and the int8 quantization.

## Status

- Construction: implemented and correct on gfx1151, with the mandatory u-rounding fix.
- Cost: 1.54x-1.60x on the measured core, 1.80x-1.83x with deferred recombination, plus a
  preprocessing charge of ~10% of one matrix's core work in its current unoptimized form.
- Not done here: integration into `ph_matvec_w`, streaming weight loads from L2 (this experiment
  keeps fragments resident), and a proof-grade bound for the WMMA accumulation error.
- This is a building block measurement on one tile shape. It is not a whole-FFN win claim.
