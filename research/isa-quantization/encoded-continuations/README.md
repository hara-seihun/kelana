# Jointly perturb two live encoded consumers

A small counterexample shows why fitting each map separately can miss the best *shared* label system. Two exact maps each need one XOR in a suitable 3-bit labeling, but their labelings cannot agree. Perturbing both maps cuts the one-step squared error in half relative to keeping the original labeling. This is an exact finite-domain result, not a GPU speed or trained-model result.

## Contract

The eight states have numeric observations `0..7`. The source has two live branches, `F` and `G`, and either order of a two-step continuation may be observed. Write `s=(0 4)` for the permutation exchanging states 0 and 4:

```
F(x) = x xor 1
G(x) = s((s(x)) xor 2)
```

A single 3-bit stored label `E(x)` is shared by both branches. The permitted online instructions are `xor 1` on the F branch and `xor 2` on the G branch, with all subsequent transitions staying in this label system. For scoring only, decode the state through `E⁻¹`:

```
F_E(x) = E⁻¹(E(x) xor 1)
G_E(x) = E⁻¹(E(x) xor 2).
```

This scoring decode is **not** a claimed free instruction. The proposed use requires an upstream producer already writing `E(x)` and downstream consumers accepting these labels. If a numeric result is needed, charge its final conversion. The represented state retains all eight distinctions; this is a changed pair of maps, not a lossy bottleneck or an implicit hidden-tensor decoder.

Each map fits exactly when given its own labels: `E_F(x)=x`, `E_G(x)=s(x)`. A separated implementation can carry both three-bit codes, or convert at the split and any merge. It achieves zero error with two XORs but pays the second live label or conversion. An arbitrary per-branch lookup can also implement the exact maps; our lower bound does not include that larger instruction grammar.

One *shared* exact labeling is impossible: conjugates of two XOR masks commute, whereas `F(G(0))=7` and `G(F(0))=3`. This is the existing simultaneous-conjugacy obstruction. The new question is the exact distortion frontier after changing both maps, with both continuation orders included.

## Complete finite search

`search.py` enumerates all `8! = 40,320` bijections `E`. It checks separate XOR masks and the degenerate same-mask case. Any ordered pair of distinct nonzero 3-bit XOR masks reduces to `(1,2)` by an invertible relabeling of the code space, so the search covers all such native pairs. Error is summed over all eight inputs. `path` scores both `F_E∘G_E` against `F∘G` and `G_E∘F_E` against `G∘F`. Hamming counts disagreements; squared error uses the numeric `0..7` observations. These are exact integer truth tables, with no fitted test set.

| Shared-label candidate | One-step Hamming | One-step squared | Path Hamming | Path squared |
| --- | ---: | ---: | ---: | ---: |
| Original code `E=id`, change only G | 4 | 64 | 8 | 128 |
| Best one-step squared, `E=[0,1,4,3,2,5,6,7]` | 8 | **32** | 12 | 160 |
| Best equal-weight sum of one-step and path squared | 10 | 52 | 12 | 120 |

For the 32-error code, **both** maps change and each contributes 16 squared-error units. This beats the one-map-only original-code control's 64. It spends more path error, so choosing it without the continuation would be a mistake. The complete squared-error Pareto pairs `(one-step, path)` are `(32,160)`, `(48,128)`, `(52,120)` and `(80,96)`. At equal one-step and path weight, the third pair costs 172 against 192 for `E=id`. The code in `results.json` gives a witness for each point. The same-mask family cannot fit the source exactly and has one-step Hamming minimum 8 versus 4 for distinct masks.

The branch observation is not an intermediate tensor that must be decoded. The path errors are computed by composing the encoded XOR instructions and decoding *only to score the final observed state*. The path reversal is a warning: branch-only quantization rankings do not transfer automatically to a live continuation.

## Cost and scope

The shared code needs one three-bit live state, two XOR operations at the split, and one eight-entry labeling table if the producer needs it. Two independent exact labels require six live bits if both are materialized; a conversion or a richer direct operation is the alternative. Counting three-bit labels as packed state gives a 3-versus-6-bit comparison, not a physical 1-versus-2-byte GPU claim. An arbitrary permutation table has eight three-bit entries, or 24 static bits before alignment. Instruction constants, producer preparation, branch fanout, output observation and register placement remain to be priced for any actual ISA lowering. In particular, an already numeric producer forced to construct `E` at runtime can erase the apparent benefit.

This is a deliberately constructed permutation teacher, not evidence that trained SiLU regions have this structure. The exact conjugacy controls and earlier nonlinear gauge experiments address different endpoints. Here the finite search gives a joint *approximate* frontier under one shared encoded state and both branch orders. It excludes a zero-distortion two-XOR shared-label implementation and quantifies the approximation needed within this grammar. It does not exclude a lookup, a wider register, a different instruction family or a better representation for real weights.

Reproduce in under a minute from the repository root:

```
python3 research/isa-quantization/encoded-continuations/search.py
```

The command rewrites `results.json` deterministically using only Python's standard library. Every permutation is exhausted; no stochastic fit, floating-point arithmetic or GPU is involved.
