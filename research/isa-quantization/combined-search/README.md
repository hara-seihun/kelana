# Combining sound reductions: fewer candidates is not the fastest search

**Result:** all eight ablations of projection pruning, indexed joins and a legal symmetry preserve the complete `(serialized bytes, abstract online work, complete two-observation error)` frontier on twelve exhaustive targets. Their savings do **not** multiply. Projection plus symmetry takes **30.2 ms**, while all three take **107.8 ms** and allocate an extra state index. Eliminating independent readout cells exactly takes **7.21 ms**. The unreduced search takes **1,835 ms**. These are measured **CPU search** times, not native inference times.

The useful mathematical integration is to identify which variables can be eliminated before combining search machinery. A live continuation can couple observations through one shared table without coupling the table's distinct entries. Sufficient statistics then replace a Cartesian code search. When a consumer genuinely mixes those entries, that elimination stops being valid; that interaction, not a larger enumeration limit, is the next search dependency.

## Complete finite contract

The producer supplies `x,y ∈ {0,1,2,3}`. All sixteen inputs are observed at two times. The teacher response is

```
(f(x,y), f((x+y) mod 4, x)).
```

Eight targets are seeded rounded bounded nonlinear responses of generic bivariate cubic polynomials, two are rounded/clipped affine responses, and two are unstructured tables. Their exact integer response vectors are pinned in [results.json](results.json); only target generation uses floating `tanh`. All candidate scoring and pruning use exact integers. Values in the receipt are in quarter-unit coordinates: mean squared error in ordinary output units is `sse_units / (32*16)`. This is complete-domain fitting, not a sampled or held-out quality result.

A searched image selects all of:

1. An encoding of two two-bit lanes: independently choose `0`, `x` or `y`, then add one shared static bit `k`, modulo four.
2. Zero, one or two prefix instructions. Each instruction updates a chosen lane with `lane+1+k`, `lane+other`, or `lane xor other`, modulo four where applicable.
3. A read port and four-entry table. The table uses either one-bit values `{-1,1}` or two-bit values `{-2,-1,0,1}`.
4. A live continuation: identity or one instruction from the same grammar. Read the **same paid table and port** before and after this instruction, from the candidate's own state.

The shared `k` is selected once. It is not independently reselected across the join. The encoding, prefix, continuation, port, table precision and table entries all vary jointly. No source coefficient or source intermediate must survive.

There are **774** labeled prefixes and **447** distinct complete input-to-live-state maps after retaining the `(k, prefix length)` tags. A suffix sees both numeric lanes, not just the current observed value. Identity continuations remain legitimate competitors; the required second observation is still scored and cannot be erased merely because a candidate chooses not to change its state.

### Paid controls and serialization

Every image starts with a three-bit format tag. Machine images additionally store two two-bit encoding choices, the one-bit shared constant, two-bit prefix length, three bits per prefix instruction, a three-bit continuation, one-bit read port and four table codes. Pad only to the next whole byte. This gives three to four bytes in this grammar. There is no free per-image decoder, scale or instruction choice.

The same frontier includes:

- A one-byte quarter-grid constant, used for both outputs.
- Exhaustively fitted scalar affine maps `b+a*x+c*y`, with all three coefficients stored in two-bit integer or four-bit quarter-unit fields. Evaluate the same fitted map on the source continuation. These cost two bytes.
- A **single shared** direct sixteen-entry table used at both times, not thirty-two separately charged responses. One-, two- and four-bit readers cost three, five and nine bytes. The nine-byte table is exact on every teacher here.

[replay.py](replay.py) independently serializes each frontier witness, decodes only its bytes, and replays every observation. [payloads.json](payloads.json) records the actual image bytes and replay receipts. Both scalar and table competitors optimize their legal fields, rather than using nearest source-weight rounding. Tied witnesses may differ across reductions; the entire frontier of resource/error triples is identical.

Online work is an explicit **virtual-machine** instruction count. Machine images pay two input lane initializations, their prefix, their continuation, two table reads and two output stores: `6+n+(continuation≠identity)`. Scalar readers pay four multiply-adds, one source-state update and two stores; direct tables pay two address formations, one state update, two reads and two stores. Constants pay two immediate stores. Input lanes, saved first observation and second observation fit four dynamic word slots; the scalar schedule may additionally use a temporary. All arms are admitted under a fixed five-dynamic-word cap; this does not claim equal native register use. Static images are accessed directly in this abstract machine, with no prepared copy. The fixed virtual instruction semantics are shared, while every model-specific opcode/operand is in the image. Native field loading, register allocation, caches, code lengths and latency have **not** been lowered. Thus this is an exact frontier for the declared byte/work grammar, not a claim of a physical BPW or native-time improvement.

## The three reductions and their composition

**Projection (`P`).** For a fixed structure, all current and continued observations selecting cell `j` share one value `q_j`. For that cell let `n_j` count observations, `s_j` sum target values, and `v_j` sum squared target values. The unconstrained-real response floor is

```
L = Σ_j (v_j - s_j²/n_j),
```

omitting empty cells. This is the complete-response orthogonal projection, with an indicator column per table cell. A least-common denominator for `1..32` and 128-bit intermediates give exact comparisons. Because actual losses are integral, compare `ceil(L)` with an incumbent. A branch is discarded only if an existing point uses no more bytes/work and has strictly lower error than this floor. This preserves all potentially tied frontier triples. It does not add unrelated layerwise errors or treat a tangent fit as containment.

**Indexed join (`J`).** Store tagged complete prefix maps in a trie keyed by numeric state at successive input points. A suffix consists of continuation, port and table; traverse its matching prefix index, accumulating the global two-observation squared error. Nonnegative unvisited terms and an appropriate resource-compatible incumbent permit subtree rejection. Numeric-state-identical prefixes at the same tags retain one executable witness. The index shares evaluation across prefix signatures; it is a different implementation of the exact preimage-join principle from [search factorization](../search-factorization/README.md), not the previous Hamming bitset code. Its complete state prevents mixing the shared constant or discarding a live lane.

**Symmetry (`S`).** Swap both lanes, both encoder choices, every instruction's target lane and the read port. The shared `k`, table, total bytes and work stay fixed, and the full two-observation map stays identical. Every orbit has a representative with port zero. Restricting the port halves the complete labeled space. Merely swapping an intermediate while holding the observer fixed would be invalid.

**All three.** Before table-code queries, the combined arm projects each partially specified trie node's observations into its shared readout-cell space, leaving unvisited observations free. This is a containing completion envelope. It is sound but weak: for every fixed table, the trie already computes a partial error at least as large as that projection floor. In this experiment the prepass removes no additional table-query visits. The Lean lemma `prepass_prune_is_redundant` gives the order argument: an exact partial loss above a projection floor already exceeds any improved incumbent whenever the prepass rejects. Combining two valid bounds has not supplied independent information.

## Eliminate table values rather than searching them

For a fixed structure, the complete squared error is exactly

```
Σ_j [v_j + n_j*q_j² - 2*s_j*q_j].
```

When the legal table is the product of per-cell grids, choose each `q_j` minimizing its own bracket. All observations and both times using that cell participate in the same statistics. The procedure uses `Σ_j |Q_j|` cell comparisons rather than `Π_j |Q_j|` complete table assignments. It returns a feasible image attaining the grid-aware floor, not just a relaxation.

[IndependentReadout.lean](../../../Kelana/IndependentReadout.lean) proves the integer sufficient-statistic identity, the quadratic argmin rule, and the general separable-reader minimization theorem. The grouping of this C++ grammar's observations by label remains an executable obligation; the independent byte replay and exhaustive frontier oracle discharge its finite acceptance check, not a Lean verification of the C++ implementation.

This is ordinary variable elimination applied to the **observed executable map**. The surprising practical point is that a live shared continuation does not itself defeat separability. A polynomial readout in correlated coefficients, a table reused inside arithmetic or a transition depending on readout values can couple cells again. The theorem does not authorize eliminating those dependencies.

## Measured ablation

Three fresh single-threaded processes per arm, each solving the same twelve targets; medians include input enumeration, index construction when used, control fitting and all search work. [timings.json](timings.json) records every sample, compiler, platform and source hash. `/proc/self/status` supplies the executable's peak resident set; `getrusage` inherited the launcher's high-water mark and was therefore not used for the arm comparison. Timing is hardware/load dependent; frontier triples and work counts are deterministic.

| Arm | Complete candidates scored | Search ms | Peak RSS KiB |
| --- | ---: | ---: | ---: |
| Exhaustive | 35,368,704 | 1,834.66 | 4,396 |
| P | 932,432 | 60.84 | 4,392 |
| J | 1,184 | 183.94 | 4,880 |
| P+J | 1,184 | 209.41 | 4,880 |
| S | 17,684,352 | 958.91 | 4,384 |
| P+S | 475,440 | **30.19** | 4,392 |
| J+S | 645 | 98.41 | 4,880 |
| P+J+S | 645 | 107.78 | 4,868 |
| P+S+exact cell elimination | 7,890 | **7.21** | 4,388 |

Candidate counts concern the machine family; every timing includes the same control fits. The index has 5,863 nodes, 398,684 bytes of node objects before allocator capacity/overhead. P+J+S still visits **10,090,358** index nodes and computes **483,141** projection bounds. Its tiny terminal candidate count hides that work. The elimination arm records one exact optimized table per surviving structure, so its larger terminal count than J is not evidence of more work. It is approximately **254× faster** than raw enumeration and **4.2× faster** than P+S on this workload, with no indexed-memory allocation. This is a bounded search measurement, not a general complexity or inference theorem.

The paid controls also matter. On both linear teachers, no machine-family point survives the full frontier. Two nonlinear teachers retain machine points that improve the error/byte tradeoff; several others retain a machine point only by spending six rather than seven abstract operations. The direct table is exact for nine bytes. None of this establishes that these programs beat calibrated scalar quantization on a trained network.

## Reproduce and next discriminator

```
python3 research/isa-quantization/combined-search/run.py
python3 research/isa-quantization/combined-search/replay.py
lean Kelana/IndependentReadout.lean
```

The complete compiled experiment and all isolated timing repetitions finish in seconds. There is no GPU use. The next question is **which small live consumer creates nonseparable readout interactions while keeping a compact admissible envelope**. A multiplication or table-driven transition would test genuinely new coupling. Enlarging the same separable table search would only demonstrate a problem already solved by its sufficient statistics.
