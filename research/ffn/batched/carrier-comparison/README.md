# Whole-FFN carrier comparison

This is the combined comparison of the [half carrier](../half-carrier/README.md),
[deferred arithmetic carrier](../deferred-carrier/README.md), and their controls.
All input-dependent preparation, both projections, SiLU, hidden quantization and
residual addition are timed. One-time weight preparation is outside the interval.
These are isolated FFNs on real captured inputs, not full-model throughput.

## Ramped, interleaved results

The first combined run caught an incomplete warmup. Twenty calls did not outlast
the idle-to-load clock ramp; measured batch-32 windows reported 0.7 to 2.2 GHz.
`carriers-layer*.json` keeps those samples. Do not use its small-batch timings as
the final comparison.

The shared driver now exercises candidates for two seconds before each batch.
`carriers-ramped-layer*.json` uses that repair, 120 calls per candidate in 20
randomized rounds. All samples remain. Reported clocks during measured windows
were 2.61 to 2.82 GHz at batch 32 and 2.64 to 2.67 GHz at batch 256. The Bonsai
server and a headless browser held GPU device descriptors throughout. The research
lock serialized participating workers, not those external clients.

Median whole-FFN milliseconds, layer 0:

| Candidate | 32 rows | 64 | 128 | 256 |
|---|---:|---:|---:|---:|
| Arithmetic IU8, A8 | 1.083 | 1.348 | 2.244 | 4.483 |
| Arithmetic IU4, A4 | 0.994 | 1.134 | 1.729 | 3.256 |
| Arithmetic paired FP16, A4 | 0.894 | 0.996 | 1.513 | 3.189 |
| Half carrier, RNE | 0.963 | 1.087 | 1.535 | 2.829 |
| Deferred family's matched control | 0.914 | 1.000 | 1.570 | 2.834 |
| Defer eight blocks, observed range | 0.610 | 0.759 | 1.215 | 2.461 |
| Defer with online integer-range certificate | 0.687 | 0.857 | 1.351 | 2.716 |
| Grouped-scale IU4 | 0.859 | 0.899 | 1.418 | 2.723 |

The control choice changes the conclusion. At 256 rows, geometric mean of
same-round speed ratios with round-bootstrap 95% intervals:

| Change and reference | Layer 0 | Layer 10 |
|---|---|---|
| Half carrier vs arithmetic IU4 | 1.1549 [1.1491, 1.1605] | 1.1590 [1.1537, 1.1643] |
| Half carrier vs deferred-family control | 1.0150 [1.0052, 1.0240] | 0.9938 [0.9893, 0.9988] |
| Observed defer8 vs its matched control | 1.1618 [1.1523, 1.1713] | 1.1148 [1.1113, 1.1184] |
| Range-certified deferral vs its matched control | 1.0541 [1.0453, 1.0626] | 1.0295 [1.0255, 1.0336] |
| Observed defer8 vs grouped-scale IU4 | 1.1064 [1.1010, 1.1116] | 1.0897 [1.0837, 1.0947] |
| Range-certified deferral vs grouped-scale IU4 | 1.0039 [0.9984, 1.0092] | 1.0063 [1.0003, 1.0110] |

Thus the half representation improves its IU4 implementation but does not beat
all existing A4 implementations. Deferral wins at a larger scale approximation;
at batch 256 its range-certified version gives almost the same throughput as
IU4 implementing the grouped-scale map. Removing the certificate is not a free
optimization: an earlier clipped-input configuration actually wrapped a channel.
At smaller batches the range-certified paired map retains more of its advantage.

The half carrier keeps two persistent values per register and uses packed half
scale multiplication and accumulation. Deferred separation instead retains
`lo + 2047*hi` across several blocks sharing a scale. Both change the arithmetic
between producer and consumer. Neither is merely an offline expansion of weights.

## Compare actual output vectors

The driver now accepts `--reference-candidate NAME`. It preserves engine-relative
metrics and also reports candidate-minus-candidate metrics and the reference
output hash. Equal errors to the engine do not establish equal computations.

`numeric-grouped-layer*.json` uses one checked pass per candidate at 256 rows.
Its single timing sample is not a performance measurement. Relative RMS against
`gs-shared1024-iu4-a4`:

| Candidate | Layer 0 | Layer 10 |
|---|---:|---:|
| Observed defer8 | 0.008904% | 0.007814% |
| Range-certified deferral | 0.008904% | 0.007536% |

All outputs were finite; they were not bit-identical. The maximum absolute
pairwise difference was 0.001016 at layer 0 and 0.000466 at layer 10. This closes
the earlier reporting gap where equal engine-relative RMS was described as the
same numerical object. The grouped-scale constructions agree in ideal algebra,
not in their floating evaluation or the quantizer decisions that follow it.

The half carrier's separate paired comparison found 0.127% and 0.197% incremental
FFN error against its IU4 control. Its almost unchanged engine-relative RMS hid
that difference. See its [paired-error record](../half-carrier/README.md).
The [full-model intervention](../half-carrier/model-quality/README.md) runs genuine
half accumulation across all 64 FFNs. Its mean KL from its FP32 schedule control
is 0.0264 over 128 positions. Captured replay differs from the fast standalone
half kernel by 0.1635% relative RMS, so those KL figures do not yet transfer to
the exact winning implementation. Similar sizes of two perturbations do not
make their output vectors equal. No model-quality threshold has been accepted.
The deferred approximation has no full-model acceptance.

## What is proved

[`Kelana/DeferredCarrier.lean`](../../../../Kelana/DeferredCarrier.lean) establishes:

- A run with activation L1 at most 1023 separates its two integer ternary dots
  exactly. Separating a certified partition and adding its outputs gives the
  same integer result as the original dots. Shared scales need not change.
- One 128-element A4 block always fits: `128*7 = 896`.
- Greedily taking the longest legal run minimizes the number of separations
  among ordered partitions using the same per-token L1 certificate. This is
  not minimum unit cycles. The native variable-length greedy loop was slower
  than fixed compiled runs, despite using fewer separations.
- For an imperfect rational carrier `p/q = lo + 2047*hi + e/q`, positive `q`,
  `|lo| <= 1023` and `|e/q| < 1/2`, exact nearest-rational separation recovers
  both integers. The native WMMA error and floating reciprocal/FMA decoder still
  need their own bounds. Integer-range certification does not prove those.
- One additional parity bit of the low channel doubles its recoverable symmetric
  range to `[-2046,2046]`. No decoder of the carrier alone can cover that domain:
  `-1023 + 2047*1 = 1024 + 2047*0`. The bit can be computed as a parity dot
  between ternary nonzero masks and activation low bits, without expanding signed
  trits. This is a proved representation alternative, not a measured speedup.
  Computing and transporting the side bit may cost more than it saves.

The proofs use Lean's standard logical axioms and no proof holes. The proof audit
is `research/Audit.lean`. None claims whole-program or hardware-wide optimality.

## Reproduce

From `research/ffn/batched/bench`:

```sh
make build/batch-bench
../hardware-run ./build/batch-bench \
  --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
  --rows 32,64,128,256 --iters 120 --rounds 20 --warmup 20 --ramp-ms 2000 \
  --seed 812735 \
  --candidate arith-iu8-a8,arith-iu4-a4,arith-paired-a4,hc-rowpair-a4-tt8-down1-rne,dfr-control-paired-a4-u1,dfr-defer8-paired-a4,dfr-certfixed1023-paired-a4,gs-shared1024-iu4-a4 \
  --json ../carrier-comparison/results/carriers-ramped-layer0.json
python3 paired_analysis.py ../carrier-comparison/results/carriers-ramped-layer0.json \
  --baseline dfr-control-paired-a4-u1 \
  --out ../carrier-comparison/results/carriers-ramped-layer0-vs-dfr-control-paired-a4-u1.json
```

Layer 10 uses `layer10` and seed 812736. For numerical comparison, select the
three grouped-scale candidates, add `--reference-candidate gs-shared1024-iu4-a4`,
and use `--rows 256 --iters 1 --rounds 1 --warmup 1 --ramp-ms 0`. Keep that file
separate from the performance runs.
