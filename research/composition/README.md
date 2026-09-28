# Composing representations toward the ternary FFN

The target remains Bonsai's complete FFN residual map. Internal gate, up, hidden, quantized and accumulator arrays are descriptions of the current implementation, not mandatory materialization boundaries. This directory tests general rules before choosing another native kernel. It is not a new compiler.

## Checked rules

[Composition.lean](../../Kelana/Composition.lean) supplies four useful distinctions:

- `Simulates` and `compose` relate different state types across a computation. The relation can include range, layout and reachable-state conditions. `chain` carries such a relation through a sequence without intermediate decoding. `observed_equal` requires agreement only at the final observation.
- `factors_iff` characterizes a sufficient representation: inputs with the same encoding must have the same final observation. Its converse uses a representative of each encoding, so it proves existence, not a cheap implementation. The representation type is restricted to reachable encodings by a surjectivity hypothesis.
- `operation_descends_iff` states when one operation can run on a reduced representation. `compound_closure_without_stage_closure` proves why requiring that for every source operation is too strong. With encoding `E(x,y)=x+y`, the stage `(x,y)→(x,2y)` cannot run from E alone. Following it by `(x,y)→(2x,y)` makes the whole chain `E→2E`. A discovery method must admit multi-operation rewrites, not only one-operation substitutions.
- `tolerance_is_not_transitive` prevents treating approximate closeness as exact equality in an e-graph. Absolute error budgets compose additively only under the stated setting. This is not a KL propagation theorem.

These are standard mathematical mechanisms, now represented in the project. No theorem asserts that a semantically sufficient encoding has cheap native instructions.

## Seven-stage profitability window

[PackedChains.lean](../../Kelana/PackedChains.lean) models two accumulators with unknown initial values in `{0,1}`. Every stage adds a digit in `{0,1,2}` to each. Encoding is `x+16*y` in one byte.

- `sum_commutes`: integer addition and packing commute for every chain length.
- `capacity_iff`: ordinary nibble decoding is correct for every admitted input exactly through seven stages. The worst lane is `1+2n`. At eight stages, a low-lane carry can corrupt the high lane even before the whole byte overflows.
- Synthetic costs are ordinary stage 2, packed stage 1, enter 3, exit 3. Thus the packed chain costs `n+6` against `2n` and first wins at seven.
- `profitable_window`: precisely seven stages are both universally legal and strictly profitable for a fully packed chain under this fixed encoding and cost model.

The [executable search toy](toy/README.md) compares local lowering with whole-path search and records boundary counterexamples. Production of both input forms is outside this toy. Gateway costs are declared test parameters, not measured gfx1151 charges. A known-zero initial state admits constant folding of entry and changes the break-even point; it is a separate variant, not the main contract.

[CompositionCost.lean](../../Kelana/CompositionCost.lean) proves the best schedule for every chain length, without enumerating schedules. Any packed schedule pays at least two boundaries, costing 6, and can save at most 7 stage units. Thus it saves at most 1 overall. Ordinary execution attains the bound below seven stages; a packed prefix of seven followed by ordinary stages attains it thereafter. `best_is_optimal` quantifies over every allowed ordinary/packed schedule. It does not quantify over other representations, stage reorderings or arbitrary programs.

This gives a search rule: track both accumulated conversion savings and consumed representation headroom. A path can become profitable just before it becomes invalid. Validity cannot be inferred from word overflow alone.

## Match the representation at both ends

the project lead's research rule: a representation can lose at one operation and win across a composition because the producer already emits what the final consumer needs. Do not charge a decode followed by an encode merely to reproduce a source-level intermediate. Conversely, an attractive instruction substitution is not a win if its output must be expensively reconstructed before the next operation can use it.

Search over regions with declared entry and exit representations. Allow a region to contain operations that cannot individually run on the proposed encoding. Measure the complete recurring path between the actual boundaries, including traffic and representation changes, while keeping input-invariant preparation outside the recurring cost. Intermediate representations are candidate choices, not optimization constraints.

The current FFN comparison makes this concrete. Pairing gate/up saves matrix instructions but expands streamed weights and adds a decoder. A different candidate can let activation preparation produce a table of packed linear forms, let compressed ternary weights select those forms directly, and retain packed token-pair sums across an entire scale block. Neither candidate should be judged by an isolated multiplication count.

## Applying the rules to Bonsai

[FFNBoundaries.lean](../../Kelana/FFNBoundaries.lean) anchors the rules at current FFN boundaries:

1. Gate and up are produced from one shared input. `shared_producer_boundary` allows a rewrite proved only on those reachable pairs. Requiring correctness on arbitrary independent gate/up arrays can unnecessarily exclude a valid whole-FFN rewrite.
2. At the hidden-to-down boundary, both quantized codes and scales remain observable. `quantizer_certificate_composes` turns the existing exact quantizer-cell certificates into equal inputs for any downstream consumer. The reference uses integer numerators and a retained integer maximum; it is not a model of HIP floating-point instructions.
3. The final consumer may identify even more states than the quantizer does. A two-code difference consumer erases simultaneous code translation. Therefore preserving the entire quantizer signature is a useful sufficient condition, not a compulsory boundary for every optimization.
4. `residual_context_composes` carries equality through an unchanged residual context without assuming floating-point addition is associative.

For the deployed model, the actual chain includes normalization, input sign/Hadamard/quantization, ternary gate/up projections, SiLU-product, another sign/Hadamard/quantization, down projection and residual addition. We must fix which final bits or behavioral observations are required before accepting a rewrite. The code-and-scale certificate is currently an exact reference result. The six-layer [consumer-cell probe](../ffn/consumer_cells.json) found that coarse independent intervals certified no codes, so a cheap general certificate generator is still missing.

## Hardware meaning and cost are separate obligations

The [gfx1151 inventory](../../hardware/gfx1151/README.md) describes the available instruction set. A native claim needs the exact operand/modifier profile and applicable lane or wave semantics, not just an ideal algebraic name. The [paired WMMA experiment](../ffn/packed-wmma/NOTES.md) demonstrates why: the integer construction is correct, but native floating WMMA deviates even on integer-valued inputs. Its rounded decoder has passed tests; the required hardware error bound is open.

One-time weight preparation amortizes away. Recurring decoding, activation preparation, larger weight traffic, register residency and spills do not. An experiment granting free dynamic packing must say so. Algebraic equivalence, cost-model improvement and measured native improvement are distinct results.

## Prior work to build on

- [Equality saturation for tensor graph superoptimization, TENSAT](https://arxiv.org/abs/2101.01332) separates exploration from extraction to avoid committing prematurely to rewrite order. It explores its supplied rewrite vocabulary, not every possible representation.
- [ULPPACK](https://proceedings.mlsys.org/paper_files/paper/2022/file/e09d45e14e9ece7142217550ddd3c4d0-Paper.pdf) packs low-precision computations into commodity wider arithmetic. Its packing-depth and cross-term analysis is directly relevant to our headroom constraints.
- [Simultaneous modular reduction and Kronecker substitution for small finite fields](https://arxiv.org/abs/0809.0063) combines packed integer or floating arithmetic with coefficient recovery and fewer conversions.
- [Local completeness in abstract interpretation](https://www.math.unipd.it/~ranzato/papers/csv23.pdf) studies when reduced semantics preserve the required computation and compose. Our consumer-factorization lemmas are a small functional starting point, not an implementation of that paper's framework.

Current next step: combine source-grounded instruction meanings with these representation relations for an FFN submap. Preserve alternatives across representation boundaries, allow composite rewrites whose individual stages do not descend, and reject a candidate only after considering both validity and complete boundary cost.
