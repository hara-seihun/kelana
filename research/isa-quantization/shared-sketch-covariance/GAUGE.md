# From unbiased score risk to coupled source-coordinate balancing

The [shared-sketch calculation](README.md) describes a fixed coarse residual family. Averaging also over an independent Haar coarse-quantizer rotation yields a second useful conclusion: **the part of expected per-score QJL error changed by an exact reciprocal Q/K gauge is a coupled norm-product objective**. It is not the previously used sum of query and key energies. This identifies a source-only coordinate selection problem before any new finite quantizer is fitted.

The paired gamma/RoPE symmetry is the known [reciprocal attention gauge](../reciprocal-attention-gauge/README.md), with SmoothAttention prior art recorded there. The optimization below is standard diagonal matrix balancing. Neither a new gauge family nor a new quantization algorithm is claimed.

## 1. Exact risk after averaging the coarse rotation

Fix any scalar reconstruction codebook and coordinate quantization rule. For a unit source `x`, draw Haar orthogonal `P`, reconstruct `P^T Q(Px)`, and set residual `r=x-P^T Q(Px)`. Haar invariance makes the residual law equivariant under simultaneous source rotations. Consequently constants depending only on the codebook and dimension satisfy

```
D = E||r||²,
A = E(x·r)²,
B = (D-A)/(d-1),
E[rr^T] = A xx^T + B(I-xx^T).                          (4)
```

This does not assume independent coordinates of `Px`. To prove it, every orthogonal map fixing `x` leaves the residual law invariant; its second moment therefore has one eigenvalue along `x` and one on its orthogonal complement. The parallel contraction and trace give (4). In particular `0<=A<=D` and `B>=0`.

For an arbitrary nonzero key `k`, multiply by its radius. Add an independent `m`-row QJL residual correction as in the main note. Conditional unbiasedness means there is no extra variance of a conditional mean. Averaging (1) over the coarse rotation gives the exact per-score squared error

```
E(q·(khat-k))²
 = (1/m){ [(pi/2)D-B] ||q||²||k||² - (A-B)(q·k)² }.   (5)
```

Set `a0=(pi/2)D-B`. For `d>=2` and nonzero distortion, `a0>0`, since `B<=D/(d-1)<=D` and `pi/2>1`. A zero key is trivial. Equation (5) applies to the ideal real random algorithm, not to a stored FP32 matrix or one selected seed.

Let a source-preserving gauge send `q->Lq`, `k->L^-T k`. Their inner product stays fixed. For any nonnegative fixed source weights, minimizing the corresponding average of (5) is therefore **exactly equivalent** to minimizing

```
F(L) = E_source[||Lq||² ||L^-T k||²].                   (6)
```

The unknown codebook constants do not need to be numerically estimated to choose this gauge. This is an expected **logit** risk result. The shared cross-key covariance and nonlinear value/output response still determine actual attention error; (6) is not a complete-O guarantee. The [exact finite row-gauge example](ROW_GAUGE.md) proves the distinction for every finite sketch size, beyond a first-order approximation.

## 2. RoPE-pair scales produce a directed matrix objective

Restrict to one scalar `lambda_a>0` per rotary coordinate pair, shared across all query and KV heads using the same gamma. Pair-scalars commute with RoPE at every query/key position. Because RMSNorm occurs before gamma, fold them into the existing gains:

```
gammaQ'_a = lambda_a gammaQ_a,
gammaK'_a = gammaK_a/lambda_a.
```

No extra inference field or multiply is required when the actual stored gains exactly represent these products; changed source rounding must still be checked. This is not moving a scale through RMSNorm.

Let `Q_sa` and `K_sb` be the squared energies in pairs a,b for an allowed causal source/query-key context s, including the original attention scale in q. With fixed weights `mu_s>=0`, define

```
C_ab = sum_s mu_s Q_sa K_sb.
```

Then finite distributivity yields

```
F(lambda) = sum_ab C_ab lambda_a²/lambda_b².            (7)
```

The actual query and key in each context remain paired. Replacing C by the outer product of their separate average pair energies assumes away source/history dependence. An independent norm-sum objective `sum_a A_a lambda_a²+B_a/lambda_a²` is also different from (7).

The source study uses a declared uniform measure over all visible `i<=t`, sixteen Q heads and eight original train windows; each query uses its own shared KV head. Prefix sums of key-pair energies form C without materializing all query-key pairs. No held data or random sketch table is involved in this objective.

## 3. Continuous matrix balancing and its global certificate

Write `lambda_a=2^x_a` and `z_a=log(4)x_a`. Then

```
F(z) = sum_ab C_ab exp(z_a-z_b),
B_ab(z) = C_ab exp(z_a-z_b).
```

The gradient is outgoing minus incoming mass of B:

```
partial_a F = sum_b B_ab - sum_b B_ba.
```

Its directional second derivative is `sum_ab B_ab(v_a-v_b)²>=0`. Thus F is convex and invariant under adding a common constant to z. If the positive support of C is strongly connected, F is coercive modulo that constant: a directed path from a largest to a smallest coordinate contains an edge whose positive difference diverges with their range. It therefore attains a minimum. Undirected connectivity of that support makes the Hessian positive away from constants, giving uniqueness modulo the common shift.

At a balanced point `z*`, row sums and column sums of `B*=B(z*)` agree. For every change h, `exp(h_a-h_b)>=1+h_a-h_b`, so

```
F(z*+h) >= sum_ab B*_ab[1+h_a-h_b] = sum_ab B*_ab.
```

The last cancellation is the balanced-flow condition, proving **global**, not just coordinatewise, minimality. A numerical optimizer's small gradient is evidence of approximate stationarity, not this exact certificate. The source receipt must preserve its residual rather than call floating output an exact global optimum.

The finite norm-product expansion and balanced supporting-bound assembly are the rational proof interface in `Kelana/CoupledGaugeCost.lean`. Exponentials, coercivity/existence and the Haar argument above remain analytic.

## 4. Correlated rounding to exact BF16 powers of two

Directly rounding each continuous exponent within one half can change an exponent difference by one, yielding a crude factor4 on individual terms. A **single shared rounding threshold** gives a much tighter dimension-independent guarantee without a bit/seed sweep.

For a fixed real vector x and a uniform scalar `u in [0,1)`, let

```
e_a(u) = floor(x_a+u).
```

For `delta=x_a-x_b=n+t`, integer n and `0<=t<1`, the rounded difference is n with probability1-t and n+1 with probability t. Hence

```
E_u[4^(e_a-e_b)] = 4^n(1+3t)
                 <= gamma4 * 4^delta,
gamma4 = max_(0<=t<=1) (1+3t)/4^t
       = 3*4^(1/3)/(exp(1)*log(4))
       = 1.2637407212... .                              (8)
```

The maximum is at `t=1/log(4)-1/3`. Nonnegative C allows summation of (8), so at least one common threshold gives

```
F(e(u)) <= gamma4 F(x).                                (9)
```

This is a finite deterministic choice: after subtracting x0, only the at-most n intervals between the fractional breakpoints matter, where n is the number of pairs. Enumerate their distinct integer gauges and choose the smallest F, breaking ties deterministically. A common integer shift may then set e0=0 without changing any ratio. This enumeration implements the rounding lemma; it does not tune a family against held quality.

At an exact continuous minimizer, (9) supplies a **1.263741 approximation to the globally best integer-exponent norm-product cost**, since every integer point is continuously feasible. For an approximate numerical x, the guaranteed comparison is to that F(x), not automatically to the exact optimum. A finite-precision evaluation of those costs is another numerical boundary, not an exact integer-optimality certificate.

The guarantee concerns F, the positive norm-product term. It is **not** automatically a multiplicative1.263741 bound on the full score MSE in (5), because the invariant inner-product term is subtracted. The valid additive risk comparison is `a0*(F(e)-F*)/m` for fixed source weights and exact real randomness.

Power-of-two fields must remain finite, normal where required and exactly representable after the fold. The general rounding theorem does not establish that property for arbitrary model gains. If range constraints invalidate a rounded gauge, the unconstrained approximation statement no longer certifies the constrained selection.

## 5. The next scientific boundary

The [source-only study](../qwen-coupled-gamma/README.md) now computes the train C, one continuous balancing solution and its finite common-threshold rounding. Its actual512B BF16 replacement gammas preserve scores/probabilities/full O bitwise in all12 original source windows. Train F falls285598.58→9548.63; held falls285707.49→9453.53 under the same train choice. The numerical solver's precision-loss flag and relative gradient1.65e-9 remain in the receipt. These source and proxy results are not yet a quantizer improvement.

Only after that exact source map is established is it meaningful to reuse the frozen TurboQuant seed/codebook/precision under the changed source coordinates. A subsequent paid image would be a distinct structural gauge test, not evidence that repeated random draws or higher precision rescued the original arm. The [single frozen-program test](../turboquant-coupled-gauge/README.md) is now complete: held full-O error falls1.359112→.437581 at unchanged385040B counted size, still far from KIVI.000063002 at419200B. The [integer cut/circulation theorem](../integer-gauge-balance/README.md) separately certifies that the already selected exponent vector globally minimizes the stored dyadic train C over all integer gauges. Neither result changes the ideal-law versus finite-output distinction.
