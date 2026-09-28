# Half-carrier accumulators

What the block accumulation of a batched ternary FFN is *stored in*, as opposed to what it computes.

The arithmetic family carries each projection's running sum in two FP32 register arrays,
`float ya[TT][8]` and `float yb[TT][8]`, live across all 40 (gate/up) or 136 (down) scale blocks.
At four token tiles that is 64 of a wave's 256 VGPRs, and it is the reason the projection stops at
four token tiles: eight tiles needs 256 registers and spills 70–126 of them. Four token tiles means
a wave re-reads its slice of the 44.6 MB gate/up weight image `ceil(Npad/64)` times — four times
over a 256-row batch.

Carry the same sum as one packed FP16 pair per two outputs instead, on the native packed half ALU.
The persistent state halves, the per-block epilogue loses instructions, and eight token tiles
becomes reachable, which halves the weight stream at 128 and 256 rows.

**Measured, against a bit-identical control: 1.154x at 256 rows and 1.107x at 128 rows on layer 0,
1.139x and 1.096x on layer 10, winning all 20 rounds of every comparison.** Against
`arith-paired-a4`, the fastest candidate the arithmetic directory had at 256 rows, the same
candidate is 1.149x (layer 0) and 1.135x (layer 10). It loses to `arith-paired-a4` at 64 rows.

The exact ternary weights, the per-128 weight and activation scales, and the deterministic
symmetric four-bit quantiser are unchanged. Everything input-dependent stays inside `run`, including
every conversion this representation adds.

## The control is the same program

[`candidates/half_carrier.hip`](candidates/half_carrier.hip) carries its own copy of the arithmetic
directory's producer and two-bit weight packing, so this experiment can change its own layouts
without touching a neighbour's file. `hc-control-iu4-a4` keeps the FP32 carrier and the arithmetic
directory's algebra on top of that copy. Its `output_sha256` equals `arith-iu4-a4`'s at 32, 64, 128
and 256 rows on both layers, so the transcription introduced nothing, and every number below
compares against a program that is bit-for-bit the published baseline.

`hc-rowpair-a4` and `hc-rowpair-a4-tt8` also have **identical output hashes to each other**. The
token-tile count and the LDS staging change the schedule and nothing else; only the carrier
representation moves the numbers.

## The representation

Pair adjacent output rows of the same channel, not the gate and up value of one hidden unit:

```
h_g[t][j] = (g_{4j+half}, g_{4j+2+half})        h_u[t][j] = (u_{4j+half}, u_{4j+2+half})
```

Both pairings issue the same accumulation instructions — 16 `v_cvt_f32_i32`, 8
`v_cvt_pkrtz_f16_f32`, 8 `v_pk_mul_f16`, 8 `v_pk_fma_f16` and one scale splat per token tile per
block — which is a reading of these two sources and their compiled kernels, not a general claim
about pairings. `hc-unitpair-a4` is built so it is also a measurement: its output differs from the
row-paired candidate's by 6.6e-10 to 9.1e-9 relative, maximum absolute 2.98e-08, so the two really
are performing the same arithmetic on the same values and only the lane placement moves. They differ
at the consumer: with row pairs every stage applies the same map to both lanes, so SiLU, the product
and the store need no lane selection and no "preserve up while transforming gate" masking. The
measurement agrees at 32, 64 and 256 rows and prefers row pairs sharply at 128 rows, where unit
pairs fall to 0.999 (layer 0) and 0.986 (layer 10) of the control while row pairs reach 1.023 and
1.010.

Two properties keep the *packing* exact:

- A 128-element block of four-bit activations against ternary weights reaches at most `127*7 = 889`,
  and binary16 represents every integer to 2048 exactly. `v_cvt_pkrtz_f16_f32` packs two of them in
  one instruction, and on this domain its round-toward-zero mode never rounds.
- The block scales arrive pre-paired. The per-(row, 128-block) FP16 scales are stored as half2 pairs
  in exactly the order a lane reads them, which also deletes the 16 cross-lane scale broadcasts the
  FP32 carrier does per block.

The carrier is still approximate, in two places that are worth naming separately:

- **The accumulation itself.** Forty FP16 additions per gate/up output, 136 per down output.
- **The per-block activation scale conversion.** `splat` also runs through
  `v_cvt_pkrtz_f16_f32`, but its argument is an arbitrary FP32 activation scale, not an exact
  integer, so round-toward-zero *truncates* it by up to 2^-11 relative. That is a systematic
  downward bias on every block's contribution, and it belongs to the carrier rather than to the
  quantiser. `hc-rowpair-a4-tt8-down1-rne` converts the same scale round-to-nearest instead, at one
  extra VALU instruction per token tile per block, and measures what it is worth: see below. Main's
  quality header evaluates at an RNE boundary, so a packed candidate that truncates here carries a
  quality obligation the scalar reference does not.

### Range, by dyadic gauge

FP16 has no exponent room to spare, so each output row's block scales are multiplied at preparation
by one power of two chosen from that row's largest block scale, targeting `[2^-6, 2^-5)`, and the
reciprocal power of two is applied at the consumer. Powers of two are exact in both directions, so
this contributes no error; it only moves the accumulation into the part of the FP16 range with full
precision. The width-FF Hadamard sign vector is folded into the up row scale at the same time, which
is a sign flip, also exact, and removes a multiply and a load from the consumer.

A dyadic gauge is exact only while the scaled values stay representable: it commutes with rounding
until something overflows or falls into the subnormal range, and it is not unconditionally free.

The gauge is taken from the actual scaled weights rather than from a calibration run. The
preparation's underflow counter never fired on either layer, but its coverage is narrow: it counts
**stored normalised weight block scales** that land below the FP16 normal boundary, and nothing
else. It does not observe the activation scale conversion, the product of the weight and activation
scales, or underflow during the accumulation, none of which exist until the kernel runs on real
activations.

Main's independent scan closes the range question from the other side, without relying on this
experiment's data. The upstream RMS norm, the folded sign diagonal, the norm-preserving Hadamard and
the per-128 nearest quantiser give a token-independent bound on the accumulated row value,
`B_i = ||W_i||_2 * max|k| * sqrt(D) * (1 + sqrt(128)/(2L))`. Over all 17408 rows of each projection
that is at most 191.71 (layer 0 gate), 135.07 (layer 0 up), 311.63 (layer 10 gate) and 185.49
(layer 10 up), so a static gauge of `2^ceil(log2(B_i/30000))` — mostly `2^-8` at layer 0 and `2^-7`
at layer 10, with three layer-10 gate rows at `2^-6` — holds the accumulator under 30000 for any
token, and the same Cauchy bound controls the sum of absolute block partials, which is what a
40-step rounding margin would be built on. That is a bound on the real map, not a certificate about
the hardware's floating arithmetic.

## Eight token tiles, and what it took

Halving the persistent carrier is not by itself enough for eight token tiles. Two schedules failed
first, and both are informative:

- Running the two matrices as separate passes over the K slices inside each block, with the WMMA
  accumulator set chunked four token tiles at a time, still needed 290 registers and spilled 34.
  Chunking the *transient* set changed nothing at all — identical spill counts at chunk 4 and chunk
  8 — so the pressure was never the WMMA accumulators. Measured at 4.142 ms against the control's
  3.254 ms at 256 rows, in [`results/pilot-chunked-split-layer0.json`](results/pilot-chunked-split-layer0.json);
  that source was deleted rather than left to drift beside the kernel it copied, so the run is a
  12-call pilot kept as the record of why.
- Simply reordering to two sequential block loops does not help either: the first matrix's carrier
  stays live through the second loop, so the peak is unchanged.

What works is to park the first carrier in LDS between the two passes. The packed carrier is 128
bytes per lane instead of the 256 an FP32 pair would need, so the parking area is 16 KB per
workgroup and occupancy stays at 8 waves per SIMD. Only the owning lane touches its slot, so there
is no barrier and no sharing; lanes are indexed consecutively so the dwords do not collide on banks.

The down projection then needs one more change. The arithmetic candidate splits the down matrix into
rows `[0, D/2)` and `[D/2, D)` so one wave can carry 32 logical rows, which the paired FP16 map
needs and the integer map does not. Waves per launch are `tiles * ceil(Npad / (16*TT))`, so with the
split, eight token tiles halves the wave population and loses: `hc-rowpair-a4-tt8-both` measured
3.151 ms against `-tt8`'s 2.973 ms at 256 rows in
[`results/pilot-tilecount-layer0.json`](results/pilot-tilecount-layer0.json). Dropping the split doubles the tile count, the
two factors cancel, and `hc-rowpair-a4-tt8-down1` keeps 8 waves per SIMD at eight token tiles.

### Register cost, from the compiler

`make resource` writes [`results/resource.txt`](results/resource.txt). Gate/up kernels, `<TT, ACC,
CONS, FUSE, SPLIT>`, with ACC 0 the FP32 control, 1 the row-paired half carrier, 2 the unit-paired
one:

| kernel | VGPRs | LDS | waves/SIMD | spilled |
| --- | ---: | ---: | ---: | ---: |
| `k_proj<4,0,0,1,0>` control | 228 | 0 | 6 | 0 |
| `k_proj<4,1,0,1,0>` row pairs | 163 | 0 | 9 | 0 |
| `k_proj<4,2,0,1,0>` unit pairs | 161 | 0 | 9 | 0 |
| `k_proj<8,0,0,1,1>` control, eight tiles | 256 | 0 | 5 | 126 |
| `k_proj<8,1,0,1,1>` row pairs, eight tiles | 167 | 16384 | 8 | 0 |
| `k_down_single<4>` | 99 | 0 | 12 | 0 |
| `k_down_single<8>` | 162 | 0 | 9 | 0 |

Halving the carrier is worth 65 registers and three waves per SIMD at four token tiles on its own.

## Measurements

gfx1151, 20 WGPs / 40 CUs / 80 SIMD32 ([geometry](../GEOMETRY.md)), through
[`bench`](../bench/README.md) on real contextual rows, randomized warmed candidate blocks, 120
timed calls per point in 20 rounds, every sample retained, resident `bonsai-halo` server sharing the
GPU. Full records in [`results/interleaved-layer0.json`](results/interleaved-layer0.json) and
[`results/interleaved-layer10.json`](results/interleaved-layer10.json).

Median ms per batch, layer 0:

| candidate | 32 | 64 | 128 | 256 |
| --- | ---: | ---: | ---: | ---: |
| `hc-control-iu4-a4` (= `arith-iu4-a4`) | 0.976 | 1.114 | 1.700 | 3.238 |
| `arith-paired-a4` | 0.893 | **1.000** | 1.560 | 3.230 |
| `hc-rowpair-a4` | **0.885** | 1.071 | 1.668 | 3.043 |
| `hc-rowpair-a4-tt8` | **0.885** | 1.065 | 1.537 | 2.810 |
| `hc-rowpair-a4-tt8-down1` | 0.965 | 1.087 | **1.539** | **2.805** |
| `hc-rowpair-a4-poly8` | 0.899 | 1.078 | 1.562 | 2.851 |
| `hc-unitpair-a4` | 0.899 | 1.066 | 1.708 | 3.057 |

Round speed ratios against `hc-control-iu4-a4` from
[`paired_analysis.py`](../bench/paired_analysis.py), geometric mean over rounds with its round
bootstrap 95% interval. Analyses in [`results/interleaved-layer0-analysis.json`](results/) and
[`results/interleaved-layer10-analysis.json`](results/):

| rows | candidate | layer 0 | layer 10 |
| ---: | --- | --- | --- |
| 32 | `hc-rowpair-a4` | 1.104 [1.101, 1.107] | 1.093 [1.089, 1.098] |
| 32 | `hc-rowpair-a4-tt8` | 1.105 [1.101, 1.108] | 1.073 [1.068, 1.079] |
| 32 | `arith-paired-a4` | 1.095 [1.092, 1.098] | 1.110 [1.105, 1.116] |
| 64 | `hc-rowpair-a4-tt8` | 1.047 [1.043, 1.050] | 1.021 [1.017, 1.025] |
| 64 | `arith-paired-a4` | **1.115** [1.110, 1.120] | **1.130** [1.126, 1.134] |
| 128 | `hc-rowpair-a4` | 1.023 [1.015, 1.030] | 1.010 [1.005, 1.017] |
| 128 | `hc-rowpair-a4-tt8` | **1.107** [1.100, 1.113] | 1.096 [1.090, 1.101] |
| 128 | `hc-rowpair-a4-tt8-down1` | 1.106 [1.101, 1.113] | **1.101** [1.094, 1.110] |
| 128 | `arith-paired-a4` | 1.093 [1.088, 1.099] | 1.100 [1.094, 1.107] |
| 256 | `hc-rowpair-a4` | 1.067 [1.062, 1.072] | 1.051 [1.043, 1.057] |
| 256 | `hc-rowpair-a4-tt8` | **1.154** [1.148, 1.160] | 1.139 [1.134, 1.145] |
| 256 | `hc-rowpair-a4-tt8-down1` | 1.153 [1.143, 1.163] | **1.143** [1.137, 1.148] |
| 256 | `arith-paired-a4` | 1.004 [0.998, 1.010] | 1.003 [0.995, 1.012] |

`arith-iu4-a4` against `hc-control-iu4-a4` is the same program measured twice: 0.990 to 1.008 across
the eight points. That is the noise floor of this protocol, and every claim above is well outside
it.

Stage times at 256 rows, layer 0, from `KELANA_ARITH_STAGES=1` (it synchronises, so these are not
from a timed run): the control spends about 1.92 ms in gate/up and 0.86 ms in the down projection;
`hc-rowpair-a4-tt8` spends about 1.68 ms in gate/up. The gain is where the weight stream is.

### Where the gain is not

- **This polynomial consumer is not a speed lever on this kernel.** The nonlinearity runs once per
  output per token group, the block epilogue runs 40 times more often, so the consumer is about a
  fortieth of the work it sits in. `hc-rowpair-a4-poly8`, which computes SiLU and the product
  entirely in packed half arithmetic from the packed carrier, is *slower* than the same candidate
  with a scalar FP32 SiLU at the boundary: 1.131 against 1.154 at 256 rows on layer 0.
  Five packed instructions beat `v_exp_f32` per element, but the exact branch for `|g| > 3.5` is
  taken often enough to pay it back. The packed consumer is worth keeping for what it demonstrates
  and for its quality behaviour, not for its time. Its packed evaluation follows the same order as
  main's scalar reference — Horner descending in `z = g*g`, then `fma(z, v, half(0.5*g))` — so the
  two agree on arithmetic choices as well as coefficients. The shared scalar header lives in
  `consumer-polynomial/consumer.hpp` on `agent/kelana-ffn-consumers`; this directory does not depend
  on it, and adopting it is main's integration step rather than a second copy here.
- **Eight token tiles is worth nothing at 32 and 64 rows**, where the padded batch gives one token
  group either way. At 64 rows `arith-paired-a4` still wins by 8% over the best candidate here.
- **The down projection is parallelism-bound, not bandwidth-bound**, until its row split is removed.

## Errors, separated

Every candidate here shares one approximation with `arith-iu4-a4`: the deterministic symmetric
four-bit activation quantiser, `scale = amax/7`, round-to-nearest-even, clamped to `[-7,7]`, per
(row, 128-block), at both projections. That is the 0.96% (layer 0) and 1.68% (layer 10) deviation
from the engine. The quantiser was not changed and the control proves it byte for byte.

**An error measured against the engine does not measure the carrier.** Against the engine the half
carrier reads 0.9625% where the control reads 0.9647%, which invites the conclusion that it costs
nothing and is wrong. A small change reroutes the coarse quantiser's noise rather than adding to it,
so the two deviations partly cancel; main's full-model runs show the same trap, where the half
boundary scored better than the A4 control against the original model and worse against the matched
A4 control. What the carrier costs is the difference between the two candidates' own outputs.

[`paired_error.cpp`](paired_error.cpp) measures that directly: it runs each candidate once per batch
size, keeps the output vectors and reports candidate minus reference candidate, with the
engine-referenced numbers alongside. Records in
[`results/paired-error-layer0.json`](results/paired-error-layer0.json),
[`results/paired-error-layer10.json`](results/paired-error-layer10.json) and, with the reference
moved to `hc-rowpair-a4-tt8-down1` to isolate the consumer,
[`results/consumer-isolated-layer0.json`](results/consumer-isolated-layer0.json) and
[`results/consumer-isolated-layer10.json`](results/consumer-isolated-layer10.json).

Half carrier minus `hc-control-iu4-a4`, relative RMS over the control's own RMS:

| | 32 | 64 | 128 | 256 | bias at 256 | worst row | max abs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| layer 0 | 0.163% | 0.148% | 0.140% | **0.127%** | -3.7e-08 | 0.302% | 1.45e-02 |
| layer 10 | 0.225% | 0.222% | 0.214% | **0.197%** | -6.2e-07 | 0.365% | 1.36e-02 |

So the carrier is not free. It perturbs the FFN output by about 0.13% (layer 0) and 0.20% (layer
10), against a quantiser deviation of 0.96% and 1.68% — roughly an eighth of the deviation already
present, and about 0.9% of it when added in quadrature, which is why it is invisible in the
engine-referenced column. The perturbation is unbiased to 1e-7, its worst row is 2.4x the batch
figure rather than concentrated, and it shrinks slightly with batch size because more rows average
the same per-row rounding.

Where it comes from, and what each further approximation adds, all measured against the candidate
that shares everything else:

| change | layer 0, 256 rows | layer 10, 256 rows |
| --- | ---: | ---: |
| FP16 carrier, gate/up + down, vs FP32 control | 0.127% | 0.197% |
| the down projection's 136-step FP16 accumulation alone | 0.027% | 0.020% |
| degree-8 packed SiLU, vs the same candidate with exact SiLU | 0.136% | 0.252% |
| degree-6 packed SiLU, same comparison | 0.270% | 0.512% |

The down projection's longer accumulation contributes almost nothing despite running 136 blocks to
the gate/up projection's 40: removing it leaves 0.123% of the 0.127%. Nearly all of the carrier's
cost is at the gate/up projection, where the value then passes through SiLU.

### The truncated activation scale is what made the engine metric look good

`hc-rowpair-a4-tt8-down1-rne` changes one thing: the per-block activation scale is converted
round-to-nearest instead of truncated toward zero. At 256 rows it costs **nothing measurable** —
1.1878 against 1.1880 of the control on layer 0, overlapping bootstrap intervals, in
[`results/rne-layer0.json`](results/rne-layer0.json) — and it barely moves the paired difference,
0.1262% against 0.1265% on layer 0 and 0.1970% against 0.1969% on layer 10. The FP16 accumulation,
not the scale truncation, is the dominant term.

What it does move is the engine-referenced number, and this is the useful part:

| | control | truncated scale | round-to-nearest scale |
| --- | ---: | ---: | ---: |
| layer 0, 256 rows, vs engine | 0.96465% | 0.96247% | 0.96469% |
| layer 10, 256 rows, vs engine | 1.6781% | 1.6765% | 1.6785% |

Truncation shrinks every block's contribution slightly, the FFN output shrinks with it, and that
shrinkage partly cancels the quantiser's deviation from the engine — which is exactly why the
truncating candidate appears to have *less* error than the control it perturbs. With
round-to-nearest the engine-referenced figure lands a hair above the control, which is what a small
added perturbation should look like. Round-to-nearest is the form to prefer; the truncating
candidate is kept because it is the one the timing tables above were measured on, and because it is
the demonstration.

The polynomial consumer's coefficients are main's fixed-interval fits, already rounded to binary16
and checked under half-rounded FMA evaluation: degree 6 at maximum absolute SiLU error 0.0068897,
degree 8 at 0.0030232, with the exact function evaluated outside `[-3.5, 3.5]` rather than the
polynomial extrapolated. Degree 8 costs about half what degree 6 costs on the whole FFN, matching
the ratio of their fit errors, and it is of the same order as the carrier itself.

This is one FFN on two layers, measured on its own output. It says nothing on its own about logit
divergence, held-out loss, or the change applied across all 64 layers.

[`model-quality/`](model-quality/README.md) runs the carrier in the whole model, all 64 layers, with
real per-128 binary16 accumulation and scale rounding rather than binary16 casts of finished FP32
projections. On one captured layer, its perturbation relative to its control is 0.1926%,
against 0.1910% for the standalone candidate pair. Those similar norms do not establish
numerical transfer: the two half implementations differ from each other by 0.1635%, and
their FP32 controls differ by 0.0469%. Exact transfer to the winning kernel remains open.
The full-model experiment reports mean KL 0.0264 from its FP32 schedule control over
128 positions, against 0.0244 for reversing FP32 addition order. These similar KLs do
not track the much larger difference in local perturbation magnitudes. They establish
neither a noise floor nor a bound on model behavior.

Resident device bytes at `max_batch` 256: 92.0 MB for the row-paired candidates against 91.9 MB for
the control, 114.3 MB for `-down1`, which stores the down matrix unsplit and keeps a float gain
vector per row. Untimed preparation is 262–291 ms against the control's 233–245 ms, from the extra
host-side row normalisation and pair packing.

## Candidates

| name | what it changes |
| --- | --- |
| `hc-control-iu4-a4` | nothing: FP32 carrier, output-hash-identical to `arith-iu4-a4` |
| `hc-rowpair-a4` | packed FP16 carrier over adjacent rows of one channel, four token tiles |
| `hc-rowpair-a4-tt8` | the above with eight token tiles and LDS parking at gate/up |
| `hc-rowpair-a4-tt8-both` | eight token tiles at the split down projection too; loses |
| `hc-rowpair-a4-tt8-down1` | down projection as one unsplit matrix over all D rows |
| `hc-rowpair-a4-tt8-down1-rne` | the same, with the activation scale rounded to nearest instead of truncated |
| `hc-rowpair-a4-fp32down` | half carrier at gate/up only; isolates the down projection's error |
| `hc-rowpair-a4-poly6`, `-poly8` | packed-half polynomial SiLU consumed from the packed carrier |
| `hc-rowpair-a4-tt8-down1-poly8` | the fastest schedule with the packed consumer |
| `hc-unitpair-a4` | carrier holds `(gate, up)` of one hidden unit instead of two rows |

## Run

```sh
cd research/ffn/batched/bench && make build/batch-bench     # globs ../half-carrier/candidates/*.hip
../hardware-run ./build/batch-bench \
    --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
    --rows 32,64,128,256 --iters 120 --rounds 20 --warmup 20 --seed 40213 \
    --candidate arith-iu4-a4,arith-paired-a4,hc-control-iu4-a4,hc-rowpair-a4,hc-rowpair-a4-tt8,hc-rowpair-a4-tt8-down1,hc-rowpair-a4-fp32down,hc-rowpair-a4-poly6,hc-rowpair-a4-poly8,hc-unitpair-a4 \
    --json ../half-carrier/results/interleaved-layer0.json
python3 paired_analysis.py ../half-carrier/results/interleaved-layer0.json \
    --baseline hc-control-iu4-a4 --out ../half-carrier/results/interleaved-layer0-analysis.json

cd ../half-carrier && make resource          # per-kernel VGPR, LDS, occupancy and spill counts
make paired-error                            # candidate minus candidate, not candidate minus engine
../hardware-run ./build/paired-error \
    --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 --rows 32,64,128,256 \
    --reference hc-control-iu4-a4 --json results/paired-error-layer0.json
```

`KELANA_ARITH_STAGES=1` prints per-stage times to stderr; it synchronises between stages, so leave
it unset for a timed run.

## What is left

- **The gate/up projection is still 2x off its instruction rate.** 1.68 ms at 256 rows against a
  0.82 ms IU4 WMMA floor. The per-block drain is 41 VALU per token tile and the weight decode is 112
  per block per matrix; at eight token tiles those are 328 and 112, so the drain now dominates the
  non-WMMA work. Cutting it needs either a coarser activation scale, which changes the quantiser, or
  a WMMA form that lands closer to the carrier's representation.
- **The down projection's weight stream is still read `ceil(Npad/128)` times.** Splitting K across
  two workgroups with a reduction pass would double its wave population and let sixteen token tiles
  in; the reduction costs about 16 MB of traffic against 44 MB of weight reads saved at 256 rows.
- **No full-model quality measurement of the carrier itself.** Main owns that comparison, and it has
  to be against a matched A4 control, not against the original model.
- **No hardware error bound for the packed FP16 accumulation.** The measured whole-FFN error does not
  move, and every conversion into the carrier is exact, but `v_pk_fma_f16`'s behaviour is measured
  here, not proved, exactly as the paired FP16 WMMA's is in [the arithmetic
  directory](../arithmetic/README.md).
