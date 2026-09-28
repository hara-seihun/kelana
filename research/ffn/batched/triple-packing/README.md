# Three ternary weight rows in one FP16 WMMA

Ternary activations bound every K16 partial sum by 16, which is exactly what a radix ladder needs
to carry three independent ternary weight channels through one `v_wmma_f32_16x16x16_f16` and pull
them apart afterwards. Three channels per instruction against IU4's one at half the issue cost is a
1.5x advantage in matrix work. The question is whether the separation can be paid for.

**The tested triple map loses.** In the independent-channel, positive integer ladder with top-down rounding studied below, a pair can accumulate 63 K16 instructions before separation, while a triple can accumulate only one. The compiled triple decoder costs 49 VALU issue slots against an estimated break-even budget of 16. This is a cost for that decoder, not a lower bound over every possible program. Register-resident, with no
memory traffic at all, the triple map is **1.73x slower** than the three native IU4 instructions
that do the same work. On the whole FFN at 32–256 real tokens it is **1.27x to 1.84x slower** than
the matched native baseline, 0 wins in 20 interleaved rounds at every size.

The construction itself works. `tp-triple-a2` reproduces `tp-iu4-a2` **bit for bit** on the whole
FFN at 32, 64, 128 and 256 rows, and both reproduce a CPU integer reference exactly in
[`proj_check.hip`](proj_check.hip). This is a measured negative result about cost, not a broken
map.

## What the algebra allows

[`feasibility.cpp`](feasibility.cpp) enumerates the feasible region and verifies decode exhaustively
over every attainable digit vector. Main proved the integer algebra for the minimal ladder in
`Kelana/TriplePacking.lean`. Main also proved the `[1,60,1987]` operand bound, upper-channel separation for integer perturbations up to 13, and the optimal separation margin of 14 within the specified `[1,b,c]` ladder family. The bottom channel retains the perturbation; those theorems do not prove native floating-point exactness. This directory contains the finite checks and native measurements.

Ternary activations, `K = 16` products per instruction, `c` channels at radices
`1 = R_0 < ... < R_{c-1}`, `n` instructions accumulated before separation, digit bound `B = 16n`.
The following constraints characterize this ladder family, assuming every independent ternary operand combination and every digit sum in `[-B,B]` must be supported:

- **Representation.** The attainable operand values include `sum_i R_i` and that value minus one, because the lowest weight can change from 1 to 0 and `R_0=1`. Both adjacent values must be exactly representable, requiring `sum_i R_i <= 2048`.
- **Separability.** Peeling from the top, `round(P / R_i) = S_i` needs `B * sum_{j<i} R_j < R_i / 2`
  at every level.

Minimising gives `R_i = 2*B*T_{i-1} + 1`, so the smallest operand for `c` channels is
`((2B+1)^c - 1) / (2B)`:

| channels | minimal ladder at `n = 1` | operand | verdict |
| ---: | --- | ---: | --- |
| 1 | `[1]` | 1 | fits |
| 2 | `[1, 33]` | 34 | fits |
| 3 | `[1, 33, 1089]` | 1123 | fits |
| 4 | — | 37060 | does not fit FP16 |

**Three is the ceiling in this ladder family.** The accumulation-depth bound also belongs to that family:

| channels | maximum `n` | minimal ladder at that `n` | operand |
| ---: | ---: | --- | ---: |
| 2 | 63 | `[1, 2017]` | 2018 |
| 3 | **1** | `[1, 33, 1089]` | 1123 |

That single row is the whole experiment. A pair separates once per 63 instructions — once per K1008,
or in practice once per K128 scale block, where it costs 3 VALU slots per instruction. A triple has
to separate after every instruction, and pays 49.

## Radices: the lead's `[1, 33, 1089]` leaves 0.5 of room, `[1, 60, 1987]` leaves 14

`v_wmma_f32_16x16x16_f16` is not bit-exact on exactly representable integer operands
([packed-wmma/NOTES.md](../../packed-wmma/NOTES.md)), so the separation margin is not a formality.
The minimal ladder's margin is `1089/2 - 16*(1+33) = 0.5` in accumulator units, out of an
accumulator that reaches 17968. Spending the rest of the FP16 operand on margin instead of leaving
it idle gives `[1, 60, 1987]`, which sums to exactly 2048 and leaves 14 — twenty-eight times the
room for the same instruction count.

[`feasibility.cpp`](feasibility.cpp) bisects the exhaustive check to confirm both numbers, and
distinguishes two tolerances that are easy to conflate. Requiring the *whole integer triple* back
is pinned just under 0.5 for every ladder, because the bottom channel is recovered by rounding.
Requiring only that the *channels separate* is what a kernel needs — the bottom channel is carried
as a float residual and multiplied by a float scale like any other accumulation:

| ladder | operand | separation tolerance | all-integer tolerance |
| --- | ---: | ---: | ---: |
| `[1, 33, 1089]` lead's minimal triple | 1123 | 0.499 | 0.499 |
| `[1, 60, 1987]` margin-optimal triple | 2048 | **13.998** | 0.499 |
| `[1, 32, 1024]` power-of-two, needs ≤15 nonzero activations per K16 | 1057 | 0.9995 | 0.4995 |
| `[1, 2047]` deployed paired map at four-bit activations | 2048 | 134.4 | 0.437 |

## What the hardware does

`./build/triple_probe check 4000`, 1,024,000 accumulators per ladder over five weight and activation
regimes including the corner where every digit sum reaches its bound of 16:

| ladder | max abs accumulator | max deviation | non-integral | separation | margin |
| --- | ---: | ---: | ---: | --- | ---: |
| `[1, 33, 1089]` | 17968 | 9.77e-4 | 26.3% | exact | 0.5 |
| `[1, 60, 1987]` | 32768 | 1.22e-3 | 24.4% | exact | 14.0 |

A quarter of accumulators come back non-integral, and both ladders still separate correctly on
every case tried. **This is measurement, not a bound.** The ISA states round-to-nearest-even for
the float WMMA forms and says nothing about the internal dot precision, so no hardware-independent
error bound sufficient for recovery has been established here. The larger ladder has more room to keep its upper channels separated. Exact integer recovery of the bottom channel still needs a separate sub-half-unit error argument, even with the larger separation margin.

One rounding is not optional. The bottom channel emerges as `residual - R1 * (channel 1 sum)` and
inherits eight slices' worth of the native deviation. Without a `rint` on it the block result is
off by about 1e-4 relative — measured, and the reason [`proj_check.hip`](proj_check.hip) reports
exact zero now. It costs one instruction per eight slices.

## Instruction cost: the budget and the bill

`./build/triple_probe rate`, register-resident operands, no memory traffic. A work unit is
48 logical ternary rows x 16 tokens x 16 K — one triple-packed FP16 WMMA and its decode, or three
native IU4 instructions. The table below is normalized to one physical SIMD32; read [how the
stored samples normalize](#how-the-stored-samples-normalize) before quoting a number from
[`results/issue-rate.json`](results/issue-rate.json), whose `waves_per_simd` field is twice the
physical value.

| | ns per unit | what it is |
| --- | ---: | --- |
| three IU4 instructions | **17.79** | the matched native baseline |
| one FP16 WMMA alone | 11.98 | the packed instruction's issue cost |
| FP16 WMMA + accumulate, no decode | 14.56 | measured no-decode ablation |
| **triple map, full decode** | **30.81** | `[1, 60, 1987]`, float peeling |
| triple map, `[1, 32, 1024]` integer bitfield decode | 28.52 | needs ≤15 nonzero activations per K16 |
| the pair, scaled to 48 rows | 19.97 | separates once per eight instructions |
| one VALU instruction | 0.357 | |

Read it as a budget. Matrix work alone favours the packed instruction by about `17.79 / 11.98 = 1.49x`,
the 1.5x the map is designed to capture. That leaves **5.82 ns, about 16 VALU issue slots**, to
separate three channels out of eight accumulator elements. The compiled inner loop spends **49**
(393 issue slots per 8 units, 512 logical operations, 119 of them dual-issued), and measures
18.83 ns. **The measured decoder takes about three times its estimated budget**, and the 1.49x advantage becomes a 1.73x loss.

### How the stored samples normalize

The stored value is **ns per work unit per wave**, with `resident_waves` waves running. When `W`
waves share one SIMD, that SIMD issues `W` waves' worth of instructions in the same elapsed time,
so the per-SIMD cost of one instruction is the stored value divided by `W`.

`W` is not the stored `waves_per_simd` field. That field was printed when the probe read HIP's 20
work-group processors as 20 SIMD32 units rather than 80, so it launched `40 * label` waves onto 80
physical SIMDs: **each stored label is twice the physical waves per SIMD.** Below one wave per SIMD
the surplus units idle, which does not shorten the elapsed time of the waves that do run, so the
divisor is `max(1, 40 * label / 80)`.

[`normalize_issue_rate.py`](normalize_issue_rate.py) applies that to the stored samples without
modifying them, into [`results/issue-rate-per-simd.json`](results/issue-rate-per-simd.json):

| stored label | resident waves | physical waves/SIMD | divisor | f16 ns | iu4 ns | VALU ns | iu4 MAC/ns/SIMD |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 40 | 0.5 | 1 | 12.357 | 6.470 | 0.5613 | 633.1 |
| 2 | 80 | 1.0 | 1 | 12.395 | 6.507 | 0.5647 | 629.5 |
| 4 | 160 | 2.0 | 2 | 12.057 | 6.189 | 0.3662 | 661.9 |
| 8 | 320 | 4.0 | 4 | **11.976** | **6.036** | **0.3574** | **678.6** |

The per-instruction cost is stable across all four rows and settles at the most loaded one, which
is the evidence that the divisor is right: an incorrect one would make the four rows disagree by
factors of two. The last row is what the budget table above uses — `3 * 6.036 = 18.1` against its
measured `17.79` for three chained IU4, and `0.357` for one VALU instruction.

**Dividing a stored value by its own label instead gives f16 5.99 ns and iu4 3.02 ns.** Those
numbers are wrong by exactly two and imply about 217 device TOPS. The correct figure is 678.6
MAC/ns/SIMD32, or `678.6 * 80 * 2 / 1000 = 108.6` TOPS, which agrees with the
[arithmetic rate probe](../arithmetic/README.md) and with the independent chain-swept measurement
in [register-observer](../register-observer/README.md), 683.6 MAC/ns/SIMD32 from a different probe
and protocol. Where a 16x16x16 IU4 WMMA costs 6.04 ns on one SIMD, it delivers 4096 MAC, so a
single IU4 instruction is worth about 247 MAC per clock per SIMD against the sensor clocks
recorded there.

A fresh run needs none of this: the source now takes its unit count from
[geometry.hpp](../geometry.hpp), so its printed labels are physical waves per SIMD, and the `rate`
mode prints and records the per-SIMD columns directly.
[`results/issue-rate-physical-geometry.json`](results/issue-rate-physical-geometry.json) is such a
run, and it closes the reconciliation: at four physical waves per SIMD it measures 6.030 ns per IU4
instruction against the 6.036 the stored samples give at the same physical occupancy, and at eight
it reaches 5.989 ns, or 684.0 MAC/ns/SIMD32. Raw recorded samples in
[`results/issue-rate.json`](results/issue-rate.json) are unchanged.

Both decoders land in the same place. The float peeling is `mul, rndne, fma, mul, rndne` plus three
accumulations; the power-of-two ladder replaces it with `add, cvt, bfe, shr` plus three integer
accumulations and needs an activation sparsity guarantee to be legal at all. Neither approaches 16
slots. Counting two extractions plus three accumulations per element describes this lowering; it does not rule out fused instructions, another representation or composition with a different consumer.

## Whole FFN

[`candidates/triple_maps.hip`](candidates/triple_maps.hip) registers both maps with
[`api.hpp`](../api.hpp). They share the producer, the tiling policy, the epilogue and the ternary
quantiser, so the difference between them is the map alone. 256 real contextual rows of one
document, 20 interleaved randomised rounds of 120 iterations, median ms:

| rows | `tp-triple-a2` | `tp-iu4-a2` | paired speedup vs baseline | `arith-iu4-a4` | `arith-paired-a4` |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 32 | 1.355 | **1.076** | 0.790 [0.787, 0.792], 0/20 wins | 0.969 | 0.873 |
| 64 | 1.984 | **1.177** | 0.595 [0.592, 0.598], 0/20 | 1.124 | 0.988 |
| 128 | 3.304 | **1.790** | 0.544 [0.540, 0.550], 0/20 | 1.691 | 1.526 |
| 256 | 6.213 | **3.517** | 0.563 [0.560, 0.566], 0/20 | 3.219 | 3.141 |

Same-round ratios and intervals from `bench/paired_analysis.py`, full samples in
[`results/ffn-layer0.json`](results/ffn-layer0.json) and
[`results/paired-vs-iu4a2.json`](results/paired-vs-iu4a2.json).

`tp-triple-a2` and `tp-iu4-a2` produce **identical output hashes** at every size, and identical
relative RMS against the engine (8.628e-2, 7.790e-2, 7.193e-2, 6.514e-2). The triple map is not
paying for its loss with a different answer; it computes the native baseline's answer more slowly.

`tp-iu4-a2` is also the speed of native IU4 at four-bit activations — identical instruction, operand
widths and traffic, only the quantiser differs. That matters for reading the table: the ternary
activations that make triple packing possible at all are what main measured as unusable at whole-model
quality (mean KL 3.81 across 64 layers), while the four-bit `arith-iu4-a4` column is both faster and
an order of magnitude better locally. **The coarse activations are a cost the packing pays and the
native instruction does not.**

### Where the extra time goes

Three factors, all consequences of the map rather than of this implementation:

- **Decode**, 1.73x from the register-resident probe, with no memory involved. This is the floor;
  no tiling changes it.
- **Register pressure.** Three decoded channels need three output accumulators and three per-block
  accumulators per token tile — 48 registers against the native map's 16. Four token tiles spills
  117 VGPRs to scratch, so the triple map runs **two token tiles where the native baseline runs
  four**, doubling the number of passes over the weight stream. Gate and up also cannot share a
  wave for the same reason; they run as separate passes over the hidden buffer.
- **Weight image**, 2.75x. Three ternary weights per 16-bit operand is 0.667 bytes per weight against
  0.25 for the two-bit storage the native maps expand in registers. Recovering that difference means
  building the packed FP16 operand from two-bit codes with an FP16 multiply-add ladder, which is more
  VALU work than the decode this map already cannot afford.

The real projection shape shows the combination. [`proj_check.hip`](proj_check.hip) `run` streams
gate and up (D = 5120, FF = 17408, 178.3 M ternary weights) from memory:

| tokens | triple ms | iu4 ms | ratio |
| ---: | ---: | ---: | ---: |
| 16 | 0.646 | 0.565 | 1.14 |
| 32 | 0.679 | 0.578 | 1.17 |
| 64 | 1.262 | 0.617 | 2.05 |
| 128 | 2.364 | 1.043 | 2.27 |
| 256 | 4.256 | 1.857 | 2.29 |

Weight image per matrix: triple-packed FP16 61.33 MB against two-bit ternary 22.28 MB.

## What would have had to be true

The measurements and the restricted algebra leave different kinds of questions:

- A radix ladder inside an FP16 operand that survives two instructions at three channels. Ruled out:
  `1024n² + 96n + 3 <= 2048` fails at `n = 2`.
- A cheaper separation or a consumer that avoids materializing all three channels. Neither tested decoder reaches the estimated 16-slot budget. A general lower bound on decoding programs has not been proved.
- A fourth channel to raise the 1.5x matrix-work ceiling. Ruled out: the minimal four-channel
  operand is 37060, eighteen times FP16's exact-integer limit.

The earlier pair pays in the measured configurations; this triple implementation does not. That is not a universal prohibition on other three-channel encodings, sparse producer domains, shorter reductions or maps that retain packed outputs into their next consumer.

## Files

- [`feasibility.cpp`](feasibility.cpp) — channel ceiling, accumulation depth, margin-optimal
  radices, exhaustive decode verification and tolerance bisection. Pure CPU, no GPU lock needed.
  Captured output in [`results/feasibility.txt`](results/feasibility.txt).
- [`radix.hpp`](radix.hpp) — the ladders, the FP16 operand packing and the device decoder.
- [`triple_kernels.hpp`](triple_kernels.hpp) — the producer, the triple-packed projection and the
  matched native IU4 projection, shared by the candidate and the checker.
- [`triple_probe.hip`](triple_probe.hip) — lane-layout confirmation, the native exactness campaign
  and the issue-rate accounting.
- [`proj_check.hip`](proj_check.hip) — both projections against a CPU integer reference, and the
  real gate/up shape with streamed weights.
- [`candidates/triple_maps.hip`](candidates/triple_maps.hip) — `tp-triple-a2` and `tp-iu4-a2` for
  the shared [bench](../bench/README.md).

## Run

```sh
cd research/ffn/batched/triple-packing
mkdir -p build results
c++ -O2 -std=c++17 feasibility.cpp -o build/feasibility && ./build/feasibility

hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value triple_probe.hip -o build/triple_probe
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value proj_check.hip -o build/proj_check
../hardware-run ./build/triple_probe layout                        # lane geometry, fails loudly if it moved
../hardware-run ./build/triple_probe check 4000 results/native-exactness.json
../hardware-run ./build/triple_probe rate results/issue-rate.json
../hardware-run ./build/proj_check check                           # exact against the integer reference
../hardware-run ./build/proj_check run 10 results/projection.json

cd ../bench && make build/batch-bench
../hardware-run ./build/batch-bench --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
    --rows 32,64,128,256 --rounds 20 --iters 120 --warmup 10 \
    --candidate tp-triple-a2,tp-iu4-a2,arith-iu4-a4,arith-paired-a4 \
    --json ../triple-packing/results/ffn-layer0.json
python3 paired_analysis.py ../triple-packing/results/ffn-layer0.json --baseline tp-iu4-a2 \
    --out ../triple-packing/results/paired-vs-iu4a2.json
```

`KELANA_TRIPLE_STAGES=1` prints per-stage times to stderr; it synchronises between stages, so leave
it unset for a timed run.
