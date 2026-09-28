# Search for representations of the whole observed computation

Recorded from the project lead's September 20 discussion. The target remains faster full-model ternary inference on gfx1151. The immediate experiment is a small exact search where complete maps fit in memory, rather than another isolated projection optimization.

## The question

Treat registers, memory and lane placement as machine state. Instructions are composable state transitions. The required result is an observation of the final state; intermediate values need not resemble gate, up, hidden activations, or matrices.

Can a different labeling or a lossy encoding of intermediate states make a long sequence cheap, with at most one final conversion? Look for the structure of collisions and transitions before choosing recognizable arithmetic operations.

This is not a new correctness formulation. `Kelana/Composition.lean` already proves endpoint simulation, chain composition, factorization through an encoder, operation descent, and a compound operation that descends even when its individual stages do not. The missing part is executable discovery across these choices, with an honest implementation cost.

## Three separate questions

For a desired map F and a proposed carrier H on the same reachable input domain:

1. **Sufficiency:** does H(x) = H(y) imply F(x) = F(y)? If so, a decoder exists on the image of H. Otherwise return the two colliding inputs as a rejection witness.
2. **Closure:** can a chosen continuation operate on the carrier? For a reusable representation and transition T, H(x) = H(y) must imply H(T(x)) = H(T(y)). A fixed remaining program needs only its actual final observation, not every possible continuation.
3. **Cost:** can the ISA implement the producer, continuation and final observer cheaply? A decoder's existence is not its implementation. Retaining the original input always passes sufficiency and may save no work.

These questions need separate results. A proof of one is not evidence of either of the others.

## Relabeling

A reversible encoding E can conjugate a source transition F to a hardware transition H when H E = E F. One shared E for a family lets intermediate conversions cancel. Different E_i at different boundaries permit more programs, but the search must retain the correspondence between boundaries.

For independently permuted input and output labels, a finite map's fiber-size multiset classifies it. Under one shared state relabeling, functional graph structure matters. For a labeled family, even separate conjugacies of every operation do not imply simultaneous conjugacy.

Arbitrary relabelings do not preserve numeric order, bit locality, affine form, or instruction cost. Search structural equivalence separately from inexpensive realization. Bit-affine maps, lane permutations, radix codes and prepared weight tables are candidate realization families, not a universal restriction.

## Important search traps

- Two carriers with the same fibers can have different continuation costs. Fiber keys can deduplicate information questions, not arbitrary ISA search states. For example x and x xor 1 are both injective, but the same following instruction observes different numeric values.
- Requiring closure under every source operation reinstates the source decomposition. Search a complete region before asking whether its individual stages descend.
- The coarsest quotient for every possible continuation is a reusable interface, not automatically the right interface for one fixed model. More allowed continuations generally require more distinctions.
- A full machine state that retains its original inputs passes every final-observation sufficiency check. Dead-state projection and a priced continuation are needed before that fact becomes useful.
- The input domain must be producer-reachable and closed under any transitions used in a reusable quotient. A fixed schedule can instead have different domains at each boundary.
- Approximate closeness is not transitive. Approximate maps need explicit error accounting and acceptance against the complete consumer; they cannot be merged into exact equivalence classes.
- Integer, ideal floating-point and native ISA semantics are different contracts. An undocumented WMMA error bound does not become a theorem by giving it an algebraic name.

## Bounded first round

The lead owns `observer-search/`: finite factorization with rejection witnesses, fixed-suffix observations, continuation-stable quotient refinement, shortest distinguishing continuations, and small priced decoder search using exact numeric state keys. The note and discovery index are also the lead's.

An Opus worker at maximum thinking owns `whole-map-search/`: complete small three-trit gated-network synthesis, with a declared bitvector instruction grammar, input convention, baseline and priced endpoints. A bounded negative is a useful result; the two-trit lookup already exists and is not a new discovery.

A second Opus worker at maximum thinking owns `relabeling/`: simultaneous conjugacy of small transition families, obstruction examples, and the difference between arbitrary and cheaply realizable boundary permutations.

Each run records its domain, grammar, explored states, cost convention and exclusions. CPU-only semantic exploration precedes GPU experiments. A hardware experiment is justified by an actual proposed program, not the existence of an unspecified decoder.

## Weight interfaces are a search variable

the project lead specifically challenged the adopted two-bit-per-weight interface. It is not a constraint. An arbitrary ternary sequence needs asymptotically log2(3), about 1.585, bits per trit at fixed worst-case capacity; nonuniform or structured model weights can have a lower statistical entropy. Block rounding, alignment and scales must be counted separately.

The original HALO layout already stores 128 trits in 26 bytes plus a two-byte scale. The adopted batched kernels repack them to 32 bytes of two-bit codes plus the same scale. Returning to the original density would save 17.65% of this weight stream, before considering changes in decode instructions, layout and reuse. The current throughput gain does not isolate the merit of the two-bit interface because the schedule also changed.

the project lead corrected the framing explicitly: do not assume compact storage must be unpacked. Use the packing as the input coordinate system, compose ISA maps directly on it, and solve for the desired map's structure up to relabeling. Recovering individual trits is not part of the contract. Returning to a familiar tensor between source operations is not part of the contract either.

For an input encoding E and ISA composition P, a structural match up to bijective output relabeling means P(E(x)) and F(x) have exactly the same fibers on the allowed inputs. Fiber refinement establishes only a general decoder. First search for structural matches and retain their relabeling witnesses. Then search whether the next consumer can operate in those labels, or whether one shared labeling serves an entire instruction family. Do not require a cheap conventional decoder before allowing a structural proposal into the discovery set; price realization separately before claiming a native win.

A matched compact-versus-two-bit batched comparison remains a possible engineering control, but it is not a substitute for this map search. Neither byte counts nor the mere existence of a relabeling establishes an end-to-end speedup.

## Joint boundary search now implemented

The lead's [joint-observer experiment](../joint-observer/README.md) chooses carriers and consumers together by intersecting evaluated function spaces. A left annihilator of the source functions turns membership into an exact linear constraint on consumer coefficients. Taking the rank of the evaluated image, rather than the coefficient nullspace, avoids counting polynomial identities as new functions.

The first construction carries eleven states across a boundary where the original source basis distinguishes 27. Six independent source functions share that carrier; none of the original hidden units needs to be reconstructed. The complete six-parameter family has an eleven-data-instruction lowering and a Lean endpoint proof. A concrete pair of colliding inputs also shows which original atom cannot survive. The construction is not a fixed trained-model replacement. The [fixed trained-region experiment](../joint-observer/TRAINED.md) now evaluates that transfer and rejects the eleven-state carrier on the prescribed regions. Its new capacity bound uses output distances to reject lossy state counts independently of an instruction grammar. Exact packed encodings remain open: all 27 input distinctions fit in the original five-bit radix-3 code, without recovering trits or hidden units. The next search must retain those distinctions and include quantization cells in the observed region.

## Connection to full-model performance

The integrated engine now gives a measured 20% generation gain at 32 sequences and 88% prefill gain at 128 rows/pass with A8 routing. These are whole-model numbers, owned by Bonsai's batch comparison. A new FFN instruction reduction cannot be multiplied directly into those numbers: unchanged attention, recurrence and output-head work still cost time.

The synthesis work must eventually supply a reusable construction with costs that scale to real dimensions. A lookup over all small inputs, a rapidly expanding polynomial, or a cheap program tailored to one output table does not establish that. The small search is intended to find identities and representations worth generalizing, including explanations of why a tempting family fails.
