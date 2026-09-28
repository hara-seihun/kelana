# A lower risk envelope for every pairing of fixed adjacent marginals

The [source-certified pair law](../kivi-pair-rounding-risk/README.md) weakly improves every fixed-query expectation relative to independent rounding, as proved, but remains worse than deterministic V2 contextually. Instead of searching another pairing, bound the **entire pairing family**. This is an oracle relaxation, not another encoder.

## Exact scope

Fix the original source, K2 query probabilities, decoded V2 fields, clipped means and each coordinate's adjacent two-level Bernoulli marginal. Within each original G32 group, allow any disjoint pairs and singletons and any joint distribution of the two indicators in a pair. Different pairs, groups and token events remain independent. The oracle may even choose a different matching and pair coupling for every query; any one causal fixed matching is contained in this relaxation.

This is not every unbiased law on the four-level grid. When correlations are admitted, a larger marginal variance can accompany more beneficial off-diagonal covariance; the independent scalar variance-minimum theorem does not exclude that possibility. Changed adjacent marginals, larger joint groups, cross-event dependence, biased means and changed K/fields are outside this family.

## Pair improvement envelope

Let f_i,f_j be upper probabilities and d_i,d_j the actual nonnegative decoded gaps. The joint-upper probability has endpoints

```
L_ij=max(0,f_i+f_j-1), U_ij=min(f_i,f_j).
cmax_ij=max(f_i*f_j-L_ij, U_ij-f_i*f_j).
```

Its centered indicator covariance is in[-cmax,cmax]. Within one token/KV head, let u,v be the actual paired-Q attention masses and use the original O-column coefficients from [the shared-head sign study](../value-pair-covariance/README.md):

```
gamma_ij(u,v)=A_ij*u²+B_ij*u*v+D_ij*v².
```

Any pair's variance improvement over independent noise is

```
-2*d_i*d_j*(t_ij-f_i*f_j)*gamma_ij
 <= 2*d_i*d_j*cmax_ij*(|A_ij|u²+|B_ij|uv+|D_ij|v²).
```

This deliberately discards the sign and all cancellation within the polynomial. No source-specific sign certificate or selected matching is needed.

For each vertex i, precompute the three maxima over its31 possible original-group partners:

```
M_Ai=max_j 2*d_i*d_j*cmax_ij*|A_ij|,
M_Bi=max_j 2*d_i*d_j*cmax_ij*|B_ij|,
M_Di=max_j 2*d_i*d_j*cmax_ij*|D_ij|.
```

Any chosen edge's improvement is bounded by **both** endpoint row bounds. Each vertex occurs at most once in a matching, so total group improvement is at most

```
(1/2)*sum_i (u² M_Ai + uv M_Bi + v² M_Di).
```

Unused singleton vertices contribute nonnegative slack. Taking maxima separately for three coefficients relaxes the problem further: it effectively permits different partners for the three mass monomials. Thus one can prepare only three numbers per original event/head and contract with each query cheaply, instead of solving a matching per token per query.

Sum this benefit envelope B over aged events/groups. Let V_ind be independent output variance and R_mean the unchanged mean-output SSE. Every admitted pairing has

```
expected complete-O SSE >= R_mean + max(0, V_ind-B).
```

The zero intersection is actual variance nonnegativity, not clipping an output error. The original K/source/endpoint bias remains in R_mean. If this lower envelope already exceeds achieved deterministic error on a panel, no permitted oracle pairing can beat that control on expected pooled SSE. If it does not, the bound is simply inconclusive; it does not create a better candidate or license a matching search.

## Lean and source custody

[`Kelana/ValuePairEnvelope.lean`](../../../Kelana/ValuePairEnvelope.lean) proves the finite box-product inequality, covariance-radius containment, absolute shared-head polynomial bound, pair-improvement envelope, separate-monomial row relaxation and nonnegative-variance intersection. Its matching proof uses an actual permutation of vertices into edge endpoints plus singletons and sums both endpoint bounds; it does not assume the desired total inequality. The source's32 distinct vertices and disjoint matching provide that partition. It reuses prior exact pair variance and finite summation theorems. Direct Lean exits0.

## Completed source evaluation

The [independent source evaluation](../value-pair-risk-envelope/README.md) reuses prior per-query mean and deterministic controls and evaluates only the covariance envelope. Across all3,072 contextual queries the pooled lower bounds are **237.531322 train** and **121.180421 validation**, above achieved deterministic V2 **209.016696/107.923582** by13.64%/12.28%. Thus even the query-specific oracle-pairing relaxation loses on these pooled panels. The eight retained layer0 queries instead have lower bound **.485730 versus.832658**, so this bound does not exclude that source population.

This closes the specified adjacent-marginal independent-pair family contextually, not arbitrary correlated grids or biased deterministic codes. The exact finite theorem and its FP64 source evaluation have separate custody: this is not an outward-rounded interval certificate or a Lean certificate for every floating arithmetic step. The source check labels explicitly distinguish the direct vertex-row envelope from the sum of all incident edges, which is not a matching.
