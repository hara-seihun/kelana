# A continuation score for the candidate's *own* finite state

For a deterministic finite-state autoregressive program, the continuation is not an unspecified downstream penalty. The teacher's token-conditioned state and the candidate's token-conditioned state form a **product machine on the same history**. Its occupation measure yields the exact generated-sequence KL; optimizing unrestricted candidate emissions gives an admissible, computable **conditional-information floor** for any restricted emission/ISA family. This addresses the state gap left by [observation-loss](../observation-loss/README.md) and complements [stateful-maps](../stateful-maps/README.md) and [encoded-continuations](../encoded-continuations/README.md). It is not a claim about unrestricted language models.

## Contract and theorem

Let finite teacher and candidate states be `S,C`, tokens `A`, initial pair `(s₀,c₀)`, teacher emissions `p_s(a)>0`, candidate emissions `q_c(a)>0`, and deterministic transitions `T(s,a), U(c,a)`. Both programs start at their own initial state, and after the **same token history** each follows its own transition. For a fixed length `H`, define `w_H(s,c)=Σ_{t=0}^{H-1} Pr_P((s_t,c_t)=(s,c))`. For a normalized geometric horizon put `w_γ(s,c)=(1−γ)Σ_{t≥0}γ^t Pr_P((s_t,c_t)=(s,c))`, `0<γ<1`. The finite product transition is

```
M[(s,c),(s',c')] = Σ_{a:T(s,a)=s', U(c,a)=c'} p_s(a),
w_γ = (1−γ)e_(s₀,c₀) (I−γM)⁻¹.
```

The inverse exists because `M` is stochastic and `γ<1`. Rational `p,γ` give rational occupation weights. The autoregressive KL chain rule, **with candidate state recomputed on teacher-drawn histories**, gives the exact finite-horizon sequence score

```
KL(P(Y₀:H) || Q(Y₀:H)) = Σ_{s,c} w_H(s,c) KL(p_s || q_c).       (1)
D_γ(U,q) = Σ_{s,c} w_γ(s,c) KL(p_s || q_c).                     (2)
```

`D_γ/(1−γ)` is the KL of generated sequences with an independent, observed length `L≥1`, `Pr(L=n)=(1−γ)γ^(n−1)`, identical in both systems. Indeed `Pr(L>t)=γ^t`; the length itself contributes no KL. Unnormalized infinite-horizon KL is not generally finite. If teacher emissions lack full support, restrict pair reachability to positive-probability histories and allow infinite KL when candidate assigns zero to a teacher-possible token.

For a *fixed candidate transition* `U`, put `W_c=Σ_s w(s,c)` and `m_c(a)=Σ_s w(s,c)p_s(a)`. For `W_c>0`, the unconstrained optimum is `q*_c(a)=m_c(a)/W_c`. Direct expansion of the logarithm proves the exact identity

```
D(U,q) = F(U) + Σ_{c:W_c>0} W_c KL(q*_c || q_c),
F(U) = Σ_{s,c} w(s,c) KL(p_s || q*_c) = I_w(S;A | C).          (3)
```

The conditional mutual information uses the joint distribution `Pr(s,c,a)=w(s,c)p_s(a)` (normalize `w_H` by `H` for that interpretation). Thus `F(U)` is an **admissible lower bound** for every restricted native-emission family, no matter how its weights, labels or instruction constants are packed. It is tight if arbitrary time-homogeneous `q_c` is allowed. It is zero exactly when, at each candidate state `c`, all teacher states reached with positive occupation have identical next-token distributions. This is a reachable *emission-lumping* criterion, not equality of intermediate state or coefficients. It holds for each finite `H`, or for the discounted infinite continuation. If the candidate may condition its emission on `t`, include `t` in `C`; silently allowing time dependence in (3) would produce a weaker floor.

A search can enumerate/construct `U`, solve the rational product occupancy once per `U`, discard `U` when `F(U)` exceeds an allowed KL budget, then enumerate paid emissions `q` and compute the nonnegative second term exactly as a finite log expression. For a multiobjective search retain `F(U)` with transition cost and paid state width. The relaxation does **not** bound an incomplete transition structure unless every possible completion is accounted for. Teacher probabilities and prompt/domain support must be specified. This scores behavior, not static bytes or native execution; no free label conversion is inferred.

## A falsifiable two-state construction

Take `A=S=C={0,1}`, `s₀=c₀=0`, `T(s,a)=a`, `p₀=(1/2,1/2)`, `p₁=(1/4,3/4)`, `γ=1/2`. Enumerate all `2⁴=16` binary candidate transition tables `U(c,a)`; candidate emissions are optimized without any price restriction. Exactly **one** transition has zero floor: `U(c,a)=a`. This is also a structural proof, not just an enumeration: positivity and `p₀≠p₁` force the candidate states after tokens 0 and 1 to differ. Because initial `c=0` already carries teacher `s=0`, token 0 must land in `c=0` and token 1 in `c=1`; subsequent tokens from `c=1` must likewise land in 0 and 1. Every other transition has a reachable collision of teacher states with different emissions.

The best nonzero transition is `[0,1,1,1]` in `(c,a)` order. Its exact occupation `(w₀₀,w₀₁,w₁₀,w₁₁)=(2/3,1/21,0,2/7)`, with `q*₀=p₀`, `q*₁=(2/7,5/7)`, gives `F=0.00574900342019` nats per normalized discounted step. The next best floor is `0.00923470073848`. [`search.py`](search.py) proves this ranking by **rational interval bounds** for all logarithms (24-term atanh series with explicit tail), not by assuming rounded floating ranks imply an optimum; floats in [`results.json`](results.json) are display values. It also computes the exact rational occupancy for every candidate.

For the collapsed transition `U(c,a)=0`, the candidate remains at 0 after every history. The occupancy is `(5/7,0,2/7,0)` and `q*₀=(3/7,4/7)`. Its irreducible floor is `0.02713579155228`. A teacher-forced local comparison can set `q₀=p₀,q₁=p₁` and score **zero at every aligned `(s,c=s)`** while ignoring its incorrect state update. The candidate's actual normalized discounted KL is `0.03737486741175`, decomposing as `0.02713579155228` state-aliasing floor plus `0.01023907585947` emission penalty. At length two its sequence KL is already `(1/2)KL(p₁||p₀)=0.06540601797057`; both systems match the first-token distribution exactly. The reference-conditioned pair search catches this failure without sampling the candidate rollout separately.

## Proof status and reproduction

The chain rule and information-projection identity above are algebraic proofs under the stated finite, positive-support contract. The exact search's rational matrix solve and interval-comparison assertions are executable certificates for the toy instance. [`Kelana/BehavioralContinuation.lean`](../../../Kelana/BehavioralContinuation.lean) formalizes the common-history pair reachability, its word-mass consequence, and the collision obstruction for integer-weighted emission kernels. It does **not** formalize logarithms, the KL chain rule, rational occupancy inversion, or interval arithmetic. The Python assertions are not a Lean proof.

From the repository root:

```
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python research/isa-quantization/behavioral-continuation/search.py
lean Kelana/BehavioralContinuation.lean
```

Both commands take seconds on CPU. No GPU, large model, generated-sequence Monte Carlo, ISA lowering, token-table storage or throughput measurement is involved. The exact theorem requires finite deterministic token-driven state and stationary state-only emissions; a hidden stochastic candidate state, unbounded cache, continuous state, or a changed input/prompt law needs a new product process or a justified finite abstraction. An arbitrary observer may intentionally identify some outputs, but KL specifically observes the whole next-token distribution. Teacher KL does not certify gold-token loss on rare individual labels, as the softmax-boundary examples explain.
