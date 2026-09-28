# Compact ternary storage, scaled FP16 operands

Two bits per weight in memory, the block scale folded into the operand while it is being built in
registers, and one FP32 WMMA accumulator across the whole K. No per-128 integer drain, no scale
epilogue, no activation scale in the inner loop.

**Result: 1.12x the compact eight-bit control at 256 rows, 1.02x at 128, 1.03x at 32 and 0.90x at
64, with 0.011% relative RMS against that control.** Layer 10 repeats it at 1.11x and 1.00x. It is
2.5x the expanded FP16 baseline on the same operand class, and 1.21x slower than four-bit IU4 at 256
rows while carrying roughly one eighty-seventh of IU4's error.

The measured lever is the tile width. Capping the identical kernel at the four token tiles the
integer maps run at turns 1.12x into 0.93x, and the wide tile is available because FP32-only
accumulators still fit at eight tiles, where the integer maps' second accumulator set spills. What the
removed epilogue is worth on its own is not separated here: this map changes the operand class and
the epilogue together, so the two effects are only measured jointly.

## What the map is

A deployed weight is a trit in {-1, 0, +1} with an FP16 scale per (row, 128-block). Its FP16 product
with that scale is exactly one of three bit patterns: zero, the scale, or the scale with bit 15
flipped. So folding the scale into the A operand is byte selection, not arithmetic. Main's
`Kelana/ScaledTrit.lean` carries the construction over raw half bits and `Kelana/ScaledTritCodec.lean`
proves this directory's packed form specifically - the code assignment, the field spread, the
selector interleave and the resulting operand. [scaled.hpp](scaled.hpp) is that construction in
HIP. Neither proof says anything about the hardware's FP16 accumulation, which stays measured.

Each lane holds one weight row for a whole 128-block, so its scale is one FP16 value for the whole
block. Two byte tables built once per block,

```
tlo = [0x00, s_lo, s_lo, s_lo]      thi = [0x00, s_hi, s_hi, s_hi ^ 0x80]
```

turn the stored code (0 for zero, 1 for +1, 3 for -1) into a v_perm selector directly: the low byte
of a half is `tlo[c]`, its high byte is `thi[c]`, and because `thi` sits in the permute's upper
source dword the high selector is just the code plus four. Four codes spread into four bytes in four
instructions, one OR makes the second selector, and two permutes per output dword finish two
weights. Nine instructions per four weights, all full-rate.

Since the weight operand carries its own scale and the activation carries its own, the accumulator
is the finished projection. The integer maps instead drain int32 every 128 columns, convert, shuffle
in the weight scale row, load the token scale and run two FMAs per accumulator element - 40 times
per row for gate/up and 136 times for down.

Activations come in two labelled forms:

- `cs-scaled-f16-a8` keeps the deployed eight-bit quantiser and feeds `q * scale` rounded to FP16.
  Near-A8 input semantics with one extra rounding.
- `cs-scaled-f16-direct` rounds the transformed float straight to FP16 with no eight-bit grid. A
  different quality rung, not a different speed rung.

Weights are never approximated: the deployed trits with the deployed FP16 block scales.

## Reassociation and source precision, stated

- Weight operands are **exact**: `trit * scale` is representable in FP16 for every trit, so nothing
  is lost building them. Main's CPU isolation confirmed the round trip independently.
- Activation operands are FP16, one rounding below the eight-bit value they represent (or below the
  transformed float in the direct variant).
- Products of two FP16 values are exact in FP32. The summation **is** reassociated: one FP32
  accumulator over 5120 or 17408 terms instead of exact int32 sums over 128 terms combined in FP32.
- The hardware's internal accumulation order and rounding inside `v_wmma_f32_16x16x16_f16` are not
  documented, so the numeric cost below is measured, not bounded.

Pairwise candidate outputs at 256 rows, layer 0, each pair sharing one producer family:

| pair | relative RMS |
| --- | ---: |
| `cs-scaled-f16-a8` against `arith-iu8-a8` (this directory's producer both sides) | 1.104e-4 |
| `native_fp16` against `native_iu8` (the engine's own producer both sides) | 1.104e-4 |

Both pairs differ by scaled-FP16 operands with whole-K FP32 accumulation on one side against int8
operands with per-128 int32 accumulation on the other, and both land at 1.10e-4. At layer 10 the
corresponding numbers are 1.93e-4 and 1.94e-4 against the same control.

This is consistent with the difference being the operand and reassociation change rather than a
producer artifact, and it is not a proof of that. Two producers agreeing on an RMS figure does not
make their numeric maps identical, and the two pairs are not source-matched: `native_*` calls the
engine's `prep_chunk_r`, this directory's candidates use the reimplemented producer, and the
quantisers have not been compared element by element. Settling it needs one producer feeding both
operand classes, which is a source change to `bench/candidates` and belongs to that owner.

For scale, `arith-iu4-a4` against the same control is 9.66e-3, eighty-eight times larger.

Against the deployed engine the whole candidate is 1.58e-4 at 256 rows. Part of that is the
producer: `native_iu8`, which calls the engine's own `prep_chunk_r`, sits at 1.76e-5 against the
engine, while this directory's reimplemented producer family sits near 1.2e-4 on its own. These are
isolated FFN errors, not model quality acceptance.

## Whole FFN, measured

Layer 0, 256 real contextual rows of one document, [interleaved protocol](../bench/MEASUREMENT.md):
20 randomized rounds, 160 timed calls per candidate per batch, 2 s untimed ramp per batch size,
telemetry retained. Medians in ms, full samples in
[results/compact-scaled-layer0.json](results/compact-scaled-layer0.json),
[analysis](results/compact-scaled-layer0-analysis.json).

| rows | arith-iu8-a8 (control) | cs-scaled-f16-a8 | round ratio vs control | 95% round interval | cs-scaled-f16-direct | arith-iu4-a4 | native_fp16 |
| ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 32 | 1.103 | 1.075 | 1.0259 | 1.0227–1.0294 | 1.072 | 0.981 | 2.734 |
| 64 | 1.356 | 1.510 | 0.8990 | 0.8931–0.9051 | 1.503 | 1.111 | 3.039 |
| 128 | 2.251 | 2.200 | 1.0192 | 1.0080–1.0308 | 2.212 | 1.704 | 5.189 |
| 256 | 4.518 | 4.024 | 1.1242 | 1.1129–1.1354 | 4.062 | 3.325 | 10.172 |

Layer 10, separate seed, same protocol and candidates
([results](results/compact-scaled-layer10.json), [analysis](results/compact-scaled-layer10-analysis.json)):

| rows | arith-iu8-a8 (control) | cs-scaled-f16-a8 | round ratio vs control | 95% round interval | cs-scaled-f16-a8-t4 | arith-iu4-a4 |
| ---: | ---: | ---: | ---: | --- | ---: | ---: |
| 128 | 2.260 | 2.241 | 1.0049 | 0.9973–1.0119 | 2.648 (0.855) | 1.690 |
| 256 | 4.494 | 4.049 | 1.1085 | 1.0982–1.1192 | 4.800 (0.934) | 3.245 |

Relative RMS against the control at layer 10 is 1.93e-4 at 256 rows and 2.07e-4 at 128, against
1.68e-2 for `arith-iu4-a4`. Layer 10's errors are larger for every candidate, including the
control's own 4.05e-5 against the engine.

Ratios against the same control for the other candidates at 256 rows: `arith-iu4-a4` 1.358,
`native_fp16` 0.443, `cs-scaled-f16-a8-t4` 0.930. The control is the honest one: same two-bit weight
image, same producer family, same kernel shape, same fused epilogue, differing in operand class and
where the scales are applied.

Per-stage at 256 rows, averaged over the timed calls of one interleaved run
(`KELANA_SCALED_STAGES=1`, which synchronises and so is not part of a timed acceptance run):

| stage | arith-iu8-a8 | cs-scaled-f16-a8 | arith-iu4-a4 |
| --- | ---: | ---: | ---: |
| producers | 0.231 | 0.198 | 0.212 |
| gate/up + SiLU | 2.643 | 2.451 | 1.936 |
| down + residual | 1.621 | 1.329 | 1.054 |

Against the FP16 WMMA issue rate measured by [rate_probe](../arithmetic/rate_probe.hip)
(4096 MAC per instruction, 11.85 ns per instruction per physical SIMD, 80 SIMDs), the gate/up
projection's 4.56e10 MACs at 256 rows have a 1.650 ms floor. This map reaches 67% of it, the IU8
control 62%, and IU4 43% of its own twice-as-fast floor.

## Instruction mix, and what it does not settle

The compiled inner loop of `k_proj<8, true>` issues, per 16 WMMA instructions:

```
16 v_wmma_f32_16x16x16_f16    92 VALU (32 v_perm, 16 v_mul_u32_u24, 16 v_or, 10 v_and, 4 v_bfe, ...)
18 memory instructions        25 SALU
```

The 92 VALU are two weight operands, 46 each for 16 weights. That is the real instruction cost of
the operand, and it is not a cycle model: whether VALU and matrix issue overlap on this target, and
which resource actually binds, is not established here, so these counts bound nothing on their own.
The rate probe's 11.85 ns per FP16 WMMA instruction per SIMD puts the gate/up projection's floor at
1.650 ms and the measurement at 67% of it; what occupies the other 33% is not identified. Activation
fragment size is the obvious suspect - 32 bytes per (k-slice, token) against the control's 16 and
IU4's 8, with every workgroup reading the whole activation matrix - but no traffic counter was read,
and instruction-mix arithmetic cannot distinguish it from issue interleaving or latency.

What the measurements do separate is the tile width: same kernel, same operands, same epilogue, cap
changed from eight tiles to four, 1.12x becomes 0.93x.

## Register headroom is the actual mechanism

No spills anywhere. `k_proj` VGPR counts and occupancy from `-Rpass-analysis=kernel-resource-usage`:

| token tiles per wave | fused gate/up | down |
| ---: | --- | --- |
| 8 | 227 VGPR, 6 waves/SIMD | 201 VGPR, 7 waves/SIMD |
| 4 | 141 VGPR, 10 waves/SIMD | 126 VGPR, 10 waves/SIMD |
| 2 | 104 VGPR, 12 waves/SIMD | 91 VGPR, 16 waves/SIMD |
| 1 | 88 VGPR, 16 waves/SIMD | 69 VGPR, 16 waves/SIMD |

The integer maps carry an int32 accumulator set **and** an FP32 accumulator set, 2 x TT x 8 of each,
which is why [arithmetic](../arithmetic/README.md) measured eight tiles at 256 VGPRs with 70-82
spilled and a 2.8x regression, and runs at four. This map has only the FP32 set. The ablation is
`cs-scaled-f16-a8-t4`, the identical kernel capped at four tiles: 0.930x the control at 256 rows
instead of 1.124x, and 0.934x against 1.109x at layer 10.

So the wide tile is what carries the win at 128 rows and above. That is a statement about the tile
width, not an accounting in which every other difference cancels exactly; the operand cost and the
removed epilogue were changed together and are not individually measured.

## Batches the tile width does not divide

A wave walks the token axis in steps of `TT*16`. When the batch's 16-token tile count is not a
multiple of the width - 200 rows is 13 tiles, and 13 is prime - the last step covers tiles past the
batch. Outputs were always guarded by the row count, but the B fragment reads were not, and at the
last k-slice of the last block they ran past the activation buffer.

The launch now passes the fragment stride and the walked token axis separately: the axis is rounded
up to a whole tile group and the row guard discards the extra columns. Width choice stays free, so no
batch is forced down to one tile per wave, and an environment override cannot reintroduce the read.

The fragment index is `slice * Npad + token`, so an overhanging read aliases the next k-slice's own
valid columns and only the final slice can run off the end. The buffer therefore carries one tile
group of fragments past the whole allocation - 128 fragments, 4 KiB - rather than a slack column in
every slice. Those aliased columns belong to invalid tokens, so nothing that survives the row guard
depends on what they hold.

40, 88 and 200 rows run with relative RMS 1.92e-4, 1.77e-4 and 1.66e-4 against the engine, in line
with the aligned sizes. Aligned batches are bit-identical to the pre-repair kernel: 256 rows gives
the same output hash.

## Tile widths are fitted, not derived

Gate/up spreads 1088 row tiles over 272 workgroups, so the device is full before the token axis is
split at all and the widest tile always wins. Down has 160 row tiles in 40 workgroups and must split
the token axis to fill the machine, which re-reads its weights once per split. Whole-FFN medians
over the forced grid (`KELANA_SCALED_TT_GU` / `_DN`, which still work for rechecking on other
shapes):

| rows | gate/up width | down width 1 | 2 | 4 | 8 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 32 | 2 | 1.106 | **1.062** | - | - |
| 64 | 4 | 1.573 | **1.523** | 1.972 | 1.923 |
| 128 | 8 | 2.540 | **2.246** | 2.429 | 2.489 |
| 256 | 8 | 5.103 | 4.438 | 4.319 | **4.142** |

At 32 rows a gate/up width of 1 costs 1.232 against 1.062 for width 2. The shipped rule is: gate/up
takes the widest tile the batch allows, down takes 8 at 256 rows and above and 2 below. Down's
reversal at 256 is weight traffic overtaking occupancy - eight splits re-read its 22 MB image eight
times - and the crossing point is fitted to this device and these two shapes.

## Storage

| candidate | weight image | resident at 256 rows |
| --- | ---: | ---: |
| deployed HALO tiles | 58.5 MB (1.75 bits/weight) | - |
| this map, `arith-*`, `gs-*` | 71.0 MB (2.00 bits/weight plus FP16 block scales) | 100.4 MB |
| `native_fp16` | 534 MB (16 bits/weight) | 593.9 MB |

The stored image is the two-bit form every integer map in this investigation already uses; nothing
here expands it. The 16-bit form exists only in registers: `native_fp16` buys the same operand class
for 7.5x the weight bytes and runs at 0.45x the control.

## Ownership boundary for the arithmetic

[scaled.hpp](scaled.hpp) is the reusable part and has no kernel plumbing in it: `pack_two_bit` and
`tile_major` for offline layout, `scale_tables` for the per-block constants, `expand_scaled` for the
operand, and `weight_operand` for the whole per-(block, slice) load-and-expand a consumer needs. A
full-model runner that wants this arithmetic should include that header and call those functions
rather than re-deriving a projection with a similar RMS.

## Run

```sh
cd research/ffn/batched/bench
make build/batch-bench                  # globs ../compact-scaled/candidates/*.hip
../hardware-run ./build/batch-bench \
  --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
  --rows 32,64,128,256 --iters 160 --rounds 20 --warmup 20 --seed 19073 --ramp-ms 2000 \
  --candidate cs-scaled-f16-a8,cs-scaled-f16-a8-t4,cs-scaled-f16-direct,arith-iu8-a8,arith-iu4-a4,native_fp16 \
  --reference-candidate arith-iu8-a8 \
  --json ../compact-scaled/results/compact-scaled-layer0.json
python3 paired_analysis.py ../compact-scaled/results/compact-scaled-layer0.json \
  --baseline arith-iu8-a8 --out ../compact-scaled/results/compact-scaled-layer0-analysis.json
```

`KELANA_SCALED_STAGES=1` prints per-stage times and synchronises between stages; leave it unset for
a timed run.

## What is open

- 64 rows loses and 32 ties. The map needs 128 rows before the eight-tile width is available, and
  below that it pays more for operands with no wider tile to amortise them. Candidates worth trying
  at the low-batch end are a narrower activation fragment and a schedule that amortises the operand
  across weight rows rather than tokens; neither has been measured here.
- The 33% of the issue-rate roofline this map does not reach is unexplained. Reading traffic
  counters, or A/B-ing LDS staging of the B fragments, would identify it. LDS staging is also the
  arithmetic worker's next step, and would move more bytes here because these fragments are twice
  the width.
- Nothing here is model quality. The 0.011% against the eight-bit control is one layer of one
  document.
