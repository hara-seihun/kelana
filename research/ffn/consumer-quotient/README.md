# Choose hidden codes for the consumer

The down projection observes `W v`, not the individual coordinates of hidden vector `v`.
We tested whether choosing low-bit codes jointly, rather than rounding each coordinate to
its nearest level, can preserve that observed result with fewer levels.

The answer splits in two. Expensive oracle search finds much better codes. The two cheaper
weight-prepared feedback maps tested here recover only a small part of that gain. None is a
measured inference speedup.

## The object being compared

Inputs are eight native rows from each of layers 0 and 10, captured under
`/path/to/workspace/data/kelana-ffn/ptq1_0/layerNN/r8`. We use the deployed hidden A8 codes and their
per-128 FP32 scales, so the target operand is exactly their decoded vector. `W` is the real
ternary down matrix with its original per-row per-128 FP16 scales. All output scores below
are relative RMS error in the **down projection**, not the residual or model logits.

A candidate keeps one scale per 128 hidden coordinates and chooses integer codes in
`[-L,L]`. L=1 is ternary, L=3 is seven levels, and L=7 is fifteen levels. Unless stated
otherwise the scale is the block maximum divided by L. These experiments do not narrow the
input to gate/up; they alter only the hidden operand consumed by down.

The eight tokens and the clip sweeps are exploratory samples, not held-out model-quality
acceptance. Source and input fingerprints are in the result records.

## Oracle capacity

[`discrepancy.py`](discrepancy.py) computes the target `Wv` and repeatedly uses the full
consumer gradient to propose code changes. Each token's complete update is accepted only
when it decreases actual squared projection error. A final full projection checks the
incrementally maintained residual.

After 128 iterations with unclipped scales:

| layer | code levels | independent rounding | joint oracle |
|---|---:|---:|---:|
| 0 | 3 | 29.19% | 18.07% |
| 0 | 7 | 9.25% | 5.87% |
| 0 | 15 | 3.95% | 1.85% |
| 10 | 3 | 63.59% | 21.41% |
| 10 | 7 | 22.17% | 7.08% |
| 10 | 15 | 9.43% | 3.03% |

The representation has room that nearest rounding misses. Seven-level codes chosen jointly
at layer 10 outperform independently rounded fifteen-level codes on these rows.

Longer search and a selected shorter quantizer step reach:

| layer | levels | scale / unclipped scale | iterations | initial | final |
|---|---:|---:|---:|---:|---:|
| 0 | 3 | 0.75 | 1024 | 20.25% | 5.71% |
| 0 | 7 | 0.75 | 1024 | 8.49% | 1.87% |
| 10 | 3 | 0.40 | 1024 | 38.76% | 9.61% |

These are achieved errors, not lower bounds or optima. The search can stall and its update
policy is not globally optimal. It also computes the answer it is trying to approximate,
then many additional projections. That is an oracle experiment, not a hidden online cost
we can declare free.

## A small prepared observer

[`sketch.py`](sketch.py) prepares a rank-r approximation of the consumer Gram matrix from
weights alone, plus a diagonal matching the remaining column norms. It chooses codes using
that approximate metric. No full target projection participates in selection or acceptance.
The full consumer is used only to report the resulting error.

The basis is a randomized weight-only singular subspace, with 16 oversamples and two power
iterations. It is not fitted to these eight activations. We tested ranks 8, 32 and 128, one
and four update iterations. The update includes backtracking when jointly proposed changes
increase the surrogate error.

At rank 128 and four iterations, the fifteen-level error changes from 3.953% to 3.897% at
layer 0 and 9.433% to 9.170% at layer 10. The oracle's factor-of-two to three gain does not
survive this cheap approximation of the observer. Sorting, feedback projections and
backtracking all remain input-dependent work; no native implementation was justified by
these results.

The [random-sketch follow-up](random-sketch/README.md) tests Gaussian and Rademacher
observers, independent acceptance sketches, refreshed pools and diagonal corrections.
A fixed observer can improve its own score while worsening the true output. Held-out
acceptance finds a small layer-0 ternary gain, but no improvement at 7 or 15 levels in
the tested grid. The [general discovery tools](../../discovery/README.md) connect this
to the proved requirement to capture off-diagonal correlations.

## Weight-prepared sequential feedback

[`feedback.py`](feedback.py) applies the inverse-Cholesky compensation idea from
[GPTQ/Optimal Brain Quantization](https://arxiv.org/abs/2210.17323) to changing activations.
Here the quadratic metric is `WᵀW`, rather than a calibration input covariance for static
weight quantization. We prepare a damped inverse-Cholesky factor for each fixed coordinate
block and use it to compensate later coordinates after rounding each value. The factor
uses only weights. Per-token per-128 quantizer scales stay dynamic and are charged online.

| layer | feedback block | levels | independent | feedback |
|---|---:|---:|---:|---:|
| 0 | 128 | 15 | 3.953% | 3.905% |
| 0 | 1024 | 15 | 3.953% | 3.704% |
| 0 | 1024 | 7 | 9.252% | 8.626% |
| 10 | 1024 | 15 | 9.433% | 8.854% |
| 10 | 1024 | 7 | 22.173% | 20.709% |

For a block of B coordinates, feedback requires `H*(B-1)/2` multiply-adds per token and a
sequential dependence through B rounding decisions. B=1024 adds about 10% of the down
projection's MAC count, before scheduling and traffic, for about 6–7% less error here.
Its prepared triangular FP32 coefficients occupy about 35.6 MB. This is a cost model, not a
GPU timing. The tested version is not an attractive route to a throughput gain.

## Proofs about what the observer permits

[`ObserverDescent.lean`](../../../Kelana/ObserverDescent.lean) checks exact integer statements:

- `observed_gain` gives the exact change in squared consumer error for a proposed code change.
- `coupled_gain` exposes the cross term between two changes. Two individually useful rounding
  decisions can be harmful together; the file gives a concrete counterexample.
- `approximate_observer_certificate` proves a true improvement when a surrogate's predicted
  gain exceeds twice a bound on its unseen error's correlation with the update.
- `nearest_source_codes_can_lose` gives two values of 0.49 on a unit grid. Rounding both to
  zero minimizes source error; choosing one as one and the other as zero increases source
  error but reduces the observed sum error by 49×.

The integer proofs apply to exact scaled arithmetic. They do not certify these floating
searches or infer a model-quality bound from projection RMS.

## A separate operand-rounding check

[`operand_rounding.py`](operand_rounding.py) supports the compact-scaled FP16 projection
experiment. It runs a complete CPU FFN with matched FP32 BLAS accumulation on both sides,
then changes only the activation operands to FP16. Every scaled ternary weight round-trips
through FP16 exactly. A8 integer codes and their block scales are retained at both boundaries.

Whole residual candidate-minus-control relative RMS is **0.01690% at layer 0 and 0.02291% at
layer 10**. This isolates a much smaller perturbation than switching activations to A4.
The CPU reference also reports its own discrepancy from the native engine. This experiment
does not simulate WMMA's internal accumulation or prove numerical transfer to a native
candidate. The native owner is `batched/compact-scaled/` when integrated.

[`ScaledTrit.lean`](../../../Kelana/ScaledTrit.lean) proves the exact sign/zero bit construction
for scaled ternary FP16 operands and the ideal-ring algebra for absorbing per-block scales
into the operands. [`ScaledTritCodec.lean`](../../../Kelana/ScaledTritCodec.lean) additionally
checks the native code assignment, byte spreading, selector interleave and scale-table selection
against the ISA byte-permute meaning. These proofs use kernel-checked bit extensionality, not a
native-decide axiom. Native floating reassociation and operand rounding are separate claims.

## Reproduce

From the repository root, with the installed Python/NumPy:

```sh
OPENBLAS_NUM_THREADS=8 python3 research/ffn/consumer-quotient/discrepancy.py \
  --steps 128 --levels 1 3 7 --clip 1.0 \
  --json research/ffn/consumer-quotient/results/layer0-unclipped.json
OPENBLAS_NUM_THREADS=8 python3 research/ffn/consumer-quotient/sketch.py \
  --basis research/ffn/consumer-quotient/build/layer0-basis.npy \
  --json research/ffn/consumer-quotient/results/sketch-layer0.json
OPENBLAS_NUM_THREADS=8 python3 research/ffn/consumer-quotient/feedback.py \
  --block 1024 --cache research/ffn/consumer-quotient/build/feedback0-1024.npy \
  --json research/ffn/consumer-quotient/results/feedback0-1024.json
OPENBLAS_NUM_THREADS=8 python3 research/ffn/consumer-quotient/operand_rounding.py \
  --json research/ffn/consumer-quotient/results/rounding0.json
```

Add `--layer layer10` and use distinct result/cache paths for the second layer. The result
JSONs retain settings and intermediate oracle histories. `build/` contains disposable
weight-prepared matrices; its metadata rejects a different weight image. Source and
results belong to Kelana. No services, clocks or GPU work are involved in these CPU studies.
