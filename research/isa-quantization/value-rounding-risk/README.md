# Independent grid rounding: an exact full-observer risk floor

The completed [error-moment program](../kivi-value-error-moment/README.md) corrects a mean while preserving independent deterministic codes. Its [sharp query-law boundary](../kivi-value-error-feedback/MOMENT.md) explains why mean removal need not improve a selective response. A different premise changes the code law itself: remove interior rounding bias through independent randomized code assignment, without a carried residual or a trained response metric.

These are standard unbiased-rounding and bias–variance facts applied to the actual shared-KV observer, not a novelty claim. The useful discriminator is an **analytic minimum over the entire independent clipped-unbiased class** at fixed decoded levels. No seed sweep is needed.

## Fixed decoded grid and law

For one source coordinate v, fix the original stored FP16 low/step fields. Its four permitted numerical levels are the actual source reader's separately rounded FP32 product and sum for digits0…3, not an ideal unrounded affine grid. Set x to v clipped to the decoded endpoints. If x is between distinct adjacent levels l<h, choose h with exact probability `(x-l)/(h-l)` and l otherwise. Endpoint values are deterministic; repeated levels use a canonical digit. Draws belong to token-coordinate flush events and are independent across those events. Both Q heads sharing a KV value read **the same draw**. Codes persist across future queries.

This defines an ideal rational probability law: BF16/FP16/FP32 source and decoded numbers are dyadic rationals, while the probability need not itself be a representable FP32 number. A practical PRNG, threshold rounding, seed/state cost and draw work would require a separate implementation contract. The analytic law is not a delivered paid random cache.

The exact mean is x and variance is `(x-l)(h-x)`. Clipping leaves deterministic bias `x-v`; it is not discarded under the word unbiased.

## Complete output, including both heads

Condition on a fixed source, unchanged K cache, fixed attention probabilities and original O. For a value-coordinate event i=(KV head, token, channel), define its full output coefficient

```
a_i = sum_(Q heads h sharing that KV) p[h,token] * O_h[:,channel].
```

Let b be **mean complete output minus teacher**, including K/source error, recent deterministic values and endpoint bias. Centered independent code noise has zero cross-coordinate covariance, hence

```
E ||output - teacher||² = ||b||² + sum_i Var_i * ||a_i||².
```

It is wrong to square each head coefficient separately: the cross-head O term is present because both heads share the code. With two heads, the coefficient energy uses only the three per-channel O-column Gram fields `||O0||²`, `<O0,O1>` and `||O1||²`, weighted by `p0²`, `2p0p1`, `p1²`. This avoids materializing an output vector per token-coordinate while preserving the exact linear map.

Reusing a code across queries correlates their errors. That does not alter the sum of their expected squared errors; it matters if one asks for concentration or joint distributions, neither of which is claimed here. For a candidate autoregressive rollout, Q/K/source can depend on earlier random choices and the fixed-observer conditioning must be revisited. Current teacher-forced source tests do not establish that rollout result.

## Why adjacent interpolation is a family minimum

Take any law supported on the same ordered grid, with mean x in adjacent interval[l,h]. Every allowed outcome Y satisfies `Y<=l` or `Y>=h`, so

```
E[(Y-x)²] = (x-l)(h-x) + E[(Y-l)(Y-h)]
          >= (x-l)(h-x).
```

Adjacent interpolation attains equality. At an extreme endpoint, maintaining that mean forces an endpoint output. Therefore the displayed complete-output risk is the minimum for **all coordinate-independent laws with these clipped coordinate means and these fixed decoded levels**. A negative source result against deterministic rounding would reject that class at the same fixed ideal linear readout, not merely one random realization. Correlated code choices, changed fields, changed means, additional state and changed key/query maps are outside this class.

The variance weights are nonnegative actual squared full-output coefficients. This makes coordinatewise minimum variance sufficient for the complete risk minimum even when head correlations in O are nonzero. It does not say the best deterministic code vector has greater error: that vector is generally biased coordinatewise and is outside this class.

## Lean custody

[`Kelana/ValueRoundingRisk.lean`](../../../Kelana/ValueRoundingRisk.lean) proves:

- valid adjacent probabilities, exact mean and variance;
- the actual finite variance-gap identity and adjacent minimum under grid support;
- finite centered-response expectation zero;
- exact affine bias–variance with deterministic baseline retained;
- diagonal covariance contraction through the existing full output Gram;
- coordinatewise variance lower bounds imply the complete-output lower bound;
- zero cross moment for the two-coordinate independent Bernoulli marginal, and the shared-head coefficient expansion.

It reuses [`SharedSketchCovariance`](../../../Kelana/SharedSketchCovariance.lean)'s finite Gram/Fubini machinery. The exported summation helpers are unchanged proofs, not new assumptions. The general risk theorem takes the exact zero-mean/diagonal-second-moment premises; it does not formalize a pseudorandom generator or an entire N-coordinate product sampler. Nonnegative normalized probabilities and support are explicit in the variance-minimum theorem. Direct `lake env lean Kelana/ValueRoundingRisk.lean` exits0.

## Completed source discriminator

The [immutable source screen](../kivi-value-rounding-risk/README.md) evaluates this minimum mean-risk plus variance from original KIVI2 fields on all3,072 owned contextual queries and eight retained layer0 states. Train expected SSE is249.765157 versus deterministic209.016696; inspected validation127.760254 versus107.923582. Better means156.152406/76.951085 do not compensate for variance93.612750/50.809169. Thus the contextual numerical minimum is worse by19.50%/18.38% at the same ideal fixed readout, excluding an advantage for any independent law with the same means/grids there. The eight layer0 queries reverse: expected.516749 versus deterministic.832658,7/8 improve. This is not all-source rejection.

Every query retains mean-risk, variance, clipping and deterministic FP64/owner-FP32 differences; direct summed-head covariance agrees with the efficient Gram contraction within2.78e−17. Those are numerical source evaluations of the exact law, not formal interval bounds or implemented random-code outputs. The complete source/chronology hashes and law are owned by the source report. No RNG, paid image, source forward or GPU experiment was performed; there is no seed search to continue.
