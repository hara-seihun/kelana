# A norm-product-optimal key center need not minimize the exact attention error

The [coupled gauge objective](GAUGE.md) exactly minimizes an ideal **per-score** mean-square term. The [integer certificate](../integer-gauge-balance/README.md) is correspondingly strong but scoped. Here is an analytic shared-QJL example where the minimum-norm key center is not even a local minimum of the **exact nonlinear attention output error**, for every finite number of sketch rows. It also gives two readers with equal logit-difference variance but unequal exact output risk. No new Qwen candidate is fitted or selected by this example.

## 1. A reachable two-key reader and one source-preserving translation

Work in dimension at least three. Fix `a>0`, query `q=e3`, two keys `k_+=a e1`, `k_-=-a e1` and scalar values `+1,-1`. This may be a two-token causal history whose current query is fixed by its source. Both teacher scores are zero, probabilities are one half and output is zero. The complete output map's strongest direct control is therefore simply zero; this construction is a geometry discriminator, not a compression frontier claim.

Translate both keys by `-t e2`, `t>=0`. The exact scores remain zero; no query-dependent row offset is even needed in this example. Let `R=sqrt(a²+t²)`. Apply **pure QJL** (zero coarse map) with the same m independent standard-Gaussian rows `g_l` to both keys:

```
khat = sqrt(pi/2) R/m sum_l g_l sign(g_l · k).
```

This is the unbiased Gaussian-sign construction from the [main note](README.md), not an assertion about a particular 2-bit coarse codebook's residuals. Any exact common translation changes which approximate source map is encoded.

The difference of the two reconstructed scores is

```
D_m = (2 sqrt(pi/2) R/m) sum_l
      g_l3 sign(g_l1) 1{|a g_l1| > |t g_l2|}.          (1)
```

The sketch uses shared rows; replacing the two noises by independent samples would give a different law. By planar Gaussian rotational symmetry, the active indicator has probability

```
p(t) = (2/pi) arctan(a/t),    p(0)=1.
```

The third coordinate is independent of the indicator and sign. Hence, conditional on the active count `N~Binomial(m,p(t))`, the actual half score difference is Gaussian:

```
D_m/2 | N=n ~ Normal(0, v_n(t)),
v_n(t) = (pi/2)(a²+t²)n/m².                           (2)
```

The approximate complete attention output is `Y=tanh(D_m/2)`. Defining

```
H(v) = E_Z[tanh²(sqrt(v) Z)],    Z~Normal(0,1),
R_m(t) = sum_n Binomial(m,p(t))[n] H(v_n(t)),           (3)
```

gives its **exact** output MSE. This is a finite mixture formula, not a central-limit approximation.

## 2. The source-norm optimum is not an output optimum at any finite m

The per-key expected score-error variance is `(pi/2)(a²+t²)/m`, strictly minimized at `t=0`. The positive norm-product proxy has the same minimum. Yet `H` is strictly increasing, directly from the pointwise increase of `tanh²(sqrt(v)Z)` for nonzero Z. At zero, the variance factors in (2) have zero first derivative, while `p'(0+)=-2/(pi a)`. Differentiating the finite polynomial mixture gives

```
R'_m(0+) = -(2m/(pi a))
  [H(pi a²/(2m)) - H(pi a²(m-1)/(2m²))] < 0.           (4)
```

Thus a sufficiently small common translation **increases every key's individual score variance while decreasing exact complete-output MSE**, for every positive integer m. There is no appeal to asymptotically small output error.

The large-m coefficient follows as a secondary consequence, not as the justification of (4):

```
m R_m(t) -> (a²+t²) arctan(a/t).
```

Its derivative at zero is `-a`, whereas the norm-product derivative is zero. The shared covariance, not merely smaller key norms, accounts for this difference.

## 3. Equal difference variance still does not fix nonlinear risk

There is also a fixed, non-infinitesimal comparison requiring no center search. Choose `t=a`. Then `p=1/2` and `N~Binomial(m,1/2)`. The variance in (2) is random with mean

```
E v_N(a) = pi a²/(2m) = v_m(0).
```

Thus both constructions have **exactly the same score-difference variance**. Their distributions differ, however. The function `H` is strictly concave on nonnegative v. To see this, first put `g(v)=tanh²(sqrt(v))`. For `z=sqrt(v)>0`, the sign of `g''(v)` is the sign of

```
z(1-3 tanh² z) - tanh z.
```

Its negative starts at zero and has derivative
`2 tanh² z + 6z tanh z sech² z > 0`. Thus g is strictly concave, extends continuously at zero, and averaging `g(vZ²)` preserves strict concavity. Jensen now gives

```
R_m(a) = E_N H(v_N(a)) < H(E_N v_N(a)) = R_m(0).        (5)
```

For every finite m, the center `t=a` has twice the per-key norm-product/score variance, the same score-difference variance, and **strictly smaller exact attention-output error** than the norm-optimal center. This does not contradict the covariance-based first-order theory: the two cases have the same leading large-m coefficient, and (5) concerns the finite nonlinear distribution.

## 4. Scope and what this changes

These are analytic real-Gaussian statements. The finite shared-noise covariance pushforward has its rational Lean foundation in `Kelana/SharedSketchCovariance.lean`; Gaussian angular integration, the binomial mixture and strict tanh concavity here are not claimed kernel-checked. No floating random table, paid source image, seed choice or Qwen score is substituted into this theorem.

The result forbids treating an exact optimum of the norm-product proxy—or even a complete covariance matrix—as an exact finite softmax-risk optimum. It does not erase the measured same-size gain from the fixed Qwen source gauge. It explains why the next practical question is attribution of the **existing** reader's coarse bias, shared residual noise and live value errors, rather than automatically selecting another norm-minimizing source transform. A direct zero-output program solves this deliberately simple source, so the example earns no implementation or frontier claim of its own.
