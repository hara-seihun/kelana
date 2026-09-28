# Source-dependent live contexts: co-visibility, not a joint-emission span

The [shared-emission subspace](../emission-subspace/README.md) lift into `(context,token)` assumes a context law `π(t)` independent of source. That premise matters. When the producer changes the distribution of a live context before the reader sees it, `π(t|x)` is *side information*: it can reveal some or all of `x` for free even though the upstream code `E(x)` has only `C` values. The right logical label constraint is which sources the **same context can see together**. It is not the dimension of the square roots of the source-specific joint laws.

## Exact conditional-centroid objective and zero theorem

For finite sources `x`, live contexts `t`, teacher output laws `p_{x,t}`, source occupancy `ν_x`, and conditional context laws `π_x(t)`, put `a_{x,t}=ν_x π_x(t)`. An upstream label `g(x)∈[C]` is selected before observing `t`; the reader can use any stationary categorical law `q_{g(x),t}`. Its complete loss is

```
D(g,q)=Σ_x,t a_{x,t} KL(p_{x,t} || q_{g(x),t}).
```

For fixed `g`, each `(label,context)` separately takes the weighted centroid of the positive-mass sources assigned there. The exact value is

```
F(g)=Σ_t Σ_c [ A_{c,t} H(pbar_{c,t})
                  − Σ_{x:g(x)=c} a_{x,t} H(p_{x,t}) ],
A_{c,t}=Σ_{x:g(x)=c} a_{x,t},
pbar_{c,t}=A_{c,t}^{−1}Σ_{x:g(x)=c}a_{x,t}p_{x,t},
```

with zero contribution when `A_{c,t}=0`. Only the *minimization over the one shared `g`* couples contexts. Allowing a separate `g_t` at every context is a lower bound but can discard the entire collision cost.

Build the **co-visibility conflict graph** on sources of positive occupancy: join `x≠x'` precisely when some `t` has `a_{x,t}>0`, `a_{x',t}>0`, and `p_{x,t}≠p_{x',t}`. Then

```
min_{g:S→[C],q} D(g,q)=0   ⇔   χ(conflict graph)≤C.        (1)
```

If loss is zero, KL is zero at each occupied cell, so same-label co-visible sources have the same requested law. Conversely, a proper graph coloring makes all occupied teacher laws at each `(c,t)` equal; assign `q_{c,t}` this law, choosing any default if that cell is empty. This works for arbitrary source-dependent `π_x` and arbitrary finite vocabularies, including deterministic contexts. Its Lean algebraic zero-decoder theorem does not silently assert real-log KL equality: the KL-zero iff equal-law step is analytic.

Context can make two completely different sources **compatible** if it never presents them together, or if their laws agree at every context where it does. Different source joint laws `P_x(t,y)=π_x(t)p_{x,t}(y)` are necessary but not sufficient for a conflict edge: equal joint laws have equal context marginals and conditional laws on every occupied context, whereas unequal joint laws may differ only in what the context reveals. An upstream logical label still needs a payable physical reader for `(label,context)`; the graph theorem does not make context lookup, transition computation, or code bytes free.

## Quantitative co-visibility obstruction

At a graph edge `e=(x,x',t)` define its conditional, mass-weighted pair merge cost

```
w=a_{x,t}+a_{x',t},    pbar_e=(a_{x,t}p_{x,t}+a_{x',t}p_{x',t})/w,
J_e=a_{x,t} KL(p_{x,t}||pbar_e)+a_{x',t} KL(p_{x',t}||pbar_e)>0.
```

If `g(x)=g(x')`, their two source-context cells pay at least `J_e` by the KL centroid identity. Every explicit subgraph `H` with `χ(H)>C` has a monochromatic edge in every C-label assignment. Let `U_H` be the *set* of source-context cells incident to H's edges, each included once. Nonnegative per-cell KL therefore gives the quantitative floor

```
Σ_{(x,t)∈U_H} a_{x,t} KL(p_{x,t}||q_{g(x),t})
    ≥ min_{e∈H} J_e.                                     (2)
```

The whole graph `H=G` makes (2) strictly positive whenever (1) rules out zero (finite positive edge costs), though finding a general non-C-colorability proof can be expensive. For small C, an explicit odd cycle (`C=2`), `(C+1)`-clique, or other certified non-C-colorable subgraph is enough. Unlike source-only packing, the charging unit is a **source-context cell**, not an entire source: contexts partition `ν_x` by `π_x(t)`.

Several obstructions may be combined. For nonnegative shares `λ_H` satisfying `Σ_{H:(x,t)∈U_H} λ_H≤1` for every cell, the sum of their right sides `Σ_H λ_H min_{e∈H}J_e` remains a lower bound. Taking a minimum edge of an obstruction never adds overlapping pair costs. Source-context incidence prevents repeatedly spending the same mass, even if multiple graph edges share a context. This is a certificate family, not a promise of polynomial exact C-coloring or a substitute for a payable decoder.

## Tiny complete witness: a conditional triangle

There are three equally occupied sources `0,1,2`, binary emissions, and six contexts. For source `x`, its private context `t=x` has probability `4/5` and deterministically emits token 0. Each source also reaches its two incident **pair contexts** with probability `δ=1/10`: contexts `3,4,5` expose pairs `(0,1)`, `(1,2)`, `(2,0)` respectively, with opposite deterministic binary outputs at each pair. Other context probabilities are zero.

Every context individually sees at most two different laws, and a separate two-label fit at *every* context costs **zero**. Yet the co-visibility graph is a triangle, which no shared two-label encoder can color. All three graph edges have exact merge cost `(2δ/3)log 2`; one colliding edge can be chosen and the other two properly colored, so the graph certificate is **exact**:

```
independent-context floor     0
triangle graph certificate    (1/15)log 2 = .04620981203732968
complete shared-label oracle  (1/15)log 2 = .04620981203732968
```

Each source-specific *joint* law `P_x(t,y)` is supported on a disjoint set of `(t,y)` cells: private contexts differ, and endpoints of shared contexts emit opposite tokens. Its square-root density is `I₃/3`, so naively applying the fixed-joint-emission rank-two span bound would say `log(3/2)=.405465...`, **larger than the actual loss**. It is not a lower bound. For an even starker zero control, let three contexts reveal their respective source deterministically and all source-specific emissions be token 0. One upstream label yields loss **zero**, while the same unsound fixed-joint rank-one lift would say `log 3`. The context itself carries the information; it must not be counted against upstream label capacity.

[`search.py`](search.py) evaluates every unlabeled shared assignment only for the tiny oracle (four assignments in the triangle, one in the revealed-context control), every independently fitted context, all conditional centroids, graph edges and joint-support disjointness. All probabilities and logarithm interval endpoints are exact rationals via the sibling categorical-tree engine. [`results.json`](results.json) contains the full tables; the experiment takes about 0.005 seconds. No full-model performance or physical decoder implementation is claimed.

## Formal scope

[`Kelana/ContextConfusability.lean`](../../../Kelana/ContextConfusability.lean) proves (i) decoder existence iff proper coloring of the co-visibility conflict relation for arbitrary types and arbitrary active cells, (ii) a context-separated six-cell triangle pair floor, and (iii) fractional graph-obstruction charging across arbitrary selected source-context cell sets. There is no `sorry`. Its graph-forcing and pair-paid premises isolate the combinatorics from real-log KL; the centroid identity, KL equality condition and nonnegativity are analytic proofs above, while exact rational log intervals certify the finite numerical fixture.

```sh
python3 research/isa-quantization/context-confusability/search.py
lake build Kelana.CollisionPacking
lake env lean Kelana/ContextConfusability.lean
```
