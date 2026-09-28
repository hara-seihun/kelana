# Whole-FFN maps

The boundary is Bonsai's residual-in to residual-out FFN, including normalization, signs, Hadamard transforms, quantization, gate/up, SiLU product, down projection and residual addition. One-time weight preparation is untimed. Every input-dependent producer, representation change, weight read and output operation is timed.

There is no whole-FFN speedup yet. The useful results are exact spanning constructions, measured failures, and clearer representation choices.

## Research rule

Choose entry and exit representations for a region, not a required representation for every source operation. An encoding can lose locally and win across a composition when the producer already emits what the final consumer accepts. Conversely, saving arithmetic is insufficient if the next operation forces an expensive reconstruction. The general rules live in [composition](../../composition/README.md).

Investigate the complete region before rejecting an encoding. Include recurring traffic, live registers, gather operations and cache-sized working sets. Amortizing the construction of a weight representation does not amortize reading or decoding it each inference.

## Implemented maps

### Pair gate/up rows inside FP16 WMMA

[paired_phases.hpp](paired_phases.hpp) makes the input quantizer emit two FP16 digit planes directly. [paired_codec.hpp](paired_codec.hpp) stores each gate/up trit pair as a four-bit code for one of nine exact FP16 coefficients `g + 2047*u`. The GPU decodes those codes, computes packed sums, recovers both integer contributions per scale block and preserves the baseline's scale FMA and cross-wave addition order. It applies SiLU/product/sign before storing one hidden buffer. Separate gate/up buffers exist only in the capture variant.

Gate/up weight bytes increase from 38,993,920 to 47,349,760. Pipelining compact loads removes the first implementation's roughly 2x gate/up slowdown, but the whole FFN does not win. Distributing decode across lanes also loses. The maintained decoder is the faster prefetched version.

[FFNPairedMap.lean](../../../Kelana/FFNPairedMap.lean) proves that substituting the correct integer block map preserves an arbitrary ordered accumulation, nonlinear map and downstream consumer. It does not assume floating-point associativity. Native floating WMMA still has the separate error-bound question recorded in [the prepared-core experiment](../packed-wmma/NOTES.md).

### Let ternary weights select linear forms

[table/table_phases.hpp](table/table_phases.hpp) changes the direction of representation work:

1. The activation producer builds the 27 possible ternary linear forms of each three-input group.
2. Each table entry holds results for two tokens in one unsigned 32-bit word: `(a+384) + 65536*(b+384)`.
3. Each three-trit weight group stays a five-bit selector. The consumer never expands those weights to bytes or halves.
4. Forty-three selected entries are added while still packed. The final group pads the 129th input with zero.
5. Only the scale boundary decodes the two sums, subtracting `43*384`. The baseline scale FMAs and wave reduction order follow.
6. Gate/up are interleaved offline, so the projection applies SiLU/product/sign before the hidden buffer. The down projection can use the same table map or remain the baseline.

[table/weights.hpp](table/weights.hpp) packs 215 selector bits and 16 scale bits into 29 bytes per row block, versus HALO's 28. It uses spare bits in the last selector word for part of the scale. A work unit handles 128 logical rows, reusing each table neighborhood across four rows per lane. Table construction remains inside timing.

[TernaryTable.lean](../../../Kelana/TernaryTable.lean) proves lookup correctness, packed addition closure, the 43-stage no-carry bound and exact final decoding. The integer representation has no floating-WMMA accuracy dependency. Native output, gate/up, hidden codes, scales and sums match bit-for-bit on the recorded layer-0 and layer-10 cases at one and eight tokens.

The table map still loses. It replaces arithmetic with repeated table traffic and address generation. An antipodal variant halves the table by replacing negative forms with signed access to positive forms. That compression adds recurring sign operations and caused large compiler spills until group lifetimes were constrained; even after that repair it loses. Prefetching its weight records also loses. Those experiments remain in Git history and result files; the maintained implementation uses the faster direct 27-form table.

### Precompute the instruction-ready weights

[preexpanded/README.md](preexpanded/README.md) records the explicit test of free offline expansion. It deletes runtime weight decoding but increases the gate/up image to 181,043,200 bytes. Expanded and staged candidates remain bit-exact and lose. The read probe shows a working-set performance cliff between 32 MB and 48 MB. This result applies to the measured whole-image sweeps at one and eight tokens, not all possible tile-reuse schedules or batch sizes.

## Measurements

Real PTQ1_0 weights and native prefill inputs, source Bonsai commit `6fcff4c0a881e1fa2f448db630e76a57cb1bf268`. Datasets are `/path/to/workspace/data/kelana-ffn/ptq1_0/layer00` and `layer10`. All samples are retained under [harness/results](harness/results/) and [preexpanded/results](preexpanded/results/).

The layer-10 confirmation run uses the maintained pair and direct-table implementations. Capture variants also write gate/up for comparison.

| tokens | map | whole FFN median / minimum, ms | gate/up median, us | down median, us |
| --- | --- | --- | --- | --- |
| 1 | baseline | 0.287 / 0.273 | 174.4 | 93.1 |
| 1 | paired capture | 0.335 / 0.329 | 229.3 | 91.7 |
| 1 | table capture | 0.378 / 0.316 | 201.5 | 99.4 |
| 8 | baseline | 0.463 / 0.413 | 240.1 | 144.1 |
| 8 | paired capture | 0.502 / 0.426 | 241.7 | 151.4 |
| 8 | table capture | 1.739 / 0.537 | 341.7 | 189.4 |

All six comparisons have zero bit mismatches at every captured boundary. Whole-interval distributions contain dispatch waits and co-resident workload stalls. Independent stage medians do not sum to an interval median. Even the candidates' minimum intervals do not beat the baseline minimum in this run.

The harness now records exact bit-mismatch counts, rejects nonfinite comparison values, checks hidden scales and sums as well as codes, charges each candidate's actual weight layout, and embeds a build-time source fingerprint. Earlier result files predate fingerprinting. The direct-table first experiment is committed at `810a040`; the antipodal experiment at `4514f07`; table-prefetch at `c3e5c76`; the selected direct schedule was restored in `3b32a52`. Paired prefetch measurements and implementation are in `dbe758f`, distributed decode in `4f91269`.

## Another proved direction: guided packing

[GuidedPacking.lean](../../../Kelana/GuidedPacking.lean) removes an unnecessary restriction on a packed channel. For `p = a + 2047*b`, it is enough to know an estimate `e` with `|a-e| <= 1023`. Decode `b` from `p-e`, then recover `a`. The full `a` need not fit in the radix's low-digit range.

For signed-int8 activations, `q=floor(x/16)` fits signed int4 and `x-(16*q+8)` lies in `[-8,7]`. Consequently a ternary row with at most 127 nonzeros has the exact coarse estimate

`e = 16*dot(w,q) + 8*sum(w)`

with residual magnitude at most 1016. The row sum is input-invariant. This proves a possible two-channel representation: a packed calculation plus a cheaper coarse calculation, rather than a packed calculation that must carry everything alone.

There is no native guided-packing speed claim. A full-int8 packed sum has a larger range than the digit-plane sum and can exceed FP32's consecutive-integer range. The hardware lowering must solve that problem and pay for the coarse channel. The theorem is a discovery rule, not permission to ignore those costs.

## Run

See the [harness interface and dataset capture](harness/README.md). For the selected maps:

```sh
cd research/ffn/full-map/harness
make -j3
./ffn-bench --dataset /path/to/workspace/data/kelana-ffn/ptq1_0/layer10 \
  --candidate paired-capture --rows 1,8 --iters 100 --warmup 20 --json results/paired-capture-layer10.json
./ffn-bench --dataset /path/to/workspace/data/kelana-ffn/ptq1_0/layer10 \
  --candidate table-capture --rows 1,8 --iters 100 --warmup 20 --json results/table-capture-layer10.json
```

`codec_check.cpp` checks all 6561 four-coefficient LUT inputs and HALO repacking. `table/check.cpp` checks ternary selectors, split scale fields and packed accumulation. `probe.hip` checks the paired codec and projection on GPU. The root Lean build and `research/Audit.lean` include all three new proof modules. The proofs use only Lean's standard logical axioms, with no `sorry` or native-evaluation axioms.
