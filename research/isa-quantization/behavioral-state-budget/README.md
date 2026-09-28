# A marginal state budget, and the causal information it forgets

The teacher's occupancy marginal is fixed even when the candidate evolves its **own** state. That yields a transition-independent lower bound on future sequence KL. Minimizing over arbitrary couplings between teacher and candidate states does **not** require stochastic channels: a deterministic clustering attains the minimum. For binary-token teacher emissions, the clusters can be chosen as contiguous intervals after sorting their Bernoulli probabilities, giving an `O(C |S|²)` dynamic program rather than transition or emission-code enumeration. The relaxation can nevertheless score zero where *every* two-state candidate has positive sequence KL; a three-phase witness identifies the missing causal constraint and quantifies it.

## Fixed teacher marginal and deterministic clustering

For a finite-horizon teacher with stationary next-token laws `p_s` and state occupancy `ν_s=Σ_{t<H} Pr_P(s_t=s)`, any candidate's same-history product occupancy `w(s,c)` satisfies `Σ_c w(s,c)=ν_s`. Its sequence KL is `Σ_{s,c} w(s,c) KL(p_s||q_c)`, with candidate state computed by its own token-driven transition as in [behavioral-continuation](../behavioral-continuation/README.md). Drop causal consistency and allow **any** channel `r(c|s)` with `w(s,c)=ν_s r(c|s)`. For `C` available labels, define

```
L_C(ν,p) = min_{r,q} Σ_s ν_s Σ_c r(c|s) KL(p_s||q_c).
```

For any fixed *globally shared, stationary* `q`, choosing for each `s` a single minimizer of `KL(p_s||q_c)` costs no more than a convex mixture of labels. Since deterministic channels are in the relaxed family, exchanging the two minima proves

```
L_C = min_{f:S→{1..C}} Σ_s ν_s KL(p_s||q_{f(s)})
    = min_f Σ_{c:W_c>0} Σ_{s:f(s)=c} ν_s KL(p_s||p̄_c),
p̄_c(a) = Σ_{s:f(s)=c} ν_s p_s(a) / W_c,    W_c=Σ_{s:f(s)=c}ν_s.
```

The second equality is the KL centroid identity. Empty labels cost zero. This is weighted KL/Bregman clustering, with no candidate transition or emission constants enumerated. It is a lower bound on **every** deterministic candidate with at most `C` states, including every completion of a partial transition table. It also applies to an infinite discounted occupancy whenever the total teacher marginal is finite. Positive source probabilities avoid infinite log boundary issues; zero-weight states can be removed.

For binary tokens write `p_s=p_s(1)` and sort these scalars. There is a global optimum with contiguous source clusters: with fixed centroids `q_i<q_j`, the difference `KL(Bern(p)||Bern(q_i))−KL(Bern(p)||Bern(q_j))` is affine and strictly increasing in `p`. Its nearest-centroid cells are intervals; reassigning to nearest centroids cannot increase a putative optimum, and reoptimizing centroids cannot increase it either. Hence interval costs `J(i,j)=Σ_{s=i}^{j−1}ν_s KL(p_s||p̄_[i,j))` and the recurrence `D(j,k)=min_{i<j}(D(i,k−1)+J(i,j))` compute the exact free-emission floor for `k` nonempty labels in `O(k|S|²)` after sorting. This contiguity statement is **specific to one-dimensional Bernoulli probabilities**; general vocabulary simplices retain the deterministic-clustering theorem but not this sorting argument. For three distinct equal-weight Bernoulli laws `(1/4,1/2,3/4)`, the two-label DP floor is `0.0676441511372` nats, versus `0.2616240718823` for one label. These are sequence-sum losses for one observation from each state, not normalized per step.

[`Kelana/BehavioralStateBudget.lean`](../../../Kelana/BehavioralStateBudget.lean) proves the fixed-emission deterministic-choice inequality for an integer-weighted two-label channel, including its sum over any finite list of source rows. The algebraic KL centroid and Bernoulli interval theorem are proved above but not formalized in Lean. The runner supplies rational log intervals and a small DP witness, not an exhaustive proof of sorting for all inputs.

## A zero marginal floor with unavoidable own-state loss

Take `H=3`, deterministic teacher phases `0→1→2`, independent of token, starting at 0. Let `p₀=p₁=Bern(1/2)` and `p₂=Bern(3/4)`; both tokens have positive probability. Then `ν=(1,1,1)` and `L₂=0`: the channel labels phases `0,1` together and phase `2` separately. Yet **no deterministic two-state token-driven candidate with stationary emissions can have zero generated-sequence KL**. The proposed labels are not a right congruence: the same candidate state for teacher phases 0 and 1 cannot both stay in the first emission class and advance into the second on an identical next token.

There is a strictly positive bound without enumerating candidate transitions. Fix the teacher-history prefix `00`. Write `c₀` for candidate initial state, `c₁=U(c₀,0)`, `c₂=U(c₁,0)`. The first occurrence of 0 has probability `1/2`, and `00` has probability `1/4`. If `c₁=c₀`, determinism forces `c₂=c₀`: this state's emission is compared with `Bern(1/2)` at time 0 with mass 1 and `Bern(3/4)` at time 2 on `00` with mass `1/4`. If `c₁≠c₀` and `c₂=c₀`, the same pair of demands holds at `c₀`. Otherwise `c₂=c₁`, whose emission sees `Bern(1/2)` at time 1 on prefix 0 with mass `1/2`, and `Bern(3/4)` at time 2 on prefix `00` with mass `1/4`. Discard all other **nonnegative** KL terms and optimize that one shared emission. With `J(u,v;A,B)=min_q[u KL(A||q)+v KL(B||q)]`, monotonicity in `u` gives, for *every* candidate transition and emission,

```
KL(P(Y₀:₃)||Q(Y₀:₃)) ≥ J(1/2,1/4;Bern(1/2),Bern(3/4))
                        = 0.02223757305896955… nats  > L₂=0.
```

The minimizing shared Bernoulli probability is `7/12`. This is a **causal collision certificate**: it requires two different teacher phases to reach the same candidate state along one legal token history, unlike the arbitrary source-conditioned marginal channel. It holds even for arbitrary real-valued candidate emissions. With an incomplete transition table, take the minimum over the collision cases still permitted by its fixed edges, and combine it with the marginal bound by `max`, **not addition**: they may count the same mismatch. The [transition envelope](../transition-envelopes/README.md) is another independent lower bound whose maximum is safe. Computing these case refinements on a large graph would require its own reachability procedure; only the universal two-state witness is implemented here.

## Accounting for paid candidate codes

The marginal floor can filter a paid search without listing emission codes. If `k` distinct candidate emissions are actually used, it satisfies `KL≥L_k`. If a serializer necessarily pays at least `b_E^−(k)` bits for `k` distinct laws and `b_T^−` for its transition, then for `λ≥0`, every feasible candidate with budget `B` obeys a bound obtained by minimizing `L_k+λ(b_E^−(k)+b_T^−)` over `k` whose lower paid cost fits `B`. This is sound even if real native emissions are grid-constrained, since the marginal optimization *relaxes* them. The assignment of `k` must use **reachable** distinct emission laws; unused paid entries can only add cost. Be careful: `min(L_C, paid bits)` is not a bound, and independently minimizing bit cost and a fixed transition information floor can assume incompatible witnesses unless each relaxation individually contains every candidate.

For a concrete logical-bit grammar, use the framed fields from [transition-envelopes](../transition-envelopes/README.md): transition self-loop default 1 bit, otherwise 5; emissions both `1/2` default 1 bit, otherwise 5 for two two-bit grid entries in `{1/4,1/2,3/4}`. Total costs are `2,6,10` bits. If **either** field is default, the emitted distribution is constant along every history (`c₀` never changes, or both emissions equal `1/2`). For fewer than 10 bits, the best legal grid constant is `1/2`, and the **exact** minimum sequence KL is `KL(Bern(3/4)||Bern(1/2))=0.1308120359411` nats: only the third teacher emission differs. Thus a budget of six bits forbids *any improvement over the two-bit default*, regardless of the four candidate transition choices, without enumerating them. Ten bits are necessary, not sufficient, for an improvement; their own-state KL remains at least the causal `0.0222375731` floor. At `λ=.01` nats per stored bit, `B=6` has exact optimal objective `0.15081203594` (default feasible), whereas with `B=10` the proven lower envelope is `min(0.1308120+2λ,0.0222376+10λ)=0.12223757306`. No claim that the ten-bit lower envelope is attained is made.

The pure state-budget floor in this witness, `L₁=J(2,1)=0.0889502922359`, `L₂=0`, would miss the low-bit grid's `0.130812` penalty and the causal `0.0222376` obstruction. Its value is a transition- and emission-code-free screen on generic source laws, not a replacement for transition envelopes or paid-code evaluation. In particular duplicate teacher laws allow it to vanish at a state budget that is causally impossible.

Reproduce in well under a second on CPU from the repository root:

```
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python research/isa-quantization/behavioral-state-budget/derive.py
lean Kelana/BehavioralStateBudget.lean
```

[`results.json`](results.json) records rational-input bounds (24-term `atanh` series with rational geometric tails; displayed decimals only), the clustering DP, the causal collision and the paid-code decision. This is finite exact **ideal probability arithmetic**, not model-transfer evidence, ISA throughput, or a universal hidden-state reduction. Bernoulli one-dimensional ordering does not transfer to arbitrary vocabulary laws or to constrained nonlinear emission parameterizations without a separate containment argument.
