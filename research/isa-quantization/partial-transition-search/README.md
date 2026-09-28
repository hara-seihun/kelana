# Possible labels from real partial programs: cheaper, not more consistent

The [partial-label study](../partial-label-capacity/README.md) supplied possible-label lists directly. Here a set-valued interpreter derives them from the **same partial recurrent transition table that the search will complete**. It gives a cheaper behavioral envelope on the existing [paid transition grammar](../transition-envelopes/README.md), retains the complete logical-bit/KL frontier, and exposes a general obstruction: even exact per-history possible labels can forget every causal state-capacity constraint in a family where every fixed completion has positive error.

## The containing interpreter and ordered envelopes

Let `K(c,a)` be a fixed destination or unknown, and `U` any deterministic completion. Start with `A_empty={c0}`. For each history `h` and token `a`, form

```
A_(ha) = union_{c in A_h} ({K(c,a)} if known, all candidate states otherwise).
```

Induction on the history gives `state_U(h) in A_h`. Unknown edges may choose anew on repeated visits in this interpreter; containment, not joint realizability, is the contract. A known suffix can contract the set again after an unknown edge. A forced-prefix bound that discards the entire continuation on its first unknown edge misses that recovery.

For fixed stationary candidate emissions `q`, write the reachability-label envelope

```
R_K(q) = Σ_{|h|<H} P_teacher(h) min_{c in A_h} KL(p_(s(h)) || q_c).     (1)
```

Every legal completion scores at least (1). Importantly, the **same q** serves every history: minimizing emissions independently inside each history would discard this constraint. For every fixed q the bounds obey

```
forced-prefix F_K(q) ≤ reachability R_K(q) ≤ Bellman V_K(q) ≤ D_U(q).  (2)
```

The first inequality retains the already-forced histories and adds nonnegative future costs. For the second, any history-/teacher-/time-aware unknown-edge policy allowed by the Bellman relaxation generates a state in `A_h` at each history. Its local loss is at least the independent minimum in (1); summing and minimizing over policies proves the inequality. The final inequality is the existing completion-containment result. For complete tables all three complete-state evaluations agree (forced prefix then has no truncation).

Add a nonnegative price times a containing lower bit cost and minimize **outside** the envelope over the same feasible superset of globally shared emission codes. The ordering and admissibility survive. Thus the new envelope cannot beat Bellman numerically on this contract. Its possible advantage is reduced work.

The interpreter need not enumerate the `2^H` histories. Propagate teacher probability mass over `(teacher state, possible-state bitmask)` at each depth, then accumulate `ν_K(s,mask)`. These are sufficient statistics for (1). Worst-case frontier size is `|S|(2^C−1)`, not a polynomial promise in the candidate state count C. The replay below uses at most nine such pairs. Every teacher-history probability is retained; it is not teacher-forced alignment of candidate state to source state.

## Existing grammar, exact acceptance, full bit frontier

[`search.py`](search.py) imports the teacher, horizon, finite emission alphabet and framed cost definition from the existing owner. It does **not** enlarge the state budget or fit a new teacher. The grammar has two candidate states, three teacher states, binary tokens, H=7, four Boolean transition fields, and emission choices `1/4,1/2,3/4` at each candidate state.

Each transition/emission section is one default-mode bit or a mode bit plus four payload bits. Default transitions self-loop; default emissions are both 1/2. Canonical total descriptions have **2, 6 or 10 logical bits**, occupying **1, 1 or 2 physical bytes** separately. We preserve the owner's logical-bit objective and report actual rounded bytes alongside it; they are not interchangeable quantities. Generic interpreter code is shared, as declared by that grammar. No native work price or model BPW is inferred.

The exact log intervals from the owner are outward-rounded once to a common integer scale `25*2^80`. Integer probability accumulation then provides rigorously outward KL numerators; the 80-bit grid does not assert that the underlying log interval is 80 bits tight. Search compares a lower numerator with a feasible upper numerator, never floating scores. All arms use this same backend, seed programs, branch order and objective. Timings exclude initial common log preparation and independent post-search acceptance.

The unpriced searches at **all three possible bit budgets**, rather than selected scalarizations alone, recover the complete error/logical-bit frontier:

| Stored image hex | Logical bits | Physical bytes | Complete sequence KL |
| --- | ---: | ---: | ---: |
| `00` | 2 | 1 | .5595599809 |
| `ad01` | 10 | 2 | .3425761180 |

There is no intermediate six-bit improvement. At its zero-price budget there are 18 programs with the same optimal observed emission map. These are real semantic ties, not strictly separated numerical optima. The deterministic winner minimizes logical bits, then transition tuple, then emission tuple. Distinct observed maps are separated by the rational intervals in all six tested objectives. An independent decoder reads the stored bytes, reconstructs both fields, then enumerates common teacher histories while running the decoded candidate's **own** transition. It checks every feasible program after the pruned searches, not just the winners.

## Actual bounded search result

| Price λ / bit budget | Forced-prefix nodes | Reachability nodes | Bellman nodes | Reachability search ms | Bellman search ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 / 2 | 9 | 9 | 9 | .24 | .15 |
| 0 / 6 | 31 | 31 | 31 | 1.72 | 2.67 |
| 0 / 10 | 29 | 23 | 23 | 1.77 | 4.65 |
| .015 / 10 | 27 | 19 | 19 | 1.26 | 3.64 |
| .04 / 10 | 27 | 17 | 13 | 1.09 | 2.52 |
| .015 / 6 | 29 | 9 | 9 | .42 | 1.17 |

These are one retained small CPU run, not a universal timing ratio. Reachability matches the Bellman node count in five settings and visits more in one; the two-bit case is budget-dominated and its extra work loses. At `.04/10`, the weaker bound visits more nodes but still runs faster in this implementation. A cheap-reachability-then-Bellman cascade reduces Bellman calls but often costs more than Bellman alone and always more than reachability alone here. Fewer expensive calls are not a speed result by themselves.

Concrete complete-continuation decisions at λ=0, budget10:

* At `[1,0,?,?]`, forced prefix .287421 does not reject the .342576 incumbent. Reachability .405650 does, while Bellman is stronger at .474796.
* At `[0,?,0,?]`, every 0 token contracts the possible-state set to `{0}`. Forced prefix is zero; reachability and Bellman both certify .404540.
* At the all-unknown root, reachability and Bellman both give .192577 on this particular three-law teacher, versus forced-prefix zero.

[`results.json`](results.json) records all counts, integer intervals, inline byte images, tie checks, timings and witnesses. Ordering (2) is also checked at all **81 partial tables × nine emission assignments**, not just the prefixes visited by a winning search. Bounds are never seeded by the exhaustive optimum.

## A general failure that stronger marginal geometry cannot cure

For **every C≥2**, consider the teacher clock from [causal-state-capacity](../causal-state-capacity/README.md): full-support law A for C phases, then B≠A at phase C, horizon C+1. In an all-unknown C-state table every nonempty history individually admits every destination (indeed, a constant-to-that-destination completion realizes it). Set the initial state's emission to A and a second state's to B. Every source history can now select an individually reachable state with its exact teacher law. Consequently even the **exact globally shared-emission list relaxation** has zero loss. The free-edge Bellman policy can likewise switch using time/teacher knowledge and has zero loss.

But no fixed C-state completion realizes that teacher. On a repeated positive token, the final state of a C-step orbit repeats an earlier state. It would have to emit both A and B. The earlier all-C theorem strengthens this to an explicit positive sequence-KL floor with correct multi-history mass charging. For the two-state Bernoulli clock the certified floor is .04447515. Thus the ratio between these marginal/adaptive envelopes and the actual optimum can be exactly zero for every C≥2, with positive source laws. More tensor powers, exact marginal clustering, or more accurate pointwise lists cannot fix the missing **shared-edge equality**.

The next object is a history-to-state coloring with right-congruence constraints: equally colored prefixes must have equally colored same-token children. It retains the defining consistency of an executable transition program rather than treating each reachable observation as an independent choice. This is a changed mathematical constraint, not a request for a larger transition census.

## Formal scope

[`Kelana/PartialTransitionReachability.lean`](../../../Kelana/PartialTransitionReachability.lean) proves universal fixed-completion containment for arbitrary words/frontiers, the readout consequence, and a repeated-use counterexample to joint realizability. Its all-unknown theorem shows every listed state is reachable after every nonempty word. `all_unknown_clock_gap` constructs the pointwise two-law fit for every C≥2 and proves no fixed C-state transition realizes the changed-final-law clock, using the existing general causal theorem. No KL or timing theorem is claimed in Lean. The real-KL envelope ordering is the argument above; exact integer intervals and independent byte replay certify the finite search decisions.

```sh
python3 research/isa-quantization/partial-transition-search/search.py
lake build Kelana.CausalStateCapacity
lake env lean Kelana/PartialTransitionReachability.lean
```
