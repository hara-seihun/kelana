# Normalized kernel error: correlations and live values, not marginal variance

The [fixed positive-feature experiments](../qwen-balanced-feature-reader/README.md) improve their score geometry dramatically under exact gauges but remain far behind the [named KIVI cache](../kivi-causal-cache/README.md). A better surrogate is not automatically a better reader. This study derives the **actual normalized value error**, an exact finite-realization bound, and an analytic iid-Gaussian large-feature risk. An exact rational counterexample gives identical individual kernel-error laws but different output error; a separately certified Gaussian example shows that the mean-exponent-optimal key center can be much worse for output risk than another equally paid center.

These are self-normalized importance-sampling/covariance and delta-method arguments applied to the existing positive attention representation, not a new Monte Carlo algorithm. See [Art Owen, *Monte Carlo theory, methods and examples*, chapter9](https://www.artowen.su.domains/mc/Ch-var-is.pdf), especially the self-normalized estimator and optimal-proposal distinction. No new source fit, feature rank/seed, GPU experiment or trained-model result is claimed.

## 1. Exact deterministic output identity

Fix one query and its finite visible keys. Teacher kernel weights `k_i>0` give `p_i=k_i/Z`, `sum p=1`. Let `w_i` be the **live output value**: it can already include the head's fixed O columns. Write `y=sum p_i w_i`, `delta_i=w_i-y`. Any positive approximate kernel has ratios `r_i=khat_i/k_i>0` and `rbar=sum p_i r_i`. Its exact output error is

```
yhat-y = [sum_i p_i r_i delta_i]/rbar
        = [sum_i p_i (r_i-rbar) delta_i]/rbar.                 (1)
```

Consequently, by weighted Cauchy,

```
||yhat-y||² <= [sum p_i(r_i-rbar)² / rbar²] * sum p_i||delta_i||².   (2)
```

The scalar proof is in `Kelana/NormalizedKernelError.lean`, including positivity of the denominator and a genuine finite-sum Cauchy argument. The Euclidean vector extension follows by summing the scalar bounds coordinatewise. Both statements concern a **realized** positive reader, with no unbiasedness assumption and no infinitesimal edit. The mean squared relative kernel error to1 decomposes into centered variance plus `(rbar-1)²`; that last common component alone causes no output error.

For two values with probabilities p,q (`p+q=1`),

```
yhat-y = p q (r0-r1)(w0-w1)/(p r0+q r1).                    (3)
```

Equal kernel ratios give zero output error however large they are. Equal live values also give zero error however inaccurate the probabilities. These facts do not permit discarding denominator information needed by a [future value probe](../attention-prefix-state/README.md), and do not imply a finite-feature prefix is cheap to update.

### Exact same-marginal counterexample

Take `p=(1/4,3/4)`, values `(0,1)`, and two equiprobable outcomes. Reader A has ratio vectors `(1/2,1/2)` and `(3/2,3/2)`. Reader B has `(3/2,1/2)` and `(1/2,3/2)`. Every individual ratio in both readers has **the same entire marginal law**, mean1 and variance1/4. A is exact at the output. B outputs1/2 or9/10 against teacher3/4, so exact mean squared output error is **17/400**. Both use four one-byte ratio numerators over a common denominator2; neither wins by hidden fields. This is an algebraic reader witness, not a proposed online cache or superiority to the exact direct3/4 constant reader.

## 2. An iid-Gaussian covariance that keeps the live values

For a fixed source query q, visible keys k_i, and shared key translation c, let `z_i=q+k_i-c`. The ideal iid positive Gaussian feature's kernel ratio is

```
R_i(omega)=exp(omega dot z_i - ||z_i||²/2),   omega~N(0,I).
```

This is the ratio of the positive product feature to its own exact shifted kernel. Thus `E R_i=1` and

```
E[R_i R_j] = exp(z_i dot z_j),
Cov(R_i,R_j) = exp(z_i dot z_j)-1.                            (4)
```

For r iid features define `D_r=mean_a sum_i p_i R_i(omega_a)` and `T_r=mean_a sum_i p_i R_i(omega_a) delta_i`. Equation(1) gives the exact realized error `T_r/D_r`. Its numerator variance and denominator variance are

```
E||T_r||² = A/r,
A = sum_ij p_i p_j (delta_i dot delta_j) exp(z_i dot z_j),     (5)
Var(D_r) = B/r,
B = sum_ij p_i p_j [exp(z_i dot z_j)-1].                     (6)
```

The missing `-1` in(5) cancels because `sum p delta=0`; all covariance between key estimates remains. A and B are nonnegative since they are actual second moments, even though individual terms in(5) can be negative. Raw entrywise exponent maxima or independent per-key variance lose precisely this structure.

### Finite-r bound, not a variance-as-error substitution

Let `Delta=max_i ||delta_i||`. For any fixed `eta in(0,1)`, positivity makes the candidate a convex combination of the same values, so its error is at most Delta. Splitting at `D_r>=eta` and using one-sided Cantelli gives

```
E||yhat-y||² <= min(Delta²,
                   A/(r eta²) + Delta² B/[B+r(1-eta)²]).    (7)
```

This is valid at every positive r for the stated iid features. It can be very weak; common large noise with A=0 already illustrates an unnecessary tail penalty. It is not applied to the fixed FP16 feature table in the real experiment, whose distribution and independence are not guaranteed by the ideal Gaussian model.

### Actual large-r output risk

For a fixed finite source row, the delta method yields

```
lim_{r->infinity} r E||yhat-y||² = A.                       (8)
```

Here expectation convergence, not only convergence in distribution, is justified. Each one-feature positive denominator D has all positive and negative moments: `D>=p_j R_j` for any fixed j, and R_j is lognormal. Jensen gives `E D_r^-8 <= E D^-8`. A centered iid numerator with finite eighth moment satisfies `E||T_r||^8=O(r^-4)`. Hence Cauchy bounds `E[(r||T_r||²/D_r²)²]` uniformly. Uniform integrability plus the multivariate CLT and `D_r->1` proves(8). No finite-r accuracy promise follows just from A, especially with enormous higher moments.

For several heads sharing the same random feature table, the complete O output is a sum of separately normalized heads. The analogous A includes **cross-head** terms:

```
sum_{h,g,i,j} p_hi p_gj (delta_hi dot delta_gj)
                       exp(z_hi dot z_gj),                 (9)
```

where each delta already includes its own O block and is centered under its own head probabilities. It is not in general the sum of per-head A values. The same fixed finite-row moment/CLT argument applies to the joint denominator vector. This matters for the real two-head observer but has not been numerically evaluated on that capture here.

## 3. A mean-exponent optimum can be the wrong output-risk center

Consider the exact two-key source `k=(-1,1)`, live values `(0,1)`, and two equiprobable queries `q=0,4`. Every key translation preserves teacher outputs `sigmoid(2q)`. The uniform-pair mean exponent is uniquely minimized by centroid **c=2**:

```
E_pairs (q+k-c)² = 5+(c-2)².
```

For either query the exact leading output risk is

```
A_q(c) = [p_q(1-p_q)]² *
         [exp((q-c-1)²)+exp((q-c+1)²)-2exp((q-c)²-1)],
p_q = sigmoid(2q).                                        (10)
```

The witness compares only the predeclared, exactly representable centers **c=2 and c=1**, each an actual two-byte FP16 field. The centroid has mean exponent5; c=1 has mean exponent6. Nevertheless c=1 has mean output-risk A **2.17393988**, versus **252.05142621** at the centroid—a certified factor greater than115.94 in the wrong direction. `witness.py` certifies this comparison with rational upper/lower Taylor bounds for exp and exact interval arithmetic, rather than trusting a float optimizer. The exact interval values are in `results.json`. This is not a search for the optimal output-risk center, a finite-r win, or a real-source result. Direct `sigmoid(2q)` is the exact stronger reader on this toy.

For a **single** query with symmetric keys `m±d` and scalar nonconstant values, (10) generalizes to

```
A(c) = 2[p(1-p)]² (w1-w0)² exp(||u||²)
       [exp(||d||²) cosh(2u dot d)-exp(-||d||²)],
u=q+m-c.
```

It is minimized at u=0 because both exp and cosh factors are minimized there and the bracket is nonnegative. Different queries ask for different c. A query-dependent shift inside an online common feature prefix is not automatically an available operation; one must pay another state/program or give an exact transport of its labels. The source-pair centroid solves a different declared objective, not this constrained shared-output problem.

## 4. Key centering is a Gaussian importance proposal

There is a useful exact interpretation of the earlier key gauge. Put `z=q+k`, `t=omega+c`. Let `phi` be the standard Gaussian density and `rho_c(t)=phi(t-c)` the Gaussian with mean c. Then

```
R_c(omega) = R_0(t) * phi(t)/rho_c(t),
log[phi(t)/rho_c(t)] = -c dot t + ||c||²/2.                  (11)
```

Expanding squares proves this identity for every q,k,omega,c. It holds simultaneously for every key and query because its importance factor depends only on the sampled feature. Thus shifting keys while drawing standard Gaussian omega is equivalent, at the normalized ratio, to keeping the original key coordinates and drawing features from a **shifted Gaussian proposal with its importance weight**. The former can be cheaper to encode using one shared center rather than a changed full table, but it is not a new exact attention function. Finite table quantization and code/state realization are still separate.

For a fixed finite source law over query/prefix observations s, write the one-feature live-output influence `G_s(t)=sum_i p_si R_si(t) delta_si` (or the sum of head influences for a shared table). Under a positive proposal density rho, the average influence second moment is

```
A_rho = integral phi(t)² F(t)²/rho(t) dt,
F(t) = sqrt(E_s ||G_s(t)||²).
```

Cauchy gives the optimal-proposal lower bound

```
A_rho >= [integral phi(t) F(t) dt]²,                        (12)
```

attained by `rho proportional to phi F` where F is positive. If F vanishes on a set of positive Gaussian measure while full-support kernel unbiasedness is required, this is generally an **infimum**: mixing the proposed density with any positive amount of phi approaches it. If F is identically zero, output influence is zero and every proposal has zero leading risk. For an arbitrary rho, finite influence second moment alone does not prove the denominator moment conditions used in(8). The mixture `rho_epsilon=(1-epsilon)rho*+epsilon phi` bounds `phi/rho_epsilon<=1/epsilon`, so every positive epsilon preserves the required moments for a finite source law; its actual large-r coefficient approaches(12). The limiting density itself need not have that property. This is the standard optimal importance-sampling calculation, not a claimed sampler or a cheaply executable density. Knowing the entire source continuation law/teacher values to form F and sampling it are substantial obligations.

Equation(11) also yields `phi(omega) F_c(omega)=phi(omega+c) F_0(omega+c)`. By change of variables, the right side of(12) is **invariant under a common key translation**. Therefore centering changes the risk of the restricted standard-Gaussian feature program, but cannot lower the best unrestricted importance-proposal risk of that integral representation. Reciprocal non-orthogonal Q/K balancing changes the decomposition differently; this translation argument does not make its optimum invariant. Source-dependent proposals and jointly changed values are also distinct from picking more random seeds.

The finite rational exponent identities and importance Cauchy interface are the scope of `Kelana/KernelImportance.lean`; Gaussian density, integration and the optimization over actual proposal densities are analytical. They do not provide a finite-r or real-model gain. A query-dependent optimal center is not a free operation on one shared online prefix, while a fixed model-specific proposal must pay its fields and causal preparation.

## Scope and next decision

The finite rational identities/bound, exact packed ratio example and rational exponential comparison are independent of the failed real feature fit. Gaussian expectations, Euclidean vector extension, finite probability bound and CLT/UI bridge are analytical statements, not Lean claims. No new quantizer/cache image, no changed feature rank or seed, and no native runtime result is supplied by this study.

Use the complete observer to choose a representation; preserve key correlations and live-value directions when deriving a bound. A useful next program must still beat strong paid causal cache/state controls at comparable size and count the prefix update, denominator, finite arithmetic, table sharing and final O. Replacing one surrogate by another without a surviving executable map is not the requested outcome.

```sh
python3 research/isa-quantization/normalized-kernel-error/witness.py
lake env lean Kelana/NormalizedKernelError.lean
```
