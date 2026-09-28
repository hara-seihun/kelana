# Fractional collision packing: a global-label KL floor without partition search

This sidecar addresses the loss of a *common source-to-emission label* in the [categorical-tree](../categorical-tree/README.md) relaxation, without repeating the [emission-subspace](../emission-subspace/README.md) spectral argument. It is a lower bound on the same complete conditional emission objective, not an inference format or an improvement in model quality. Teacher occupancies must be actual teacher occupancies; a captured response panel does not establish a floor on unseen histories.

## The certificate

Let finite sources `s` have categorical teacher laws `p_s` and masses `ν_s≥0`, with total mass `M>0`. At most `C` stationary candidate emissions `q_c` are shared by all sources. For every pair put

```
W_ij = ν_i+ν_j,       pbar_ij = (ν_i p_i+ν_j p_j)/W_ij,
D_ij = ν_i KL(p_i||pbar_ij) + ν_j KL(p_j||pbar_ij).
```

For zero pair mass define `D_ij=0`. This is the *weighted Jensen–Shannon merge cost*, in the same unnormalized loss units as the target. The KL centroid identity proves, for any common assigned label `c`,

```
ν_i KL(p_i||q_c) + ν_j KL(p_j||q_c)
    = D_ij + W_ij KL(pbar_ij||q_c) ≥ D_ij.                    (1)
```

The identity follows by expanding each logarithm through `pbar_ij`; all linear cross-terms collect into the final KL. Boundary cases follow by extended KL conventions or positive-law approximation. In particular `D_ij>0` when both masses are positive and the laws differ.

Choose *any* collection `E` of `(C+1)`-element subsets of the sources. Define `m_A=min_{i<j in A}D_ij`. Give each hyperedge a **nonnegative rational share** `λ_A` satisfying `Σ_{A∋s}λ_A≤1` at every source. Then **every** assignment `g:S→[C]` and emissions `q_c` obey

```
Σ_s ν_s KL(p_s||q_g(s))  ≥  Σ_{A∈E} λ_A m_A.               (2)
```

Indeed pigeonhole forces a same-label pair in each `A`. Its cost in (1) is no greater than the nonnegative sum of *all source costs within A*. Multiplying by `λ_A`, exchanging sums, and using the per-source load constraints bounds the result by the full loss. The shares are the indispensable no-double-charge constraint: summing every pair's merge cost is false, even for three equal-mass point masses and two labels (all three pair floors are positive while an assignment need collide only one pair). A hyperedge may overlap other hyperedges; it is its total fractional source load, not disjointness, that licenses addition.

This also bounds arbitrary own-state occupancy `w(s,c)` with `Σ_c w(s,c)=ν_s`: for fixed candidate laws, replacing each row by its cheapest label does not increase loss, then (2) applies. The same deterministic-own-state sequence-KL premise and stochastic-mixture caveat as in the sibling studies apply. A shared upstream label across several fixed independent live contexts can be studied by lifting `(context,token)` into one joint emission law, as in emission-subspace.

A uniform explicit certificate uses **all** `(C+1)`-subsets and `λ_A=1/binom(n−1,C)`. A stronger sparse certificate maximizes `Σ λ_A m_A` subject to these `n` incidence inequalities, a fractional hypergraph-packing LP. There are at most `binom(n,C+1)` candidate hyperedges, not `C^n` assignments: the full family is cheap for small fixed `C`, while arbitrary selected `(C+1)`-subsets give valid certificates for larger `C`. This bound is **strictly positive whenever at least `C+1` positive-mass sources have pairwise distinct laws**: select their single hyperedge at share one. Its mathematical scope is all finite vocabularies and all `1≤C<n`, with nonuniform masses. This detects a global collision in binary vocabulary, where a two-dimensional emission-subspace bound vanishes at `C=2`.

The certificate does not promise a uniform approximation to exact clustering. For `n` equal-weight distinct point masses it gives `2 log(2)/(C+1)` using all hyperedges, whereas exact clustering can grow like `log(n/C)`; the spectral bound is preferable there. Take the **maximum**, never the sum, of independent floors unless a joint charging argument licenses the sum.

## Complete small controls

[`search.py`](search.py) uses the sibling rational log-interval engine (24-term atanh with exact range reduction and outward dyadic rounding). It enumerates all unlabeled partitions only for the *oracle*, never for the packing bound. The LP's floating solution is solely a proposal: shares are truncated to dyadic rationals and rescaled under exact rational incidence checks; all pair floors, objectives, and oracle comparisons have rational interval endpoints in [`results.json`](results.json). The uniform witness is accepted independently of the LP. Runtime is about 0.3 seconds on this host.

| Complete source family (`C=2`) | Collision packing | Exact clustering | Comparison with siblings |
| --- | ---: | ---: | --- |
| Four crossing Bernoulli-product laws | .08720802 | .13081204 | Best singleton tree .06850669, subspace .06933646; packing beats both, but not two-node tree grouping .09985216. |
| Six generic four-token laws, occupancy `1:2:1:3:2:1` | .03758132 | .07584540 | Best singleton tree .05180352 wins; subspace .02869151 loses. |
| Four near-disjoint laws | .46208732 | .69313098 | Best singleton tree .00001178; subspace .69114719 wins. |
| Four Bernoulli laws, occupancy `1:2:3:4` | .01672424 | .02303592 | Subspace is zero in two-dimensional vocabulary; the Bernoulli ordered oracle is stronger. |
| Three Bernoulli laws | .02254805 | .02254805 | One forced pair: the certificate is exact. |

All teacher probabilities are strictly positive; exact rational fixtures and per-pair/per-hyperedge/share receipts are recorded in `results.json`. The six-source oracle tests all 32 unlabeled at-most-two partitions. This discriminates a new *label-collision* floor against the independent-node, spectral, and exact-clustering controls rather than merely increasing a budget constant.

## Formal scope and reproduction

[`Kelana/CollisionPacking.lean`](../../../Kelana/CollisionPacking.lean) proves the arbitrary-overlap rational fractional-charge theorem by an explicit finite interchange of sums, its hyperedge-floor corollary, the three-source/two-label pigeonhole principle, and the exact rational triple pair-floor consequence. It has no `sorry`. It does **not** assert a Lean real-log theorem: (1), KL nonnegativity/centroid optimality, and general `C+1` pigeonhole are the analytic/combinatorial proofs above; the executable certifies finite rational log intervals, not the universal real-log bridge. This distinction matters when reusing an interval certificate for a different divergence.

```sh
python3 research/isa-quantization/collision-packing/search.py
lake env lean Kelana/CollisionPacking.lean
```
