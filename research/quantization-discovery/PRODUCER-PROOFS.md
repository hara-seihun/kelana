# Correlated producer-domain proofs

`Kelana/ProducerDomain.lean` formalizes an affine generated integer domain in arbitrary finite dimension. It imports only `Std`.

## Domain model

A vector is `Nat -> Int`. A `Generator` contains a vector and a natural-number radius. For a center `c`, generators `g_j`, and integer coefficients `z_j`, `realize` denotes

```text
x_i = c_i + sum_j (g_j)_i * z_j.
```

`CoefficientsBounded` requires one coefficient per generator and proves

```text
|z_j| <= radius_j.
```

`InDomain c generators x` packages the coefficients, their bounds, and the equality with `realize`. A coordinate residual is an ordinary generator whose vector is a scaled standard basis vector. It needs no separate case in the theorem.

The dot product takes an explicit `dimension`, so every result applies to any finite dimension without encoding a fixed width in a type.

## Projection bridge

The scalar coefficient of generator `g_j` is defined from the vectors:

```lean
projectedCoefficient dimension row g_j =
  dot dimension row g_j.vector
```

It is not an input assumption. `dot_offset` proves

```text
row . sum_j (g_j * z_j) =
  sum_j ((row . g_j) * z_j),
```

and `dot_realize` adds the center term. These two lemmas are the bridge an experiment can use when its domain builder works with full producer vectors but its search uses scalar row projections.

## Exact support and attainment

`supportRadius` is

```text
sum_j radius_j * |row . g_j|.
```

`projectedOffset_le` proves the triangle-inequality upper bound for every bounded coefficient list. `domain_upper` then proves

```text
|row . x| <= |row . center| +
  sum_j radius_j * |row . g_j|
```

for every `x` in the domain.

`exact_support` proves more than the bound. Its second conjunct constructs a domain member attaining equality. The proof uses the coefficient sign matching each projected generator when the center projection is nonnegative, and the opposite signs when it is negative. Zero projected generators and zero radii are covered directly. Thus the displayed bound is the exact maximum over the integer domain, not the relaxation to a real box.

## Transport to a producer

For a producer `producer : Input -> Vector`, `Contained producer center generators` means every actual output belongs to the domain. `contained_upper` transports the support formula to every producer input:

```text
Contained producer center generators ->
|row . producer(input)| <=
  |row . center| + supportRadius dimension row generators.
```

Containment need not be exact. An enclosing domain gives a sound upper bound even when its attaining corner is not an actual producer output.

## Producer-null directions

`ProducerNull dimension producer d` means

```text
d . producer(input) = 0
```

for every input. `equivalent_iff_difference_null` proves the exact quotient relation:

```text
row1 - row2 is producer-null
  iff
row1 . producer(input) = row2 . producer(input) for every input.
```

`natAbs_eq_of_difference_null` then proves equality of the absolute row error on every producer output. Any maximum, threshold test, or cost computed only from those absolute errors can therefore search row errors modulo producer-null directions without changing the producer objective. This quotient is about the real producer, not the enclosing domain, so an over-approximate domain may assign different support values to two rows that are still equivalent on all actual outputs.

## Search API

A correlated-domain search can use the module in this order:

1. Build the center and generator vectors from producer analysis.
2. Prove `Contained` once for the producer family.
3. For each candidate error row, compute `projectedCoefficient` for each generator.
4. Use `contained_upper` for a certified producer bound.
5. Use `exact_support` when the generated domain itself is the optimization set and an attaining point is needed.
6. Identify candidate rows with `equivalent_iff_difference_null` when producer analysis proves their difference null.

The formalization assumes independent coefficient intervals. Correlation is carried by shared full-vector generators: one coefficient moves all coordinates of a generator together. Extra relations between coefficients require a smaller domain theorem. Dropping such relations remains a sound enclosure through `contained_upper`, but may lose exactness for the real producer.

## Signed rational dual certificates

The same module contains the generic arithmetic for replaying signed-probe lower bounds on

```text
static + sum_block optionCost +
  lambda * sum_j |sum_block optionFactor_j|.
```

`l1 dimension factors` is the final sum of absolute factor values. A probe is an integer vector representing the rational values `p_j / Q`. `ProbeBounded dimension Q probe` states `|p_j| <= Q` for each active coordinate.

`probe_dot_natAbs_le` and `signedL1Projection_le` prove

```text
|sum_j p_j * factor_j| <= Q * sum_j |factor_j|

sum_j p_j * factor_j <= Q * sum_j |factor_j|.
```

The proof works for arbitrary dimension and does not depend on how an LP found the probe.

A `BlockChoice` records one selected option's cost and its contribution to every shared factor. `ScoresLowerBound` records one replayed inequality per selected block:

```text
minimum_b <=
  Q * optionCost_b + lambda * sum_j p_j * optionFactor_bj.
```

The checker establishes this inequality for every option in a block. It can then instantiate `ScoresLowerBound` for whichever option a candidate solution selects.

`separableDual_lower` sums the block inequalities, proves that the signed projections distribute through the summed factor vector, and applies `signedL1Projection_le`. Its result is the cleared bound

```text
Q * static + sum_b minimum_b <=
Q * (static + sum_b optionCost_b +
     lambda * sum_j |sum_b optionFactor_bj|).
```

`separableDual_ceiling_lower` converts that result to the executable certificate formula

```text
ceil((Q * static + sum_b minimum_b) / Q) <= robustObjective.
```

The ceiling theorem requires `Q > 0` and a nonnegative replayed numerator. The latter holds for the current certificate and keeps conversion to a natural-number objective explicit. The LP output itself is only a proposal. Globality within a fixed option family comes from replaying every per-option inequality and then applying these theorems.
