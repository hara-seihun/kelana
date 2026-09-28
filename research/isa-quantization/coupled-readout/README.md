# Coupled readouts: eliminate interactions, not source operations

The independent-cell rule from [combined search](../combined-search/README.md) fails once a live consumer multiplies entries of the same stored table. The correct object is the **interaction graph of the stored description under complete observation**. Exact min-sum elimination across its separators preserves the full paid frontier. A second structure can be stronger than small separators: a binary readout gives a signed Ising energy, and a gauge-balanced interaction graph is solvable by min-cut even at large treewidth.

On four complete finite teachers, the search exhausts **33,685,504** table/program images. All six algorithms return the same error/serialized-byte/abstract-work frontier; **156** retained witnesses independently serialize and replay. Exact variable elimination takes **12.62 ms** versus **1,235.65 ms** for direct endpoint enumeration. A cheap sum-of-factor-minima bound followed by elimination takes **2.04 ms**, while a tighter split-bucket bound takes **14.16 ms**. This is CPU search time, not inference latency. The direct and scalar controls remain formidable: machine-family frontier points here buy fewer abstract operations, not better error at the same byte/work budget as the appropriate direct table.

## Complete map and paid grammar

Input `x` ranges over all eight three-bit states. The teacher supplies `f(x)` in quarter units, with the eight exact integer numerators recorded in [results.json](results.json). Two responses are smooth nonlinear tables, one is affine, one unstructured. No random sampling or unseen-input inference is involved. Define source continuations `A(x)=(x+1) mod 8` and `B(x)=rol3(x,1)`. Observe the complete five-output map

```
(f(x), f(Ax), f(Bx), f(x)*f(Ax), f(Ax)*f(Bx)).
```

A candidate selects `E(x)=(x or x² mod 8) xor k`, `k∈{0,1,2,3}`; two independent continuations from `{identity, add1 mod8, xor1, rol1}`; and one shared eight-entry response table `q`. Its three branches read `q(E(x))`, `q(C0(E(x)))`, `q(C1(E(x)))`, then multiply the corresponding pairs. The continuations act on the **candidate's own encoded state**, not the source successors. Table values are either `{-1,1}` in one bit or `{-2,-1,0,1}` in two bits. There are 128 structural choices and two precision choices.

The loss in the receipt is 256 times summed squared error over all 40 observations: unary differences use `16*(4q-y)²`, product differences `(16q_i*q_j-y_i*y_j)²`. All scoring is exact integer arithmetic. Mean squared output error is `loss/(256*40)`. The source output coordinates are observed, but no source intermediate or coefficient must be reconstructed.

A three-bit format tag precedes every actual image. Machine fields additionally contain one square-mode bit, two xor bits, two bits for each continuation and eight table codes: **three/four bytes**. Controls are a one-byte quarter-grid constant; exhaustive quarter-grid affine `intercept+slope*x` (two four-bit coefficients, two bytes); a single table reused across the source continuations (one/two/four-bit entries, **two/three/five bytes**). The low-bit direct tables are fitted against the *complete product objective*, not nearest branch rounding. The five-byte direct table is exact on these teachers. One shared constant produces all three branches and computes its square once.

Machine work is `10 + square + (k≠0) + (C0≠identity) + (C1≠identity)`: three reads, two products, five stores, plus input encoding and state updates. Direct/scalar controls cost twelve abstract operations; constants cost six. All arms fit a fixed seven-dynamic-word allowance and use their serialized fields without a second prepared copy. These unit-cost virtual instructions include their stipulated field access, not measured native register allocation or code-fetch behavior. Native opcode lengths, bit-field unpacking, code installation, cache behavior and timing remain unlowered. This is a complete frontier **within this explicit virtual-machine contract**, not a physical BPW/latency claim.

[replay.py](replay.py) packs every field LSB-first with zero byte padding, decodes only the image, recomputes all five endpoints, and checks exact byte length, work and error. [payloads.json](payloads.json) is the receipt. Tied witnesses can differ; all frontier triples agree.

## A factor graph derived from the whole consumer

For a fixed candidate structure, gather all observations using one table index into unary costs `U_i(q_i)`. Gather all product observations using indices `i,j` into pair costs

```
V_ij(q_i,q_j) = sum_observations (16*q_i*q_j - target_product)².
L(q) = sum_i U_i(q_i) + sum_(i,j) V_ij(q_i,q_j).
```

A self-product is a unary factor, not a fake edge. This grouping preserves the exact complete loss, including repeated labels, all source inputs and both live products. Numeric labels remain important: the program determines which variables interact. Equal carrier cardinality alone does not determine this graph or its elimination cost.

The prior independent-cell procedure chooses unary minima and ignores edges. It is strictly suboptimal in **437 of 1,024** teacher/structure/precision cases. Even with the exact source continuations on the first nonlinear teacher, its two-bit table scores 2,507 versus the coupled optimum 2,251. A correct algorithm must carry these interactions rather than assert that a small branch error controls a product.

To eliminate variable `v`, collect all factors containing it and form the message

```
m(neighbors) = min_(q_v legal) sum_(f in bucket(v)) f.
```

Keep an attaining `q_v` for each neighbor assignment. Factors not containing `v` remain unchanged. Repeating this rule produces the exact minimum, and reverse substitution reconstructs a real table. Min-fill chooses an order; no claim of minimum treewidth is made. If the largest retained neighbor set has size `w`, a `K`-value alphabet costs tables of size `K^w` and bucket enumerations of size `K^(w+1)`, times the factors being combined. The finite grammar has induced widths zero through three. This theorem applies to arbitrary finite factor scopes; higher-order consumers can create larger separators and invalidate any assumption that this particular width persists.

[Kelana/CoupledReadout.lean](../../../Kelana/CoupledReadout.lean) proves exact elimination with an attaining witness, preservation of outside-bucket residuals, and soundness of splitting a shared variable into independently optimized buckets. The last operation relaxes consistency: `min(f+g) ≥ min f + min g`, with a strict Boolean counterexample in Lean. The exhaustive oracle evaluates every complete five-output program directly, without using the factor construction; the low-bit direct controls also have independent endpoint-enumeration optimum checks. The numeric factor construction and C++ eliminator are not mechanically proved in Lean.

## Bounds: more informative can still be slower

The inexpensive structural bound sums the independent minimum of **each unary and pair factor**. Different occurrences may choose contradictory values for a shared table entry, so it is a lower bound, not an executable reader. Reject a structure only when a previously found point has no greater bytes/work and strictly smaller loss than the bound. This also preserves potentially tied frontier points.

A tighter mini-bucket bound partitions an elimination bucket into groups involving at most two variables, eliminates the shared variable independently in each group, then continues. Its domain contains every consistent assignment. On this workload it rejects only three extra structures (1,000 versus 997 of 1,024), while paying much more grouping and elimination work. The lesson from projection pruning survives genuine coupling: measure information gained per bound operation, not only the number of full assignments avoided.

## Beyond treewidth: signed interactions and exact cuts

For `q_i∈{-1,1}`, `q_i²=1`, so every product factor is a constant plus `-J_ij*q_i*q_j`. Choosing signs `g_i∈{-1,1}` and substituting `q_i=g_i*z_i` changes the coupling to `J'_ij=J_ij*g_i*g_j`. This is a bijection of legal **stored parameter assignments**, with no extra inference decoder. It is not a claim that arbitrary relabelings of numeric ISA state are free.

All `J'_ij` can be nonnegative exactly when every signed interaction cycle is consistent; parity propagation constructs the gauge or returns a conflict. For nonnegative `J'`, the edge energy is

```
-J' + 2*J' * [z_i differs from z_j].
```

Shift each unary potential by its smaller value, then use the remaining nonnegative differences as terminal capacities. Thus a minimum cut gives an exact readout. The Lean module proves the product-square identity, gauge identity, attractive/submodular equivalence and cut-energy representation; the max-flow implementation and theorem are not formally verified there.

[ising.hpp](ising.hpp), independently implemented by a Sol 6 worker, also handles frustrated graphs. It conditions vertices until the remaining signed graph is balanced, enumerates those bits, and solves the remainder by min-cut. Disconnected components are handled independently, so work is a sum of component conditioning searches, not a product over unrelated components. The deletion heuristic need not find the smallest conditioning set. Insufficient cut budget returns an explicit incomplete status, never an approximate answer disguised as exact.

Of the **512 binary** teacher/structure cases, **395** need no conditioned vertex; 84 need one, 31 two and two cases three. All match the exhaustive optima. [ising_test.cpp](ising_test.cpp) separately checks 1,200 brute-oracle cases, a **192-vertex dense balanced** graph with a certified planted optimum, a frustrated clique with a known optimum, and invalid-edge/overflow/budget boundaries. A 20-vertex antiferromagnetic clique needs 18 conditioned vertices under this heuristic and is rejected at the default 65,536-cut budget. This explicit failure boundary matters as much as the dense balanced success. Integer capacities and intermediate sums use 128 bits; the returned original loss must fit 64 bits. [ising-receipt.txt](ising-receipt.txt) records the bounded test run.

Small separator width and small frustration are **different** useful structures. Dense balanced graphs show why treewidth alone is not a universal measure of readout difficulty. Neither is a proof that a real trained region induces a cheap graph.

## Measured full-search ablation

Three fresh single-threaded processes per arm; medians include factor construction, control fitting and the full search. Independent per-structure diagnostics run separately. [timings.json](timings.json) pins both C++ source hashes and all samples. Counts below refer to machine candidates; RSS is `/proc/self/status`'s executable high-water mark.

| Search | Complete assignments | Factor entries examined | Structures pruned | ms | Peak RSS KiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| Exhaustive | 33,685,504 | — | 0 | 1,235.65 | 4,132 |
| Exact variable elimination | 0 | 125,800 | 0 | 12.62 | 4,148 |
| Independent-factor floor + elimination | 0 | 6,356 | 997 | **2.04** | 4,152 |
| Split-bucket floor + elimination | 0 | 71,634 | 1,000 | 14.16 | 4,156 |
| Ising for binary, elimination for two-bit | 0 | 108,688 + 1,047 cuts | 0 | 11.80 | 4,164 |
| Independent-factor floor + hybrid | 0 | 6,112 + 16 cuts | 997 | 2.07 | 4,156 |

The fastest measured arm is about **606×** faster than enumeration on this workload. The Ising route helps the unpruned mixed search but does not improve the already strongly pruned tiny search. Its general large-width tractable family is a separate structural result, not a claim of a win in every small instance. The largest retained exact factor set contains 240 table entries; this count excludes transient allocator/copy overhead and is not substituted for the measured RSS.

```
python3 research/isa-quantization/coupled-readout/run.py
lean Kelana/CoupledReadout.lean
```

The full oracle, all timing repetitions, codec acceptance and independent Ising tests finish in seconds, with no GPU. The next transfer question is which *real producer/consumer* yields sparse, balanced or low-frustration interactions in a paid representation. The approximation itself may change that graph. Expanding the same eight-state census would not answer it.
