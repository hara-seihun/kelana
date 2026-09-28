# Tools for discovering different computations

The target is a cheaper map with the same observed result, not a shorter transcription of the original layers. These tools let us discard the original operation boundaries while keeping an exact account of what changed.

## Discover quantization under a work budget

The [quantization-discovery study](../quantization-discovery/README.md) maps entropy-constrained and functional coding, low-bit LLM quantizers, exact trellises, variable elimination and certified decision diagrams. Its new executable search combines consumer responses with paid storage/work costs, sound suffix bounds and replayable branch covers. Lean proves that a cheaper prefix can safely dominate a numerically different prefix when its cost saving pays for the worst continuation error. The same study proves exact robust linear-row quantization over an entire input box by reduction to independent block choices, and records why a real sub-bit calibration candidate fails outside its fitted observations.

## Search representations across complete regions

The [whole-map research plan](observer-search/PLAN.md) records the next direction: treat memory and registers as state, instructions as transitions, and the final answer as an observation. Intermediate channels need not be recoverable unless a continuation needs them. A [checked packed-input obstruction](packed-input-boundary/README.md) shows that no bit-affine map can squeeze the 27 valid three-trit `packed2` words into the five address bits of a wave gather without collisions. The next address search needs a nonlinear instruction, a different input coordinate, or more carried state.

The [observer-search tools](observer-search/README.md) now construct semantic decoders or collision witnesses, minimize reusable finite-state interfaces, identify shortest distinguishing continuations, and search priced one-register decoders. A small gated map needs three final states, five states under sign/swap continuations, and all nine after adding gate rotation. The continuation set changes the representation requirement. Equal fibers also do not imply equal ISA cost: numeric labels must remain in costed program-search keys unless a hardware symmetry justifies removing them.

[`ObserverAutomata.lean`](../../Kelana/ObserverAutomata.lean) proves the coarsest stable observation relation and its monotonicity under additional operations. Fixed complete regions can use smaller representations than that reusable interface; the search does not require each source operation to survive independently.

The same directory now runs an **instruction-first** search: start with ISA maps on densely radix-3 packed inputs and solve for output relabelings that give them gated-network structure. Of 531 distinct candidate partitions in the declared grid, 16 admit such labels. One exact five-hidden-unit ternary gated network becomes `v_mad_u32_u24` followed by `v_bfe_i32`, with no trit expansion or intermediate gate/up recovery. [`PackedObserver.lean`](../../Kelana/PackedObserver.lean) proves all 27 inputs. This is a constructed small network with an already-packed input contract, not a speed claim for the trained model.

A [packed sign-consumer construction](observer-search/fiber-cost/README.md) observes SiLU gate/up sign on all 676 three-input ternary weight pairs. [Its shared sign-orbit coordinate](observer-search/fiber-cost/SIGN-ORBIT.md) has exactly 14 necessary states for the whole family and puts a complete three-valued endpoint into one 28-bit signed-field literal. From the original radix-3 code, three shared instructions prepare an offset and one signed bit-field extract serves each consumer. One observer loses in instruction count against the earlier three-instruction two-mask path; at least two share the preparation and win in this restricted grammar. This is neither an A4 quantizer replacement nor a native timing result.

The complementary [fixed-network whole-map search](whole-map-search/README.md) uses SMT on a declared integer instruction subset. It constructs a universal three-trit observer from one wave gather when a scaled radix-3 address is already available, or an address instruction plus gather from byte-packed input. The table occupies one VGPR across the wave and the result needs a wait before use. That construction was checked on gfx1151; no throughput gain is claimed. The same search records template negatives, solver timeouts and unrun cells, and distinguishes the index's fibers before lookup from the exact final output.

## Prove a search family cannot win

The [resource-bound toolkit](resource-bounds/README.md) derives instruction-count cuts from potentials on complete machine states, then combines them with resource demands using exact dual certificates. Its finite-machine checker covers all straight-line program lengths in a declared grammar. On a two-bit machine, the target `2*(b1 and b0)` costs three instructions, but forcing `b1 and b0` to exist anywhere along the way costs four. Representation freedom excludes a real cost, rather than merely broadening a search heuristic.

The same toolkit separates service lower bounds from feasible schedules, dependency latency and register capacity. Lean proves the comparison rules; executable checkers replay the witnesses. The gfx1151 profile records which native facts and family restrictions would be needed to instantiate those rules. No full-ISA or whole-FFN optimality is claimed.

## Choose the representation with its consumer

The [joint-observer search](joint-observer/README.md) intersects source-function spaces with evaluated consumer features. It solves `L B u = 0`, where `L` annihilates the source space and `B` contains features computed from the candidate carrier. It returns both source and consumer witnesses for the entire shared family, discarding coefficient freedoms that evaluate to zero. Numeric labels remain part of the search.

One two-instruction producer on three radix-3 packed inputs carries eleven states instead of the source basis's 27 distinguishable states. Five odd polynomial observers plus one two-bit register-table observer preserve a six-parameter family of gated networks. The full region assembles to eleven data instructions, or eight for its five-parameter odd subfamily. [`JointObserver.lean`](../../Kelana/JointObserver.lean) checks all basis identities and proves the parameterized composition. Original hidden units cannot all be recovered and are not recovered. These are constructed ReLU networks with integer output weights, not trained Bonsai weights or a native speed result.

The [trained-region follow-up](joint-observer/TRAINED.md) evaluates all 27 states of twelve prescribed input cubes using layers 0 and 10, with three hidden-quantizer settings and all 5120 outputs. The eleven-state carrier loses distinctions that even an arbitrary decoder cannot recover. A new output-distance bound applies to any carrier of a given capacity, independently of the ISA grammar. On these computed tables, reducing even to 26 states prevents 5% accuracy in the cube's output-variation metric. This does not rule out an injective packed encoding, or imply a 5% whole-model quality loss. The dense input already preserves all 27 states without unpacking.

## Compare functions before comparing programs

The [ternary algebra tool](ternary-algebra/README.md) represents rational-valued functions on ternary inputs in

```
Q[x₁,…,xₙ] / (xᵢ³ − xᵢ).
```

Every variable has exponent 0, 1 or 2. The normal form is unique. Different hidden networks can therefore have the same canonical key even when their hidden states differ. The tool interpolates exact truth tables, normalizes symbolic expressions, reports reachable states and supplies a counterexample when two maps differ.

This generalizes the small contracted FFN beyond one hand-derived identity. The 2×2 `AB+C` packed column is seven monomials over eight relevant ternary variables. Small three-input networks with up to 256 hidden units contract to 10–18 monomials in the recorded examples. Neither number is an instruction count.

The sparse Python representation scales with the terms it actually constructs. Full truth-table interpolation still costs `3^n`; it is for small regions, not a 5120-input FFN. A useful search region can span several conventional operations without spanning every input coordinate.

## Proposals become checked identities

[Certificate export](certificates/README.md) takes two original expression trees and produces a Lean theorem. Python proposes equality; Lean recomputes the normal forms independently. The examples include a contracted gated expression and a rejected replacement with a concrete counterexample.

[`TernaryAlgebra.lean`](../../Kelana/TernaryAlgebra.lean) proves normalization correctness, coefficient uniqueness, interpolation correctness and the equivalence criterion. Its generic statements work over a commutative ring with the stated assumptions on 2. The exporter uses exact rationals.

There is a real composition trap. `x³−x` vanishes on ternary inputs, but replacing `x` by `x+1` gives 6 at `x=1`. Once we have identified expressions only on a finite domain, substitution is sound only when the replacement stays in that domain. The tool checks `p³=p` for each replacement coordinate. Lean proves that closure certificate and the resulting substitution law. Alternatively, substitute into the original unreduced expression and normalize afterward.

The rational basis is a semantic representation, not a required hardware representation. The indicator of `+1` is `(x²+x)/2`; it has no integer-polynomial representative, while a bit-field extraction and a permutation instruction can implement the finite lookup. A search that allows only ring operations would miss it.

## Eliminate impossible coefficients before searching

For a bias-free gated network

```
f(x) = Σᵢ cᵢ s(gᵢ·x)(uᵢ·x),
s(t) − s(−t) = t,
```

we have

```
f(x) + f(−x) = Σᵢ cᵢ(gᵢ·x)(uᵢ·x).
```

The even part is quadratic at every hidden width and input arity. SiLU and ReLU satisfy the activation identity in real arithmetic. [`TernaryFFN.lean`](../../Kelana/TernaryFFN.lean) proves the network identity assuming that activation law, then transfers it to canonical coefficients. It does not commute through quantization or claim a floating-point identity.

On the ternary cube, every even-total-degree coefficient above degree 2 therefore vanishes. The constant vanishes too. Counting the remaining basis terms gives the dimension upper bound

```
n(n+1)/2 + (3^n−1)/2.
```

For 2, 3 and 4 inputs this is 7, 19 and 50, compared with unrestricted dimensions 9, 27 and 81. The executable exact-rational ReLU experiment attains those ranks. The Lean files prove reflection and coefficient elimination; the dimension count and sampled spanning calculation are separate from those proofs.

This is a search-space reduction, not a hardware lower bound. It suggests searching only the odd terms plus a prepared quadratic form, then testing whether those terms share a cheap hardware representation. The [real-weight quadratic study](../ffn/contracted-quadratic/FINDINGS.md) already rejects the tested dense low-rank version at Bonsai scale.

## Ask whether one relabeling serves a whole family

The [simultaneous relabeling tools](relabeling/README.md) decide exactly, on
small state sets, whether a single bijection of the states conjugates every
operation of a labelled family at once. That is the property that lets a region
run many operations between one encode and one decode. Separate operation
labelings instead leave connectors whose implementation cost must be checked;
a compatible consumer or fused instruction can make a connector free.

The two are far apart. An exhaustive orbit census finds that at six states and
two permutations, 121 per-operation classes carry 901 genuinely different
family orbits, of which 97.7% share their per-operation invariants with a
different orbit. The discrete logarithm relabels a whole set of `GF(2^w)`
multiplications into additions at once. A fixed word collapses to one addition
in the new representation, while the source also collapses to one field
multiplication by a prepared constant; this alone is not a speedup claim.

`GL(3,2)` acting on points, against the same two matrices acting on planes,
shows which kind of screen is worth running. The two agree on every invariant
computed from the composite maps, including the cycle structure of every
composite word at every length, and admit no relabeling among all 5,040
bijections. A relational screen rejects them: pair refinement separates them
after one round, provided colour meanings rather than local colour indices are
compared. Collision counts and commutation reject, they never accept; the
state-relational screens are where a usable one lives.

Restricting the relabeling changes the answer rather than the confidence in it:
multiply-by-`α` and multiply-by-`α³` on GF(8) are conjugate as permutations of
eight states and no bit-affine map conjugates them, because a linear conjugacy
would transport the minimal polynomial. Boundary maps are priced by
synthesising an actual program in a declared grammar of invertible word
operations and re-executing it, under declared abstract charges with no
hardware claim attached; a relabeling with no program inside the search bound
is reported as cost unknown rather than given a number. One worked case has a
witness that buys nothing.

## Measure the information a cheap observer needs

For approximate representations, source error is the wrong objective whenever the consumer can cancel it. The [consumer-directed code study](../ffn/consumer-quotient/README.md) measures error after the down projection.

There is a useful exact screen here too. Starting from nearest rounding, a one-step code change cannot improve its diagonal Gram contribution. Any gain must exploit off-diagonal correlations. [`ObserverDescent.lean`](../../Kelana/ObserverDescent.lean) proves this with integer-scaled errors in `nearest_diagonal_nonnegative` and `nearest_gain_requires_correlation`.

That tells us what to test in an approximate observer: its ability to select a beneficial direction, not merely its estimate of total matrix energy. The [random-sketch experiment](../ffn/consumer-quotient/random-sketch/README.md) implements that test, plus independent acceptance sketches and positive-semidefinite controls. Fixed rank-256 sketches can reduce their own surrogate by 20× while increasing true error. Held-out acceptance finds a small ternary gain on layer 0, but no improvement at 7 or 15 levels or on layer 10 in the tested grid. Larger singular sketches recover more of the oracle gain at too much online arithmetic for this route.

## How to use this in the next search

1. Define only the required input and observed output. Preserve a recognizable intermediate only if a consumer needs it.
2. Canonicalize a small complete region. Deduplicate equivalent proposals before hardware work.
3. Carry the domain with every representation change. Reject substitutions that leave it.
4. Use reflection, reachable states and observer equivalence to remove unnecessary distinctions.
5. Export exact identities to Lean. For lossy maps, score the complete change against the actual consumer and keep a separate acceptance measurement.
6. Price the resulting program, including dynamic construction, accumulation, memory layout and register pressure. A shorter polynomial can still be slower.

No new native speedup is claimed by these tools. They supply exact proposal checks and measured rejection criteria so the next hardware experiments start from a smaller, better-defined set.
