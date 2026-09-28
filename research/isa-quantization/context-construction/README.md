# Constructing continuation contexts without listing suffix programs

The exact residual simulation in [continuation-context](../continuation-context/README.md) is the right quotient, but a direct test enumerates all legal suffix programs. A **stage-indexed observational separator** and a **future-paid-asset incidence projection** make an exact backward dynamic program possible when their widths are small. This is a constructive sufficient route to the exact frontier, not a theorem that all ISA grammars admit a narrow separator.

## The two separators

At remaining depth `h`, let `s` denote the **complete numeric machine state over every declared producer input**, not just a response at one input. Find a structural label `α_h(s)` such that:

1. At `h=0`, equal labels give the same complete observed response.
2. For each instruction choice `a`, equal labels agree on its legality, charged resources and static identities used; their successors have equal `α_(h-1)` labels.

Induction then pairs *the same suffix word* from either state at identical response and cost. This is stricter than the canonical residual simulation (which permits different witness suffixes), but sufficient for exact frontier preservation. For a finite explicit machine, backward partition refinement builds these labels by hashing `(terminal observation)` and then `(legality, charged use, next class)` over actions, in `O(Σ_h |S_h||A_h|)` local transitions and label-hash work instead of `|A|^h` words. A symbolic instruction identity can avoid enumerating even the numeric state set. The same-word construction is valid only when every live register and boundary that a legal suffix can inspect is present in `s` and the label laws hold on the actual reachable states.

Let `A` be the prefix's paid static identities, with nonnegative weights `w`, and `U_h(q)` the union of identities any remaining legal path from abstract state `q` can use. Backward graph union computes `U`: union each outgoing instruction's static uses with its successor's `U`. A prefix only needs `(base = w(A), profile = A∩U_h(q))` for future static pricing. For any suffix-use set `B⊆U_h(q)`,

```
w(A∪B) = w(A) + w(B\A).
```

The second term depends on `A` only through `A∩U_h(q)`. At an edge using `B_e` and moving to `q'`, charge `w(B_e\profile)` once, then project `(profile∪B_e)∩U_(h-1)(q')`. The original base stays fixed. This does **not** confuse equal byte totals for different paid identities; `a` and `b` remain different profiles if future instructions reuse them differently. Assets outside the future-use set still count in the base. Correlated future-use patterns can sometimes shrink the profile further, but only after proving equality of their entire future union-charge functions.

Define `D_h(q,p)` as an antichain of `(complete response map, **additional** static bytes, additional work)` attainable from abstract state `q` and future-paid profile `p`. Its terminal entry is `(observation(q),0,0)`. For every legal first action, add its charges to each successor entry; union these entries and discard an entry only when another has the **same complete response** and no larger charge in either resource. Thus responses are not approximated or locally matched to one teacher. This is precisely the one-step recurrence for complete suffix runs, followed by resource skyline reduction. Comparing the finished skylines for different `q,p` permits *different suffixes* to match each other and recovers the exact residual simulation over the computed entries, even when the same-word separator could not merge their states.

Let `K_h` be the number of abstract numeric labels, `m_h=|U_h|` the future-used asset count, and `H_h` the largest response/resource antichain stored per `(q,p)`. With a naive pairwise skyline pass over at most `|A_h| H_(h-1)` candidates per state, work is bounded by `O(Σ_h K_h 2^m_h (|A_h| H_(h-1))²)` (plus response comparison and arithmetic), and storage by `O(Σ_h K_h 2^m_h H_h)` for the retained skylines. Incremental response-indexed skyline insertion costs `O(|A_h| H_(h-1) H_h*)` per subproblem, where `H_h*` bounds its largest transient antichain. An indexed skyline improves comparisons when useful. These are **context-width and output-width bounds**, not a claim that either width is always small. Legal-state dependence and shared static choices must participate in the state/transition keys.

[`Kelana/ContextConstruction.lean`](../../../Kelana/ContextConstruction.lean) contains completed, sorry-free proofs: `charge_union`, `future_incidence_sufficient`, the exact `run_step_iff` recurrence, and `replay_on_separator` for full traces under the explicit stage-indexed separator laws. The Lean machine uses *incremental charged bytes*; the union-charge lemma proves why the future-incidence profile can supply those increments. Constructing a particular small separator is a separate obligation, discharged below by a finite exhaustive local-law check and the symbolic shift identity. This module does not declare an unproved optimal search-runtime theorem.

## Small discriminating construction

Run `python3 research/isa-quantization/context-construction/search.py` from Kelana's root (standard-library CPU, under one second). It regenerates [`results.json`](results.json). There are 256 reachable **four-input state maps** `s(x)=seed xor (x<<4)` for `x∈{0,1,2,3}`, each with eight possible already-paid subsets of one-byte identities `{a,b,c}`: 2,048 labeled prefixes. At each of four steps choose a right shift with no static use (work 1), a right shift that sets the top bit using `a` (work 0), or the analogous `b` instruction (work 0). The endpoint observes the low two bits of each live input state's byte. A single symbolic separator is

```
α_h(s) = tuple((s(x) >> h) & 3 for x in 0..3).
```

For `1≤h≤4`, `α_(h-1)((s>>1) | (high<<7)) = α_h(s)` pointwise, independent of `high`. The script checks this for every reachable starting map, action and stage. All suffixes at a fixed prefix have the same four-input response, but distinct `(bytes,work)` choices; already-paid `a` or `b` can make a zero-work suffix cost no new bytes. Identity `c` is never used later, yet its prefix byte remains paid. This tests response *and* two-resource Pareto preservation with actual shared identity reuse, not just Boolean output equality.

The script independently executes all `2,048 × 3⁴ = 165,888` complete suffix words and checks their resource/response frontiers against the abstract dynamic program. **All match.** Memoization needs **68** `(remaining depth, abstract map, paid-incidence)` subproblems; full root outcomes form **20** mutually equal frontier classes, rather than 2,048 numeric-and-paid prefix labels. The comparison is a finite certificate, not a native speed ratio or evidence of trained-model prevalence. The context width comes from the shift identity; extending the horizon enough for injected high bits to enter the observation invalidates it.

## Failure boundaries

- A legal one-step probe `((s>>1) xor ((s&1)<<1))` separates numeric states `0` and `1`, although `α₁(0)=α₁(1)=0`: its endpoint low-two-bit outputs are `0` and `2`. An observed separator must be closed under **every** legal continuation instruction, not merely fit the original shift suffixes.
- The sufficient same-word condition can be **too fine**. For states `0` and `1` with equally priced `identity` and `flip` suffixes, both have the same residual outcome set `{(0,0,1),(1,0,1)}`: each can choose the other word. Same-word successor outputs differ. Exact skyline comparison recovers this merge; blindly calling local partition refinement the *coarsest* quotient would be false.
- If the legal grammar can cheaply expose the whole state, a universal teacher-independent quotient retains every distinct observable state. If independent suffix choices emit independent bits of the final response, one node can have `2^h` different response maps after `h` steps; an explicit complete residual frontier can then itself be exponential. Shared asset incidence may also have exponentially many distinguishable profiles. No bound using only the instruction count is possible without structural width assumptions.

There is no duplicate of the combined-search product-table factor graph here. The object is the **remaining program automaton**, whole live-state congruence and static-use incidence; costs and responses are compared only after complete suffixes have been represented exactly.
