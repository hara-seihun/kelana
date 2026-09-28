# Keep independent codes; expose their error moment

The completed [selectivity diagnosis](../value-feedback-selectivity/README.md) distinguishes two operations that temporal feedback conflates: retaining information about cumulative quantization error, and changing later token errors to balance it. The frozen feedback reader's source-weighted boundary completion removes a genuine boundary term, but leaves those redistributed interior errors. A different complete state map can keep **every original independent K2/V2 code** unchanged and retain only a moment of the errors observed when V records are encoded.

This is an online quantization-error control variate, not a novel conservation principle. It is distinct from a trained source-range center, a new feedback coefficient, a different residual route, or another precision choice.

## Exact finite identity

For already quantized tokens i=1…m of one KV head, let `e_i=decoded_i-source_i`. Accumulate `s_m=sum(source_i-decoded_i)=-sum e_i`. Recent values remain original BF16. At a query with actual unchanged K2-cache probabilities p, let `P=sum_(i<=m) p_i`. The changed reader adds **`(P/m)*s_m`** to the ordinary mixed value, before the original summed-head O map. For m=0 it adds nothing. Then the quantized-value error is

```
sum_(i<=m) p_i e_i + (P/m) s_m
 = sum_(i<=m) (p_i-P/m) e_i.
```

Unlike feedback, this never changes the individual packed codes or propagates one token's error into another code. It removes the actual mean error on the encoded subset at read time. With implemented moment updates `s_(i+1)=s_i-e_i+d_i`, the exact identity retains the additional term `(P/m)*sum d_i`. Each Q head sharing a KV record uses its own P. Recent-value and K/source errors, all head O blocks and signed cross terms must remain in the complete error calculation.

[`Kelana/ValueErrorMoment.lean`](../../../Kelana/ValueErrorMoment.lean) proves the finite centered-weight identity, accumulation with explicit defects, changed-reader consequence and equal-weight cancellation. `mean_energy` also proves the unweighted energy identity `sum(e_i-mean(e))² = sum e_i² - m*mean(e)²`. Applied coordinatewise after any fixed linear O, ideal mean removal cannot increase this unweighted projected energy. The actual selective observer remains different. The module gives a strictly positive normalized two-token reversal: e=(1,0), p=(1/10,9/10). Original error1/10 becomes−2/5 under exact mean correction. Therefore neither zero uniform error nor retaining independent codes supplies a universal selective-quality guarantee. This abstract error/observer witness is not a source-model example. The formal identity leaves the coefficient parameterized; its application chooses the actual encoded mass divided by encoded count.

## Which query law actually guarantees a gain?

For a **fixed encoded prefix and fixed scalar errors**, let a finite query law have nonnegative weights μ, actual aged coefficients p, and aged mass P. Define `b_i=E_mu[P p_i]`, the row sums of the query coefficient second-moment matrix. The necessary and sufficient condition for nonincrease for **every arbitrary error vector** is **b_i=κ for every aged token**, not full exchangeability or independent query coefficients. If c is the exact unweighted error mean, then

```
E[(sum p_i e_i)^2] - E[(sum p_i(e_i-c))^2]
 = c² E[P²] >= 0.
```

[`Kelana/ValueMomentRisk.lean`](../../../Kelana/ValueMomentRisk.lean) derives this from actual finite sums: weighted Fubini gives `E[P sum p_i e_i]=sum b_i e_i`; a pointwise square expansion gives the exact risk change; balanced b and the actual mean yield the displayed identity and nonincrease. If the entire normalized row is encoded (P=1), uniform marginal expected attention is sufficient, regardless of correlations among token probabilities. With recent values excluded, the requirement involves the actual aged mass P, not merely each token's marginal probability.

The converse is constructive. If two legal coordinates have `d=b_i-b_j != 0`, put `A=E[P²]`, `lambda=-(A+1)/(2d)` and choose

```
e_k = 1 + lambda*1[k=i] - lambda*1[k=j].
```

Its exact mean is one, and `risk(e)-risk(e-1)=-1`: mean removal worsens squared response risk by exactly one. [`Kelana/ValueMomentRiskBoundary.lean`](../../../Kelana/ValueMomentRiskBoundary.lean) proves this witness and the full nonempty-prefix `universal_nonincrease_iff` theorem. The witness ranges over arbitrary rational errors; it is not asserted to lie on a particular source's quantizer grid. The sufficient theorem now requires balance only on legal prefix coordinates. Both integration Lean commands exited0.

This isolates the needed **observer law**, instead of assuming that unweighted cache error cancellation controls an arbitrary selective query. It is a rational finite scalar result for fixed error vectors; summing coordinates after a fixed single-head linear O is immediate, but distinct-head probability correlations, K/source baseline cross terms, implemented accumulator defects and changing-prefix distributions must still be retained for complete GQA risk. No balanced-law premise is claimed for the source data, and the completed output gains are measurements rather than consequences of this sufficient condition.

## One paid source contract before outcomes

The [completed fixed realization](../kivi-value-error-moment/README.md) uses original KIVI2 G32/R32 codes/fields, K and V after-query flush chronology, BF16 recent words and original source/teacher/O. Each V flush computes the actual FP32 stored-field decode, FP32 `source-decode`, and FP32 accumulator addition, once per coordinate. No target feedback or code reassignment occurs. At the query, compute the actual FP32 sum of probabilities over the m encoded positions, divide by FP32(m), multiply by the actual prequery FP32 moment, add to the ordinary mixed value, then apply original O. No trained coefficient or alternative grouping is selected.

Persistent state is4,096 B (eight128-coordinate FP32 accumulators), giving308,864 B logical peak /253,952 B final, exactly the temporal-feedback state allocation and768 B above original-code V34. The existing chronology supplies m; there is no index or per-token residual bank. At each V flush the state pays512 B read+512 B write per head plus128 decoded products/adds,128 error subtractions and128 accumulator additions. Each full query pays the probability-mass reduction over aged positions,16 scalar divisions,2,048 products/adds, and4,096 B moment reads if shared across the paired heads. Temporary decode/mixed vectors, original Q/K/V/O and source preparation remain separately charged.

Actual chronological moment images and all-phase checks are now retained:384 separate512B images cover all t128/t256/final head/window states; source, unchanged donor cache bytes and moment recurrence are independently replayed. Full contextual train/validation SSE falls209.016698→204.115581 and107.923584→104.977831; eight retained layer0 states fall.832657928→.608755. The moment beats the smaller V34 control by1.054%/1.418%/24.54% respectively at768B more state. Temporal feedback is stronger on layer0 and weaker contextually; higher-rate K2/V4 remains stronger in every pooled population. The outcome is not inferred from uniform cancellation: full-O error–delta inner products and delta² are explicit, with both heads and baseline errors retained.

No source projection, missing query regeneration or GPU execution was needed for those results. The [complete resident producer/reader](../kivi-value-moment-native/README.md) now passes4,096 device phases,16,384 exact moment checks and16 output guards. Actual pooled retained SSE.832657474839→.608754082474 matches the26.89% source gain, at4,096B extra active globals and1.122× slower median event time across32 matched empty-start flush-boundary pairs. Full phase/output/latency evidence, module resources and lifecycle are retained; this one realization stops without a placement ladder. A result in one panel cannot be promoted to a model-wide or latency gain.
