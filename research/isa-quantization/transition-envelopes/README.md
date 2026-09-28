# Bound incomplete transitions without completing them

The fixed-transition information floor in [behavioral-continuation](../behavioral-continuation/README.md) cannot directly prune a *partial* candidate transition table: a missing edge can change every future candidate state. Here a Bellman **transition envelope** lets every missing edge choose its next candidate state separately on each encounter, even with knowledge of the teacher state and remaining horizon. This illegal extra freedom makes the score a sound lower bound for **all globally consistent completions at once**. The candidate emission code remains one stationary, globally shared assignment, chosen *outside* the Bellman recurrence; future destinations and those emissions remain coupled. This supplies a finite search decision rather than a larger exhaustive state census.

## A sound relaxation with paid codes

For a finite teacher `(S,A,p,T)`, candidate states `C`, horizon `H`, a partial deterministic candidate transition `K:C×A→C∪{?}`, and a fixed candidate emission `q_c`, let `ell_q(s,c)=KL(p_s||q_c)`. Set `V⁽q⁾_0=0` and

```
V⁽q⁾_h(s,c) = ell_q(s,c) + Σ_a p_s(a) ·
  { V⁽q⁾_(h−1)(T(s,a), K(c,a))                  if K(c,a) is fixed,
    min_d∈C V⁽q⁾_(h−1)(T(s,a),d)                if K(c,a)=? .       (1)
```

For every completion `U⊇K`, induction on `h` gives `V⁽q⁾_h(s,c)≤D⁽q,U⁾_h(s,c)`, where `D` obeys the exact same recurrence with `U(c,a)` on every edge. The teacher draws the common token; the candidate follows its **own** transition. The oracle at an unknown edge may illegally use `s`, `a` and `h` and even change its choice on the next visit. That is precisely why it is a relaxation. It never replaces the candidate state by the teacher state. For full `K`, (1) is equality and is the exact generated-sequence KL chain rule.

Suppose the finite paid emission-code set is `Q`, its complete static cost is `b_E(q)`, a completion costs `b_T(U)`, and `b_T^−(K)≤b_T(U)` for every extension. Given byte/bit budget `B`, nonnegative price `λ`, initial `(s₀,c₀)`, compute

```
LB(K;B,λ) = min_{q∈Q : b_T^−(K)+b_E(q)≤B}
             [ V⁽q⁾_H(s₀,c₀) + λ(b_T^−(K)+b_E(q)) ].          (2)
```

The minimum over the superset of feasible emission assignments, with (1) and monotone paid cost, is ≤ every feasible completed program's `KL_H+λ bits`. If the set in (2) is empty, no completion is feasible. Compare the lower bound with an **upper** bound from a concrete serialized program and prune when strictly greater. Exact minimization over the finite emission codes preserves their cross-history sharing; moving `min_q` inside (1), or optimizing independent emissions per `(s,c,h)` visit, would weaken the result. Equation (2) is polynomial in `H,|S|,|C|,|A|` for each emission assignment and **does not enumerate missing transition completions**. Enumerating `Q` can still be expensive for many candidate states; a separate admissible emission relaxation would then be needed. This is not an unconditional polynomial algorithm for joint program synthesis.

For a baseline, a *forced-prefix* recurrence uses zero continuation after the first unknown edge, rather than the `min_d` term. KL is nonnegative, so it is sound but can forget a large unavoidable future mismatch. The envelope retains all remaining stages and their state/emission interaction, despite relaxing the unknown transition choices.

## Exhaustible paid grammar and strict decision

[`search.py`](search.py) uses `S={0,1,2}`, `C=A={0,1}`, `s₀=c₀=0`, `H=7`, teacher emissions `p_s(1)∈{3/4,1/2,1/4}`, and teacher transitions `(T(s,0),T(s,1)) = (0,1),(2,0),(1,2)`. Each candidate state has a single stored emission choice `q_c(1)∈{1/4,1/2,3/4}`. The candidate transition has four Boolean entries. All 16 transition tables and 9 emission pairs are small enough for an *independent post-search oracle*.

Static logical bit accounting is a fully framed two-field code, not a free decoder: the transition field is one mode bit (`0` means the hardwired self-loop `U(c,a)=c`; `1` means four paid transition bits), and the emission field is one mode bit (`0` means both probabilities `1/2`; `1` means two two-bit alphabet entries). Thus each field is 1 or 5 bits, total 2, 6 or 10 bits. One of four two-bit emission words is unused. The hardwired defaults and runtime reading logic are shared code and not charged per instance; alignment, packing, instruction cost and initial-state conversion would matter in an ISA realization. `b_T^−(K)=5` once any fixed edge deviates from self-loop, otherwise `1`. This is ≤ the cost of every completion. The header bits are paid even for defaults.

| Objective/budget | Best completed `(U,q₀(1),q₁(1))` | Certified KL+λ bits | Forced-prefix nodes | Envelope nodes | Completed leaves (envelope) |
| --- | --- | ---: | ---: | ---: | ---: |
| `λ=0`, `B=10` | `([0,1,1,0],3/4,1/2)` | `0.3425761180` | 29 | **23** | 7 / 16 |
| `λ=.015`, `B=10` | `([0,1,1,0],3/4,1/2)` | `0.4925761180` | 27 | **19** | 2 / 16 |
| `λ=.04`, `B=10` | `(self-loop,1/2,1/2)` | `0.6395599809` | 27 | **13** | 1 / 16 |
| `λ=.015`, `B=6` | `(self-loop,1/2,1/2)` | `0.5895599809` | 29 | **9** | 1 / 16 |

All transitions are listed in `(c=0,a=0),(0,1),(1,0),(1,1)` order. The root bound at `λ=0,B=10` is `0.1925772892` for the envelope versus `0` for forced-prefix: the first emitted token can match perfectly, but seven future steps cannot all be matched with two **shared** emission constants even when missing edges are teacher-aware. At the partial prefix `[1,0,?,?]`, the envelope bounds every completion by `0.4747963562`, above a feasible `0.3425761180` incumbent, while forced-prefix gives only `0.2874205479`. Four completion tables are cut at that node, before any is evaluated. Under `λ=.015,B=6`, `[0,1,?,?]` similarly has envelope bound `0.6495599809`, forced-prefix `0.2644054024` and incumbent `0.5895599809`. This is *strict pruning from the coupled future*, not just a bit-budget rejection.

The pruned search starts with three concrete inexpensive controls (self-loop, token-as-state, constant-zero), never uses the exhaustive optimum to seed itself, and runs the full 16-table oracle **afterward** to check the answer. All reported KL intervals use rational arithmetic: 24 terms of the `atanh` log series plus a rational geometric tail, nonnegative clipping of KL lower bounds, and comparison of a rational Bellman **lower** to a rational feasible **upper**. The global lower/upper interval, the strict lower bound on every competing full program, and the pruning witness are in [`results.json`](results.json). Each run takes under one second including exhaustive validation. On this tiny grammar the bound's overhead can exceed the saved leaf work; node pruning and the logical bound, not an inference-time or large-search speedup, are the result.

## Proof status and limits

[`Kelana/TransitionEnvelope.lean`](../../../Kelana/TransitionEnvelope.lean) proves the Bellman order for any teacher state type with two tokens, two candidate states, nonnegative integer emission/transition weights, every horizon, and every completion consistent with the partial table. It also proves monotonicity of the 1/5-bit transition cost. The real-valued KL chain rule, rational log interval routine, budget minimization and this instance's search frontier are not Lean-formalized. Positivity of teacher probabilities is used to interpret the arithmetic as a generated-sequence KL; nonnegative Bellman weights alone suffice for the order proof.

Reproduce from the repository root:

```
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python research/isa-quantization/transition-envelopes/search.py
lean Kelana/TransitionEnvelope.lean
```

The relaxation is loose when illegal history-/teacher-aware choices exploit a missing edge; a zero envelope cannot certify a zero-error completion. Its free-edge `min` assumes every candidate destination is legal and imposes no global use/count constraint; restricting those options can strengthen it only when all actual completions remain included. Costs here are logical static bits for a declared serialized grammar, not measured native instructions or effective model BPW. Unlike a full fixed-transition information floor, this bound can be applied *before* any missing edge is selected, but its finite emissions are enumerated; continuous emission families, hidden stochastic candidate state, and unbounded KV-cache continuations require additional relaxations or a justified abstraction.
