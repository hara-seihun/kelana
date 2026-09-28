# Deferred carrier: how long can a packed FP16 pair survive before it is separated?

**Answer: eight 128-blocks on this model, and that is worth 1.25x to 1.37x on the whole FFN against
the previous best candidate in the paired family.** The separation epilogue was never the thing that
made the paired map expensive; paying it once per 1024 columns instead of once per 128 is.

The paired map packs a gate row and an up row into one FP16 coefficient `g + 2047*u`, so one
`v_wmma_f32_16x16x16_f16` covers 32 logical rows, and then pulls the two channels back out of the
accumulator after every 128-block because the weight scale and the activation scale change there.
This directory changes the scale representation so the carrier can keep accumulating, and measures
what that costs and what it buys.

| rows | 32 | 64 | 128 | 256 | rel RMS at 256, layer 0 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `arith-paired-a4` (previous best in the family) | 0.892 | 0.993 | 1.555 | 3.245 | 0.965% |
| `dfr-control-paired-a4-u1` (matched control, same file) | 0.908 | 0.990 | 1.576 | 2.885 | 0.965% |
| `dfr-defer2-paired-a4` | 0.676 | 0.804 | 1.338 | 2.734 | 1.106% |
| `dfr-defer4-paired-a4` | 0.667 | 0.767 | 1.261 | 2.547 | 1.217% |
| `dfr-defer8-paired-a4` | **0.654** | **0.744** | **1.232** | **2.492** | 1.304% |
| `gs-shared1024-iu4-a4` (same approximation on IU4) | 0.858 | 0.909 | 1.414 | 2.713 | 1.304% |

Median ms, layer 0, randomized interleaved rounds through [`../bench`](../bench/README.md), all
samples retained in [`results/`](results).

**Read the small-batch rows with the clock ramp in mind.** Main found that with a 20-call warmup a
32-row batch is over in milliseconds, so its measured blocks can run while the shader clock is still
climbing from about 0.7 GHz to 2.2 GHz, while a 256-row batch sits at about 2.6 GHz throughout. The
driver is being repaired with a workload ramp before each batch and a recorded `--ramp-ms`, and the
combined table produced by that driver owns the cross-candidate comparison. The records here stay as
they were taken; the 256-row rows are the ones taken at a settled clock, and the 32- and 64-row
ratios should be treated as provisional until the ramped rerun replaces them.

**Two ratios, and they are not the same claim.** `arith-paired-a4` is the strongest previously
published candidate in this family, but this directory's control is a different kernel shape: 1024
byte code blocks with the shared scales in their own tile-major array rather than 1088 byte blocks
carrying them inline. That shape alone is worth about 1.10x at 256 rows and nothing at 32. So the
deferral's own contribution is the ratio against `dfr-control-paired-a4-u1`, which differs from this
directory's candidates in exactly one thing, and the ratio against `arith-paired-a4` is the ratio
anyone comparing published candidates would see. Both, 16 of 16 rounds won at every point:

| rows | 32 | 64 | 128 | 256 |
| --- | ---: | ---: | ---: | ---: |
| `dfr-defer8` against the matched control, layer 0 | 1.378 | 1.321 | 1.295 | **1.159** |
| `dfr-defer8` against the matched control, layer 10 | 1.365 | 1.311 | 1.288 | **1.130** |
| `dfr-defer8` against `arith-paired-a4`, layer 0 | 1.368 | 1.336 | 1.266 | 1.300 |
| `dfr-defer8` against `arith-paired-a4`, layer 10 | 1.356 | 1.310 | 1.239 | 1.253 |
| `dfr-defer4` against `arith-paired-a4`, layer 0 | 1.336 | 1.295 | 1.236 | 1.276 |

`dfr-defer8-paired-a4` and `gs-shared1024-iu4-a4` are **the same ideal construction** - a shared
scale over 1024 columns on both sides, no per-block correction - reached by different instructions
and different FP32 summation orders, so their outputs are close but not asserted equal. What is
measured is that their relative RMS against the engine agrees to four decimals at every batch size
in both layers (1.3040% against 1.3041% at 256 rows, 2.1748% against 2.1748% at layer 10). Equal
residual RMS is not a proof of numerical identity; a pairwise output comparison is correctness-only
work that the driver does not yet expose. At that matched approximation the packed FP16 carrier is
1.09x faster at 256 rows and 1.31x at 32 rows than the IU4 form. Bootstrap intervals and per-round records are in
[`results/interleaved-defer-layer00-analysis.json`](results/interleaved-defer-layer00-analysis.json)
and its layer-10 companion.

This is a speed and local-error result on one layer at a time. Nothing here accepts an error budget.

## The representation: the integer multiplier is dead, and it dies quadratically

The plan was `lam[i,b] -> L[i] * m[i,b]` with a small positive integer `m` folded into the matrix
operand, so per-block scale detail survives inside a longer accumulation. It does not work, and the
reason is worth stating precisely because it kills the whole family rather than one setting.

The packed coefficient `m_g*t_g + R*m_u*t_u` has to be an exact FP16 integer, and FP16 represents
integers exactly to 2048, so `M*(1+R) <= 2048`. Separation needs `|S_low| <= R/2` where `S_low` is
the `m`-scaled integer sum, whose magnitude scales with `M`. So the usable headroom is about
`1024/M^2`:

| M | radix R | headroom | weight-scale fit at G=8 (layer 0, three matrices, 2048 sampled rows) |
| ---: | ---: | ---: | ---: |
| 1 | 2047 | 1023 | 6.17% |
| 2 | 1023 | 255 | 6.14% |
| 3 | 681 | 113 | 6.11% |
| 7 | 291 | 20 | 3.70% |

A headroom of 113 cannot hold even one 128-block (a single block admits `7 * 102 = 714` by the
nonzero count alone, and 251 is observed). The one setting that improves the fit, `M = 7`, has 20.
Worse, `M = 2` and `M = 3` barely improve the fit at all: the grid of ratios reachable from
`m1/m2` with small integers has a gap right where the real scales live, which
[`../grouped-scales`](../grouped-scales/README.md) already found from the other direction.

So the only deferrable representation reached here is `M = 1`, which is a shared scale per
(row, group), with `L_g` and `L_u` free per row because the epilogue applies them separately.

The scope of that: it is measured for the multiplier grids this file fits (`m` a positive integer in
[1, M], one `L` per row and group, chosen to minimise relative RMS on a search grid over `L`) under
the separation criterion `|S_low| <= R/2` with an exact-integer FP16 operand. A different fit, a
different criterion, or an encoding that does not put the multiplier inside the operand is not
covered by it.

Shared-scale fit, relative RMS against the deployed per-block scales, layer 0:

| group | 2 blocks | 4 blocks | 8 blocks | whole 5120 |
| --- | ---: | ---: | ---: | ---: |
| gate | 4.65% | 5.71% | 6.17% | 6.57% |
| up | 4.62% | 5.69% | 6.16% | 6.54% |
| down | 4.61% | 5.66% | 6.13% | - |

## The range: what actually sets the deferral limit

Separation is exact while `|S_low| <= R/2 = 1023`, where `S_low` is the gate channel's integer sum
over the **whole** deferred run. The high channel needs no bound: `u = rint(p/R)` and `g = p - R*u`
recover any integer `u` once the low bound holds. A larger high channel only raises `|p|`, which is
a float condition, measured separately below.

No counting argument gets past one block. With at most 102 nonzeros per 128-block here and
activations in [-7, 7], the worst case for a single block is already 714. Everything beyond that is
a measured property of these weights against these activations.

[`defer_probe.hip`](defer_probe.hip) accumulates the paired FP16 carrier and the exact IU4 integer
sums over the same operands and compares every result. All 17408 gate/up rows, 256 real tokens,
whole enumeration, not a sample:

| deferral | columns | checked | wraps | max \|low\| | max \|high\| | max \|p\| | max float deviation | decode mismatches |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 block | 128 | 178 257 920 | 0 | 158 | 168 | 343 985 | 0.018 | 0 |
| 2 blocks | 256 | 89 128 960 | 0 | 247 | 237 | 485 377 | 0.031 | 0 |
| 4 blocks | 512 | 44 564 480 | 0 | 444 | 376 | 769 472 | 0.063 | 0 |
| 8 blocks | 1024 | 22 282 240 | 0 | **839** | 668 | 1 366 801 | 0.063 | 0 |
| 20 blocks | 2560 | 8 912 896 | 79 | 1527 | 1415 | 2 895 447 | 0.125 | 79 |
| 40 blocks | 5120 | 4 456 448 | 447 | 2904 | 2664 | 5 451 142 | 0.125 | 447 |

Layer 10 is milder: 213, 298, 544 and 905 at 2, 4, 8 and 20 blocks, with 20 blocks clean there and
32 wraps only at the whole 5120. **The limit is layer dependent**, which is exactly why 8 blocks is
where this stops rather than somewhere further out.

Three things to read off that table:

- **Every observed failure is a wrap, not a float failure.** The decode mismatch count equals the
  wrap count at every deferral length in both layers. The FP16 WMMA deviation from the exact integer
  grows slowly with `|p|` (0.018 at 344 K, 0.125 at 5.45 M) and never reached the 0.5 boundary that
  `rint` needs, even where the algebra had already failed. That is measurement on this device with
  this data, not a bound; [`../../packed-wmma/NOTES.md`](../../packed-wmma/NOTES.md) explains why no
  proved bound exists.
- **8 blocks keeps 18% of margin** (839 against 1023) at layer 0 and 47% at layer 10.
- **The quantiser step interacts with the wall.** Shortening it to `0.8*amax/7`, the setting
  [`../grouped-scales`](../grouped-scales/README.md) found helpful on the IU4 absorb candidate,
  multiplies every `|q|` by 1.25 and pushes layer 0 at 8 blocks to `max |low| = 1045`: **one wrap in
  22 282 240**, observed. That single wrapped element is visible in the whole-FFN result as
  `max|err| = 0.406` against 0.231 for the same candidate at step `amax/7`, and the clipped
  candidates are worse on relative RMS as well: 1.463% against 1.304% at 8 blocks and 1.356%
  against 1.217% at 4, at the same speed
  ([`results/interleaved-defer-clip-layer0.json`](results/interleaved-defer-clip-layer0.json)).
  Both clip variants stay registered because a candidate that wraps once in 22 M is the useful
  demonstration of what the wall looks like from the wrong side.

[`carrier_scan.py`](carrier_scan.py) computes the same channel sums on the CPU from the HALO tiles
and reaches the same maxima (158, 247, 444, 839 at layer 0; 213, 298, 544 at layer 10), and also
covers the down projection, which the native probe does not: layer 0 gives 251, 321, 481 and 782 at
1, 2, 4 and 8 blocks, layer 10 gives 302, 462, 789. The down projection is the tighter of the two
and is still inside the wall at 8 blocks.

### A certificate you can compute online, and what it proves

This is a range certificate: it rules out the low channel aliasing into the high one. It is not a
statement about the hardware's accumulation error, which is measured separately above and stated as
an outstanding obligation in the certified section.


`|S_low| <= sum_k |q_k|` over the deferred run. That L1 norm is one extra warp reduction in the
producer, per (token, group), and it is a genuine per-token certificate rather than a statistic:

| deferral | layer 0 gate/up | layer 0 down | layer 10 gate/up | layer 10 down |
| --- | ---: | ---: | ---: | ---: |
| 2 blocks | 100% | 98.4% | 100% | 99.9% |
| 4 blocks | 73.0% | 74.6% | 93.8% | 88.8% |
| 8 blocks | 0% | 0% | 0% | 0% |

So 2 blocks is certifiable per token almost everywhere, 4 blocks is certifiable for most tokens, and
8 blocks is never certifiable this way: its mean L1 is 1819 against a headroom of 1023, while the
realised sums are 60 RMS. The shipped `dfr-defer8` therefore rests on enumeration over this model
and these 256 tokens, not on a certificate. A deployment that wants a guarantee has
`dfr-certfixed1023-paired-a4`, measured in the next section: same scales, same quantiser, runs
shortened wherever the certificate cannot rule out a wrap.

## The certified program: what safety actually costs

`dfr-defer8` rests on enumeration, not on a certificate. The safe version keeps the group-8 scales
and the group-8 quantiser exactly as they are - the intended numerical object does not move with the
data - and only shortens the runs the accumulator makes inside that group, wherever the L1
certificate cannot rule out a wrap. Shortening a run leaves the exact integer and shared-scale map untouched, because every partial run
carries the same `L_g`, `L_u` and `c`; what does change is the FP32 order in which the partial sums
are added, and the native carrier's own behaviour, since a shorter run reaches a smaller `|p|` and
runs the decoder more often. Those two are measured, not assumed equal. Main's Lean
development in [`Kelana/DeferredCarrier.lean`](../../../../Kelana/DeferredCarrier.lean) has the
corresponding statements: `certified_partition`, `single_block_safe`, `prefix_budget`,
`greedy_dominates` and `noisy_separation`.

**What is certified is integer aliasing, not native numerical safety.** The budget proves the low
channel cannot alias into the high one: `|S_low| <= 1023` makes the exact rational separation of
`p = S_low + 2047*S_high` recover both channels. It says nothing about what the hardware adds to
`p`. Main's `noisy_separation` states the shape of the remaining obligation: for `p = q*(lo + 2047*hi) + e`
with `|e/q| < 1/2`, exact nearest separation still recovers both channels, so the outstanding
requirement is a bound on the WMMA accumulation error together with the reciprocal multiply and FMA
in the decoder. Those are measured here, not proved: at most 0.063 deviation at 8 blocks and 0.125
at the whole 5120, against a boundary of 0.5. A certified candidate is therefore range-certified and
error-measured, not proved safe end to end.

`dfr-certfixed1023-paired-a4` implements it. The producer computes `sum_k |q_k|` per
(token, 128-block) as one extra warp reduction on values already in registers, a picking kernel takes
the largest run length R in {1, 2, 4, 8} for which every aligned run of R blocks of every token of
that call stays inside the 1023 budget, and four compiled projections stand ready with the guard
`if (*chosen != R) return;`. Every one of those is inside `run` and therefore timed, including the
three empty launches per projection.

Round speed ratios against the matched control, 16 of 16 rounds:

| rows | 32 | 64 | 128 | 256 |
| --- | ---: | ---: | ---: | ---: |
| `dfr-defer8` (enumerated, not certified), layer 0 | 1.378 | 1.321 | 1.295 | 1.159 |
| `dfr-certfixed1023` (certified), layer 0 | 1.302 | 1.201 | 1.161 | **1.043** |
| `dfr-certfixed-unbounded` (machinery, R always 8), layer 0 | 1.342 | 1.292 | 1.290 | 1.159 |
| `dfr-certfixed1023` (certified), layer 10 | 1.400 | 1.233 | 1.162 | 1.031 |

Read it in that order. The machinery is nearly free: with a budget nothing can exceed, the
certificate's producer reduction, picking kernel and empty launches give back 0% to 3% of the
deferral. **What costs is the certificate's verdict.** At 256 rows on layer 0 it picks R = 2 for
gate/up and R = 1 for the down projection, so the down projection gets no deferral at all and the
whole-FFN gain falls from 1.159x to 1.043x. At 32 rows it keeps most of the gain, because the batch
is smaller and so is the worst token in it.

Why the verdict is that harsh, in numbers: the worst aligned-run L1 at layer 0, 256 rows, is 330 at
R = 1 and 644 at R = 2 for gate/up, so R = 2 passes and R = 4 (worst 1234) does not; for the down
projection it is 705 at R = 1 and 1407 at R = 2, so R = 1 is all that passes even though **98.9% of
(token, run) pairs would have been fine at R = 2**. One token in a hundred sets the run length for
the whole batch. Meanwhile the realised low channel at 8 blocks has RMS 60 and maximum 839 against
the same 1023 budget: the L1 bound is roughly a factor of three conservative, and it has to be,
because it is the bound that holds for every weight row including the one that lines up with the
activation's large entries.

### Choosing the run length per work unit costs more than it recovers

The obvious repair for "one token in a hundred sets the run length for the whole batch" is to let
each work unit choose. `dfr-certunit1023-paired-a4` does that: the certificate is reduced per
(work unit, group) instead of per call, each of the four compiled lengths sweeps the same grid and
skips the units that chose a different length, and the inner loop stays a compile-time constant.
The work unit is the TT*16 tokens one pass of the tg loop owns, which is the finest granularity
available without either a variable-length inner loop or re-reading the weight stream once per
16-token tile.

It is slower than the per-call choice at every point measured:

| rows | 32 | 64 | 128 | 256 |
| --- | ---: | ---: | ---: | ---: |
| `dfr-certfixed1023`, layer 0 | 1.299 | 1.200 | 1.173 | 1.039 |
| `dfr-certunit1023`, layer 0 | 1.267 | 1.177 | 1.171 | 1.031 |
| `dfr-certfixed1023`, layer 10 | 1.379 | 1.250 | 1.177 | 1.049 |
| `dfr-certunit1023`, layer 10 | 1.367 | 1.234 | **1.031** | 1.034 |

(round speed ratios against the matched control, 16 of 16 rounds each.)

The certificate does get better: at 64-token units, layer 10's down projection reaches 1.33 blocks
per run against the per-call 1.00, and at 32-token units 1.60. Layer 0 gains nothing at that
granularity - every unit still certifies only R = 1 for down, and R = 2 for gate/up - and needs
16-token units before two of sixteen tiles reach R = 2. What eats the gain is the four launches:
each one is a full grid that finds work in only some of its tg iterations, they serialise on the
stream, and the tail of a partially-populated launch costs more than the epilogues the longer runs
removed. The layer-10 128-row point, where only two work units exist and each launch can be half
empty, is where that shows worst.

So the shipped certified candidate stays the per-call one. The finer certificate is a real
improvement in run length and a real loss in throughput, and both are in
[`results/interleaved-certunit-layer00.json`](results/interleaved-certunit-layer00.json) and its
layer-10 companion.

### The adaptive greedy version is a codegen loss, and that is measured

`dfr-cert1023-paired-a4` is the per-token-tile greedy program: schedule bits per (token tile, group),
run lengths read from them, separation wherever the running budget would be exceeded. It reaches the
run lengths it should (2.67 blocks per run for gate/up, 1.95 for down at layer 0, against the fixed
split's 2 and 1), and it is **0.39x** at 64 rows and above. The reason is the run length being a
runtime value rather than a compile-time constant: replacing `len` with the constant `G` in the same
kernel, changing nothing else, takes it from 7.2 ms to 2.46 ms at 256 rows. It is not register
pressure (209 VGPRs, 7 waves per SIMD, no spills, no scratch), not the schedule load, not divergence
(`readfirstlane` on the mask changes nothing), and not the number of compiled run lengths (cutting
eight specialisations to four changes nothing). The kernel stays registered as the record of that
obstruction; a version that beats the fixed split has to get a variable-length accumulation loop
compiled as well as a fixed one, and this compiler does not.

So the honest frontier today is: **1.159x enumerated, 1.043x certified** at 256 rows, and
1.378x / 1.302x at 32 rows. The gap is not the certificate machinery, it is the distance between an
L1 bound and the realised sums.

## What deferral actually buys, and the thing that nearly hid it

The first deferred kernel was **slower** than its control at every deferral length: the down
projection went from 0.80 ms to 1.16 ms at 256 rows while executing strictly fewer instructions. The
compiled ISA for `G = 1` and `G = 8` is the same code to within four instructions (same 4 WMMA in
the loop body, same 64 `v_rndne_f32` in the epilogue); only the epilogue's execution frequency
changes. What changed with it was latency hiding: with `#pragma unroll 1` on the slice loop, a
64-iteration tight loop has nothing to overlap its loads with, while the control's 8-iteration loop
is effectively unrolled against the epilogue that follows it.

Unrolling the slice loop twice fixes it and is the difference between a negative and a positive
result:

| slice unroll | control | defer 4 | defer 8 |
| --- | ---: | ---: | ---: |
| 1 | 2.79 | 2.86 | 2.98 |
| 2 | 2.87 | 2.52 | **2.41** |
| 4 | - | - | 10.2 |
| 8 | 7.28 | 10.2 | 10.2 |

(ms at 256 rows, layer 0, single run.) Four and eight spill. The control is faster rolled, so the
control shipped here (`dfr-control-paired-a4-u1`) uses its own best setting and the deferred
candidates use theirs; `dfr-control-paired-a4` is the same-shape control at unroll 2 for anyone who
wants the strictly-one-variable comparison. The unroll is a property of this kernel, not of
deferral, and it is reported because the honest version of "deferral is worth 1.3x" is "deferral is
worth 1.3x once the loop that replaces the epilogue is scheduled".

Where the time goes at 256 rows, layer 0 (`KELANA_DFR_STAGES=1`, which synchronises between stages):
the gain is in both projections, and the down projection in the control is already close to the FP16
WMMA issue rate, so what deferral buys there is the epilogue's share of a nearly saturated pipe.

Weight image: 1024 bytes per (16 rows x 128 K) of paired codes, with the shared scales in their own
tile-major `[tile][group][16]` array instead of the 64 bytes per block the previous layout carried
inside the code stream. Resident device bytes at batch 256 fall from 100.6 MB (`arith-paired-a4`) to
96.8 MB at 8 blocks. Preparation is untimed, as the API requires, and the offline scale fit happens
there.

## Quality, stated without a claim

Relative RMS against the residual the deployed engine produced for the same rows, 256 rows:

| candidate | layer 0 | layer 10 | bias (layer 0) | worst row |
| --- | ---: | ---: | ---: | ---: |
| control | 0.965% | 1.678% | 1.6e-07 | 2.06% |
| defer 2 | 1.106% | 1.906% | -1.3e-06 | 2.31% |
| defer 4 | 1.217% | 2.054% | -2.4e-06 | 2.51% |
| defer 8 | 1.304% | 2.175% | -1.8e-06 | 2.65% |

The approximation is explicit and labelled: ternary weights are never changed, but their deployed
per-128 FP16 scales are replaced by one fitted scale per group, and the activation amax is taken
over the group rather than the block. Both are reshapings of the scale representation, and both
enlarge the error. Whether 1.304% instead of 0.965% is affordable is a full-model question that
belongs to [`../lossy`](../lossy/README.md) and main's evaluation, not here.

## Run

```sh
cd research/ffn/batched/bench
make build/batch-bench                       # globs ../deferred-carrier/candidates/*.hip
../hardware-run ./build/batch-bench \
    --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
    --rows 32,64,128,256 --iters 80 --rounds 16 --warmup 16 --seed 7717 \
    --candidate dfr-control-paired-a4-u1,arith-paired-a4,dfr-defer2-paired-a4,dfr-defer4-paired-a4,dfr-defer8-paired-a4,gs-shared1024-iu4-a4 \
    --json ../deferred-carrier/results/interleaved-defer-layer00.json
python3 paired_analysis.py ../deferred-carrier/results/interleaved-defer-layer00.json \
    --baseline arith-paired-a4 --out ../deferred-carrier/results/interleaved-defer-layer00-analysis.json

# the certified program, against the matched control
../hardware-run ./build/batch-bench \
    --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
    --rows 32,64,128,256 --iters 80 --rounds 16 --warmup 16 --seed 2209 \
    --candidate arith-paired-a4,dfr-control-paired-a4-u1,dfr-defer8-paired-a4,dfr-certfixed1023-paired-a4,dfr-certfixed-unbounded-paired-a4,dfr-cert1023-paired-a4 \
    --json ../deferred-carrier/results/interleaved-cert-layer00.json
python3 paired_analysis.py ../deferred-carrier/results/interleaved-cert-layer00.json \
    --baseline dfr-control-paired-a4-u1 --out ../deferred-carrier/results/interleaved-cert-layer00-analysis.json

cd ../deferred-carrier
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -I /path/to/workspace/projects/bonsai-halo/src \
      defer_probe.hip -o build/defer_probe
../hardware-run ./build/defer_probe /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 17408 256
../hardware-run ./build/defer_probe /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 17408 256 0.8

python3 carrier_scan.py check                # CPU pipeline against the engine's own residual
python3 carrier_scan.py weights --groups 2,4,8,40 --json results/weights-layer0.json
python3 carrier_scan.py carrier --layer layer00 --groups 1,2,4,8 --json results/carrier-layer0.json
```

`carrier_scan.py check` reproduces the candidates' error from the HALO tiles on the CPU (1.237% at
four bits, 32 rows, against the kernel's 1.2375%), which is what makes the rest of that file's
numbers usable as a cross-check on the native probe.

## What this does not answer

- Whether the wall moves on other models, other documents or longer contexts. Two layers and 256
  tokens of one document is what was enumerated. Layer 0 and layer 10 already differ by a factor of
  1.5 in realised range at 8 blocks.
- Whether 8 blocks is safe for tokens not in this set. It is not certified; `dfr-certfixed1023` is
  what safety costs, and the 2- and 4-block rungs are what it buys.
- A tighter certificate. The L1 bound is about 3x conservative against the realised sums and is set
  by the worst token in the batch. A per-token-tile bound exists and is implemented in
  `dfr-cert1023`, but its runtime run length compiles badly enough to lose everything it gains.
- A hardware error bound for `v_wmma_f32_16x16x16_f16` on integer operands. The deviation was
  measured at every deferral length here and stayed at or below 0.125 against a 0.5 boundary; that
  is evidence, not a bound, and it is the standing argument for the IU4 route over this one.
- Whether deferral composes with the other open move in this family, two-level tiling with LDS
  staging so the weight stream is read once per batch rather than once per token group. That is
  where the remaining gap to the instruction rate is, and it is untouched here.
- Narrower activations. Levels 3 would halve every realised sum and put the whole 5120 columns
  inside the wall at layer 10; the quality cost of that was not measured.
