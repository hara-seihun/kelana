# Mathematical results and their scope

The [prior-art review](PRIOR-ART.md) identifies the established machinery. This note gives the precise problem and the connections proved in Kelana. The contribution of this round is a usable combination of consumer-state search, cost-funded dominance, arithmetic-aware bounds and an explicit accuracy-domain contrast. It is not a claim to have invented min-plus dynamic programming or a new universal quantization algorithm.

## 1. The object being discovered

At stage `i`, choose `z_i` from a finite menu `A_i`. Each choice has a response vector `v_i(z_i)` in `Z^m` and a nonnegative integer charge `c_i(z_i)`. The charge may combine stored bits and priced online work. Static model-dependent metadata is an additional charge `c_0`.

For a fixed target response `t` and integer `lambda >= 0`, solve

```
OPT = min_z c_0 + sum_i c_i(z_i) + lambda ||sum_i v_i(z_i) - t||_infinity.
```

The coordinates are declared observations, not necessarily individual weights. They may be the complete finite input domain of a small consumer, captured calibration inputs, or another specified interface. These choices give different theorems. Agreement on captured inputs does not imply agreement on unseen activations.

The finite menus need not be integer-valued weight alphabets. They may denote arbitrary executable block codes with precomputed integer responses. Real or rational responses require an exact rational formulation or a separately bounded integer conversion. The current executable implementation does not silently round them to integers.

The original model is not automatically a member of a newly chosen codec family. Include its representation explicitly when claiming a comparison against it.

## 2. Exact consumer-state dynamic programming

A prefix has state `(r,c)` where `r` is its accumulated response and `c` its paid charge. At a fixed stage, two prefixes with equal `r` have identical response to every common remaining choice sequence. The less costly prefix can replace the more costly one.

Thus the recurrence

```
D_0(0) = c_0
D_(i+1)(r+v) = min(D_(i+1)(r+v), D_i(r)+c)
```

is exact, followed by minimizing `D_n(r)+lambda||r-t||_infinity`. Every path admitted by the recurrence is feasible, and every original path has a no-more-costly representative with the same complete response. This is ordinary min-plus DP with a consumer-derived state, not a new general algorithm.

The relevant size is the number `W_i` of reachable response states at a stage, not the product of menu sizes. With at most `K` choices, dimension `m`, and peak width `W`, hashing gives expected `O(n K W m)` arithmetic work, excluding witness materialization and integer bit complexity. A balanced map replaces the expected constant-time lookup with a logarithmic factor.

If coordinate `j` of every reachable state lies in an integer interval of width `R_j`, then `W <= product_j(R_j+1)`. Fixed small dimension and polynomially bounded numeric ranges give a tractable family. This is pseudo-polynomial when the ranges are exponentially large relative to their binary descriptions. It makes no promise that the real FFN has a small width.

The two-coordinate collision example has state `(k,k)` after a prefix of length `i`, so only `i+1` states remain from `2^i` assignments. No weight reconstruction is required to retain that sufficient state.

## 3. Safe approximate reduction is a directed relation

Let `d` be a nonnegative integer distance satisfying the triangle inequality. More generally it may be asymmetric. Suppose the loss of every legal common suffix `u` obeys

```
loss(a,u) <= d(a,b) + loss(b,u).
```

Define the paid dominance relation

```
(a,c_a) dominates (b,c_b)
    iff c_a + lambda d(a,b) <= c_b.
```

Then for every common suffix,

```
c_a + suffix_cost(u) + lambda loss(a,u)
    <= c_b + suffix_cost(u) + lambda loss(b,u).
```

The cheaper prefix pays for its entire possible disadvantage. Unlike epsilon-closeness, this relation is transitive: add the two paid inequalities and apply the triangle inequality. A zero self-distance makes it reflexive. Replacing a cover by a dominating cover preserves every global lower bound proved on the survivors.

[QuantizationDominance.lean](../../Kelana/QuantizationDominance.lean) proves these statements and instantiates them for `d(a,b)=max_j |a_j-b_j|` under additive suffix responses. It also proves that a common-charge nonexpansive transition preserves dominance.

### Why this is stronger than equality reduction

In the family with zero option `(response=0,cost=1)` and nonzero option `(response=2,cost=6)`, a prefix of length `n` with `k` nonzero choices has response `2k` and cost `n+5k`. At `lambda=2`, the zero prefix dominates it because

```
n + 2|2k| = n+4k <= n+5k.
```

Equality alone retains `n+1` different responses. Paid dominance retains one. `zero_dominates_count_family` proves this for every `n,k`; the experiment at 160 choices is an illustration, not the theorem's scope.

A full pairwise antichain pass over at most `K W` generated states has worst-case `O((K W)^2 m)` arithmetic work per stage. Pruning is not automatically faster than exact-state hashing. The anytime solver limits comparisons to 64 stored representatives per stage. This can miss valid pruning opportunities but cannot license an invalid prune. The full exact-DP experiment uses the complete cost-ordered antichain pass.

### Exact scalar dominance from two suffix endpoints

The metric rule pays for a disadvantage over every possible translation. Knowing the legal suffix range gives a stronger rule. For scalar responses, define the signed advantage

```
h(s) = |a+s-t| - |b+s-t|.
```

If `a >= b`, `h` is nondecreasing; if `a <= b`, it is nonincreasing. Therefore its maximum on any bounded suffix set occurs at one of its extrema. For a nonempty allowed suffix set with attained minimum `low` and maximum `high`,

```
for every allowed s:
  cost_a + lambda |a+s-t| <= cost_b + lambda |b+s-t|

if and only if the same inequality holds at low and high.
```

The suffix set need not contain the integers between its endpoints. Shared suffix charges cancel even when they vary with the suffix. `scalar_advantage_monotone`, `scalar_endpoints_dominate` and `scalar_dominance_iff_endpoints` prove these statements in Lean. If the endpoints merely enclose the set, the checks remain sufficient but need not be necessary.

This can prune equal-cost unequal responses, which the global metric rule cannot. For example, response 1 at cost 2 dominates response 0 at cost 2 when target is 10 and every suffix lies in `[0,4]`. Both completed responses remain below target, so the larger response is always better. `endpoint_rule_strictly_extends_metric` proves the strict separation.

In the additive menu family, suffix extrema are sums of block minima and maxima. Precomputation is linear in the menu size; each dominance comparison uses two scalar objective comparisons regardless of the number of suffix assignments. The 160-stage equal-cost binary family retains one state instead of 161, using 320 transitions rather than 25,760. The antichain pass removes previously retained states when a newly encountered state dominates them, including equal-cost cases.

This is a complete test for scalar absolute-error dominance with common suffix actions. It is not a complete test for vectors under maximum-coordinate error, and it does not eliminate the possible exponential number of nondominated scalar states.

### Where the rule does not apply

The prefixes must have the same available suffix actions and the same suffix charges, or an explicit no-worse completion mapping. Equal observation vectors do not erase decoder registers, codebook-usage state, scale regimes, lane labels or transition legality. Those belong in the state if they affect continuation. The proof does not permit dropping them because their current numeric outputs coincide.

A different input domain may change the metric. The three-observation distance used in the real-block search says nothing about its five held-out observations. Extending the domain tightens the required distance and may invalidate a previous dominance certificate.

## 4. Local lower bounds and a global search interval

For each scalar integer probe `a`, project a suffix response onto `a`. At a stage, let each remaining block's possible values have minimum `l_i`, maximum `u_i`, reference `b_i` and difference gcd `g_i`. Then every suffix projection belongs to

```
[sum l_i, sum u_i] intersect (sum b_i + gcd(g_i) Z).
```

The gcd of an all-zero difference list is zero, meaning a singleton rather than arbitrary integers. Interval extrema are attainable blockwise, but not every point inside the intersection need be attainable. The set is used only as a relaxation.

Let `D` be the distance from the projected remaining target to that interval/residue intersection. For a nonzero probe,

```
||complete_error||_infinity >= ceil(D / ||a||_1).
```

Taking the maximum over probes and adding the minimum suffix charge gives an admissible objective bound. Coordinate probes and pairwise difference probes expose both coordinate ranges and some cancellation constraints. They are not a complete integer hull.

### Signed cost/error dual

Separately minimizing cost and distortion can lose their coupling. A second lower bound prices them jointly. For an integer probe `a` and positive integer denominator `q >= ||a||_1`,

```
lambda a·e <= q lambda ||e||_infinity.
```

For a prefix `(r,c)`, define

```
N = q c + lambda a·(r-t)
    + sum_remaining_i min_(z in A_i) (q c_i(z) + lambda a·v_i(z)).
```

Then `ceil(N/q) <= J` for every completion. This is a standard separable Lagrangian lower bound. The implementation tries both signs of each probe and five denominator multipliers. It takes the maximum of this bound and the interval/residue bound. It does not claim to optimize the continuous dual.

[QuantizationBounds.lean](../../Kelana/QuantizationBounds.lean) proves the interval/residue sum rule, projection inequality, nonnegative ceiling rule and signed min-sum inequality. The [bound contract](BOUNDS.md) states exactly which numeric facts the generator still supplies.

### Complete cover, including discarded states

A search prefix is either expanded into every legal next option, terminal, retained as an unresolved bounded region, pruned by an admissible bound, or represented by a no-worse prefix with the same suffix set. Keep those reasons as a proof DAG. A cycle of dominance references is not an acceptable certificate.

The checker replays this DAG bottom-up. Expanded nodes take the minimum of their children's floors; represented nodes inherit their representative's floor; bounded leaves recompute their local floor. A concrete feasible complete assignment gives `U`. The root floor gives `L`, hence `L <= OPT <= U`. `L=U` certifies optimality within the declared family.

The [generic Lean certificate](CERTIFICATES.md) derives the global statement from local bounds and coverage. The numerical JSON checker is separate software, not a Lean proof exporter. Its shared bound evaluator, integer codec and branch coverage are exercised by exhaustive tests on small instances; this does not make the Python implementation formally verified.

A prefix-expansion budget is not an instruction budget. With `B` expansions, `K` choices, `J` probes and at most `M` dominance representatives per stage, bound/dominance arithmetic is on the order of `B K (J+M)m`, plus preprocessing, complete-witness scoring, seed construction and trace storage. The saved trace stores whole prefixes and therefore adds length-dependent work and memory. Arithmetic bit lengths matter too. Seconds are measured separately.

## 5. A stronger accuracy domain can remove the combinatorics

Consider one linear row and error vector `e=q-w`. On the complete integer box `|x_i|<=R`,

```
max_x |sum_i e_i x_i| = R sum_i |e_i|.
```

The upper bound is the triangle inequality. Equality is attained by the explicit input `x_i=R sign(e_i)`. It costs linear work to construct that witness; enumerating the box's corners is unnecessary.

[BoxQuantization.lean](../../Kelana/BoxQuantization.lean) proves the upper bound, the legal maximizing input and its attained value for arbitrary integer vectors and radii. It also proves additive independent minima compose into a global minimum.

For independent block choices, the robust quantization objective therefore becomes

```
c_0 + sum_i [c_i(z_i) + lambda R ||q_i(z_i)-w_i||_1].
```

Choose the minimum option separately in each block. This finds the global optimum in `O(sum_i |A_i| block_width_i)` arithmetic work, over every possible input in the box. It is exact assignment in the frozen family, not joint dictionary design. A hard global bit budget, shared dictionary charges, a nonlinear consumer or a maximum across several output rows can restore coupling.

This is norm duality applied to the quantization contract. The contrast is useful: a finite calibration set allows error cancellations that couple decisions and make search difficult; the independent box chooses adversarial signs that remove those cancellations and make the objective separable. The robust optimum can be easy to find and unattractive as a compressed model.

For the real 128-trit example, the domain has `255^128` integer inputs. The robust family optimum requires evaluating only 96 options and chooses all literals. The eight-byte calibration candidate has exact worst-case integer response error 11,684. The original HALO block is smaller than the robust literal result. These facts are not obstacles to other representations; they locate the assumption that the next construction needs to change.

A correlated producer domain is the natural next target. If inputs are exactly `B z` with `||z||_infinity<=1`, its support function is `||B^T e||_1`. This retains correlations, but it couples block choices again. That identity is standard linear algebra; extracting a small, useful and valid `B` for the real producer is an open task here, not a property inferred from eight samples.

## 6. What is and is not established

Established in this round:

- generic Lean proofs for paid dominance, finite covers and arithmetic lower bounds;
- a necessary-and-sufficient two-endpoint test for scalar absolute-error dominance over an arbitrary bounded suffix set with attained extrema;
- arbitrary-size exact robust-box quantization within a fixed additive menu family;
- a finite assignment solver that retains a replayable gap when interrupted;
- an actual variable-length block codec with all model-dependent values accounted for;
- a real-weight example separating calibration fit, held-out fit and exact robust error.

Not established:

- a globally optimal learned codebook or arbitrary compressed program;
- a bound on unseen activation error from the calibration observations;
- a cheap native GPU lowering of the example codec;
- a whole-layer or whole-model quality improvement;
- a new information-theoretic lower bound across every representation;
- literature novelty of the elementary dominance, dual or support-function lemmas.

The next advance should reduce a meaningful consumer's effective state width or tighten its admissible bound. Increasing the same search budget without changing either object would produce more work, not the mathematical leverage this project is seeking.
