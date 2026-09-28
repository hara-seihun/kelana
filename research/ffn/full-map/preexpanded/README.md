# Pre-expanded paired operands

Does precomputing the paired FP16 weight operands offline turn the gate/up arithmetic map into a
whole-FFN win, once the traffic recurs on every call?

No, for these one-token and eight-token whole-image sweeps. On real layer-0 weights and activations,
the expanded eight-token minimum is 2.67x the baseline minimum. Its gate/up stream reaches 226 GB/s,
close to the 236 GB/s measured by the large-footprint read probe. The output and recorded
intermediates match the deployed engine bit-for-bit.

## What was measured

`preexpanded` is `paired` with its decode deleted. The compact kernel rebuilds each A fragment from
nibble codes with two `V_PERM_B32` per four coefficients; this one loads the same FP16 values from a
weight image expanded in `prepare`. The eight WMMA accumulations, the `g + 2047u` recovery, the
digit plane recombination, the per-block scale FMAs and the fused SiLU product are the compact
kernel's instructions in the compact kernel's order, so the FP accumulation order is preserved by
construction and the intermediates agree bit for bit.

`staged` answers the producer/consumer half: it keeps the compact image in memory, decodes it once
per call into a transient operand cache in device memory, and points the same consumer at that
cache.

One copy per (tile, block, slice, row). The two halves of a wave hold the same A fragment in RDNA3's
w32 layout and read the same 32 bytes; nothing is duplicated to match the register file.

| form | bytes per 16x128 block | gate + up image |
| --- | --- | --- |
| deployed HALO tiles | 896 | 38,993,920 |
| compact pair codes | 1088 | 47,349,760 |
| expanded FP16 operands | 4160 | 181,043,200 |

The down projection adds 19,496,960 bytes of HALO tiles in every candidate.

## Results, layer 0, one call covering the whole FFN

Prep, quantisation, both nonlinearities, all weight traffic and the residual write are inside the
timed interval; weight expansion is outside it. 300 intervals per row count, every sample kept.
Medians and minima are both given because the resident `bonsai-halo` server puts roughly a quarter
of the intervals in a slower regime, and because the expanded consumer itself has two regimes.

rows = 8:

| candidate | FFN ms median | ms min | gate/up us median | gate/up us min | weight bytes |
| --- | --- | --- | --- | --- | --- |
| baseline (deployed) | 0.423 | 0.378 | 237 | 227 | 58,490,880 |
| paired (compact) | 0.454 | 0.386 | 230 | 224 | 66,846,720 |
| preexpanded | 2.196 | 1.010 | 807 | 799 | 200,540,160 |
| preexpanded-split | 2.389 | 2.325 | 2208 | 901 | 200,540,160 |
| staged | 4.818 | 4.712 | 2257 (+2373 producer) | 964 | 428,933,120 |

rows = 1:

| candidate | FFN ms median | ms min | gate/up us median | gate/up us min |
| --- | --- | --- | --- | --- |
| baseline | 0.283 | 0.269 | 169 | 165 |
| paired | 0.335 | 0.323 | 228 | 220 |
| preexpanded | 2.255 | 0.941 | 2094 | 790 |
| staged | 4.737 | 4.663 | 2253 (+2369 producer) | 961 |

The expanded consumer runs at either ~800 us or ~2.1 ms for identical work, and which one it gets
varies within a run and between runs; `preexpanded` at 8 rows spent about three quarters of its
intervals in the fast regime, `preexpanded-split` and `staged` almost none. 800 us for 181 MB is
226 GB/s, close to the large-footprint probe's 236 GB/s. The fast-regime comparison therefore
exposes the recurring traffic cost without attributing dispatch waits to the arithmetic map.

Numeric agreement, both row counts, capture variants: 0 bit mismatches on the output residual, 0 on
the gate projection, 0 on the up projection, 0 on the hidden int8 values, 0 on the hidden block
scales and 0 on the block sums.

## Why the bytes decide it

`bandwidth_probe.hip` sweeps a contiguous read with the gate/up kernel's own access shape
(`results/bandwidth-probe.txt`):

| footprint | GB/s | with a 160 KB resident stream paired 1:1 |
| --- | --- | --- |
| 16 MB | 863 | 441 |
| 32 MB | 658 | 324 |
| 48 MB | 235 | 188 |
| 181 MB | 236 | 167 |

The probe shows a working-set performance cliff between 32 MB and 48 MB. It does not identify
which physical cache causes it. Dropping half-wave duplicate reads with `--unique` produces no
measured improvement in this access pattern.

At the measured 236 GB/s streaming rate, reading 181 MB costs about 0.77 ms, already beyond the
roughly 0.39 ms compact whole-FFN interval. The compact image is 3.8x smaller and its gate/up stream
reaches 211 GB/s. This is a measured bandwidth budget for the present batch sizes and access
pattern, not a lower bound on every possible program or representation.

An expanded working set below the observed cliff is one different regime worth testing. A 32 MB
budget holds roughly 16.5M gate/up pairs rather than this layer's 89.1M. Larger batches or a schedule
that reuses a small expanded tile before moving on could also change the comparison.

## Why this staging schedule does not amortise

Repeating the measured whole-image consumer cannot repay staging. Each expanded sweep costs at
least 799 us in the recorded samples, versus 224 us for the compact decode-and-consume sweep.
Its 2.37 ms producer is an additional cost. This statement assumes the measured per-sweep costs
remain fixed; it does not cover tiling or larger batches that change reuse and traffic.

Within this candidate's one-call schedule, each prepared fragment is consumed once and serves its
16 physical rows and eight tokens together.

## Knobs that were tried and did not matter

Pipeline depth over the wider stream (`preexpanded-pf2`, `preexpanded`, `preexpanded-pf8`: 2, 4 and
8 slices in flight), block alignment (`preexpanded-split` lifts the 64 scale bytes out so operand
blocks are exactly 4096 bytes on the line grid) and non-temporal operand loads (`preexpanded-nt`)
all land within noise of each other in the slow regime, and the fast regime is already at the
measured streaming rate. These variants did not recover the expanded representation's byte cost.

## Files

- `expand_codec.hpp` - offline expansion from the deployed HALO tiles, both layouts, threaded.
- `expand_phases.hpp` - the gate/up consumer over expanded operands and the staging producer.
- `../harness/candidates/preexpanded.hip` - the registered candidates.
- `bandwidth_probe.hip` - footprint sweep; `results/bandwidth-probe.txt` is its output.
- `results/*.json` - every interval, every stage stamp, every error count.

## Reproducing

```sh
cd research/ffn/full-map/harness && make
./ffn-bench --dataset /path/to/workspace/data/kelana-ffn/ptq1_0/layer00 --rows 1,8 \
            --iters 300 --warmup 50 --candidate preexpanded --json ../preexpanded/results/preexpanded-layer0.json
hipcc --offload-arch=gfx1151 -O3 -std=c++17 ../preexpanded/bandwidth_probe.hip -o /tmp/bandwidth-probe
/tmp/bandwidth-probe && /tmp/bandwidth-probe --mix
```
