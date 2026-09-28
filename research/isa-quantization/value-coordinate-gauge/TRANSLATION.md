# Additive value coordinates and an exact range certificate

A fixed value translation is different from changing the value quantizer's bit count, rotating its coordinates, or minimizing a separate O-weighted squared residual. Normalized attention permits its correction to move through all token contractions to a single query-independent output bias. Whether this helps the actual finite cache is a separate question; a range optimum is not an output-error optimum.

## The constant correction belongs after the observer

For a shared KV group with center c and consuming head blocks O_h, set `v'_i=v_i-c`. For every probability row with sum one,

```
sum_h O_h sum_i p_hi v'_i + sum_h O_h c
    = sum_h O_h sum_i p_hi v_i.
```

Apply this per KV group and add the groups. The correction `b=sum_h O_h c_group(h)` depends on source O and stored centers, not the query, position or attention probabilities. Thus a consumer can use centered values directly, without reconstructing uncentered values per token. `Kelana/ValueCoordinateGauge.lean` proves `headOutput_constant` and `value_translation_transport` over finite rational arrays. This requires normalized rows: arbitrary unnormalized moment accumulators need their denominator/mass treatment instead.

For the current eight128D KV heads, an FP16 center would occupy2,048B; a prepared1,024D FP32 complete-O correction would occupy4,096B, shared per model layer. Subtracting1,024 center coordinates on each arriving V and adding1,024 bias coordinates per output are online work. Deriving the bias from common source O has preparation work and scratch. These fields are not free because they are smaller than the source weights. Replacing an existing projection bias could change that ledger only if such a field and consumer actually exist; the source V projection here has no bias.

An exact source identity does not make `BF16(v-c)+c` equal the original BF16 v. Storing centered recent values, rounding affine fields, and changing softmax/O reductions each require their own comparison. In particular, the original full teacher and the source-only centered/uncentered discrepancy must remain distinct from quantized error.

## Translate a whole finite source, not one token

Fix one existing group of D channels and finite source vectors v_s. Define the directed pair matrix

```
A_de = max_s (v_sd - v_se).
```

The worst centered within-token range is

```
R(c) = max_s [max_d(v_sd-c_d) - min_e(v_se-c_e)]
     = max_de (A_de-c_d+c_e).
```

Hence `R(c)<=R` is exactly the finite difference-potential system

```
c_d-c_e >= A_de-R       for every d,e.                 (1)
```

The source maxima must be checked from source bytes; this is not a free diagonal statistic or an assumed upper bound. `ValueRangeTranslation.source_range_upper` proves one direction from pairwise upper bounds, and `source_range_converse` proves the converse when each pair bound is attained by a source row. No probabilistic source law is required.

## Global optimum: feasible potential plus balanced flow

Take nonnegative edge masses B_de with total mass one and equal incoming/outgoing mass at every channel. For any feasible c,R, multiply(1) by B_de and sum. All center terms cancel, giving

```
R >= sum_de B_de A_de.                                (2)
```

A directed cycle is a concrete certificate: assign mass1/length to each traversed edge, counting multiplicity. Its lower bound is its mean A-weight. If a supplied center is feasible at exactly that mean, it is globally optimal among all centers. The independent checker need not trust the optimizer, its termination message or a floating gradient.

`Kelana/ValueRangeTranslation.lean` reuses the already proved finite balanced-potential cancellation in `CoupledGaugeCost.lean`. `balanced_lower_bound` and `optimality_certificate` prove(2) and global sufficiency over exact rational fields; no desired optimality or cycle inequality is assumed. The cycle's closedness, mass and balance are obligations of its finite witness/checker. Real centers obey the same analytic finite-sum bound, but the kernel-checked API is rational.

The constructive difference-constraints characterization is classical: interpret `A_de-R` as edge weight from e to d. Any cycle with positive sum prevents feasibility. If every cycle has nonpositive sum, removing cycles cannot decrease a path's weight, so longest paths from a zero-weight supersource need at most D-1 edges and supply feasible potentials. Therefore the optimum is the maximum directed cycle mean. A deterministic Karp dynamic program can propose that value; exact feasible potentials plus a matching cycle are the acceptance certificate. Optimizer implementation/existence and finite machine cost are separate from the proved sufficiency theorem.

## Gauge choice and stored-center rounding

Adding the same scalar to every center coordinate in a group leaves(1) unchanged. A deterministic canonical representative may subtract the midpoint of the smallest/largest center coordinates. This fixes a storage gauge, not a second fit.

If stored center c' has coordinate error at most eps, then

```
R(c') <= R(c) + 2 eps.                                (3)
```

`common_shift` and `rounded_range` prove these rational statements. A real FP16 image must still be decoded and its actual per-coordinate error and source ranges checked; representability is not assumed. Equation(3) concerns the *source range before further storage rounding*, not min/max code selection, aggregate O error or native latency.

The [range-gauge study](../value-range-gauge/README.md) already gives a counterexample where improving a robust range/error envelope worsens realized output loss. Here too, a tight globally optimal proxy can fail the actual observer. The appropriate next discriminator is a single frozen paid center plus the unchanged source/K/quantizer chronology, not repeated center choices after seeing held outputs.

## Why preserving every individual source range can forbid any change

There is a stronger constraint than minimizing the single worst range. Suppose a center must avoid increasing the range of **every** source vector separately. Whenever source s attains its minimum at e and maximum at d, that requirement implies

```
(v_sd-c_d)-(v_se-c_e) <= v_sd-v_se  =>  c_e <= c_d.
```

Make an edge e→d witnessed by that actual source row. Along any path the centers must be nondecreasing; two-way reachability forces equality. Therefore an entire strongly connected group permits only a common scalar center if every original range must remain no worse. Such a scalar leaves all within-group pair differences and ranges unchanged. This does not say that arbitrary nonconstant shifts are useless: they can lower a worst case or average loss while worsening some rows. Nor does it exclude FP16 origin-rounding effects of a common shift.

`source_edge_monotone`, `reach_monotone` and `mutual_source_forces_equal` in `ValueRangeTranslation.lean` prove the finite rational implication for explicit source witnesses and paths. The [source owner](../value-range-translation/README.md#source-extremum-connectivity) supplies inward/outward trees for **28 of32** complete groups, with actual BF16 extrema rows. Each tree can be checked without trusting a strongly-connected-component solver. This explains a structural limit on a universal no-worse-range requirement, not a theorem about the quantized output or all possible source distributions.

## Reproduce the foundation

```
lake build Kelana.CoupledGaugeCost
lake env lean Kelana/ValueCoordinateGauge.lean
lake env lean Kelana/ValueRangeTranslation.lean
```

All three direct commands completed successfully. The [source-only instance](../value-range-translation/README.md) now certifies all32 original groups, with exact critical cycles and a2,048B FP16 center. Largest train range falls2.587891→1.677734, while mean range rises.616681→.684183. That opposite movement is why the globally optimal source proxy is not a consumer conclusion. A separate frozen paid consumer is required. This document supplies mathematical and cost obligations, not a quantized candidate, native result or new quantization-method claim.
