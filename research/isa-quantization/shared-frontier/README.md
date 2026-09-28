# Shared executable choices: an exact joint frontier

A locally unattractive model-specific reader can be optimal for a collection of regions, but the resulting complete frontier cannot be recovered by sweeping a weighted error/byte/work score. This note gives both an exact decision rule for a *fixed* installed-program set and a small, completely enumerated counterexample to treating that rule as a full-frontier algorithm. The construction concerns finite response maps and an explicitly declared byte/work grammar, **not** trained-weight prevalence or measured ISA latency.

## Conditional opening theorem and its boundary

Fix an incumbent installed set `U` and one additive scalarization of distortion, static bytes, work and prepared live bytes. Let `a_i` be the cheapest *complete* tile cost among executable choices already available in `U`, including the best fitted scalar and direct response table. Let `b_i` be the complete tile cost of a proposed additional program family. If the installed family's new static/preparation charge in the same scalarization is `H`, and incumbent code bills remain paid, then opening that family changes the optimum by exactly

```
H - sum_i max(0, a_i - b_i).
```

Hence it strictly helps iff `H < sum_i max(0,a_i-b_i)`. This is a *conditional* marginal: another installed family can remove all the savings; a newly redundant incumbent code path can be closed, changing the comparison. It is not `n` times a typical tile saving. [The Lean statement](../../../Kelana/SharedFrontierActivation.lean) proves the identity for arbitrary integer tile costs and list length. In particular its `a_i` may be the optimum among multiple fitted competitors, not one arbitrarily chosen baseline.

For the **complete** joint frontier, carry the installed code/table identity. For every allowed shared-description choice `U`, take the Cartesian product of its legal tile realizations; add per-tile errors and online work, add serialized bytes, and charge installed code and shared tables once by *set union*. Retain nondominated vectors `(error, static bytes, online work, extra prepared bytes)` after the union. If an asset in `U` is never used, deleting it only improves costs, so enumerating supersets and discarding unused assets is exact. Equivalent current responses cannot be merged when their future available assets or installed-code unions differ. This finite algorithm is exhaustive for its declared grammar, whereas weighted optimization returns only supported exposed points.

## Discriminating finite grammar

There are three independent regions on input `x∈{0,1,2,3}`, with integer responses

```
A = (0,1,0,1),  A = (0,1,0,1),  C = (0,1,0,2).
```

Distortion is total squared response error at all twelve inputs. All responses and dictionary entries are signed one-byte integers. This abstract executable grammar pays **model-specific code** once per used kind, **tile payload** per use, and **extra prepared live state** separately:

| Kind | Installed code B | Per-tile B | Online work units/tile | Additional prepared B |
|---|---:|---:|---:|---:|
| Constant `b` | 1 | 1 | 1 | 0 |
| Integer affine `s*x+b` | 2 | 2 | 2 | 0 |
| Direct four-byte response table | 2 | 4 | 2 | 0 |
| One shared four-byte dictionary response, with one-byte tile selector | 3 | 1 | 2 | 4 per installed dictionary |

The dictionary also costs **four serialized bytes once**. Its prepared four bytes are a hot copy *in addition* to serialized model bytes; other arms use serialized bytes directly. A direct table may reproduce any teacher exactly, and duplicated direct tables can be consolidated using the shared-dictionary arm rather than pretending duplicate data is intrinsically mandatory. The affine family is fitted over every integer `s,b∈[-2,2]` without requiring its outputs to stay in the teacher's range; the constant is fitted over `b∈{0,1,2}`. These bounds contain the best fits for these teachers (their constant errors are at most five, while parameters outside the range already incur larger endpoint errors). Every dictionary entry in `{0,1,2}^4` is searched. An entry outside this box is coordinatewise clampable without increasing error, for the fixed three teachers, at unchanged costs. Exact direct responses dominate approximate direct responses of the same cost and work. Within this grammar, only the best fitted scalar of each kind need be retained at each tile.

The code byte counts and work units **define a toy machine's accounting**, not lengths or cycles measured on CPU/GPU. No native speedup follows. The code-path union is essential: a table read and dictionary read have distinct installed costs, and a mixed image pays both. Each row's serialized model bytes are also resident; the last column is only additional prepared state, not total residency.

## Exact oracle and consequences

[`frontier.py`](frontier.py) considers 81 dictionaries and all four per-tile kinds, and stores one witness per achievable cost vector; [`results.json`](results.json) has the six nondominated vectors among 161 distinct feasible vectors. Columns are `(squared error, complete static B, work, additional prepared B)`:

| Vector | Witness |
|---|---|
| `(0,14,6,0)` | Three exact direct tables, one shared direct reader |
| `(1,10,6,4)` | All three use one dictionary entry `A`; `C` incurs error 1 |
| `(2,12,5,0)` | One constant, two direct tables |
| `(3,11,5,4)` | One constant, two uses of `A` dictionary |
| `(4,9,4,0)` | Two constants, one direct table |
| `(7,4,3,0)` | Three constants |

For a single region, dictionary code plus entry plus selector costs `3+4+1=8` bytes, plus four prepared bytes, while an exact direct table costs `2+4=6`. Even for three regions a best *per-region* choice can miss the joint winner. At scalarized cost `2*error + static_bytes + prepared_bytes/4` (online work weight zero), the `(1,10,6,4)` shared image scores **13**, beating the exact direct image's **14** and all other vectors. No isolated tile would open the dictionary at this score; its best direct table costs six, while opening a dictionary costs at least nine including preparation. This is a genuine shared-choice reversal, not an unpaid dictionary.

More subtly, `(3,11,5,4)` is Pareto but **unsupported by every nonzero, nonnegative linear weighting** of the four metrics. The midpoint of feasible `(2,12,5,0)` and `(4,9,4,0)` has `(3,10.5,4.5,0)`: at equal error it is strictly cheaper in bytes, work and preparation. If *any* of those three resource weights is positive, this midpoint scores strictly lower, hence at least one of its two feasible endpoints scores strictly lower. If all three are zero, the nonzero error weight strictly prefers the exact `(0,14,6,0)` direct-table image. The all-zero objective selects everything and carries no frontier information. The Lean theorem `unsupported_by_any_nonzero_weights` checks both cases. Neither midpoint endpoint dominates `(3,11,5,4)` as a *single executable image*. A weighted opening threshold, even evaluated against all incumbent programs, cannot produce the complete frontier. Keep the vector frontier or answer constrained budget queries directly; convexifying by an imaginary half-image would be unsound for an indivisible deployment.

## Reproduce and scope

From the Kelana root, `python3 research/isa-quantization/shared-frontier/frontier.py` prints the complete compact JSON certificate. No fit queries are hidden: this script evaluates all twelve declared teacher values for every realization. `lake env lean Kelana/SharedFrontierActivation.lean` checks the general conditional identity. Both complete in seconds on CPU. The enumeration proves optimality **within this grammar**, not over arbitrary instruction sequences, entropy codes, direct tables with more sophisticated multi-tile compression, or real models. In particular a general compressor can discover the same reuse, so “dictionary” is not privileged as a format. Arbitrarily more dictionary entries, mixed-precision scalar fitting, alignment, address directories and actual lowering would change the physical frontier and require their own paid search.

[Program description](../program-description/README.md) measured code-size break-even for a constructed rotation template; here joint *approximation* and unsupported multiobjective points are the additional issues. [Instruction cells](../instruction-cells/README.md) fits actual produced partitions and table continuations but one teacher at a time. [Strong representation controls](../../quantization-discovery/representations/SYNTHESIS.md) show why real trained evaluation must include calibrated scalar formats, resident prepared tables, and complete live consumers. This finite witness supplies a search rule and an obstruction, not an adoption decision.
