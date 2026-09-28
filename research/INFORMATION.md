# Information and matrix lemmas

These modules provide reusable results about setup costs, exact byte representations and selected matrix-instruction interfaces. They are not global lower bounds for the current [2×2 ternary MAC](toy2/PROOF.md), and do not require that map to materialize an int8 activation tile or an unpacked accumulator.

## Amortization

[Kelana/Amortization.lean](../Kelana/Amortization.lean) defines vanishing work per use with an integer, division-free reciprocal-tolerance condition. It proves that finite setup work vanishes, that recurring work does not, and that a strictly smaller recurring bill eventually dominates any finite preparation difference. `recurring_cost_limit` is the selected reuse rule.

## Representation-independent information cuts

[Kelana/Information.lean](../Kelana/Information.lean) proves a symbolic finite injection bound using list lengths, without enumerating state machines. An exact decoder for n independently variable signed bytes needs an input representation with at least 8n bits. For N arbitrary byte-valued 16×16 activation tiles, the bound is 2048N bits even if the batch is encoded jointly and nonlinearly.

The theorem assumes the encoded state is the decoder's only input-dependent information source. Any additional input-dependent values, addresses, control flow or timing invalidate a cut that omits them. Static weight-dependent metadata may be part of the decoder because it contains no new activation information.

`mixed_port_lower_bound` applies that result to a stated class where all activation information passes through fixed, valid IU4/IU8 B operands, with no additional dynamic information through A, C or other channels. It gives `2N ≤ n4 + 2n8`. With additive charges satisfying `w8 ≤ 2w4`, `iu8_optimal_in_mixed_port_class` proves a lower bill of `N*w8`, excluding no-opcode preprocessing only when the cut assumption actually holds. This is a conditional interface theorem, not a gfx1151-wide optimum and not a result about tiles sharing the same activation input.

## Matrix meanings

[Kelana/Matrix.lean](../Kelana/Matrix.lean) proves signed-byte preparation preserves arbitrary ternary matrix operands, bounds the exact 16-term ternary-by-byte dot, and models the signed IU8 instruction's integer denotation. Its native layout and hardware validity remain separate obligations.

The identity is a valid ternary matrix and returns all activation information. `universal_matrix_cut` connects this example to the exact-byte bound. A nontrivial invertible 0/1 prefix-sum matrix is also formalized; differencing its outputs recovers its inputs. These examples explain when an information-preservation lower bound is justified. A thresholded or otherwise information-discarding function needs a different argument.

All modules are included in `lake build`. [Audit.lean](Audit.lean) prints the principal theorem axioms. No GPU measurements are involved in these lemmas.
