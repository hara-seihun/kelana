# One shared emission subspace: a cheap global-label KL certificate

The [categorical-tree study](../categorical-tree/README.md) identified a structural failure: independent binary nodes may each need only two labels even when the complete categorical observer needs many. Trying every tree does not fix it. This study retains a different piece of the common-label constraint: **all candidate square-root emission laws lie in one C-dimensional subspace**. It gives an assignment-free behavioral floor and an independently checked matrix certificate. It also applies to a shared encoded label carried through several live contexts.

## Theorem: shared-label overlap bounds complete KL

Let `p_s` be teacher emission distributions on a finite vocabulary, with nonnegative teacher occupancy `ν_s` of total mass `M>0`. A candidate has at most `C` stationary emission laws `q_c`. Its own-state occupancy `w(s,c)` may be arbitrary subject to `Σ_c w(s,c)=ν_s`; in particular it may come from an autoregressive candidate whose state is a deterministic function of the token history under its own transition program. Define unit square-root vectors and a trace-one positive semidefinite density:

```
a_s = (sqrt(p_s(y)))_y,
ρ = Σ_s (ν_s/M) a_s a_sᵀ.
```

Let `Λ_C(ρ)` be the sum of the largest `min(C,V)` eigenvalues of `ρ`. Then every such candidate obeys

```
Σ_s,c w(s,c) KL(p_s || q_c) ≥ −M log Λ_C(ρ).                 (1)
```

The source occupancy, not an aligned candidate-state approximation, defines `ρ`. Candidate deterministic transitions, arbitrary assignments, code-field choices and emission fitting are all relaxed; there is no transition or partition enumeration in the bound. This does **not** bound token-sequence KL for a stochastic hidden-state model whose predictive law is a history-dependent mixture of the `q_c`: that mixture is not one fixed emission, and taking its square root does not preserve the C-dimensional span. The theorem bounds the displayed occupancy-weighted conditional KL, which equals sequence KL under the stated deterministic own-state contract. For example, square roots of `(1/2,1/2,0)`, `(1/4,1/2,1/4)`, and `(0,1/2,1/2)` have rank three even though the middle law is a mixture of the endpoints. A two-component mixture decoder with an extra varying mixture weight therefore has more live information than the two fixed-label decoder bounded here.

**Proof.** Let `b_c=sqrt(q_c)` and let `P` project onto their common span, of dimension at most `C`. Jensen's inequality gives the Bhattacharyya bound

```
KL(p_s||q_c) ≥ −2 log <a_s,b_c>.
```

Because `b_c` is a unit vector in that span, Cauchy–Schwarz gives `<a_s,b_c>² ≤ ||P a_s||²`. Hence each occupied label costs at least `−log ||P a_s||²`, independently of `c`. Sum over actual product occupancy and use convexity of `−log`:

```
loss ≥ Σ_s ν_s [−log ||P a_s||²]
     ≥ −M log [Σ_s (ν_s/M)||P a_s||²]
     = −M log tr(Pρ)
     ≥ −M log Λ_C(ρ).
```

Zero overlap means infinite KL on that occupied source support and causes no exception. The final spectral variational bound follows by expanding an orthogonal projector in an eigenbasis: its diagonal entries lie in `[0,1]` and sum to at most `C`, so its trace against `ρ` cannot exceed the `C` largest eigenvalues. No claim of novelty is made for these standard inequalities; their composition is a useful candidate-family certificate here.

For a fixed sequence horizon `H`, teacher occupancy has mass `M=H`. For a normalized geometric horizon use its corresponding occupancy mass. An empirical response panel alone is not a certificate about unseen autoregressive histories. The same proof also covers arbitrary source distributions with integrable occupancy and finite vocabulary; a finite enumerated teacher is not a mathematical necessity.

## Why this survives the tree counterexample

For `V` equally occupied, different point-mass laws, `ρ=I/V`. Thus (1) is `M log(V/C)`. When `C` divides `V`, clustering equal-sized groups and emitting uniformly within each group **attains** it. The certificate is sharp for this family. Every independent binary-node tree floor is instead zero when `C≥2`.

With the strictly positive smoothed laws from categorical-tree, `V=4,C=2,ε=1/1,000,003`, the accepted subspace bound is **.69114719**, versus the exact categorical optimum **.69313098**. Even the best of all 15 vocabulary trees gives only **.0000117813**. This removes the lost global capacity in that obstruction without enumerating source assignments.

It does not recover every common-label restriction. For Bernoulli emissions and `C=2`, the vocabulary space already has dimension two, so (1) is zero even if many distinct probabilities cannot share two emission laws exactly. The ordered Bernoulli clustering bound can then be positive. In the generic four-token witness, the best tree bound is also stronger than the spectral one. Use their **maximum**, not their sum. Neither this subspace relaxation nor exact marginal clustering supplies causal memory; the [history-capacity certificates](../causal-state-capacity/README.md) address that different constraint.

## A live-context continuation uses the same label

Suppose an encoder `E(x)` produces at most `C` labels **before** a separately supplied context `t` is known, and the candidate continuation emits `q_{E(x),t}`. Let the complete observer score contexts with a fixed distribution `π(t)` independent of `x`. Define joint categorical laws

```
P_x(t,y)=π(t)p_{x,t}(y),    Q_c(t,y)=π(t)q_{c,t}(y).
```

Their KL is exactly the context-averaged complete loss. There are still only `C` candidate joint laws, so (1) applies in the joint `(t,y)` space. Different consumers may use different numeric decoders; what must survive is their **shared upstream label**. Independent per-context certificates can be much weaker.

A complete witness uses four inputs `(a,b)∈{1/4,3/4}²`, two equally weighted live contexts, and binary outputs. Context zero has probability `a`, context one has probability `b`. Each context individually admits an exact two-label readout, so both separate floors are zero. A shared two-label encoder instead has exact best context-averaged KL **.06540602**; its accepted joint subspace floor is **.03406741**. No choice of a free decoder can make the two incompatible source partitions the same upstream code.

This product-context premise is indispensable. If the context law depends on `x`, the lifted joint candidate is no longer simply one of `C` fixed distributions; use correctly conditioned bounds or another containing construction. If `E` is allowed to observe `t`, it can choose a different label partition and the shared-code conclusion does not apply. Likewise, an actual reader with other live source inputs is not a C-label-only decoder. These are complete machine-state boundaries, not naming conventions.

## Exact acceptance without trusting eigenvalues

The small numerical eigensolver in [`propose.py`](propose.py) proposes dyadic matrices `B+`, `B−` and scalar `t≥0` so that

```
ρ ≈ t I + B+ B+ᵀ − B− B−ᵀ.
```

The independent standard-library [`verify.py`](verify.py) reconstructs teacher probabilities and occupancy from exact rational inputs. Integer square roots enclose each amplitude to `2^-88`; positive products enclose every density entry. It computes an exact rational `δ` bounding the maximum absolute row sum of the symmetric reconstruction error. Hence

```
ρ ⪯ (t+δ) I + B+ B+ᵀ.
```

For any rank-at-most-C orthogonal projector,

```
tr(Pρ) ≤ C(t+δ) + ||B+||_F² =: U.
```

The verifier therefore accepts `−M log U` (or zero if negative) as the floor. It does not trust numerical eigenvalues, eigensolver orthogonality, optimizer status, or a floating PSD test. Any proposed factors yield a sound enclosure; poor proposals merely yield an uninformative bound. All displayed logarithms have rational atanh-series enclosures with geometric tails and outward rounding, shared with the categorical-tree arithmetic. The accepted certificate is the concrete matrix majorant, not an assertion that the eigensolver found a globally optimal subspace.

## Complete finite comparison

All cases have normalized occupancy `M=1`, two candidate labels, and a complete finite input/observer domain.

| Source laws / observer | Accepted subspace floor | Best independent-node tree | Exact shared categorical labels |
| --- | ---: | ---: | ---: |
| Four Bernoulli-product laws | .06933646 | .06850669 | .13081204 |
| Six generic four-token laws | .02869151 | **.05180352** | .07584540 |
| Four near-point-mass laws | **.69114719** | .0000117813 | .69313098 |
| Two live binary contexts, one shared input code | **.03406741** | separate-context floors both 0 | .06540602 |

The first three teacher-law fixtures come from the sibling categorical-tree report; the fourth is defined exactly by the shared-context construction above. [`certificates.json`](certificates.json) stores dyadic proposal fields and hashes of the normalized source laws/occupancy. [`results.json`](results.json) stores exact matrix-error allowances, overlap upper bounds, log intervals and complete-clustering controls. Proposal and acceptance each take substantially under a second on this host. No packed inference reader, BPW result, native latency or model perplexity is claimed; these are search-pruning certificates for explicitly stated observation/state contracts.

## Reproduction and proof status

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/isa-quantization/emission-subspace/propose.py
python3 research/isa-quantization/emission-subspace/verify.py
lake env lean Kelana/EmissionSubspace.lean
```

[`Kelana/EmissionSubspace.lean`](../../../Kelana/EmissionSubspace.lean) proves the finite rational row-error quadratic bound and the exact **positive-minus-negative Gram certificate**, with the row allowance charged only to the residual. The proof expands the negative Gram into a nonnegative sum of squares before dropping it; it does not assume PSD domination as a premise. It also proves explicit finite shared-emission coordinates. These foundations apply to every rational test vector, with arbitrary finite index sets.

The real/algebraic-density interval bridge, orthogonal-projector trace/Bessel bound, and KL/Jensen/occupancy arguments remain the analytic derivations above, not Lean theorems. The exact executable checker certifies its saved finite matrix witnesses, not the entire mathematical derivation by itself.
