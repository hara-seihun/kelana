# Price the whole consequence of a state collision

Independent possible-label sets forget the defining constraint of a shared executable transition: revisiting the same state/token pair must produce the same successor. The [partial-transition study](../partial-transition-search/README.md) proves a general zero-gap example for that relaxation. Here finite **right-congruence closure** restores the missing program object and yields quantitative behavioral bounds without completing a transition table. This is state-machine search mathematics, not a quantization format or a comparison against state-of-the-art quantization.

## A constructive representation theorem

Let `T` be a finite prefix-closed set of token histories, including the empty history. A coloring `g:T→[C]` with fixed root `g(empty)=c0` is the trace of a deterministic C-state transition machine **if and only if**

```
g(h)=g(k) and ha,ka in T  =>  g(ha)=g(ka).
```

Necessity follows from applying the same token to the same state. For sufficiency, define `U(c,a)` using the child color of any listed parent of color c with an a-child. Right congruence makes all such choices agree. If no edge represents `(c,a)`, choose any fixed legal default. Induction on histories proves the constructed table realizes every listed color. This is a complete characterization of finite-trace realizability, not just a necessary pair test. It does not assert the table's static bytes or native work are optimal.

[`Kelana/TrieRightCongruence.lean`](../../../Kelana/TrieRightCongruence.lean) proves both directions, with an explicit `List.find?` completion and root default. The trie need not be duplicate-free; tokens need decidable equality. `realizable_iff_right_congruent` specializes to `Fin C` and the fixed root. Missing descendants impose no constraints beyond the finite observation contract.

## Quantitative closure floor

Each observed history h carries teacher mass `w_h=P_teacher(h)` and next-token law `p_h`. For an equivalence class B, its least possible common-emission cost is

```
J(B)=min_q Σ_{h in B} w_h KL(p_h||q)
    = Σ_{h in B} w_h KL(p_h || weighted_centroid(B)).
```

For a right-congruent equivalence relation R, put `L(R)=Σ_{B in R}J(B)`. Every actual coloring coarser than R has loss at least `L(R)`. A coarser partition restricts common readout laws, so this cost is monotone under merging. Each history is charged **once**, even when several propagated equalities reach it.

Suppose two history states collide. Start with that equality and an existing right-congruent relation R; repeatedly union the same-token children of equivalent parents until stable. Denote the resulting least right-congruent relation by `cl_R(h=k)`. Any actual deterministic coloring extending R and that collision also contains this entire closure. Therefore

```
state(h)=state(k)  =>  complete loss >= L(cl_R(h=k)).
```

Choose C+1 distinct R-class representatives A. Every actual C-state completion must merge some pair from A. Thus

```
complete loss >= min_{h!=k in A} L(cl_R(h=k)).              (1)
```

The maximum of (1) over chosen anchor sets is still sound. Unlike a single right-suffix pair bound, it prices *all* successor collisions and all transitive mergers together. It does not add pairwise divergences that repeatedly charge one history.

This also gives an exact search representation. If R has more than C classes, branch on each possible pair collision in one chosen C+1-anchor set and close each branch. Every completion survives at least one branch. Deduplicate relations, prune with `L(R)` or (1), and stop when at most C classes remain. The representation theorem constructs a deterministic machine for every leaf. Centroid emissions then attain `L(R)` exactly, yielding a feasible upper bound. The search is complete for finite-trace C-state behavior with unrestricted stationary emissions, not polynomial in trie size and not a proof of cheap stored emission codes.

## The footprint is larger than the anchor set

Combining several anchor-set bounds requires new care. For one query A, let `U_A` be the union of the nonsingleton history classes in **every hypothetical pair closure** used in its minimum. Regardless of which pair the actual program merges, the charged closure cost lies within `U_A`. Nonnegative losses therefore permit fractional combination only when

```
Σ_{queries A with h in U_A} α_A <= 1  for every observed history h.
```

Charging just the C+1 anchor histories is generally wrong: propagated common-suffix histories can lie far beyond them. Existing [fractional-cover arithmetic](../partial-label-capacity/README.md) applies to these full footprints. The current executable takes a maximum, not a packed sum; it records all footprints for future reuse. An intentionally unsafe unweighted sum of all anchor-query floors exceeds the exact optimum in both nontrivial fixtures, illustrating the double-charge error directly.

## Complete small controls

[`search.py`](search.py) scores the full binary history trie through depth two (three emitted tokens, seven history observations), with two candidate states. It uses the sibling rational log-interval engine, actual teacher history probabilities, and arbitrary centroid emissions. No source state is substituted for the candidate state. Three laws use `A=(1/2,1/2)` and `B=(1/4,3/4)`:

* **Clock:** A at depths zero/one and B at depth two.
* **Delayed parity:** A at depths zero/one; depth-two odd-parity histories request B, even histories A. Two labels suffice pointwise, but remembering parity and suppressing B at the first step needs more causal structure.
* **Realizable parity:** emission B exactly when history parity is odd at every depth. A two-state parity transition realizes it with zero loss.

| Teacher | Exact noncausal two-label floor | Root closure floor | Best single-suffix pair bound on the selected anchors | Exact two-state optimum |
| --- | ---: | ---: | ---: | ---: |
| Clock | 0 | .02223757 | .02223757 | .06764415 |
| Delayed parity | 0 | .02223757 | .01691104 | .03382208 |
| Realizable parity | 0 | 0 | 0 | 0 |

The clock closure floor here is weaker than the specialized all-ray clock certificate .04447515. The result is a general closure construction, not dominance over that specialized theorem. On delayed parity it strengthens the same-anchor best-single-suffix bound by retaining joint/transitive consequences. The achievable parity control prevents an indiscriminate penalty for repeated labels.

The exact closure searches visited 30, 25 and 15 distinct partitions, scoring 2, 2 and 1 realizable leaves, in roughly 6–9 ms each. The original two-state transition grammar has only 16 tables, so this is **not a search-speed win over enumeration on these fixtures**. Its value is the correct program representation and composable lower bounds. Larger searches need a discriminating question, not just a larger trie.

After search and bound construction, an independent oracle enumerates all 16 deterministic transition tables, runs each on every observed word, and minimizes its stationary emissions. It agrees with every closure-search optimum. For every hypothetical initial pair merger and every table realizing it, the script independently checks containment of all closure equalities and the loss floor. The incorrect unweighted query sums are .177901/.155663 for clock/delayed-parity, exceeding their actual .067644/.033822 optima.

[`results.json`](results.json) stores rational intervals, teacher laws, original unnormalized masses (total three), selected anchors/closures, all query footprints, counts and unsafe-sum counterexamples. The numerical instance uses all anchor triples because it is tiny; the theorem needs any selected C+1 representatives. Union-find closure is implemented directly. Least-closure correctness, KL centroid optimality, and bound (1) are mathematical arguments here; the Lean theorem establishes the general constructive realizability equivalence, not the Python implementation or real-log analysis.

```sh
python3 research/isa-quantization/congruence-closure/search.py
lake env lean Kelana/TrieRightCongruence.lean
```
