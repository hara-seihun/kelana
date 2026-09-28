# Shared QJL residuals: exact score covariance before the live observer

A random sketch is not independent noise on each key. TurboQuant's inner-product construction shares one Gaussian projection across cached residuals, queries and, in the selected port, KV heads. Its unbiased per-key estimator therefore has **structured cross-key and cross-head covariance**. That structure can cancel exactly at softmax or survive through values and the full output projection.

This note derives that covariance for arbitrary fixed residual vectors and pushes it through the linearized complete attention output. It does not fit a quantizer, sample seeds or predict the quality of a particular finite FP32 image. The [paper-defined causal port](../current-kv-comparators/README.md) has a separate source/rounding/cost contract. The base Gaussian-sign estimator is from [QJL](https://doi.org/10.1609/aaai.v39i24.34773) and [TurboQuant Algorithm2 and Appendix B.2](https://proceedings.iclr.cc/paper_files/paper/2026/file/5c802ef38ab6e366c2ea06eee554c088-Paper-Conference.pdf); the cross-moment calculation below is Gaussian angular integration, not a new quantization algorithm.

## 1. Condition on the coarse quantizer, not on the residual sketch

Let `k_i` be true keys, `k_i^0` arbitrary fixed coarse reconstructions and `r_i=k_i-k_i^0`. Conditioning on all source data and the coarse MSE rotation/codebook freezes these residuals. Draw independent rows `g_l ~ N(0,I_d)`, `l=1..m`, **shared for every i**. Define

```
alpha = sqrt(pi/2)
Z_i(g) = alpha ||r_i|| g sign(g·r_i),
Z_i(g) = 0 if r_i=0,
khat_i = k_i^0 + (1/m) sum_l Z_i(g_l),
e_i = khat_i-k_i.
```

Gaussian symmetry gives `E[g sign(g·a)]=sqrt(2/pi) a` for unit `a`: the component along `a` has mean `E|N(0,1)|`, while orthogonal components have zero conditional mean. Consequently `E Z_i=r_i` and `E e_i=0`. For a single key,

```
E[Z_i Z_i^T] = (pi/2) ||r_i||² I
E[e_i e_i^T] = [(pi/2)||r_i||² I - r_i r_i^T]/m.          (1)
```

The first identity follows directly from `sign²=1` almost surely. It retains the rank-one subtraction discarded by the usual isotropic upper bound. For a fixed query `q`, the exact variance is `[(pi/2)||r_i||²||q||²-(q·r_i)²]/m`.

Here `m` is arbitrary; the paper's one-sign-per-coordinate construction uses `m=d`. Normalizing a nonunit key and restoring its original radius yields this same real formula for the residual in original key units. Rounding the radius, inverse rotation, Gaussian entries or arithmetic changes the implemented law; none of (1) claims exact statistical unbiasedness for a frozen FP32 table.

## 2. Exact two-residual cross moment

For nonzero residuals write `R_i=||r_i||`, `a=r_i/R_i`, `b=r_j/R_j`, and `rho=a·b`. When `|rho|<1`, set

```
F(a,b) = asin(rho) I
       + [a b^T + b a^T - rho(a a^T+b b^T)]/sqrt(1-rho²).
```

Then

```
E[Z_i(g) Z_j(g)^T] = R_i R_j F(a,b),
C_ij := E[(Z_i-r_i)(Z_j-r_j)^T]
      = R_i R_j F(a,b) - r_i r_j^T,
E[e_i e_j^T] = C_ij/m.                                 (2)
```

The parallel endpoints are defined directly, without a singular formula:

```
b= a: F=( pi/2)I,
b=-a: F=(-pi/2)I.
```

A zero residual gives zero cross block. `C_ji=C_ij^T`; an individual cross block need not be symmetric, although the complete key-coordinate block matrix is symmetric positive semidefinite as a covariance.

### Derivation by a two-dimensional angular integral

Let `rho=cos(theta)`, `0<theta<pi`, `s=sin(theta)>0`, and choose unit `u` orthogonal to `a` with `b=cos(theta)a+s u`. In the `(a,u)` plane write the Gaussian as `R(cos(phi),sin(phi))`, with uniform `phi` and `E R²=2`, independent of the orthogonal Gaussian coordinates. The sign product disagrees on two angular intervals of length `theta`. Integrating `cos²(phi)`, `sin²(phi)` and `sin(phi)cos(phi)` over those intervals gives

```
E[g g^T sign(g·a)sign(g·b)]
  = (2/pi){(pi/2-theta)I
           + cos(theta)s (a a^T-u u^T)
           + s²(a u^T+u a^T)}.
```

For example, the `aa` entry is `1-2theta/pi+sin(2theta)/pi`, the `uu` entry changes the sign of its last term, and the off-diagonal entry is `2sin²(theta)/pi`. Every perpendicular diagonal entry is just the mean sign product `1-2theta/pi`; perpendicular mixed entries vanish. Substituting `b=cos(theta)a+s u` gives `(2/pi)F(a,b)`. Multiplication by `alpha² R_iR_j`, subtraction of means and independence between sketch rows prove (2).

This plane form also avoids pretending that a raw `1/sqrt(1-rho²)` implementation is well-conditioned near parallel residuals. Choosing a stable numerical realization remains an implementation problem, not a different covariance theorem.

## 3. Centered score covariance and the complete output

Let `h` index query heads and `g(h)` its shared KV head. Fix a causal prefix. Include the usual attention scale in `q_h`, so true logits are `l_hi=q_h·k_g(h),i`. Let `p_hi=softmax(l_h)_i`, true values `v_g(h),i`, head mean `y_h=sum_i p_hi v_g(h),i`, and original output blocks `O_h`. Define output vectors

```
B_hi = p_hi O_h (v_g(h),i-y_h).
```

They satisfy `sum_i B_hi=0`. For a key perturbation `tau e`, the first derivative of the **sum of head outputs after O** is

```
DeltaY = sum_h,i B_hi (q_h·e_g(h),i).
```

Conditioned on the fixed residuals, its exact mean-square is

```
E||DeltaY||²
  = (1/m) sum_(h,i),(u,j)
      (B_hi · B_uj) [q_h^T C_(g(h),i),(g(u),j) q_u].     (3)
```

The sum is taken **after** heads are combined, so cross-head terms remain. Shared Gaussian rows also couple different KV heads if the same prepared projection is used for all of them. Independently seeded projections would zero cross blocks between independent groups and would be a different program/state choice. Replacing (3) by per-key variances or a sum of headwise output losses discards real terms.

Equation (3) is an exact statement about the linearized response, not a finite-edit equality. With original values fixed and finite source/prefix, bounded softmax derivatives and finite Gaussian moments imply

```
lim_(tau->0) E||Y(k+tau e)-Y(k)||²/tau² = E||DeltaY||².
```

For a simultaneously quantized value cache, the value-only baseline is generally nonzero. Merely adding its squared norm to (3) does **not** give the second-order coefficient of the true nonlinear error: the baseline also contracts with the second derivative of softmax. The [joint K/V study](../joint-cache-error/README.md) and actual causal replay remain the finite-edit obligation. No key-only proxy certifies the complete port's quality.

## 4. Same marginal noise, different exact attention behavior

There is a simple nonasymptotic example inside QJL itself. Take two keys, query `q=e2`, coarse reconstruction zero, values `+1,-1`, and unit key directions in dimension at least2. In both cases teacher logits are `(0,0)` and teacher output is zero.

- **Equal directions:** keys `(e1,e1)`. Shared QJL reconstructs both with identical query error `z`, so candidate logits are `(z,z)` and the output is **exactly zero for every sketch**.
- **Opposite directions:** keys `(e1,-e1)`. Oddness of QJL makes query errors `(z,-z)`, so the output is **tanh(z)**.

For either individual key, the entire error law in either example is exactly `N(0,pi/(2m))`: each term is `sqrt(pi/2) g_2 sign(g_1)`, and the independent random sign does not change a standard Gaussian. Yet in the second case

```
E tanh²(z) > 0
```

for every finite positive `m`, while the first case remains zero. The linearized squared error is respectively `0` and `pi/(2m)`. The distinction is correlation and the softmax row-shift quotient, not estimator bias, overflow or a different marginal distortion rate. This is an exact mathematical QJL example, not a paid candidate or a claim that the two-bit coarse TurboQuant stage produces these particular residuals on Qwen.

More generally, if every key residual in a given row is the same vector, a shared residual sketch contributes exactly one common logit error for that query, and **the entire softmax row is unchanged**, not just its derivative. Equality of per-key variance does not establish this; the common random map does.

## 5. Proof and executable scope

[`Kelana/SharedSketchCovariance.lean`](../../../Kelana/SharedSketchCovariance.lean) proves finite rational covariance/Gram assembly, actual covariance symmetry/PSD and pointwise common-error annihilation. It reuses the finite Gram identity and derives the weighted interchange rather than assuming the desired quadratic identity. The parent compiled the committed module with direct successful `lake env lean` exit status. IID averaging by1/m, Gaussian angular integration, real softmax differentiation, moment domination and the particular paper's randomness remain analytic. No real-number or Gaussian kernel-check claim is made by that finite module.

For the actual comparator, prepared matrices, codebook, finite norm fields and packed sign/index arrays are paid. One fixed draw is a deterministic executable program; expectation over random projections neither establishes its quality nor licenses reseeding until it wins. Equations (1)–(3) identify what a structural source diagnostic would need to retain, while the independent packed-image causal observer decides that program's finite error.
