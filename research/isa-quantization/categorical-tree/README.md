# Categorical behavioral floors: exact KL trees and their label-consistency gap

The [behavioral state-budget study](../behavioral-state-budget/README.md) obtains a transition-free floor by clustering teacher emission laws under fixed teacher occupancy. Bernoulli laws admit an ordered interval dynamic program. This study extends a tractable lower bound to arbitrary finite vocabularies, then identifies exactly what its cheap decomposition discards. The result is **not** an inference format or a model-quality improvement.

## 1. Begin with the correct own-state objective

Let the teacher have emission laws `p_s` on a finite vocabulary and aggregate teacher occupancy `ν_s`. A candidate with at most `C` stationary emission states has product occupancy `w(s,c)` and laws `q_c`. Its sequence KL is

```
Σ_s,c w(s,c) KL(p_s || q_c),       Σ_c w(s,c) = ν_s.
```

The marginal is teacher-owned, even though candidate state evolves under its own program. Relaxing all causal restrictions on `w` permits arbitrary channels from teacher states to candidate labels. For fixed `q`, moving each source state's entire mass to its cheapest label cannot increase loss. Consequently the relaxed optimum is attained by deterministic assignments `g:S→{1,…,C}`. Given `g`, each `q_c` is the occupancy-weighted centroid of the assigned teacher laws. The resulting categorical clustering optimum is a lower bound on every legal `C`-state candidate, including every paid emission-code restriction.

For actual recurrent neural models the state set is not a small enumerated teacher automaton. A finite capture does not automatically supply the fixed teacher occupancy or a sequence-KL certificate. This study keeps that premise explicit.

## 2. A vocabulary tree is an exact loss decomposition

Choose a rooted full binary tree whose leaves are vocabulary symbols. At internal node `v`, let `N_v` be its leaf set and `L_v` its left subset. Define

```
a_s,v = p_s(N_v),     b_s,v = p_s(L_v)/p_s(N_v).
```

Nodes of zero teacher mass contribute zero. Positive-law examples avoid boundary conventions in the executable witness. Any positive candidate law is equivalently a collection of branch probabilities `r_c,v=q_c(L_v)/q_c(N_v)`. The exact chain rule is

```
KL(p_s || q_c) = Σ_v a_s,v KL(Bern(b_s,v) || Bern(r_c,v)).
```

Proof: the log leaf ratio telescopes along its root-to-leaf path; summing leaves exchanges path and node sums. At a node, each child contributes its teacher mass times its conditional log-ratio. The root has total mass one in both laws, so its potential is zero. This is why node contributions may be **added**. Adding arbitrary overlapping binary-observer KL floors would generally double-count the same loss.

For fixed source assignment `g`, independent minimization of each `r_c,v` is legitimate: any set of branch probabilities reconstructs one candidate law. Write `L_v(g)` for the optimized weighted Bernoulli clustering cost with node-specific source weights `ν_s a_s,v`. Then the exact categorical relaxed optimum is

```
F_C = min_g Σ_v L_v(g).
```

Allow a different assignment at each node to obtain

```
B_T = Σ_v min_g L_v(g) ≤ F_C.
```

Each component minimum is an ordered Bernoulli interval DP in `O(C |S|²)` after sorting. Thus a tree gives a bound in `O((|V|−1) C |S|²)` arithmetic work, without enumerating transition tables or full categorical partitions. Zero-weight sources can be dropped at the corresponding node. The tree is an analyst's bound, not a candidate's stored representation; its choice does not become a free physical reader.

## 3. Restore only the consistency that matters

Partition the tree's internal nodes into groups `Π` and retain a shared assignment inside each group:

```
B_T,Π = Σ_G∈Π min_g Σ_v∈G L_v(g).
```

Merging groups cannot weaken the lower bound, since every common assignment is allowed in the separate minimizations. Singleton groups recover `B_T`; one group containing every node recovers `F_C`. The general grouped optimization need not retain the ordered one-dimensional DP. Our small complete witness enumerates assignments for groups; it does not claim a polynomial exact categorical clustering algorithm.

Taking the maximum across several trees or groupings is sound. Taking their **sum** is not. Label names may be permuted independently between groups, but that does not remove incompatible source partitions: matching the cardinality of each coordinate is not the same as realizing one global `C`-state code.

This is the same consistency issue exposed by coupled-readout mini-buckets, now on a complete behavioral objective. It explains when a seemingly sophisticated loss decomposition merely spends time calculating a weak relaxation.

## 4. A decisive limitation: even the best tree has no uniform relative guarantee

For **every fixed vocabulary size `V` and capacity `2≤C<V`**, consider `V` equally occupied teacher states with laws tending to the `V` different point masses. At the limit, every vocabulary-tree node sees only deterministic left/right outcomes from the source states that reach it. **Every individual node has zero floor**, on **every tree**, since two labels suffice. But the whole candidate has only `C` emission laws. A cluster containing `k` point masses contributes `(k/V) log k`. Convexity balances the optimal cluster sizes: writing `V=aC+r`, `0≤r<C`, the positive full categorical floor is

```
F_C = [(C−r) a log a + r (a+1) log(a+1)] / V > 0.
```

For `V=4,C=2` it is `log 2`. This failure is not confined to zero probabilities. Let

```
p_s = (1−Vε) δ_s + ε (1,…,1),       0 < ε < 1/V.
```

For each fixed tree/node, retain a zero-loss assignment from the point-mass limit. Its centroid loss is continuous as `ε→0`, because `x log x→0` at zero. Hence its optimized node loss tends to zero. There are finitely many trees on `V` leaves, so their maximum singleton-node floor also tends to zero. The exact categorical optimum is the minimum of finitely many continuous assignment costs and tends to the positive expression above. Therefore

```
max_T B_T / F_C → 0
```

even for strictly positive teacher laws and every such `V,C`. No universal positive multiplicative guarantee can be obtained by trying more vocabulary trees while leaving their node labels independent. The lost dependency is the **common source-to-state assignment**, not the binary loss algebra or the numerical precision.

## 5. Complete finite evidence

[`search.py`](search.py) scores every two-label source assignment modulo label swap, every one of the 15 unordered four-leaf trees, each singleton-node ordered DP, all three two-node groupings, and full common-assignment grouping. It checks the chain rule separately for every assignment against direct categorical KL. All optimization and bound comparisons use rational logarithm intervals; floating numbers below are presentation only.

| Teacher laws, normalized occupancy | Best independent-node tree floor | Best two-node-group floor | Exact categorical two-label floor |
| --- | ---: | ---: | ---: |
| Four products of Bernoulli(1/4) or Bernoulli(3/4) | .06850669 | .09985216 | .13081204 |
| Six distinct rational categorical laws | .05180352 | .07390603 | .07584540 |
| Four near-point-masses, ε=1/1,000,003 | .0000117813 | see receipt | .69313098 |

For the natural product tree, the first row's independent-node floor is **exactly zero**: each node only needs two branch laws. Joining just two nodes raises it to .06540602. In the generic six-law witness, a natural tree's two-node grouping already gives .07308864, close to the full .07584540 floor. These examples distinguish useful decomposition, a recoverable consistency gap, and a family where the cheapest version fundamentally fails.

The one-state categorical control, complete teacher laws, occupancy weights, all tree/group scores and exact rational interval endpoints are in [`results.json`](results.json). The complete experiment takes about **0.7 seconds** on the recorded host. This is bound-construction work, not inference timing. No response image, byte frontier or full-model perplexity result is claimed.

## Formal and numerical custody

[`Kelana/CategoricalTreeBound.lean`](../../../Kelana/CategoricalTreeBound.lean) proves mass-weighted tree-potential telescoping over rational fields, the sum of component floors, monotonicity when grouping attains a common-assignment minimum, and a strict inconsistent-label witness. It does **not** formalize real logarithms, KL centroid optimality, Bernoulli interval ordering or the continuity argument; their derivations are given above and the relevant predecessor report.

The executable uses 24 rational atanh-series terms after exact power-of-two range reduction. A geometric tail bounds the omitted terms; all interval operations round outward at `2^-88`. Exact endpoints rather than eigensolver/optimizer statuses carry the finite numerical comparisons. Ordered DP minima and exhaustive assignment minima are compared as enclosing intervals, so an unresolved tie cannot silently become a certified unique optimizer.

```sh
python3 research/isa-quantization/categorical-tree/search.py
lake env lean Kelana/CategoricalTreeBound.lean
```

The useful next interface is a bound that restores a small amount of common-label or causal consistency **where it changes the decision**. The [general causal-history certificates](../causal-state-capacity/README.md) address a distinct gap: even full marginal categorical clustering can miss the memory needed to assign those labels along histories.
