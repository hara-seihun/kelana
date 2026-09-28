# Causal state-capacity certificates from token histories

A teacher-marginal clustering can assign the same emission law to several phases without asking whether a deterministic candidate can advance through those phases. This study supplies a **symbolic, all-state-capacities** obstruction: a `C`-state token-driven candidate cannot emit law `A` for `C` successive teacher phases and then law `B≠A` with zero sequence KL. The finite-loss version has an explicit positive bound for every `C`, without enumerating transitions, labels or emission codes. A companion right-suffix certificate works on arbitrary selected token histories, not only repeated tokens.

## All-C changed-final-law theorem

Fix integer `C≥1` and sequence horizon `H=C+1`. The teacher starts at phase zero, advances one phase after **every** token, emits the same full-support law `A` at times `0,…,C−1`, and emits a different full-support law `B` at time `C`. A candidate has at most `C` states, one deterministic transition `U(c,a)` per token and stationary state-only emission laws `q_c`. Its initial state and all transitions/emissions are otherwise free. The candidate's state is always recomputed on the **same history** as the teacher, using its own `U`.

For any token `a` of teacher probability `α_a=A(a)>0`, follow candidate states `c_i=U(c_{i−1},a)` on the repeated history `a^i`. Finite-state determinism forces **the last state** `c_C` to equal some `c_i`, `0≤i<C`: among `C+1` prefixes there is a repeated state; applying the *same* token to both sides of an earlier collision carries it forward until one occurrence is at `C`. Thus exact matching would give `q(c_i)=A` and `q(c_C)=B`, impossible. A `C+1`-state clock advancing independently of tokens emits `A,…,A,B` exactly, so **`C+1` states is the sharp threshold for exact behavior** in this contract. This is stronger than a generic pigeonhole assertion that *some two* prefixes collide: those could both belong to the `A` phase.

Write the weighted Jensen–Shannon merge cost

```
J(u,v;A,B) = min_q [u KL(A||q) + v KL(B||q)],
q* = (u A + v B)/(u+v),
```

with `J(0,v)=J(u,0)=0`. It is nondecreasing in either nonnegative weight and homogeneous in both. Autoregressive sequence KL is the sum over token histories of the teacher's history probability times `KL(teacher next-token law || q(candidate own state))`. The two demands on the repeated-`a` collision carry masses `α_a^i` at time `i` and `α_a^C` at time `C`. When `i=0`, allocate only `α_a` of the time-zero mass 1 to this ray; this avoids charging the shared empty history once **per** token. Different rays `a^i` for `i≥1` and `a^C` occupy disjoint history cells, so the charges may be added. Since `i≤C−1` and `0<α_a≤1`, every candidate obeys

```
KL(P(Y₀:C+1)||Q(Y₀:C+1))
  ≥ δ_C(A,B)
  := Σ_{a:A(a)>0} J(α_a^max(1,C−1), α_a^C; A,B).             (1)
```

For `A≠B`, `δ_C>0`, even though the teacher emission laws admit a **zero** noncausal two-label marginal-clustering floor. This is a bound on the *complete* sequence law under the stated horizon, not a one-step squared-error heuristic. The candidate emissions are optimized over all distributions in (1), so any finite paid alphabet only increases actual loss. The same certificate applies to every partial transition program whose completed machine has at most `C` states. If target KL `ε<δ_C`, every candidate must have at least `C+1` distinguishable live states; under a fixed-width state register this implies at least `⌈log₂(C+1)⌉` state bits, separately from static transition/emission bytes.

**Sharpness:** at `C=1`, (1) equals `J(1,1;A,B)`, the exact optimum of a one-state candidate. For `C>1` it is a lower bound, **not** a claimed optimum: other histories can force additional loss. A `C`-state clock emits `A` on phases `0,…,C−2` and uses the centroid `(A+B)/2` on its last state at phases `C−1,C`, giving feasible score `J(1,1;A,B)`. Let one token's probability in full-support `A` tend to one while keeping `B` distinct. That token's term in (1) tends to `J(1,1;A,B)` at the limit, and other terms vanish. Hence the explicit bound is asymptotically sharp in this family; no larger uniform-in-`A` lower bound can replace it. At the boundary where `A` is concentrated on that token, the clock attains it exactly (provided the KL terms are interpreted on teacher support).

For binary `A=(1/2,1/2)`, `B=(1/4,3/4)`, the **symbolic** all-`C≥2` formula reduces to `δ_C=2^(2−C) J(1,1/2;A,B)`. At `C=2`, it is `0.0444751461179391` nats; using only one repeated-token ray gives `0.02223757305896955`. The feasible two-state clock scores `J(1,1)=0.06764415113721046`. These three values distinguish a bound, a weaker witness and a paid-program upper bound; the exact `C=2` optimum is not inferred from them. [`certificate.py`](certificate.py) evaluates these expressions with rational log enclosures; it does **not** enumerate `C` values or candidate machines.

## Right-suffix certificate for arbitrary histories

A more general certificate starts with **any** `C+1` teacher-positive histories `h₀,…,h_C`, potentially on different branches and at different lengths. For each pair `i<j`, choose one common suffix `u_ij` whose two extended histories fit the horizon. Let `w_i=Pr_P(h_i u_ij)>0`, `w_j=Pr_P(h_j u_ij)>0`, and `P_i,P_j` be the teacher next-token laws after those extended histories. Because `C+1` candidate prefix states occupy only `C` labels, some pair has identical candidate state after `h_i,h_j`. Reading the *same* `u_ij` keeps them identical, while their teacher histories carry their own laws. Taking just those two nonnegative terms from sequence KL gives the computable certificate

```
KL(P||Q) ≥ min_{i<j} J(w_i,w_j;P_i,P_j).                    (2)
```

It is strictly positive if every selected pair has positive mass and distinct future laws under its chosen suffix. This is a **quantitative right-distinguishability/fooling-set** criterion; (2) needs `O(C²)` scored pair witnesses after the histories and suffixes have been identified, not candidate transition enumeration. Pair-specific suffixes are allowed. It can apply when the current emissions of all `h_i` coincide and only their future consumers distinguish them. As with (1), cost and a second behavioral lower bound may be combined via `max`, not addition, unless disjoint charged history cells are proved.

A branching example takes two-state candidate capacity, prefixes `ε,0,1`, common suffix `0`, teacher initial emission `(1/2,1/2)`, emission after `0` equal to `(1/4,3/4)`, after `1` equal to `(1/2,1/2)`, after `00` equal to `(1/2,1/2)`, and after `10` equal to `(3/4,1/4)`. Other prefix emissions may be any full-support law. After the suffix the three laws are pairwise distinct, with history masses `Pr(0)=1/2`, `Pr(00)=1/8`, `Pr(10)=1/4`. Their three pairwise merge scores have strict minimum `J(1/8,1/4;(1/2,1/2),(3/4,1/4))=0.011465629385859556` nats. Thus **every** two-state candidate has at least that three-token sequence KL; no repeated single-symbol orbit assumption or candidate fit is used. This is a legitimate finite prefix-tree teacher, with arbitrary full-support continuation after the scored depth.

## Formal and executable status

[`Kelana/CausalStateCapacity.lean`](../../../Kelana/CausalStateCapacity.lean) proves, for **every `C`**, collision of arbitrary `C+1` prefix states, last-state repetition on a unary orbit, impossibility of stationary `A,…,A,B` exact readout with `C` states, and preservation of a state collision under a common token suffix. It reuses the repository's symbolic finite pigeonhole theorem. It does **not** formalize KL, the multiray mass allocation, centroids or rational logarithm bounds; those proofs are above. [`results.json`](results.json) stores rational-input, 24-term atanh-series log enclosures with explicit geometric tails and display decimals. The source computes only illustrative constants, not a search over `C` or candidate programs.

From the repository root, CPU only, seconds:

```
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python research/isa-quantization/causal-state-capacity/certificate.py
lake build Kelana.Information && lake env lean Kelana/CausalStateCapacity.lean
```

The theorem requires deterministic token-driven candidate transitions and stationary readout from at most `C` live states. Time-dependent emissions, stochastic hidden transitions, an external phase clock, or a larger cache extend the candidate state contract and may evade this capacity bound. A zero marginal floor is not evidence of a cheap implementation, and the bit observation above concerns **dynamic state cardinality**, not serialized model BPW or native latency.
