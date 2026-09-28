# Producer enclosure proofs

`Kelana/ProducerEnclosure.lean` is a Std-only interval calculus for proving that a source evaluator contains every producer output. It uses unbounded integers. A producer can have any input type and any output dimension `n`; vectors use `Fin n -> Int`, so none of the proofs enumerate a fixed width.

## Interval semantics

`Interval.Contains [l, u] x` means `l <= x` and `x <= u`. `Interval.Valid` means `l <= u`. Empty intervals are permitted in the basic type because they are useful as rejected analysis states, but the module does not use emptiness to prove producer containment. `Box.lowerCorner_mem` gives a concrete member of every valid finite-dimensional box.

The arithmetic rules are:

```text
[l1, u1] + [l2, u2] = [l1 + l2, u1 + u2]
[l1, u1] - [l2, u2] = [l1 - u2, u1 - l2]
[l1, u1] * [l2, u2] =
  [min(l1*l2, l1*u2, u1*l2, u1*u2),
   max(l1*l2, l1*u2, u1*l2, u1*u2)]
```

`add_contains`, `sub_contains`, and `mul_contains` prove these rules. The multiplication proof splits on operand signs and uses integer order lemmas. It does not assume that multiplication is monotone across negative values. `add_valid`, `sub_valid`, and `mul_valid` establish endpoint order.

## Rational-scaled meaning

A `ScaledInterval` stores valid numerator bounds and a strictly positive integer scale. It denotes

```text
[lower / scale, upper / scale].
```

`ContainsRatio interval numerator denominator` gives this meaning without depending on a rational-number library:

```text
0 < denominator
lower * denominator <= numerator * scale
numerator * scale <= upper * denominator.
```

`containsRatio_same_scale` proves that membership of `numerator / scale` is exactly ordinary numerator membership. `lower_mem` gives a concrete rational member of every `ScaledInterval`. Evaluators that keep a common scale can therefore run the integer rules directly. A rescale operation must prove its own cross-multiplied relation when scales differ.

## Affine product residual

`affineProductLinear ca cb a b` keeps the center and both first-order affine contributions:

```text
ca * cb + ca * b + cb * a.
```

`affineProduct_residual` proves the exact algebraic identity behind its error bound. Given

```text
valueA = ca + a + ra
valueB = cb + b + rb
|ra| <= Ra
|rb| <= Rb
|a + ra| <= Ta
|b + rb| <= Tb,
```

it proves

```text
|valueA * valueB - affineProductLinear ca cb a b|
  <= |ca| * Rb + |cb| * Ra + Ta * Tb.
```

The labels `a` and `b` can each be the sum of any number of shared generator contributions. The evaluator keeps their individual coefficients and uses the theorem on their aggregate value. The `Ta * Tb` term covers their nonlinear interaction and all interactions with the independent residuals. For common-scaled integer numerators, the result lives at the product scale. A later division or rescale remains a separate evaluator step.

This theorem is integer algebra. It makes no Taylor or real-analysis claim. A nonlinear affine model such as SiLU still needs an externally justified residual bound before the evaluator can instantiate an integer allowance.

## Rounding and approximate intrinsics

`Interval.mapMonotone_contains` proves endpoint propagation for any monotone integer rounding map. The caller supplies `IsMonotone round`. This covers floor, ceiling, clamping, and integer requantization once the evaluator proves that its chosen map is monotone on the modeled domain.

`ErrorAllowance` has separate downward and upward natural-number errors. `Within error exact observed` means

```text
exact - error.below <= observed <= exact + error.above.
```

`widen_contains` transports exact containment through this relation. `ApproximationContract exact implementation error` requires the relation for every intrinsic input. `maps_approximation` combines that local contract with an enclosure of the exact intrinsic.

For an approximate `exp`, the evaluator supplies two facts:

1. Its chosen exact or reference `exp` maps the input set into an exact output interval.
2. The implemented `exp` satisfies `ApproximationContract` with the stated integer-scaled error.

The theorem then widens the exact interval. No theorem assumes containment of the final producer output. Approximate add, multiply, reciprocal, activation, or conversion instructions use the same local contract. Exact mathematical integer add, subtract, and multiply use the proved interval rules instead.

## Composition and arbitrary dimensions

`Interval.Maps operation source target` is the scalar mapping judgment. `Interval.Maps.comp` composes two such judgments.

For vectors, `Box.Maps operation source target` means every vector in the source box maps into the target box. `Box.Maps.comp` composes transformations of dimensions `a -> b -> c`. `Contained producer box` means every producer output is in `box`, and `Contained.map` transports containment through any sound box transformation. These theorems quantify over dimensions and producer inputs. They do not perform finite case enumeration.

A source evaluator can prove one `Box.Maps` fact per expression node, compose them along the expression graph, and apply `Contained.map` at the producer boundary.

## Paired Hadamard butterfly

`ButterflyEnclosure.ofInputs` computes separate enclosures for

```text
sum = x + y
difference = x - y.
```

It widens each result by an independent `ErrorAllowance`. `ButterflyEnclosure.contains_ofInputs` proves paired containment from input containment and the two local rounding relations. The sum and difference remain correlated at the evaluator level because one theorem handles the pair, although the returned enclosure is the rectangular projection needed by ordinary interval propagation.

This theorem models an unscaled Hadamard butterfly. A division by two, saturation, cast, or lane-specific rounding after the butterfly is another transformation and must use the rounding or division API.

## Dynamic quantization division

`DivisionWithin error numerator denominator quotient` is the cross-product contract

```text
numerator - error.below <= quotient * denominator
quotient * denominator <= numerator + error.above.
```

The error is measured in numerator units after multiplication by the runtime denominator. This supports exact division, truncation with a bounded remainder, rounded division, and approximate reciprocal implementations without fixing one division convention in the proof library.

`division_contains` requires:

- numerator and denominator interval membership;
- `0 < denominators.lower`;
- the local `DivisionWithin` fact;
- a lower quotient certificate;
- an upper quotient certificate.

The endpoint certificates are:

```text
upper(singleton(lower) * denominators)
  <= numerators.lower - error.below

numerators.upper + error.above
  <= lower(singleton(upper) * denominators).
```

The four-endpoint product rule handles the sign of each candidate quotient. The proof derives

```text
lower * denominator <= quotient * denominator
quotient * denominator <= upper * denominator
```

and cancels the actual positive denominator. The certificates are plain integer comparisons, so a source evaluator can compute them and replay the theorem even when the quantization denominator depends on runtime data.

## Evaluator-specific obligations

The Lean file proves interval algebra and composition. The evaluator still owns these source-specific facts:

- the translation of source values into unbounded integer numerators and positive scales;
- input ranges and validity of each initial box;
- the exact evaluation order, including every cast, clamp, saturation, and rescale;
- absence of machine overflow, or a separate model of wrapping or saturating arithmetic;
- local monotonicity of each rounding map used with `mapMonotone_contains`;
- local error contracts for approximate arithmetic and `exp`;
- any Taylor, derivative, or real nonlinear-model residual used before conversion to an integer allowance;
- `DivisionWithin` and both endpoint certificates for dynamic division;
- the link between the evaluator's expression semantics and each composed `Box.Maps` judgment.

The model has no IEEE NaN, infinity, signed zero, subnormal, or exception semantics. If the source can produce them, the evaluator must exclude them by a proved precondition or add them to its value type. The module also does not prove analytic bounds for real exponential or reciprocal functions. Such bounds enter only at the intrinsic node where they are needed.

All reported declarations elaborate with Lean 4.33 and import only `Std`. The final `#print axioms` checks show no `sorryAx`; `propext` and `Quot.sound` are Lean kernel axioms used by library order machinery.
