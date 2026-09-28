# Design notes

Recorded from the project lead's "Kelana Project" discussion, September 19, 2026. These notes describe the exploration, not a fixed architecture.

## Computations and representations

The desired computation and the hardware's available operations are maps. Their source types and instruction names need not determine how we compose them. Packing, layout, restricted input domains and shared intermediates can expose cheaper constructions.

For desired computation F, encoding E, hardware computation H and decoding D, the replacement obligation is `D ∘ H ∘ E = F` on the declared domain. When `H ∘ E = E ∘ F`, successive computations can remain encoded without repeated boundary conversions. Different input and output representations generalize this equation.

An isomorphism preserves all information. An embedding uses a restricted hardware domain. A quotient discards distinctions the observer cannot detect. Each can be useful; invertibility is not always required.

Lean should help discover the structure as well as check the resulting proofs. Types can expose range restrictions, invariants, equivalence classes and collective lane layouts. Laws can justify changing a representation, fusing computations, or skipping whole operations and search subtrees.

## Tentative organization

Operations with backends, representations and composition rules are the current direction, inspired by LemmaKernel. There is no commitment to a manifest schema, folder hierarchy, custom language syntax or compiler framework. Let the toy problems reveal which abstractions earn their place.

An implementation may expose an intermediate decoding operation without making that intermediate mandatory for implementations of a larger dot product or layer. The source decomposition supplies one construction, not the definition of every legal construction.

Exact semantics, proof status and measured cost are different records. A theorem statement is not a completed proof; an executable reference is not a proof of emitted machine code. Hardware costs depend on workload and layout, including data movement, register use and synchronization.

For Lean acceptance, run the actual committed source with `lake env lean PATH` (and `lake build Module` for imported local dependencies) and preserve the compiler exit status. Do not infer success by grepping diagnostic text: Lean 4.33 can emit `error(lean.unknownIdentifier)`, which a literal `error:` filter misses. A September 24 attention-continuation handoff exposed exactly that false receipt; integration replaced the unavailable helper with direct rational algebra and compiled the complete source. If logs need filtering for display, capture the compiler status first and fail on its nonzero result, independently of the filter.

## Longer-term model question

Take a model such as a small Qwen, eventually perhaps a 9B model, and study faster, smaller implementations subject to a behavioral constraint. One proposed constraint is `KL(reference || candidate) <= epsilon`.

Still open:

- Next-token distributions or complete generated-sequence distributions?
- Every valid input, a bounded input domain, or an expectation over a specified workload?
- Which context lengths, batching regimes, cache states and hardware?
- Latency, throughput, resident bytes, or a tradeoff between them?
- Which implementation class and cost model does an optimality claim quantify over?

Equivalence, bounded approximation and optimality are separate obligations. Optimality needs a lower bound over the permitted alternatives. A local arithmetic bound needs a composition argument before it becomes a model-level divergence bound. These are research goals, not initialization requirements.

## Immediate scope

Describe all three Bonsai constructions in [BONSAI.md](BONSAI.md). Their integer computations provide an initial exact domain; surrounding floating-point scaling can be introduced separately. No automatic search system or inference replacement is being built in this initialization.
