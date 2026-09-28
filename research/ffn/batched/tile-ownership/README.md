# Who owns a weight tile

The later [integrated comparison](../RESULTS.md) repeats these candidates with the scale-carrier and dense-consumer work in one executable. It is the current comparison owner; the exploratory tables below retain their original runs.

The projection kernels of this investigation give one 16-row weight tile to each wave. Every wave of
a workgroup then streams a different tile, and whenever the batch has more token tiles than a wave
can hold, the weight stream is read again — once per extra token group, or once per workgroup when
the token axis is split to fill the device. [seven-product](../seven-product/README.md) measured the
other mapping as a by-product: give one row tile to the whole workgroup and one token group to each
wave. On the gate/up projection alone it was worth 1.110x to the eight-product IU4 map at 256 rows
and 0.644x at 128.

This directory asks what that does to a **whole FFN** — both projections, both producers, all scales
and epilogues — on the kernels that are actually fast, with nothing changed about activation
precision, the quantiser, the weight representation, or what a wave's accumulator sums. Every
token-split candidate here has matched its control's output hashes on the measured rows. The K-split variant changes floating summation order.

**The by-product survives, it is smaller than the projection number, and it is size-dependent in a
way that has a rule.** Scheduled per projection, the shared-tile map is worth 1.01–1.07x on the
strongest A8 whole-FFN kernel and 1.05–1.09x on A4, 10 of 10 rounds at most sizes. Applied flat at
every size, as the projection probe ran it, it loses up to 1.6x. The gate/up projection at 32 and
128 rows does not want it at all.

**Ownership and load shape interact in these schedules.** Reading a lane's
whole 128-block as two `uint4` loads instead of eight dword loads — the dense-byte worker's
[wide load](../dense-consumer/README.md), brought into this source so the two axes can be crossed —
*loses* 1.19x on the IU8 map under control ownership and *wins* 1.08x under the shared-tile map. The
best whole-FFN A8 result here needs both.

| layer 0, against the registered `cs-scaled-f16-a8` | 32 rows | 128 rows | 256 rows |
| --- | ---: | ---: | ---: |
| best A8 candidate here | `wide-tile` **1.221** | `share-adapt` **1.116** | `share-adapt` **1.026** |
| milliseconds, whole FFN | 0.873 vs 1.067 | 2.180 vs 2.419 | 3.898 vs 4.061 |

Geometric mean of per-round speed ratios, randomized interleaved rounds, all samples retained.
Every ratio quoted here, with its interval and rounds won, is in [results/ratios.json](results/ratios.json); the raw samples and telemetry are in the result files beside it.

## The map, as one knob

A batch of `ntiles` 16-token tiles is spent three ways, and the two ownership maps are two corners
of the same factorization:

| spent on | costs | buys |
| --- | --- | --- |
| `TT` token tiles in one wave's accumulators | registers | one weight-operand build feeds `2·TT` matrix instructions |
| `W` waves of a workgroup on the same row tile | wave slots and sometimes narrower per-wave tiles | nearby waves request the same weight bytes, offering cache reuse |
| the rest, walked serially or split across workgroups | a re-read of the weight stream | nothing |

The control is `W = 1`: a workgroup holds `NW = 4` waves on four different tiles, and everything the
tile width cannot hold becomes a serial token group or a `gridDim.y` split. The shared-tile map
moves that leftover onto `W` instead, so a workgroup covers `W · TT · 16` tokens. Each wave still issues its own weight loads and operand construction. There is no explicit one-load broadcast or LDS weight staging here. The mapping changes when and where repeated addresses are requested; memory-traffic counters were not measured.

Nothing else moves. The A operand, the scales, the per-128 integer drain or its absence, SiLU, the
residual add and the output layout are the owning directories' code. An output element is still
owned end to end by one wave, so the map needs no reduction, no staging buffer and no extra
boundary — measured, not argued: at 256 rows on layer 0 the whole IU8 family, control and every
token-split and wide-load schedule and `arith-iu8-a8`, hash to `5ef0d4d4f749a870`, and the whole
scaled-FP16 family to `95e0e5b1acc55af1`. Only the K-split schedule changes a hash, and only because
it reassociates an FP32 sum.

## When sharing pays

From the per-stage decomposition ([results/stages-layer0.txt](results/stages-layer0.txt), layer 0,
milliseconds):

| rows | schedule | gate/up | down | rest | total |
| ---: | --- | ---: | ---: | ---: | ---: |
| 256 | IU8 `tile` | 2.635 | 1.470 | 0.239 | 4.345 |
| 256 | IU8 `auto` (W=4, TT=4 both) | **2.518** | **1.381** | 0.218 | **4.117** |
| 128 | scaled-FP16 `tile` | **1.231** | 0.844 | 0.092 | 2.167 |
| 128 | scaled-FP16 `w2` (W=2, TT=4 both) | 1.344 | **0.721** | 0.095 | 2.159 |
| 32 | scaled-FP16 `tile` | **0.593** | 0.480 | 0.029 | 1.102 |
| 32 | scaled-FP16 `w2` | 0.653 | **0.450** | 0.029 | 1.131 |

The measured stage differences motivated this scheduling hypothesis:

- **gate/up owns 1088 row tiles.** Its grid is full without splitting the token axis, so at 32 and
  128 rows the control already covers the batch in one pass at full width and the tested sharing schedule takes
  width away — 1.231 to 1.344 ms at 128 rows. At 256 rows the batch is 16 tiles against a width of
  8, so the control reads the stream twice and sharing wins it back.
- **the down projection owns 160.** That is 40 workgroups, two per work-group processor, so the
  control splits the token axis to fill the machine and re-reads the weights once per split. The
  shared map instead groups waves requesting the same weight rows, with 160 workgroups: 0.844 to
  0.721 ms at 128 rows, 1.470 to 1.381 at 256.

So the schedule is per projection, and `share-adapt` is that rule:

```
W  = min(NW, max(ceil(ntiles / cap),        // one pass over the batch at full width
                 ceil(320 / row_tiles)))    // waves the stage's grid needs to fill the device
TT = clamp(ceil(ntiles / W), 1, cap)        // cap: 4 accumulator tiles integer, 8 scaled-FP16
W == 1  =>  the control's mapping, unchanged
```

320 waves is four per SIMD32 on this device's 80 units ([geometry](../GEOMETRY.md)). The rule
was selected from this sweep. It wins against this file's scaled-FP16 control at the measured sizes on both layers. This is a fitted scheduling rule, not an optimality theorem or a held-out schedule search. Its shapes are in
[results/schedules.txt](results/schedules.txt).

## Every ownership schedule, against this file's own control

Layer 0 / layer 10, geometric mean of round ratios, scaled-FP16 class:

| schedule | what it is | 32 | 128 | 256 |
| --- | --- | ---: | ---: | ---: |
| `share` | W = 4, width sized to cover the batch: the projection probe's mapping, flat | 0.62 / 0.63 | 0.84 / 0.85 | 0.93 / 0.92 |
| `share-auto` | width first at the register cap, waves from what is left | 0.97 / 0.96 | 0.92 / 0.91 | 1.00 / 1.00 |
| `share-w2` | two waves per tile, half the width | 0.95 / 0.97 | 1.01 / 1.02 | 1.01 / 1.01 |
| `share-dn` | control at gate/up, shared tiles only at the down projection | 0.97 / 0.97 | 0.91 / 0.91 | 1.00 / 1.00 |
| `share-k2` | two token groups × two K splits, reduced through LDS | 1.01 / 1.01 | 1.01 / 1.00 | 1.00 / 1.00 |
| `share-adapt` | the rule above | **1.01 / 1.03** | **1.05 / 1.07** | **1.01 / 1.02** |

The IU8 and IU4 classes are in [results/ratios.json](results/ratios.json); `share-adapt` on IU8 is 0.996 / 1.022 / 1.037 at
layer 0 and `share-auto` on IU4 is 0.984 / 1.057 / 1.064. Two things this table settles:

- **The flat mapping is the wrong experiment on a whole FFN.** `share` is the shape the projection
  probe reported, applied at both projections at every size; it loses everywhere here, by 1.6x at 32
  rows, because it buys wave fan-out with tile width in the one stage that has no use for it.
- **Grid shape alone is not the mechanism.** `share-auto` at 128 rows degenerates to `W = 1`, one
  wave per workgroup: it keeps the 1088-workgroup grid and drops the sharing, and loses 8–9%. The
  result supports inter-wave reuse as a lead, but does not isolate it from changes in grouping, residency or scheduling.

## Ownership and load shape do not separate

The dense-byte worker reported that reading each lane's whole 128-block with two `uint4` loads,
rather than one dword per slice, is worth more than any of this — `dc-paircode-wide-a4` runs the A4
whole FFN in 2.547 ms at 256 rows where the deployed `arith-iu4-a4` takes 3.217. That is a weight
*word order* change, nothing to do with who owns a tile, so this file packs the same 512-byte block
lane-major as a second axis and crosses the two. Same bytes, same image size, same weights, same
output hash; the slice loop is fully unrolled so the word index is constant.

Against this file's control, same rounds, layer 0:

| class | schedule | 32 | 128 | 256 |
| --- | --- | ---: | ---: | ---: |
| IU8/A8 | `share-adapt` (ownership only) | 1.033 | 1.016 | 1.044 |
| IU8/A8 | `wide-tile` (load shape only) | 0.843 | 0.942 | 0.984 |
| IU8/A8 | `wide-adapt` (both) | **1.084** | **1.075** | **1.083** |
| scaled-FP16/A8 | `share-adapt` | 1.019 | 1.096 | **1.005** |
| scaled-FP16/A8 | `wide-tile` | **1.221** | 1.049 | 0.995 |
| scaled-FP16/A8 | `wide-adapt` | 0.859 | 1.089 | 0.869 |
| IU4/A4 | `share-auto` | 1.018 | 1.055 | 1.084 |
| IU4/A4 | `wide-tile` | **1.785** | 1.137 | 1.126 |
| IU4/A4 | `wide-adapt` | 1.737 | **1.172** | **1.158** |

- **On the IU8 map the wide load is only worth having with the shared tile.** Alone it loses at
  every size, by 1.19x at 32 rows; with the shared-tile schedule it is the best IU8 result measured
  here at every size. Two levers that are each worth a few percent, and one of them is negative on
  its own.
- **On the IU4 map the load shape is the dominant lever** — 1.79x at 32 rows by itself — and
  ownership adds 3% on top of it at 128 and 256 rows. This directory's A4 best, `wide-adapt` at
  2.796 ms / 256 rows, is still behind `dc-paircode-wide-a4` at 2.547: that candidate also changes
  the weight encoding, which this directory does not.
- **On the scaled-FP16 map the two do not compose.** The combination is good at 128 rows (1.089) and
  loses at 32 and 256, where the shapes it lands on are one or two waves per workgroup at the widest
  tile. The fully unrolled wide loop at eight token tiles and two waves is the worst cell measured:
  4.535 ms against 3.898 for the same schedule with per-slice loads. Registers and spills are not
  the cause — both are 232 VGPR, six waves per SIMD, no spill.

The best A8 whole FFN in this directory is therefore not one map: `wide-tile` at 32 rows,
`share-adapt` or `wide-adapt` at 128, `share-adapt` at 256.

## The K split, and what a boundary costs

`share-k2` is the contrast case: the workgroup still owns one row tile, but its four waves are two
token groups × two K splits, so a row's K is summed as two interleaved partial sums that meet
through LDS at the end of each token group. This is the only schedule here that adds a layout
boundary — 4 to 32 KB of LDS, two barriers per token group, and a changed output hash from the FP32
reassociation.

It is roughly free and roughly pointless: 1.00–1.01x on the scaled-FP16 kernel at every size, and on
IU8 it loses 1.17x at 32 rows, where its narrower width costs more than the extra parallelism buys.
The token split reaches the same parallelism with no boundary at all, so **the ownership map is
compatible with cheap accumulation without any additional layout boundary, and the boundary it could
have used is not worth its price.** The one case it is defensible is a batch too small to give every
wave a token group — 32 rows on the scaled-FP16 kernel, where it is the best per-slice schedule by
0.8%.

## The control is not a strawman

`to-*-tile` is this file's own source with the owning directories' tiling rules, so the A/B changes
ownership and nothing else. It is also faster than the kernels it copies:

| this file's control against the registered candidate | L0/32 | L0/128 | L0/256 | L10/32 | L10/128 | L10/256 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `to-iu8-a8-tile` / `arith-iu8-a8` | 1.036 | 1.018 | 1.010 | 1.049 | 1.014 | 1.036 |
| `to-csf16-a8-tile` / `cs-scaled-f16-a8` | 0.985 | 1.031 | 1.016 | 0.983 | 1.022 | 1.024 |
| `to-iu4-a4-tile` / `arith-iu4-a4` | 1.053 | 1.012 | 1.039 | 1.005 | 1.015 | 1.032 |

Getting there needed one scheduling repair worth recording. Loaded in the slice that uses them, a
block's two weight words are issued behind that slice's sixteen fragment loads, and the operand
expansion then waits on the whole outstanding queue: `s_waitcnt vmcnt(0)` instead of `vmcnt(6)`,
once per slice, with the memory latency exposed. This file's first version did exactly that and ran
the down projection at 256 rows in 1.87 ms against the owner's 1.35 with an identical grid and an
identical instruction mix. Fetching the words one slice ahead restores the pipeline; hoisting a
whole block's sixteen words at once is better still at the widest tile (1.215 ms) and much worse at
narrow ones, costing 30–38% at 32 rows, so one-slice lookahead is what this file uses at every width
in both arms. The lane-major layout above is the third form of the same idea, and the only one that
turns eight loads into two.

[A patch applying the one-slice form to the two owning kernels](one-slice-prefetch.patch) is in this
directory, together with what it measured there: those compilers already schedule most of it, so it
moved `arith-iu4-a4` 3.285 → 3.185 ms and `arith-iu8-a8` 4.433 → 4.365 at 256 rows across runs, and
`cs-scaled-f16-a8` not at all. It is not applied here — those files belong to their directories, and
the remaining gap to this file's control is not explained by prefetch alone.

## What is measured

[candidates/to_maps.hip](candidates/to_maps.hip) registers 24 whole-FFN candidates through
[api.hpp](../api.hpp), selected combinations of three operand classes, ownership schedules and two weight-word layouts, plus mixed and control shapes. This is not the full Cartesian product. Residual in, residual out; every input-dependent kernel inside
`run` — the producer with the RMS norm, folded sign vector, 1024-point Hadamard and quantiser; the
gate/up projection with SiLU, product and hidden sign; the hidden producer; the down projection onto
the residual.

- **iu8-a8** — `v_wmma_i32_16x16x16_iu8`, deployed eight-bit activations, per-128 integer drain. The
  primary A8 map, from [arithmetic](../arithmetic/README.md).
- **csf16-a8** — two-bit ternary expanded to scaled FP16 in registers, eight-bit activation values
  as FP16, one FP32 accumulator across the whole K, no per-block epilogue. The fastest current A8
  whole-FFN kernel, from [compact-scaled](../compact-scaled/README.md).
- **iu4-a4** — `v_wmma_i32_16x16x16_iu4` on four-bit activations, the A4 comparison family.

Weights are the deployed ternary values with their deployed FP16 block scales in every candidate.
For the token-split schedules, error against the engine is unchanged by ownership and by layout: 0.0117% / 0.0158% / 0.9647%
relative RMS for IU8 / scaled-FP16 / IU4 at 256 rows on layer 0, identical to the control to every
digit, because the outputs are identical.

Registers, from `-Rpass-analysis=kernel-resource-usage`, no spills anywhere in the family:

| class | TT = 1 | 2 | 4 | 8 |
| --- | ---: | ---: | ---: | ---: |
| IU8 / IU4, per-slice words | 115 VGPR, 12 waves/SIMD | 153, 9 | 229, 6 | — |
| IU8 / IU4, lane-major words | 116, 12 | 165, 9 | 247, 5 | — |
| scaled-FP16, per-slice words | 92, 16 | 108, 12 | 157, 9 | 231, 6 |
| scaled-FP16, lane-major words | 94, 16 | 110, 12 | 162, 9 | 232, 6 |

Wave fan-out adds no per-wave registers in this compilation: the `W = 1`, `2` and `4` kernels at one width have the same allocation. That does not make their scheduling or memory cost zero.
The K split adds 4–32 KB of LDS and one occupancy step.

## Protocol

Real contextual rows from `/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00` and `layer10`,
32, 128 and 256 rows, through [bench](../bench/README.md)'s driver:
[interleaved rounds](../bench/MEASUREMENT.md) with a 2 s untimed duration ramp before each batch
size, randomized candidate blocks inside 10 rounds (8 in the cross-worker runs), rewarming after
every switch, 40 timed calls per candidate per size (32 in the cross runs), every sample retained
with its round and order, and a 5 ms sensor trace. All GPU work ran under
[hardware-run](../hardware-run), which serializes the participating research workers; compilation
and analysis ran outside it.

Ratios are from [bench/paired_analysis.py](../bench/paired_analysis.py): geometric mean of per-round
speed ratios with a round bootstrap interval, comparing candidates measured in the same round.
Absolute medians moved by up to 4% between runs of the same binary; the paired round statistics are
what the claims rest on.

The `bonsai-halo` server and a headless browser held DRM devices open throughout, recorded in
`gpu_clients_before` / `gpu_clients_after` of every result file, and other research workers were
running CPU and build work concurrently. No clock, power or service state was changed for these
measurements. The recorded shader clock during the timed windows was 2.4–2.6 GHz at 256 rows after
the ramp.

Result files: `results/ownership-layer{0,10}-{32,128,256}.json` are the ownership experiment,
`results/cross-dense-layer*.json` the runs that also carry the lane-major layout and the dense-byte
worker's `dc-paircode-wide-a4`. Those runs need that worker's directory present:
`PEER_DIRS="... ../dense-consumer"`. [results/ratios.json](results/ratios.json) holds all 916 paired
comparisons from those ten runs — every candidate against every baseline, with intervals and rounds
won — and every number quoted above is one of its rows.

## Limits

- One device, gfx1151. The rule's two constants — a 4 or 8 tile register cap and 320 waves — are
  this device's, and a machine with a different SIMD count or register file needs them re-measured.
- Three batch sizes, two layers, one document's rows. 64 rows was not measured; the projection
  probe's 128-row loss suggests 64 is where the gate/up stage's width preference and the down
  stage's fan-out preference are closest.
- The adaptive rule is fitted to the sweep in this directory and then measured on the same sizes. It
  is a rule read off six stage measurements, not a model validated on held-out shapes.
- The scaled-FP16 regression under lane-major words at eight tiles is measured, not explained.
  Registers, occupancy and spills are identical between the two layouts there.
- Ownership was varied per projection but not per K range or per row block, and the lane-major
  layout was not crossed with the K split.
- The measured effect on the producers is within noise at every size: they are 3–8% of the FFN.
- No full-model acceptance. These are isolated FFN timings against the deployed engine's own output
  for the same rows.

## Run

```sh
cd research/ffn/batched/bench
make PEER_DIRS="../arithmetic ../compact-scaled ../tile-ownership" build/batch-bench
../hardware-run ./build/batch-bench \
    --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
    --rows 256 --iters 40 --warmup 10 --rounds 10 --ramp-ms 2000 --seed 19073 \
    --candidate to-csf16-a8-tile,to-csf16-a8-share-adapt,cs-scaled-f16-a8 \
    --json ../tile-ownership/results/ownership-layer0-256.json
python3 paired_analysis.py ../tile-ownership/results/ownership-layer0-256.json \
    --baseline to-csf16-a8-tile --out /tmp/l0-256-vs-to-csf16-a8-tile.json
```

That second command regenerates the per-round detail behind any row of
[results/ratios.json](results/ratios.json), for any baseline in the run.

`KELANA_TO_STAGES=1` prints the four per-stage times, with a synchronisation between stages.
`KELANA_TO_GRID=1` prints every launch shape. `KELANA_TO_TT_GU`, `KELANA_TO_TT_DN`, `KELANA_TO_W_GU`
and `KELANA_TO_W_DN` force a width or a wave fan-out per projection, which is how the sweep behind
the rule was run.
