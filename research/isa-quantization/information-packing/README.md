# Information-budget packing: multiple mergers under one shared label

The [pair-collision certificate](../collision-packing/README.md) pays for a same-label pair in each `(C+1)`-source hyperedge. That detects incompatibility even in binary output, but on `n` equally occupied point masses its all-hyperedge bound stays at `2 log(2)/(C+1)` while true clustering grows like `log(n/C)`. A label also has a global *information budget*: it carries at most `log C` nats about the source. Paying for all unavoidable mergers together closes this gap, and fractional localization finds a high-information region when a large uninformative background makes the whole-panel budget zero.

## Information identity and theorem

Let positive total teacher occupancy `M=Σ_s ν_s` define `S∼ν/M`, and draw `Y∼p_S` on a finite vocabulary. Let `G=g(S)` take at most `C` values. Candidate emissions `q_c` are stationary and shared across all sources. For each assignment, centroid optimality and the information chain rule give

```
min_{q_c} Σ_s ν_s KL(p_s||q_g(s))
  = M [H(Y|G) − H(Y|S)]
  = M [I(S;Y) − I(G;Y)]
  = M [I(S;Y) − H(G) + H(G|Y)].                         (1)
```

Hence every assignment and every candidate emissions satisfy the **global information floor**

```
loss ≥ M [I(S;Y) − log C]_+.                          (2)
```

This is not a rank calculation: the loss is the *remaining conditional information after the best C-valued label*, rather than an overlap with a C-dimensional linear subspace. The floor is exact on equally occupied, distinct point-mass sources when `C` divides their number (`H(S)=log n`, `H(G)≤log C`, balanced groups attain both). It is also a legal bound for an arbitrary own-state occupancy `w(s,c)` with teacher marginal `ν`: minimizing linear rows over labels for fixed `q_c` reduces to a deterministic `g`, just as in categorical-tree.

**Nonuniform heavy-source refinement.** Within a subset of mass `M_A`, let `α=max_{s∈A} ν_s/M_A`. The label containing that source has probability at least `α`. When `α≥1/C` and `C>1`, concavity of entropy, first conditioning on that label, then equalizing the other `C−1` labels, gives

```
H_A(G) ≤ h(α) + (1−α) log(C−1) ≤ log C,             (3)
```

where `h(x)=−x log x−(1−x) log(1−x)`. The right-hand side of the first inequality decreases once `α≥1/C`; the heavy label may be even larger, which only reduces its entropy. Use `B_A=log C` when there is no heavy source, (3) otherwise, and `B_A=0` for `C=1`. Point masses of weights `(7,1,1,1)/10` at `C=2` have `H(S)−h(.7)=.3 log 3=.32958369`, **exactly their optimal KL**. The emission-subspace floor on the same complete example is only `−log(.8)=.22314355`. For `C=1` the information floor is the exact one-centroid loss for *every* categorical teacher, not just point masses.

## Localization without repeating source mass

For *any* source subset `A` let `M_A=Σ_{s∈A}ν_s` and form its normalized local teacher channel. Restricting a global `g` to `A` still has at most `C` labels. Its locally charged cost therefore obeys

```
Σ_{s∈A} ν_s KL(p_s||q_g(s)) ≥
     L_A := M_A [I_A(S;Y) − B_A]_+.                     (4)
```

Choose any collection of subsets (not necessarily disjoint) and rational shares `λ_A≥0` satisfying `Σ_{A∋s}λ_A≤1` for every source. Nonnegative pointwise KL and (4) yield

```
loss ≥ Σ_A λ_A L_A.                                  (5)
```

No candidate partition is enumerated for (2), (4), or (5). The global singleton collection `A=S` recovers (2); a small analyst-selected family can be evaluated with `O(|A|V)` entropy arithmetic per subset, and the fractional incidence LP is over *subsets selected by the analyst*, not label partitions. Enumerating all `2^n` source subsets is optional; the tiny numerical bound here does so before its separate complete-partition acceptance oracle. This exponential subset enumeration is not presented as a scalable search algorithm. Fractional shares prevent double-charging the same teacher mass; **maxima**, rather than sums, should combine this with pair packing and subspace floors unless their source loads are jointly budgeted.

The information floor and pair packing are complementary. If `I_A(S;Y)≤log C` for every chosen subset, (5) is zero even when more than `C` distinct close emissions force a positive clustering loss. The crossing Bernoulli-product fixture below is such a case. Conversely, pair-only charges see one merger per small subset and cannot price the entropy of a large cluster's many unavoidable mergers; (2) is sharp on the point-mass family.

## Decisive masked-signal construction

Take four point-mass teachers on a four-token vocabulary, each of occupancy `.05`, plus one uniform-law source of occupancy `.8`. At `C=2`, the *whole* channel has `I(S;Y)=.2 log 4 < log 2`, so (2) is **zero**. Restrict to the four signal sources: their mass is `.2` and they carry `log 4` local nats per source, making (4) **`.2 log 2=.13862944`**. The global two-dimensional emission-subspace certificate is `−log(.9)=.10536052`: its density is `.8 uuᵀ+.05 I₄`, with eigenvalues `.85,.05,.05,.05`. Optimized pair-only `(C+1)`-hyperedge packing gives `.11126957`. The exact two-label categorical optimum, from all 16 unlabeled partitions, is `.20237711`. Thus localization beats both global information and the spectral floor **on the same complete instance**, without claiming an exact optimum or duplicating the spectral mechanism. Pair-only can still win on the crossing-product case.

| Complete instance, `C=2` | Full information | Local fractional information | Pair-only fractional | Exact cluster optimum |
| --- | ---: | ---: | ---: | ---: |
| Four equal point masses | .69314718 | .69314718 | .46209812 | .69314718 |
| Point masses, masses `7:1:1:1` | .32958369 | .32958369 | .18483925 | .32958369 |
| Four rare point masses plus `.8` uniform background | 0 | .13862944 | .11126957 | .20237711 |
| Four crossing Bernoulli-product laws | 0 | 0 | .08720802 | .13081204 |

The fixtures and rational interval endpoints are in [`results.json`](results.json). [`search.py`](search.py) uses the sibling rational atanh-series log enclosures; the floating LP produces only proposed shares, which are truncated to exact dyadics and rationally rescaled until every incidence load is at most one. The numerical program enumerates all unlabeled partitions **only for its independent small oracle**. It takes about 0.3 seconds on this host. Strictly positive perturbations of the point masses preserve each displayed strict comparison by continuity of finite entropy/centroid costs.

## Lean and boundary

[`Kelana/InformationPacking.lean`](../../../Kelana/InformationPacking.lean) proves the exact finite information-balance algebra, the rational fractional subset-charge theorem using the collision-packing incidence result, and the fact that the label receiving a heavy source has at least its mass. No `sorry`. Shannon entropy, real logarithms, KL centroid optimality, entropy nonnegativity and upper caps (2)–(3) are analytic arguments here rather than Lean theorems. The rational interval program certifies the finite fixture scores; it does not prove those general real-log inequalities. A stochastic hidden-state mixture predictor is not bounded by a fixed `C`-emission-label theorem unless its actual predictive family satisfies that premise.

```sh
python3 research/isa-quantization/information-packing/search.py
lake build Kelana.CollisionPacking
lake env lean Kelana/InformationPacking.lean
```
