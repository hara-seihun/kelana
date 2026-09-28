# Reciprocal RoPE-pair gains: a cheap exact gauge before approximation

Key translation removes a common mean, but it does not balance a large key variance against a small query variance. There is another exact coordinate freedom at the actual Qwen attention boundary: learned Q/K gains occur **after** their RMS normalization. Reciprocal paired gains preserve the complete attention map without transporting any norm metric.

## Prior art and the present question

[Programme 12's maximal-gauge theorem](https://lemma.ing/dev/programmes/12) (`canon/rope-gauge-maximal/`, main `ead6f3c`) proves that this reciprocal per-pair family is **all** the exact full-span rotary-attention gauges realizable by replacing only the existing nonzero diagonal post-normalization gamma fields, even if the target is softmax probabilities rather than individual logits. General pair rotations require a changed reader or transported norm; pre-RoPE key shifts cannot be silently discarded, whereas an actual shared post-RoPE shift is a separate softmax gauge. Its Lean core and precise producer/rank assumptions live in programme canon; this source experiment's quality and byte receipts below are unchanged.

The reciprocal score gauge and equal-scale RoPE-pair constraint are **not new**: [QServe's SmoothAttention, §IV-B, equations7–9](https://arxiv.org/html/2405.04532v1#S4.SS2) uses both, with key-max scaling and folding into preceding Q/K projection weights. Here the actual source has Q/K normalization between projection and RoPE, so the exact cheap fold is into its existing **post-normalization gamma** fields, not arbitrary pre-normalization projection scaling. The contribution of this study is the explicit positive-feature covariance objective, dyadic representability/cost boundary, finite rational proofs and paid source experiment—not discovery of reciprocal attention scaling or a new quantization method.

## Exact source law and custody

Write a source head as

```
q_i = R_i Gamma_Q N_epsilon(W_Q x_i),
k_j = R_j Gamma_K N_epsilon(W_K x_j),
score_ij = q_i dot k_j / sqrt(d).
```

Let L have a positive scalar lambda_a on both coordinates of each RoPE plane `(a,a+d/2)`. It commutes with every R_i and is symmetric. Replacing

```
Gamma_Q' = L Gamma_Q,    Gamma_K' = L^-1 Gamma_K
```

gives `q_i'=L q_i`, `k_j'=L^-1 k_j` and exactly the same score for **every** pair of positions, hence the same causal probabilities and V/O response. Epsilon and the pre-gamma normalization are unchanged. The same L must serve all query heads sharing a key head. When Q/K gamma are globally shared, applying the same L globally preserves every such group in ideal arithmetic; choosing it from only one group's producer law is not an optimality claim for the others.

This differs from changing the coordinates **before** RMSNorm, which requires a transported metric, and from arbitrary rotations that fail to commute with RoPE. Source Q/K intermediate coordinates change, but the complete observer does not require their old labels. Existing gamma fields can carry the transformation: no additional inference multiplication or scale-index field is necessary if the replacement gains are in the original stored format. A general real lambda usually needs rounding. For `lambda_a=2^e_a`, a BF16 field changes only exponent when representable; source-field exactness, activation/product range and actual numerical score equality must still be checked separately. The algebra is not permission to ignore underflow, overflow, altered accumulation order or a live cache in the old coordinates.

## Choose a coordinate by a declared source objective

Use the positive-feature scaled source coordinates `u=q/d^(1/4)`, `v=k/d^(1/4)` and a declared pair law mu (the same law for all terms). Its means and covariances are `mu_u,mu_v,C_u,C_v,C_uv`. After reciprocal L and an optimal shared key translation

```
c_L = E(Lu+L^-1 v),
```

the mean Gaussian positive-feature variance exponent is

```
E ||Lu+L^-1 v-c_L||²
 = tr(L² C_u) + tr(L^-2 C_v) + 2 tr(C_uv)
 = sum_a [ a_a lambda_a² + b_a/lambda_a² ] + 2 tr(C_uv),       (1)
```

where a_a and b_a are the traces of the two-coordinate query/key covariance blocks for RoPE pair a. The cross-covariance trace is invariant: each matching-coordinate product receives reciprocal scales. This objective is exactly the **mean log(1+r relativeVariance)** from [positive-kernel-gauge](../positive-kernel-gauge/README.md), not mean variance or final output error.

For positive a,b, the continuous optimum is `lambda*=(b/a)^(1/4)`, with minimum `2 sqrt(ab)`. Powers of two give a discrete optimum without a gain sweep: evaluate the floor and ceiling of `e*=(1/4) log2(b/a)` and choose the smaller `a 4^e+b 4^-e` (fixed lower-e tie). At a nearest exponent the squared ratio `r=(lambda/lambda*)²` lies in `[1/2,2]`, so

```
a lambda²+b/lambda² = sqrt(ab)(r+1/r) <= (5/2)sqrt(ab).
```

Thus rounding adds at most25% to the **positive a/b part**. It does not give a25% ratio bound on total (1): the invariant cross term can be negative and nearly cancel the continuous minimum. A valid total bound is additive excess at most `(1/2) sum_a sqrt(a_a b_a)`. Zero variances require a separate feasible exponent/range rule; taking a logarithm of zero or silently clipping is not the theorem.

`Kelana/ReciprocalAttentionGauge.lean` is the finite rational foundation: reciprocal dot cancellation, commutation with a two-coordinate rotation, gain folding and the conditional quadratic/rounding inequalities. Real logarithmic exponent selection, empirical covariance estimation, BF16 representation and complete machine arithmetic are separate obligations.

A full non-diagonal reciprocal map could lower the same surrogate further, but then it generally does not commute with RoPE or fit in existing gain fields. Its matrix data and online operations are not supplied by (1). The paired family is interesting precisely because its exact source realization is cheap and explicit.

## A fixed exact toy and strong reader

The witness uses scalar query labels `u=±1/4`, key labels `v=±4` and values0/1. The exact teacher output after the two keys is `sigmoid(8u)`. Both means are zero, so translation alone cannot remove its imbalance. Query/key variances are `a=1/16,b=16`; the exact dyadic optimizer lambda4 gives balanced coordinates `±1,±1` and changes mean exponent **257/16→2**, preserving every source score. Actual BF16 source gain fields `(1/4,4)` and replacement `(1,1)` each cost four bytes. The coordinate change is carried by replacement fields, not an unpaid extra scale.

A fixed two-feature positive reader `omega=(-1,+1)` is evaluated before and after this source gauge without changing its feature table. Its final scalar absolute error changes from **.25841988 to .09078425** for both queries, while the exact target does not. `witness.py` independently reads both actual four-byte BF16 gain images and checks all scores and exponent means as rational numbers; finite exponential outputs are FP64 diagnostics. No seed/feature-count search is used. A direct `sigmoid(8u)` reader is an exact and stronger control on this deliberately simple family; the witness does not claim a frontier win. Its purpose is to show that centering and reciprocal balancing address different representation freedoms, with a complete paid route for the latter.

## Comparison obligations

A source-preserving gauge is available to competing programs too. Full-precision attention is invariant. Ideal per-channel affine key quantization is equivariant to positive per-channel scales when origin/step scale with the channel, while per-token quantization generally is not. Finite scale/min fields and recent cache rounding may break exact numerical equivariance. The named asymmetric cache control must not be treated as frozen in a needlessly unfavorable coordinate system merely to favor the feature approximation. Weight-only Q/K quantization followed by reciprocally changed gamma also preserves its own candidate scores; the gauge does not magically improve that distinct error source.

The [real-source study](../qwen-balanced-gamma/README.md) now exports an actual **512-byte replacement BF16 gamma image**, with 12 of64 RoPE pairs changed and exponents from−2 to3. Every field rescales exactly. All eight train/four inspected-held windows have **bitwise identical** causal scores, probabilities, both head outputs and their combined O response under the canonical CPU observer. After a newly train-defined centroid, mean exponent falls **395.244→51.056 train**, **429.194→52.885 held**. This is an exact captured coordinate change and surrogate improvement; its reader result is a separate measurement.

The completed [centering-only reader](../qwen-centered-positive-kernel/README.md) already shows why a surrogate is insufficient: KL improves while complete O error worsens. The [named causal KIVI control](../kivi-causal-cache/README.md) is far stronger than the initial per-token cache: held pair-O relative squared error **.000155355** at **52,400B** peak cache state. The single [balanced-and-centered feature reader](../qwen-balanced-feature-reader/README.md) now faces that comparison: at49,920B table+center+state, held pair-O error improves to **1.09345** but remains far behind KIVI and the initial scalar caches. No seed/rank/fit ladder follows. Shared model fields, center bytes, cached labels and preparation remain part of the frontier.

```sh
python3 research/isa-quantization/reciprocal-attention-gauge/witness.py
lake env lean Kelana/ReciprocalAttentionGauge.lean
```
