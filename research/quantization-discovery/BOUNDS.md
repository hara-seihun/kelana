# Bounds used by the additive search

`Kelana/QuantizationBounds.lean` proves the arithmetic behind the lower bounds in `search.py`. It imports `Std` only.

## Interval and residue suffixes

For a probe `a`, the Python search first projects every vector option to the integer `a · response`. Each block records four scalar values:

```text
lower, upper, base, step
```

`ScalarBound.Holds` means that a projected option lies in `[lower, upper]` and in `base + step * Z`. `ScalarBound.holds_of_dvd_sub` reduces the residue check to

```lean
step ∣ value - base
```

This is the fact supplied by a gcd of the block's option differences. The Lean module does not compute that gcd.

`BoundedTerm commonStep` packages one selected projected option. It records the local scalar bound and a proof that `commonStep` divides the local step. For a list of any finite length, `sum_bounds` proves

```lean
sumLowers terms ≤ sumValues terms
sumValues terms ≤ sumUppers terms
InResidue (sumValues terms) (sumBases terms) commonStep
```

The last statement is the affine class

```text
sumBases + commonStep * Z.
```

The proof repeatedly applies `inResidue_add`. A zero step has the intended singleton meaning. This matches the suffix recurrence in `Bounds.__init__`: endpoints add, bases add, and the new gcd divides each local option-difference step.

The caller still proves that a chosen response comes from each block and constructs its `BoundedTerm`. No theorem assumes that the candidate family itself is finite. Only the concrete suffix list is finite.

## Projection error

`projectionError` sums `coefficient * coordinateError` over a finite list of integer pairs. `probeNorm` sums the absolute coefficient values.

`projectionError_le` proves

```lean
|sum_i coefficient_i * error_i| ≤
  (sum_i |coefficient_i|) * E
```

when every `|error_i| ≤ E`. The proof uses `Int.natAbs_add_le` and `Int.natAbs_mul`.

`ceilDiv distance norm` is `(distance + norm - 1) / norm`. Given a proved lower bound

```lean
distance ≤ |projectionError terms|
```

and a positive probe norm, `projectedDistance_lower_bound` proves

```lean
ceilDiv distance (probeNorm terms) ≤ E.
```

This is the justification for `(delta + norm - 1) // norm` in `Bounds.lower`. The runtime checker must prove that `delta` is a lower bound on distance to the interval and residue intersection. The nearest-progression algorithm itself is outside the Lean module.

## Signed min-sum dual bound

The real-valued interval relaxation can ignore the coupling between option cost and approximation error. `signedMinSumDual` provides the arithmetic core for the stronger integer min-sum bound.

Its inputs are integers `q`, `paid`, selected suffix cost `C`, error price `lambda`, prefix projection `p`, selected suffix projection `S`, precomputed minimum sum `M`, and error `E`. From

```lean
M ≤ q * C + lambda * S
p + S ≤ q * E
0 ≤ lambda
```

it proves

```lean
q * paid + lambda * p + M ≤
  q * (paid + C + lambda * E).
```

For each block, selecting the actual option shows that the block minimum is at most `q * optionCost + lambda * optionProjection`; adding those inequalities supplies the first premise. The one-sided probe estimate supplies the second. Run the construction for signed probes as needed. Positivity of `q` and conversion of the integer numerator to a `Nat` objective lower bound belong to the certificate generator, since they depend on its chosen scaling and division convention.

## Connection to the anytime certificate

A search certificate can use these theorems to discharge `QuantizationCertificates.RegionBounds.sound`:

1. prove each option's local interval and difference-divisibility facts;
2. apply `sum_bounds` to the unresolved suffix;
3. prove the reported scalar distance lower bound;
4. apply `projectedDistance_lower_bound`, or use `signedMinSumDual` for the coupled cost bound;
5. add the already-paid cost, minimum remaining storage and work costs, and the priced error lower bound.

The Python certificate generator remains responsible for replayable min, max, gcd, progression-distance, and signed block-minimum calculations. This Lean file proves the generic arithmetic those checks feed.
