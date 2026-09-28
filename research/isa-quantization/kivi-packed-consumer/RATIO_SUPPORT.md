# Value-aware support of a normalized ratio box

The [byte-query contract](QUERY_ERROR.md) obtains score-edit intervals from the packed map and then applies a sharp total-variation bound. That last step discards which values receive the changed mass. This note gives an exact finite alternative for **scalar observed outputs**, and a support representation for complete vector outputs. It optimizes a declared interval relaxation; it neither changes the frozen reader nor mistakes every independently legal interval edit for an executable shared-query edit.

## 1. The scalar problem is a finite threshold problem

Fix nonempty visible keys, positive baseline masses `p_i`, scalar observed values `v_i`, and positive bounds `lo_i <= r_i <= hi_i`. Normalizing p to sum1 is optional. Define

```
y(r) = sum_i p_i r_i v_i / sum_i p_i r_i.
F(t) = sum_i p_i endpoint_i(t) (v_i-t),
endpoint_i(t) = hi_i if v_i >= t, otherwise lo_i.
```

For any legal r the sign of `v_i-t` gives, term by term,

```
sum_i p_i r_i (v_i-t) <= F(t).
```

The endpoint vector is legal and attains the right side. Every denominator is positive, hence

```
F(t) <= 0  iff  y(r) <= t for every legal r.                 (1)
F(t) = 0   implies y(endpoint(t)) = t = max_r y(r).          (2)
```

These are actual finite-sum statements, not a tangent bound or an assumed optimizer. [`Kelana/RatioBoxSupport.lean`](../../../Kelana/RatioBoxSupport.lean) proves the endpoint inequality/attainment, positive denominator, iff certificate, exact-zero maximum, and the minimum by negating values. Exp, numerical sorting and vector geometry are outside that rational module.

`F` is continuous and strictly decreasing: on every interval between successive distinct v values its slope is `-sum p_i endpoint_i < 0`, and switching an endpoint at `t=v_i` changes a zero summand. It crosses zero between min(v) and max(v). Sort values once; start with every ratio high and maintain numerator A and denominator B. Moving past a value replaces its high ratio by its low ratio in A and B. The first interval containing `A/B` gives the exact maximum. Equal values switch together. Thus sorting plus a linear scan, **O(n log n)** arithmetic comparisons, replaces a `2^n` vertex census. Minimum is `-max(-v)`. For rational fields all comparisons and the final value can be exact; this is not a promise that arbitrary source exp ratios are rational.

## 2. Why this is a convex output set

Write `tau=1/sum p r` and `a_i=tau p_i r_i`. The feasible normalized weights are exactly the projection of

```
sum_i a_i = 1,
tau p_i lo_i <= a_i <= tau p_i hi_i,
1/sum p_i hi_i <= tau <= 1/sum p_i lo_i.
```

This is a compact convex polytope in `(a,tau)`. Conversely its positive tau recovers the legal `r_i=a_i/(tau p_i)`. Therefore the attainable vector-output set `Y={sum a_i w_i}` is convex. For any fixed direction u its support is exactly the scalar threshold maximum with `v_i = u dot w_i`. Nothing requires attention probabilities themselves to resemble their baseline if the actual observed values agree.

For a declared product of independent ratio boxes across heads, put `w_hi=O_h V_i`. The full output set is the Minkowski sum of the head sets, so its support is

```
h_Y(u) = sum_h T_h(u),
T_h(u) = scalar_ratio_max(p_h, lo_h, hi_h, u dot w_hi).
```

With fixed teacher target y*, the exact robust Euclidean error of this relaxation is

```
max_(y in Y) ||y-y*|| = max_(||u||=1) [sum_h T_h(u) - u dot y*].   (3)
```

The remaining direction maximum is a real optimization problem, not removed by cheap scalar support. In particular, no claim of a cheap exact high-dimensional squared-error oracle follows. A simple certified outer bound uses any orthonormal output basis: compute exact scalar min/max in each direction, subtract the teacher coordinate, and sum the larger squared endpoint magnitude per coordinate. This can be combined by taking the smaller of it and an independently valid TV/diameter bound. It retains actual O and value amplitudes, but discards cross-coordinate coupling.

**Shared-source limitation:** one byte query creates correlated edits across keys, and shared cache/encoding can correlate different heads. Independent ratio boxes enlarge that reachable family. Equation (3) is exact for the product-box relaxation, not for all and only the original byte program's reachable errors. For example, two heads with identical probabilities/ratios and opposite O contributions cancel for every shared edit; treating their ratios independently generally destroys that cancellation. The earlier complete [joint K/V](../joint-cache-error/README.md) and value Gram identities remain the stronger bookkeeping where those correlations are known.

## 3. A strict improvement over the universal TV/diameter bound

Take three equal baseline masses and observed values `(0,0,1)`. Let the first two ratios vary in `[1/4,4]`, and fix the third ratio at1, as can happen for an unchanged recent key. The baseline output is1/3. Exact scalar support gives

```
min y = 1/(4+4+1) = 1/9,
max y = 1/(1/4+1/4+1) = 2/3.
```

The exact maximum output displacement is therefore **1/3**, squared **1/9**. The uniform ratio range gives sharp universal `TV<=3/5`; the observed-value diameter is1, hence that route gives squared bound **9/25**. Both are valid, but the value-aware bound is strictly tighter. It uses the fixed recent value and actual values rather than inventing a smaller score interval.

[`ratio_support.py`](ratio_support.py) sorts/scans with exact Fractions, returns endpoint witnesses and checks (1)/(2) algebraically; [`ratio-support.json`](ratio-support.json) records this example and the common-ratio two-head cancellation. It does not enumerate ratio vertices, run a source fit, or score another cache candidate.

## 4. Applying this to a packed query

For actual bounded score edits `ell_i <= e_i <= u_i`, use `lo_i=exp(ell_i)`, `hi_i=exp(u_i)`. Recent unchanged keys have both ratios1. The baseline p is the **original quantized-cache** probability row; V is its same decoded value, and the target can be the actual teacher output in (3), so existing cache error is retained directly. A rigorous floating implementation needs outward exponential and dot-product bounds; point-estimated FP32 endpoints do not become certificates by being fed to an exact rational optimizer.

No native kernels, timing, stored cache bytes or source images change here. The immediate gain is an exact observer-aware acceptance primitive, not a new frontier point. The [native byte-query discriminator](../kivi-two-bit-dot-native/README.md) later obtained a separate admission, passed numerical checks and measured the byte reader slower. The ratio certificate is not a reason to disregard that measured implementation result.
