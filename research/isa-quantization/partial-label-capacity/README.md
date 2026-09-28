# Partial-program label capacity with sound source-mass charging

A partial executable program restricts which stored readout labels can serve each source observation. Counting *all* labels in the machine discards those restrictions. This study combines a bipartite Hall witness with the [tensor capacity](../emission-tensor/README.md) and [collision-packing](../collision-packing/README.md) floors, before completing any source-to-label assignment. It is a behavioral search bound, not a new quantized image or an inference-speed result.

## General envelope

Let source observations `s` have positive mass `ν_s` and fixed categorical laws `p_s`. A completion chooses a label `g(s)` from the declared set `A_s`, and one stationary emission law `q_c` per label. Its complete loss is

```
D(g,q) = Σ_s ν_s KL(p_s || q_g(s)).
```

The possible-label sets must **contain every label reachable by every legal completion** of the partial program. A separately chosen best label need not itself come from a common program: relaxing that consistency is safe, imposing a guessed restriction is not. Live contexts sharing an upstream code must remain in the same observation contract; splitting them into independently coded consumers changes the problem.

For a source subset `T`, put `N(T)=union_{s in T} A_s` and `r_T=|N(T)|`. Every completion uses at most `r_T` laws on `T`. Let `L(T,r_T)` be any valid lower bound for unconstrained `r_T`-law approximation on those observations, in the **original, unnormalized source-mass units**. Then

```
Σ_{s in T} ν_s KL(p_s || q_g(s)) ≥ L(T,r_T).              (1)
```

For arbitrary overlapping subsets and nonnegative shares `α_T`, require

```
Σ_{T containing s} α_T ≤ 1  for every source s.
```

Nonnegative KL, finite interchange of sums, and (1) give

```
D(g,q) ≥ Σ_T α_T L(T,r_T).                              (2)
```

Thus disjoint witnesses may add at share one. Overlapping ones need a fractional source-mass packing, not an informal sum. Different bounds on the *same* subset combine by **maximum**, not addition. The argument also covers split occupancy `w(s,c)` supported on `A_s` with fixed marginal `ν_s`: for fixed `q`, replacing a row by its cheapest available label only reduces loss.

Equal laws may be merged **inside a relaxed capacity calculation**: with fixed candidate laws, their total minimum cost equals the sum of their masses times the common minimum KL. They may not be globally identified while deriving label access. Two occurrences of the same law can have different possible-label sets, and need different physical labels.

## Constructing witnesses without label completion

[`search.py`](search.py) forms connected components of the source/allowed-label bipartite graph, then runs augmenting-path maximum matching in each. If some sources are unmatched, alternating reachability from them yields `T` with `|T|>|N(T)|`. The source components are disjoint, so these witness floors add without an LP.

For pairwise distinct positive-mass source laws, this detects **every zero-error obstruction in the independent-list relaxation**:

* A matching saturating all sources assigns each a different allowed label and permits exact free emissions.
* If there is no such matching, the Hall subset has more distinct laws than labels. The tensor theorem (or one collision hyperedge) supplies a strictly positive floor.

This is not a statement about the magnitude of the optimum or causal realizability. With repeated laws, matching is sufficient but no longer necessary for zero error. A deficient source-name set alone proves nothing; its actual law geometry must be evaluated. The chosen single Hall witness per component is not claimed complete for repeated-law lists.

The implemented capacity call normalizes the subset masses, collapses identical laws only within that relaxation, and takes the larger of:

1. the exact coherence/Gershgorin tensor floor at one analytically selected power;
2. uniform fractional packing of `(r_T+1)`-law collision subsets using exact weighted pair-merge costs.

It multiplies back by the subset mass. Uniform hyperedge shares are `1/binom(m-1,r_T)` for `m` distinct laws, so their exact incidence load is one. No spectrum, floating optimizer, or label-completion search is needed. General matching is polynomial in graph size; the selected packing implementation enumerates `binom(m,r_T+1)` hyperedges. Large capacity calls should use selected valid hyperedges or another envelope rather than pretend that cost is polynomial in arbitrary `r_T`.

## Complete controls and actual decision

The error budget `1/1000` is fixed before calculating bounds. All source masses in this experiment are uniform; the six generic laws are the sibling fixture but **not its nonuniform occupancy**. The complete free-readout oracle is run only after the bound and decision. It enumerates all legal label assignments and minimizes every occupied readout analytically at its weighted centroid, using exact rational log intervals.

| Allowed-label construction | Global capacity floor | Partial-list floor | Exact free-readout optimum | Complete assignments in post-bound oracle |
| --- | ---: | ---: | ---: | ---: |
| Three Bernoulli laws, each repeated in two disjoint three-source components; two labels per component, four total | 0 | .0225480504 | .0225480504 | 64 |
| Same six sources, all four labels accessible to all | 0 | 0 | 0 | 4096 |
| Six distinct four-token laws, six total labels; first three can use only labels 0/1 | 0 | .0284001438 | .0284001438 | 64 |
| Same six laws; source `i` can use `i` or `(i+1) mod 6` | 0 | 0 | 0 | 64 |

The two positive bounds reject every completion at the declared error budget **before scoring any completion**. The zero controls remain feasible. The collision floor is exact in these deficient three-source/two-label components because exactly one pair need merge; other components admit exact matchings. The tensor-only component floors were .00310306 and .00420307, already sufficient to make the same rejection, but quantitatively weaker.

The retained run spent about 5 ms constructing each positive bound, versus 7/23 ms for the two independent complete oracles. Zero-control bound times were below 1 ms. These tiny CPU measurements price the actual bound construction; they are not a scaling or native-inference speed claim. [`results.json`](results.json) records the rational intervals, allowed sets, Hall witnesses, capacity certificates, decision, counts and timings. Exhaustive oracle enumeration is an acceptance control, not an input to the bound.

## Formal and executable scope

[`Kelana/PartialLabelCapacity.lean`](../../../Kelana/PartialLabelCapacity.lean) proves `weighted_cover_floor` for arbitrary finite overlapping subsets, rational losses/shares and per-source coverage. It proves `deficient_subset_forces_error` for a nodup subset with pairwise distinct teacher laws, using restricted injectivity and a finite length bound. The proofs do not assume the desired global inequality. Duplicate entries inside a subset cannot multiply its charge because membership is evaluated on the global source list.

General bipartite matching correctness, the real-KL centroid and tensor analytic steps are the arguments here and in their owning reports, not additional Lean claims. The executable uses exact rational log intervals for the displayed finite decisions. The lists in this first experiment are supplied directly, not derived from an actual ISA suffix or recurrent transition grammar; that containment bridge is the next obligation. Static fields, prepared state and online execution would still need their own accounting before adopting a program.

```sh
python3 research/isa-quantization/partial-label-capacity/search.py
lake env lean Kelana/PartialLabelCapacity.lean
```
