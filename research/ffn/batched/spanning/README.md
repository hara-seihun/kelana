# Representations across the FFN's middle

The region is gate/up projection → SiLU product and sign → 1024-point Hadamard → int8 quantisation
→ down projection, at 32, 64, 128 and 256 real token rows. The question asked here is whether the
producer can hand its consumer what the consumer already wants, so the wide FP32 hidden image and
the recurring repacking disappear.

At 256 rows, the measured nonlinearity/Hadamard/quantiser stage reads 35.6 MB of FP32 hidden and costs 268 µs of this family's 9.45 ms region. Removing that stage alone offers limited savings. This is not an upper bound on gains from changing the producer, consumer and representation together. The proposed fusion that retains every accumulator of a 1024-wide hidden chunk restricts the token panel and raises weight traffic; other fusion schedules are not excluded.

What did pay is the *layout* at the quantiser/WMMA boundary, and the panel width at small batch.
The projection's store looked like a second prize. On the faster arithmetic base, the tested LDS-staged store loses at 256 rows. The earlier 19% stage saving does not transfer to that base.

## What is measured here

[`candidates/spanning.hip`](candidates/spanning.hip) registers one kernel family through the shared
[`api.hpp`](../api.hpp), measured by the shared [driver](../bench/README.md) on 256 real contextual
rows. Every candidate reproduces the deployed engine's floating accumulation order for each
(output, token) and is checked as `exact_reference`: **zero bit mismatches against the engine's own
residual at 32, 64, 128 and 256 rows, for all of them.** They differ only in representation:

| knob | what changes |
| --- | --- |
| panel | tokens per work unit: 16, 32, 128 or 256 |
| activation layout | canonical `[token][K]`, or the panel layout a WMMA B fragment reads |
| hidden residency | whole image between producer and consumer, or blocked into chunk groups |
| hidden layout | `[token][hidden]`, or `[hidden][token]` as the C fragment writes it |

Results: [`results/span-32.json`](results/), `span-64.json`, `span-128.json`, `span-256.json`.

### Preserving the deployed order while changing the panel

The deployed matvec splits K across the eight waves — wave *w* sums block group *w*, then the eight
partials combine in ascending wave order — and that grouping decides the floating result. A wide
token panel cannot keep one group per wave, because the panel is bounded by what a wave's
accumulators hold. `mv_seg` therefore carries two wave splits:

- `WSPLIT = 8`, the deployed split, panel 16·NTOK.
- `WSPLIT = 1`, where each wave walks all eight groups for its own tokens, accumulating each group
  separately and combining them in the same ascending left-nested order. The panel becomes 128·NTOK
  and a 256-row batch reads every weight tile once.

Both give the deployed result bit for bit; the second costs one extra accumulator set per fragment.
A fourth fragment under `WSPLIT = 8` (panel 64) needs 256 VGPRs and spills 115 bytes per lane, so
that rung is not built.

Unit order is part-major over the whole range, as the deployed dispatch orders it, so the down
projection's two K-split atomic contributions keep arriving in the deployed order. That ordering is
observed, not proved: two `atomicAdd` contributions to one address are not ordered by the hardware.
Tile-major unit order inside a part breaks it and shows up as a 1.7e-8 relative RMS.

## The panel layout the consumer wants

A WMMA B fragment is sixteen tokens' sixteen K values. In the canonical `[token][K]` activation
buffer those are sixteen 16-byte pieces one row stride apart, so one fragment load touches sixteen
cache lines. The quantiser can place them next to each other instead, at no cost to itself — the
store is still one dword, at a different address:

```
value  xq[(token/16 * nblocks + block) * 2048 + kb * 256 + (token % 16) * 16 + byte]
scale  xs[block * batch + token]
```

Everything before the store — the scale, the sign vector, the SiLU product, the Hadamard
butterflies, the block maximum, the rounding, the block sum — is the deployed code in the deployed
order, so the bytes are identical and only their addresses change. It stays bit-exact.

| rows | canonical, best panel | panel layout, best panel | change |
| ---: | ---: | ---: | ---: |
| 32 | 0.761 ms | 0.780 | −2.4% |
| 64 | 2.592 | 2.700 | −4.0% |
| 128 | 5.072 | 4.974 | +2.0% |
| 256 | 11.179 | 9.453 | **+18.3%** |

Minimum intervals; the resident `bonsai-halo` server puts a share of the samples in a slower
regime and every sample is kept in the result files.

The win is conditional on a wide panel. At panel 32 the layout is a small loss at every batch size;
at panel 256 it is 15–18%. The gather only hurts when the sixteen row strides are large enough and
the wave's working set wide enough to miss, which is what a 256-token panel produces. The
arithmetic directory's kernels already emit this layout, which is consistent with their rate.

## The panel width is not the lever at batch

| rows | panel 16 | panel 32 | panel 128 | panel 256 |
| ---: | ---: | ---: | ---: | ---: |
| 32 | 0.761 ms | 0.770 | 0.761 | 0.761 |
| 64 | 2.627 | 2.615 | 2.592 | 2.592 |
| 128 | 5.132 | 5.072 | 5.093 | 5.090 |
| 256 | 11.431 | 11.179 | 11.297 | 11.322 |

A panel of 16 re-reads the 58.5 MB weight image sixteen times at 256 rows and costs 2% against a
panel that reads it once. Its nominal weight traffic is 936 MB in 11.4 ms, or 82 GB/s, below the separate streaming probe's 236 GB/s. Other costs dominate this measured family. The deployed eight-row schedule takes 27.7 ms versus 9.45 ms here, but this comparison changes more than weight reuse and does not isolate the cause of the entire gap.

## Keeping the hidden image hot buys nothing

`span-p256-chunkN` blocks the region so the quantiser consumes each group of 1024-wide hidden chunks
while the projection's output for those chunks is still in cache, instead of producing the whole
17408-wide image first. The hidden working set falls from 35.6 MB to `N/17` of it.

| rows | whole image | 8 chunks | 4 chunks | 2 chunks | 1 chunk |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 32 | 0.761 ms | 0.775 | 0.791 | 0.841 | 0.948 |
| 64 | 2.592 | 2.584 | 2.623 | 2.625 | 2.709 |
| 128 | 5.090 | 5.143 | 5.141 | 5.317 | 6.873 |
| 256 | 11.322 | 11.230 | 11.267 | 11.670 | 11.890 |

Flat at eight chunks and worse below it. Each group costs two grid barriers, and the residency it
buys does not offset the added work in these measurements. The consumer stage is only 2.9% of this base, so eliminating that stage alone would not deliver a large speedup.

## Where the hidden image does cost something, and why moving it fails

A WMMA C fragment holds sixteen tokens across the lanes and its rows in the register index, so
storing `[token][hidden]` scatters sixteen separate four-byte writes per instruction. Storing
`[hidden][token]` makes each one contiguous. `span-hidden-t256` does exactly that and nothing else.

| stage, 256 rows | `[token][hidden]` | `[hidden][token]` |
| --- | ---: | ---: |
| entry quantiser | 88 µs | 88 |
| gate/up projection | 6303 | **5098** |
| nonlinearity, Hadamard, quantiser | 268 | **4370** |
| down projection | 2713 | 3940 |

The producer's scattered store is worth 19% of the projection stage. The naive consumer of the
transposed image is 16x worse, because a token's 1024-wide Hadamard chunk becomes 1024 loads one
batch stride apart, and the whole candidate loses.

Capturing that 1.2 ms looked like it needed a consumer that reads the transposed image as a
two-dimensional tile. The follow-up instead transposed a smaller tile in the producer. That implementation did not recover a net saving at 256 rows; a different consumer design remains untested.

## The store saving was an artefact of a narrow row tile

The 19% above was measured on this directory's projection, whose work unit owns one 32-row weight
tile, so a token's share of the result is 128 bytes. The arithmetic directory's projection puts
four waves of sixteen rows in one workgroup: a token's share is 64 consecutive floats, 256 bytes,
already two full cache lines. Its eight store instructions per wave land in those same lines, allowing write merging. This address geometry is consistent with the measured result; the experiment did not isolate cache-line merging as its sole cause.

The test keeps the hidden image row-major, which is the layout the Hadamard consumer already wants,
and does the transpose inside the workgroup instead: stage the 64-row by (16·TT)-token tile in
17 KB of LDS, then write it back as contiguous 256-byte runs, sixteen lanes to a token. One barrier
pair, local. The arithmetic, the producers, the quantiser, the weight packing, the tiling and the
floating operation order are the arithmetic directory's, unchanged, so the pair is a clean A/B —
and the driver confirms it: every pair below has an **identical `output_sha256`**.

| rows | candidate | direct store | staged coalesced store | change |
| ---: | --- | ---: | ---: | ---: |
| 128 | paired-a4 | 1.819 ms | 1.848 | +1.6% |
| 128 | iu4-a4 | 2.075 | 1.956 | −5.7% |
| 128 | iu8-a8 | 2.752 | 2.734 | −0.6% |
| 256 | paired-a4 | 3.008 | 3.301 | +9.7% |
| 256 | iu4-a4 | 3.119 | 3.281 | +5.2% |
| 256 | iu8-a8 | 4.207 | 4.565 | +8.5% |

Stage times for `iu8-a8` at 256 rows, direct against staged: entry producer 0.048 / 0.043 ms,
gate/up 2.604 / 2.710, hidden producer 0.187 / 0.189, down 1.393 / 1.631. The down projection
loses most, which is where the staged form pays two barrier pairs because it writes two row halves.

The resource report identifies an additional cost: `k_proj<4, 2>` goes from 228 VGPRs and 6
waves/SIMD to 250 VGPRs and 5, because the staging loop holds the accumulators live across the
barrier and adds the addressing. Barriers, addressing and reduced occupancy are bundled in this comparison, so their individual timing contributions are not separated.

**The tested staged epilogue loses at 256 rows.** At 128 rows the IU4 case improves by 5.7%, while the other two are close. These measurements do not prove that direct stores cost nothing, establish a universal 64-row threshold, or rule out a changed global layout with a matching consumer. The fork that produced these numbers is commit `b1e4388`,
`research/ffn/batched/spanning/candidates/store_epilogue.hip`; it was removed afterwards rather
than left to drift alongside the kernel it copies. Results are in
[`results/store-128.json`](results/) and `store-256.json`.

## What was ruled out and what remains

Ruled out by measurement, for this region at 32–256 rows:

- Eliminating the FP32 hidden image by fusing the region into one work unit. Bounded above at 4.5%
  of the region at 256 rows, against an eight-fold weight re-read, because one unit would have to
  hold a 1024-wide hidden chunk's accumulators for every token in the panel.
- Blocking the hidden image for cache residency. Worse at every batch size and every group width.
- Widening the token panel as a way to cut weight traffic at batch. Free but worthless above 32
  rows here.
- Transposing the hidden image with an unchanged consumer.
- The tested LDS-staged projection store at 256 rows. It loses 5–10% on the arithmetic kernels with bit-identical output. The earlier 19% saving belonged to the narrower spanning base.

Standing:

- The quantiser emitting the panel layout: exact, 18% at 256 rows, and the effect grows with panel
  width.

This kernel family is not the fastest exact implementation of the region. The arithmetic
directory's `arith-iu8-a8` is 4.21 ms at 256 rows against 9.45 ms here; the spanning results are
deltas measured on one common base, and the layout conclusion is independent of that base — their
kernels already emit the panel layout and their whole-FFN advantage does not come from the
boundary. At 32 rows this family's 0.761 ms is faster than that control's 1.117 ms.

## Instruction rates this region can reach

[`rate_probe.hip`](rate_probe.hip) times the exact instruction mix the projections issue, with no
FFN structure around it.

| probe | TOPS |
| --- | ---: |
| `v_wmma_i32_16x16x16_iu8_w32` back to back | 55.4 |
| one HALO block decode plus the 32 WMMA it feeds at panel 32 | 51.9 |
| the candidates' inner loop with real weight and panel-layout activation buffers | 39.8 |
| the same inner loop without the activation loads | 67.6 |

The region reaches 14.6 TOPS at 256 rows, so the gap is not the decode and not the instruction mix.
The activation fragment loads are a third of the inner loop's own cost, which is what the panel
layout addresses, and the rest is outside this directory's question.

## Build and run

```sh
cd research/ffn/batched/bench && make build/batch-bench
../hardware-run ./build/batch-bench \
  --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
  --rows 256 --iters 12 --warmup 4 --candidate all --json ../spanning/results/span-256.json

# stage breakdown for one candidate; reading the stamps forces a synchronisation, so this is a
# diagnostic run and not a timed comparison
KELANA_SPAN_PROF=1 ../hardware-run ./build/batch-bench --dataset ... --candidate span-panel256

cd ../spanning && make && ../hardware-run ./build/rate-probe
```

## Files

- [`region.hpp`](region.hpp) — the kernel family: HALO block decode, the two wave splits, the
  panel-layout quantiser, the chunk-blocked schedule, the transposed hidden variant, and the host
  state the candidates share.
- [`candidates/spanning.hip`](candidates/spanning.hip) — registrations through the shared API.
- [`rate_probe.hip`](rate_probe.hip) — instruction rate and inner-loop ceilings.
- [`results/`](results/) — every interval, every stage stamp and every error count.
