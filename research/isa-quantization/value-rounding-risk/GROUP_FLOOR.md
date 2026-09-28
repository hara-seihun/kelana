# A source-frame floor for every within-G32 unbiased law

The [pair envelope](PAIR_ENVELOPE.md) permits arbitrary pairings but only adjacent two-level marginals and independent pairs. Here the whole original32-coordinate group is one joint random object. Its marginals may use **all four original decoded levels**, with the same clipped means. Groups and token events remain independent; the two Q heads reading one KV draw are not independent. No specific joint sampler is proposed.

## A source-uniform frame certificate

For one original layer/KV head/G32, concatenate the two same-layer original O-head column blocks:

```
B=[O0_group, O1_group]             (1024×64)
G=B^T B, D=diag(G).
```

A rational lambda≥0 is admissible when `G-lambda*D` is positive semidefinite. The source discriminator obtains one proposed lambda from the smallest normalized FP64 eigenvalue, rounded downward once to a multiple of1/4096, then certifies the exact dyadic matrix. The estimate is a proposal, not evidence of positivity: exact factorization/elimination and signs own that claim. There is no sequence of backoff values or query-selected lambdas.

For any actual shared KV error vector e and any head masses u,v, substitute the **same e** into both halves of the64-vector `(u*e,v*e)`. The certificate gives

```
||u*O0_group*e+v*O1_group*e||²
 >= lambda Σ_d (u² ||O0_d||²+v² ||O1_d||²) e_d².
```

This keeps actual cross-head interaction on the left. It does not approximate two shared readers as independent noise, and no sign assumption on u,v is needed. The resulting lower bound has no off-diagonal term on the right because it relaxes the whole64-column Gram, not because the32 errors are independent.

## Arbitrary grid marginals and complete risk

If Y_d has original-grid support and clipped coordinate mean x_d, the [adjacent-grid theorem](README.md) gives

```
Var(Y_d) >= (x_d-l_d)*(h_d-x_d),
```

where l,h are the actual adjacent decoded levels enclosing x. This remains true when its marginal uses other decoded levels or is coupled arbitrarily to the other31 coordinates. Nonnegative diagonal frame weights let us replace each variance by this minimum. Summing the group floors over independent groups/events and adding unchanged deterministic mean-output error yields a complete expected-SSE floor. Original K/source error and endpoint clipping stay in that mean-output term.

A bound below achieved deterministic V2 is inconclusive: it does not exhibit a useful joint law. A pooled floor above V2 would exclude the entire stated within-group fixed-mean family on that panel, without enumerating4^32 codewords or a random-seed search. Cross-event correlations, changed means/fields/K and autoregressive observer changes lie outside it.

## Formal custody

[`Kelana/ValueGroupRiskFloor.lean`](../../../Kelana/ValueGroupRiskFloor.lean) proves:

- Exact coefficient equality to `L^T diag(w)L` with w≥0 implies a nonnegative finite quadratic; this is a real factor witness, not an eigenvalue assumption.
- `G-diag(d)` factor custody implies the all-vector diagonal frame bound, using a distinct coordinate list and the actual finite Gram identity.
- The bound pushes through any joint finite noise law and larger marginal second moments; coordinate independence is absent.
- Deterministic mean bias adds back through the exact finite zero-mean identity.
- The shared-head lift and its diagonal coefficients are exact finite sums.
- Zero cross moments between groups/events imply the exact sum of group variances. Independence is one way to supply that premise; none is imposed within a group.

The module imports the existing adjacent-grid and bias/covariance foundations. Direct Lean compilation exits0. It does not formalize FP64 eigensolver accuracy, concrete source bytes, or a continuous probability measure. The [source-only computation](../value-group-risk-floor/README.md) separately owns exact matrices and certificate replay; analytic observer receipts keep their FP64 boundary explicit.

## Source outcome: inconclusive, not an encoder

All64 frozen dyadic frame proposals have exact positive-definite certificates, with lambda numerators546…2534 over4096. Generation checks exact positivity on every group; a separate original-byte/congruence/projection reader checks three representative groups, including a nontrivial permutation. The source study records those scopes rather than calling the numerical eigensolver a certificate.

Pooled complete expected-risk floors are **190.557568 train**, **95.442936 validation**, and **.285963 layer0**, versus deterministic **209.016696/107.923582/.832658**. None exceeds its control. Thus the broader within-G32 family remains open under this bound; the earlier pair-family exclusion must not be extended to it. No joint law, random cache or runtime benefit has been constructed. The actual sums of variance lower bounds are34.405162/18.491851/.106395; unchanged mean bias is added in full.
