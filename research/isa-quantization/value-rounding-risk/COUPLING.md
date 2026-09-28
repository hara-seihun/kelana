# Causal coordinate coupling, not another random seed

The [independent-law floor](README.md) keeps each clipped coordinate mean fixed and shows that reducing its individual variance further is impossible on the same grid. A joint law can instead change covariance. The complete response depends on that covariance through the actual shared-head O Gram, not merely a balanced sum of errors.

## One existing-group systematic law

Keep the original G32 fields, coordinate order, flush chronology and adjacent marginal probabilities f_j. All32 coordinates are available in one V record before encoding. Define S_0=0 and S_(j+1)=S_j+f_j, and use one uniform unit threshold U per original group/record:

```
Z_j = floor(S_(j+1)+U)-floor(S_j+U).
```

The indicator is0 or1. Each marginal has mean f_j; group count telescopes to floor(S_32+U)-floor(U), within strictly one of S_32. At integer S_32 the count is exact. This is the classical systematic-sampling construction, not a new conservation principle. It has no temporal debt and uses no future token.

The indicator is one on a circular interval of length f_j starting at `(-S_(j+1)) mod1`. Thus `Cov(Z_i,Z_j)=overlap_length-f_i*f_j`. Exact finite interval support gives a PSD covariance without requiring a floating eigenvalue assertion. Actual decoded gaps multiply the covariance on both sides; they need not be equal after FP32 field decoding. Count balance alone is therefore not even exact unweighted value-error balance on a varied-gap grid.

[`Kelana/ValueGroupRounding.lean`](../../../Kelana/ValueGroupRounding.lean) proves actual rational-floor binary increments, telescoping, strict unit discrepancy, integer-count equality and the full affine covariance-Gram consequence. The continuous uniform marginal law is specified above; the Lean floor theorems are pointwise and do not formalize a random generator or continuous integration. The finite covariance theorem takes the declared zero means and actual outcome weights explicitly.

A two-coordinate example exposes the observer dependence without any numerical experiment. Let f1=f2=1/2 and unit gaps. Systematic rounding picks (1,0) or(0,1); the centered errors are antithetic. For scalar coefficients a,b, its variance is `(a-b)^2/4`, versus `(a²+b²)/4` independently. Gain is `a*b/2`. Equal-sign coefficients benefit; opposite coefficients a=1,b=-1 double variance from1/2 to1 despite exact group-count balance. These identities are also Lean-proved.

The [one complete analytic source screen](../kivi-group-rounding-risk/README.md) is finished: contextual train/validation expected SSE249.541793/127.683055 versus deterministic209.016696/107.923582, losses19.39%/18.31%. It only slightly improves on independent expected249.765157/127.760254. The eight retained layer0 states instead give.516027 versus.832658, favorable only in expectation. Original means/control outputs are reused exactly; new work is the covariance contraction. No random image, ordering/phase choice, native time or further systematic variant follows.

## Two-coordinate coupling has an exact optimum

For two Bernoulli upper-code marginals p,q, let t be joint upper/upper probability. The four probabilities are

```
P00=1-p-q+t, P10=p-t, P01=q-t, P11=t,
max(0,p+q-1) <= t <= min(p,q).
```

Independence t=pq lies inside this interval. For scalar decoded-error response coefficients a,b, the exact variance is

```
a² p(1-p) + b² q(1-q) + 2ab(t-pq).
```

For a complete vector response, replace a²,b²,ab by their full output-column squared norms and inner product. The risk is affine in t. A nonnegative column inner product is minimized by the lower Fréchet endpoint; a nonpositive inner product by the upper endpoint. Both endpoints weakly improve on independence for their indicated sign, and are optimal over all pair couplings with those marginals. Mean output and deterministic K/source/clipping bias do not change.

This does not select a best realization from random draws. It is a joint probability law whose construction only needs both source coordinates, their actual grids and a model-specific sign. It remains distinct from biased nearest rounding; beating independent expectation is not enough to beat that stronger comparator.

## Which pair sign is safe for both future Q heads?

The two Q heads sharing a KV record have nonnegative attention masses u,v for that token. Within **one layer's** original O, let columns a0,a1 be that coordinate's columns in the two head blocks, and b0,b1 those of its partner. Their combined coefficient inner product is

```
A u²+B uv+D v²,
A=<a0,b0>, B=<a0,b1>+<a1,b0>, D=<a1,b1>.
```

It is nonnegative for every u,v>=0 iff

```
A>=0, D>=0, and (B>=0 or B²<=4AD).
```

Negating A,B,D gives the nonpositive certificate. These are exact rational tests; no query calibration, source V, future weights or square-root approximation is needed. The theorem includes boundary and zero cases; a sign need not be strict at every query. Positive decoded gaps multiply the polynomial by a nonnegative factor and preserve its sign.

[`Kelana/ValuePairCoupling.lean`](../../../Kelana/ValuePairCoupling.lean) proves the iff (including rational adverse directions), legal joint weights and marginal identities, exact scalar variance, complete vector variance difference, sign-selected endpoint optimality and the actual shared-head finite Gram expansion. Direct Lean exits0. This is a within-fixed-observer expected-risk guarantee over the specified marginal laws, not an autoregressive model-wide guarantee or measured execution result.

The [source-only exact graph study](../value-pair-covariance/README.md) now certifies all31,744 candidate edges across the two owned O layers separately. Layer0 has5,708 signed edges and layer1 has4,684; each of all64 original G32 graphs has a perfect matching under the one source-only lexicographic maximum-cardinality rule. Each layer has512 pairs covering1,024 coordinates. Actual layer-indexed static maps cost1,568B per layer,3,136B together; this is shared model data, not sequence state.

Parent source review caught and repaired a layer-versus-head indexing defect before use: paired columns must be `(2*h)*128+d` and `(2*h+1)*128+d` in the **same layer**. The first producer and its independent checker had agreed on the wrong cross-layer map. Both mechanisms, all coefficients/certificates/maps and documentation were repaired; the current report records ordinary provenance and invalidates the first counts. Corrected selected row dots are independently replayed with arbitrary-precision integers. No output was evaluated with the invalid map.

The [completed fixed-law consumer](../kivi-pair-rounding-risk/README.md) uses each corrected sign's Fréchet endpoint, with no rematching or seed choice. All3,080 query corrections are nonpositive as promised, but train expected SSE247.816400 remains above deterministic209.016696; validation126.706610 remains above107.923582. Gains over independence are only1.948757/1.053644 SSE. Retained layer0 expectation.511393 is favorable versus.832658 but still above higher-rateK2/V4. Actual four-outcome projected checks and map/field/source hashes are retained. The complete source result, not sign optimality alone, decides whether the law earns implementation; this one stops without a sampler or GPU experiment.

The [all-pair envelope](PAIR_ENVELOPE.md) asks whether another matching could rescue the same adjacent marginals. It allows even query-specific oracle pairs, sums a safe degree bound and retains the same deterministic mean. This targets a stated family rather than running another pairing choice.
