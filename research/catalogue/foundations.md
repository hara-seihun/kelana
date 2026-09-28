# Packed computation, proofs and native building blocks

[Research desk](README.md)

Generated from `foundations.json`; the JSON owns classifications.

<a id="ffn-coarse-activation-quality"></a>
## A4 activation speed and quality boundary

Category: Promising but not yet. Evidence: Matched A4 FFN kernels run 1.27-1.47x faster than A8 variants, but local errors grow by orders of magnitude and the full-model tests show changes accumulate with modified layers. Naive ternary activations fail behavior preservation..

Fast local A4 arithmetic is a measured tradeoff, not permission to treat all FFN errors as interchangeable.

Comparison: Own matched native FFN A8 kernels and native model logit tests, without an accepted quality/rate budget.

Boundary: Short prompts and local relative RMS do not establish held long-context language quality or stability.

Next decision: Fix an explicit held quality criterion and compare full-model A4 schedules on the same workload, including bias and accumulation across layers.

Sources: [research/ffn/batched/lossy/README.md](../ffn/batched/lossy/README.md), [research/ffn/batched/lossy/consumer-geometry.md](../ffn/batched/lossy/consumer-geometry.md).

<a id="ffn-transformed-weight-absorption"></a>
## Absorb Hadamard/sign map into down weights

Category: Strictly bad under the tested conditions. Evidence: The exact dyadic transformed weights raise the down image from 1.75 to roughly 8 bits per weight across the model, for only 0.195% of MACs in deleted adds; moving the quantizer changes its basis and synthetic outlier error rises. A local four-bit scale-ratio proposal instead saves about 4.5% bytes at 0.98% weight error..

The shared transform is cheap relative to the weight image that would have to absorb it.

Comparison: Measured real weight entropy and explicit batch-one traffic model, not a native end-to-end benchmark or universal compression lower bound.

Boundary: Different cache/reuse patterns and a format that executes the transform implicitly are outside the tested direct absorbed image.

Next decision: Reject direct expanded absorption here; separately test the scale-ratio representation for model quality and native read cost.

Sources: [research/ffn/transformed-weights/FINDINGS.md](../ffn/transformed-weights/FINDINGS.md).

<a id="argmax-final-head-certificate"></a>
## Actual greedy-head prefix certificate and sign-count rearrangement

Category: Promising but not yet. Evidence: Native replay reproduces all 744,960 captured GPU logit bits. At cut 34/40, three real prompts yield 11.98-12.88% optimistic byte savings with ordinary count bounds. Signed counts cut survivors to 1,659/7,246/2,736 and give 10.50-12.05% savings in a 64-byte-line model; finer groups reduce survivors but lose more to metadata..

Greedy observation permits some certified pruning on actual head inputs, but the prefix still computes 85% of every row and needs a paid metadata/survivor schedule.

Comparison: Modeled head weight traffic against the full 278 MB direct stream, not measured GPU head or whole-model speed.

Boundary: Only three captured prompts; candidate scoring, bound computation, compaction, launches and repeated fetches remain unpaid. Sampling has another observation contract.

Next decision: Find a correlated-response index that beats the sign-count 64-byte-line model after its construction and native execution are charged, then test held head queries.

Sources: [research/argmax-observer/final-head/README.md](../argmax-observer/final-head/README.md), [research/argmax-observer/grouped-certificate/README.md](../argmax-observer/grouped-certificate/README.md).

<a id="ffn-batched-adoption"></a>
## Batched FFN full-model A8 adoption and equal-output layouts

Category: Promising but not yet. Evidence: Automatic A8 routing in Bonsai Halo reaches 159.4 aggregate tok/s versus 132.8 at 32 sequences; eight sequences use the original FFN and reach 142.5 versus 133.1. Research-layer matched-hash IU8 schedules improve 1.09-1.14x, scaled-FP16 1.01-1.24x and selected A4 schedules 1.29-1.98x by batch size..

Batched reuse and tile ownership are genuine local improvements; full-model routing now uses A8. The A4 result preserves its lossy A4 map, not A8 quality.

Comparison: Named deployed engine and own native arithmetic controls, not a published best-in-class SOTA baseline.

Boundary: A8 changes floating evaluation order; layer-local A4 speed does not establish quality acceptance or full-model TPS.

Next decision: Compare integrated layouts at real serving batch/context distribution and include dual-image storage for any automatic selector.

Sources: [research/ffn/batched/README.md](../ffn/batched/README.md), [research/ffn/batched/RESULTS.md](../ffn/batched/RESULTS.md), [research/ffn/batched/bench/README.md](../ffn/batched/bench/README.md), [research/ffn/batched/bench/MEASUREMENT.md](../ffn/batched/bench/MEASUREMENT.md), [research/ffn/batched/GEOMETRY.md](../ffn/batched/GEOMETRY.md), [research/ffn/batched/tile-ownership/README.md](../ffn/batched/tile-ownership/README.md), [research/ffn/batched/dense-consumer/README.md](../ffn/batched/dense-consumer/README.md), [research/ffn/batched/compact-scaled/README.md](../ffn/batched/compact-scaled/README.md), [research/ffn/batched/scale-carrier/README.md](../ffn/batched/scale-carrier/README.md), [research/ffn/batched/arithmetic/README.md](../ffn/batched/arithmetic/README.md).

<a id="discovery-packed-input-boundary"></a>
## Bit-affine gather-address obstruction

Category: Strictly bad under the tested conditions. Evidence: A checked finite argument shows no bit-affine map injects all 27 valid three-trit packed2 words into the five address bits available to the wave gather..

The attempted one-gather address lowering cannot distinguish all inputs using this packed coordinate and bit-affine map.

Comparison: Exact within the specified input encoding and address grammar; not a failure of all packed lookup programs.

Boundary: A nonlinear instruction, different coordinate or extra carried state is outside the obstruction.

Next decision: Search nonlinear address construction or a coordinate whose producer emits the needed address directly.

Sources: [research/discovery/packed-input-boundary/README.md](../discovery/packed-input-boundary/README.md).

<a id="bonsai-codec-constructions"></a>
## Bonsai byte codec, peel packing and IU4 decomposition

Category: Promising but not yet. Evidence: Lean proves codec inversion, three carry-isolated 10-bit lanes, two all-ternary radix-64 dots per byte dot, and an exact two-IU4 decomposition for arbitrary signed-byte activations. A compiled peel emits the intended four ordinary word instructions. Runtime repacking costs more than the isolated peel saving..

Preparation can move into the weight image, but online conversion, output decoding, storage and operand production decide the actual choice.

Comparison: Three peel streams use 38 word operations per six bytes against 42 packed-half operations before repacking; radix-64 fusion costs W8+24V against 2W8 after offline packing. Neither symbolic comparison establishes a native win.

Boundary: The no-carry, affine-digit and fixed-radix bounds exclude only their named encoding families. Signed-byte activations defeat the simple fused-row radix decoder by collision.

Next decision: Measure complete recurring costs against predecoded IU8 under a declared resident-byte budget and reuse regime, rather than the original decoder alone.

Sources: [research/RESULTS.md](../RESULTS.md), [research/trit-constructions.md](../trit-constructions.md), [research/constructions/iu4_radix16-certificate.json](../constructions/iu4_radix16-certificate.json), [research/INFORMATION.md](../INFORMATION.md), [research/PROBLEM.md](../PROBLEM.md), [research/cost-model.md](../cost-model.md).

<a id="ffn-consumer-directed-codes"></a>
## Choose hidden codes for down-projection response

Category: Promising but not yet. Evidence: Full-consumer oracle search lowers fifteen-level down-projection RMS from 3.95% to 1.85% on layer 0 and 9.43% to 3.03% on layer 10. Cheap rank-128 observers and sequential prepared feedback recover only small fractions; fixed sketches sometimes improve surrogate error while worsening the true response..

The consumer has exploitable rounding correlations, but the tested inexpensive selectors do not capture the oracle gain.

Comparison: Nearest independent rounding on eight native rows and their deployed A8 target; oracle computes full target and is not an executable throughput control.

Boundary: No held model-quality acceptance or native speed result. Feedback block 1024 costs about 10% of down MACs and 35.6 MB prepared coefficients.

Next decision: Find a cheap direction-selecting observer, then use independent acceptance against the true consumer rather than self-scored sketches.

Sources: [research/ffn/consumer-quotient/README.md](../ffn/consumer-quotient/README.md), [research/ffn/consumer-quotient/random-sketch/README.md](../ffn/consumer-quotient/random-sketch/README.md).

<a id="ffn-contracted-toy-observer"></a>
## Compile an observed two-trit gated network to BFE and PERM

Category: Promising but not yet. Evidence: Lean proves a two-instruction gfx1151 observer for every two-trit byte-output function vanishing at zero. Native checks pass 2,313 cases. A 64-unit ReLU example uses the observer instead of its roughly 25-operation monomial construction..

A small complete observed region can discard its hidden layer and intermediate arithmetic entirely.

Comparison: Constructed toy with packed four-bit input and one-byte observed output, not a trained Bonsai FFN or measured native throughput.

Boundary: Tables grow as 3^d and trained A4 activations have fifteen values with dynamic scales.

Next decision: Find a trained region with a small cheap sufficient state and a compatible consumer before scaling its lookup.

Sources: [research/ffn/contracted-map/README.md](../ffn/contracted-map/README.md), [research/ffn/nonlinear/NOTES.md](../ffn/nonlinear/NOTES.md).

<a id="composition-proofs"></a>
## Composition across representation boundaries

Category: Promising but not yet. Evidence: Lean proves observed equality under relational composition and shows a whole region can descend through an encoding even when a source stage cannot. A packed nibble chain wins one synthetic instruction only in its seven-stage valid window under declared 3+3 boundary charges..

Search and price complete producer-to-consumer paths instead of forcing source intermediate recovery.

Comparison: The seven-stage cost is synthetic, not gfx1151 throughput or a Bonsai FFN improvement.

Boundary: Semantic factorization establishes the existence of a decoder, not an affordable implementation; tolerance is not transitive equality.

Next decision: Pair source-grounded ISA maps with valid domains, entry and exit representations and measured recurring cost for a trained region.

Sources: [research/composition/README.md](../composition/README.md), [research/composition/toy/README.md](../composition/toy/README.md).

<a id="ffn-dense-quadratic-collapse"></a>
## Dense low-rank contraction of the real FFN even part

Category: Strictly bad under the tested conditions. Evidence: On 256 layer-0 captures, spectral rank 1600-2000 is needed for 10% quadratic-response error while independent-output arithmetic breaks even near rank 10; tested shared basis retains about 15% energy at its rank-321 arithmetic break-even..

The exact even-part identity does not make its dense matrix cheaply low rank on this layer.

Comparison: Deployed ideal-arithmetic gate/up/down MAC and storage estimates; both quantizers omitted.

Boundary: Negative for dense spectral and tested shared bases, not product-form tensor decompositions or the quantized complete map.

Next decision: If revisiting contraction, test product-form factors with an output-error and complete-cost bound rather than another dense Q matrix.

Sources: [research/ffn/contracted-quadratic/FINDINGS.md](../ffn/contracted-quadratic/FINDINGS.md).

<a id="exact-packed-toy2"></a>
## Exact packed 2x2 ternary MAC and restricted one-dot cores

Category: Promising but not yet. Evidence: Lean proves the all-input map and a 9-instruction arithmetic core against a 13-instruction elementwise int4 core. Exhaustive 531,441-case checks and assembly counts support the result. With a different free-wire/output-label contract, a radix-64 single-dot core is optimal in its declared arithmetic grammar, but no native timing or complete preparation bill exists..

A prepared weight-dependent orientation lets two outputs share one signed-i4 dot. Other output labels and free wire permutations change the best core substantially.

Comparison: Strict componentwise 9 versus 13 vector instructions against the specified elementwise baseline, not against a best known full GPU program; the native correctness attempt lacked GPU headroom.

Boundary: The baseline and later free-wire core have different boundary assumptions. Neither demonstrates whole-kernel throughput or global instruction optimality.

Next decision: Price the input wire, output conversion, register use and compatible downstream consumer under one common native contract; test the one-dot route against the best prepared baseline.

Sources: [research/toy2/README.md](../toy2/README.md), [research/toy2/PROOF.md](../toy2/PROOF.md), [research/toy2/BENCHMARK.md](../toy2/BENCHMARK.md), [research/toy2/optimality/NOTES.md](../toy2/optimality/NOTES.md), [research/toy2/radix64/README.md](../toy2/radix64/README.md), [research/toy2/TWO-INSTRUCTION-HANDOFF.md](../toy2/TWO-INSTRUCTION-HANDOFF.md).

<a id="argmax-proxy-certificate"></a>
## Greedy-head prefix and anchor bounds on FFN-input proxies

Category: Strictly bad under the tested conditions. Evidence: At 39/40 blocks the corrected proxy runs retain 1,261 or 3,426 of 248,320 rows and save at best about 2.2% of head bytes before bound construction. A previous-query Lipschitz anchor excludes zero rows on the second query even with the true winner score supplied..

Independent magnitude bounds and a single anchor do not prune early enough for these non-head proxy inputs.

Comparison: Real 278 MB HALO head with two captured layer-10 FFN inputs; exact scaled-integer scores, not actual final-head distribution.

Boundary: The GPU FP32 numerical interval was not established in that proxy experiment; the real head inputs behave differently.

Next decision: Use actual final-head captures and correlated signed residual information rather than adding another one-query anchor.

Sources: [research/argmax-observer/README.md](../argmax-observer/README.md).

<a id="ffn-batched-scale-carriers"></a>
## Grouped scales, deferred pairs and persistent half carriers

Category: Promising but not yet. Evidence: Grouped scale deferral saves epilogue work; matched interleaved experiments give 1.063-1.083x at 256 rows. Paired deferral gives 1.11-1.16x against its own control before online certification cuts the gain to 1.03-1.05x. A persistent half carrier wins 1.154x at 256 rows against its bit-identical control on layer 0, but nearly ties an improved paired control..

More persistent accumulator representations reduce online work and register pressure, but fitted scale and half-rounding errors change the numerical map.

Comparison: Own matched controls at layer boundary, not the fastest candidate at every batch size and not a full-model SOTA comparison.

Boundary: Model quality for grouped/deferred approximations is unaccepted; half-kernel captured replay still differs by 0.1635% from standalone behavior.

Next decision: Resolve half-carrier numerical transfer, then measure against the strongest selected batch schedule and held whole-model quality together.

Sources: [research/ffn/batched/grouped-scales/README.md](../ffn/batched/grouped-scales/README.md), [research/ffn/batched/deferred-carrier/README.md](../ffn/batched/deferred-carrier/README.md), [research/ffn/batched/half-carrier/README.md](../ffn/batched/half-carrier/README.md), [research/ffn/batched/half-carrier/model-quality/README.md](../ffn/batched/half-carrier/model-quality/README.md), [research/ffn/batched/carrier-comparison/README.md](../ffn/batched/carrier-comparison/README.md).

<a id="ffn-hidden-spanning-and-consumers"></a>
## Hidden-boundary layouts and direct nonlinear consumers

Category: Promising but not yet. Evidence: A wide-panel bit-exact spanning schedule improves the 32-row observed FFN, while larger-batch hidden-store rearrangements lose against the faster arithmetic base. Lean proves product, downstream sum and polynomial-derivative observations directly on packed words. Native half polynomial quality panels exist but no full-FFN speedup for those consumers..

Preserve a packed word through its next consumer when it eliminates a decode; a stage saving can vanish when the baseline changes.

Comparison: Own span and nonlinear controls, with local quality measurements against original and matched A4 references.

Boundary: Direct consumer proofs do not price preparation, native floating error or full model behavior.

Next decision: Target a substantial trained producer-to-consumer region and measure the complete path against the current fastest schedule.

Sources: [research/ffn/batched/spanning/README.md](../ffn/batched/spanning/README.md), [research/ffn/batched/direct-consumers/README.md](../ffn/batched/direct-consumers/README.md), [research/ffn/batched/direct-consumers/CARRY.md](../ffn/batched/direct-consumers/CARRY.md), [research/ffn/batched/direct-consumers/native/README.md](../ffn/batched/direct-consumers/native/README.md), [research/ffn/batched/consumer-polynomial/README.md](../ffn/batched/consumer-polynomial/README.md).

<a id="discovery-observer-instruction-first"></a>
## Instruction-first packed observer search and sign-orbit sharing

Category: Promising but not yet. Evidence: Of 531 distinct tested partitions on three packed trits, 16 admit distinct output labels of a gated-network function. A constructed five-hidden-unit network evaluates via MAD plus BFE without trit expansion. A separate shared sign-orbit coordinate has exactly 14 necessary states over 676 gate/up pairs; one observer loses to the earlier path but two can share preparation and win in the restricted instruction grammar..

Search ISA transitions as composable maps, then ask whether their fibers and labels support a source-network family.

Comparison: Constructed networks and restricted instruction counts, not trained-FFN native timing.

Boundary: Input packing is assumed at entry and the sign-orbit result observes only sign; an individual relabeling is not free hardware work.

Next decision: Find a packed-input exact match on a trained or representative complete region, carry its label through a real downstream consumer and charge entry/output conversions.

Sources: [research/discovery/observer-search/PLAN.md](../discovery/observer-search/PLAN.md), [research/discovery/observer-search/README.md](../discovery/observer-search/README.md), [research/discovery/observer-search/fiber-cost/README.md](../discovery/observer-search/fiber-cost/README.md), [research/discovery/observer-search/fiber-cost/SIGN-ORBIT.md](../discovery/observer-search/fiber-cost/SIGN-ORBIT.md).

<a id="quant-fiber-conditional-producer"></a>
## Lossless response-first fibers and producer-domain conditional codes

Category: Promising but not yet. Evidence: The real block response-first image shrinks 143,360 to 140,948 bytes including scales and header with exact reconstruction for arbitrary inputs; a matching query reads 20,512 row bytes. A local nonlinear producer enclosure permits five-byte exact replacement of a 128-weight block but needs a 5,440-byte guard. A correlated producer search proves a 272-bit robust optimum larger than HALO on the tested hidden box..

Response-first storage and producer-restricted equivalence are exact, but the current guard and robust real-block format do not buy net deployed compression.

Comparison: HALO byte image and declared upstream producer domains, no GPU throughput result.

Boundary: The fitted hidden box fails five held captures; guard overhead exceeds saved local bytes.

Next decision: Derive a broad cheap producer invariant through normalization, and replace literal guards with a paid compact predicate before claiming conditional savings.

Sources: [research/quantization-discovery/FIBER.md](../quantization-discovery/FIBER.md), [research/quantization-discovery/FIBER-PROOFS.md](../quantization-discovery/FIBER-PROOFS.md), [research/quantization-discovery/FIBER-RANK-PROOFS.md](../quantization-discovery/FIBER-RANK-PROOFS.md), [research/quantization-discovery/ENCLOSURE.md](../quantization-discovery/ENCLOSURE.md), [research/quantization-discovery/ENCLOSURE-PROOFS.md](../quantization-discovery/ENCLOSURE-PROOFS.md), [research/quantization-discovery/PRODUCER.md](../quantization-discovery/PRODUCER.md), [research/quantization-discovery/PRODUCER-PROOFS.md](../quantization-discovery/PRODUCER-PROOFS.md), [research/quantization-discovery/BONSAI-PRODUCER.md](../quantization-discovery/BONSAI-PRODUCER.md), [research/quantization-discovery/ELIMINATION-PROOFS.md](../quantization-discovery/ELIMINATION-PROOFS.md).

<a id="quant-discovery-assignment"></a>
## Paid quantization assignment and replayable bounds

Category: Promising but not yet. Evidence: Lean establishes suffix-aware paid dominance, certificate bounds and exact robust L1 row optimization over a complete integer box. A 16-block real Bonsai assignment has replayed objective interval [46,88] after 2,048 expansions. Its 64-bit sub-bit packet scores 25 on calibration but 763 held and 11,684 at its exact box worst case; robust family optimum costs 272 bits against HALO 224..

Search can certify progress without pretending a calibration-only compact code preserves the actual map.

Comparison: Frozen finite mode family and abstract bit-plus-error objective, not native instructions, loss or model throughput.

Boundary: Unresolved [46,88] gap; real sampled sub-bit candidate is unacceptable outside fitted observations.

Next decision: Use a producer-guaranteed domain and a native priced consumer before selecting a rate/error candidate.

Sources: [research/quantization-discovery/README.md](../quantization-discovery/README.md), [research/quantization-discovery/PRIOR-ART.md](../quantization-discovery/PRIOR-ART.md), [research/quantization-discovery/MATHEMATICS.md](../quantization-discovery/MATHEMATICS.md), [research/quantization-discovery/BOUNDS.md](../quantization-discovery/BOUNDS.md), [research/quantization-discovery/CERTIFICATES.md](../quantization-discovery/CERTIFICATES.md), [research/quantization-discovery/FLOAT-CONTRACT.md](../quantization-discovery/FLOAT-CONTRACT.md).

<a id="ffn-packed-wmma-core"></a>
## Paired FP16 WMMA tile with rounded integer recovery

Category: Promising but not yet. Evidence: On gfx1151 the register-resident core measures 1.54-1.60x a faithful IU8 tile, or 1.80-1.83x with deferred recombination. The tested rounded decoder recovered all integer results in 768,000 accumulators. A native counterexample proves unrounded FP32 WMMA is not exact even on tiny integer operands..

A core win exposes equal FP16 and IU8 WMMA issue rates, but the floating accumulator is not an integer oracle.

Comparison: Own IU8 tile baseline with operands resident; neither streamed weights nor the complete FFN is timed.

Boundary: No proof-grade native accumulation-error bound. Streaming weight traffic and activation preparation may erase the core gain.

Next decision: Bound native error or design a robust integer recovery, then benchmark a streamed full-FFN schedule with producer work included.

Sources: [research/ffn/packed-wmma/NOTES.md](../ffn/packed-wmma/NOTES.md).

<a id="ffn-register-and-lds-lookup"></a>
## Register PERM and LDS lookup FFN schedules

Category: Strictly bad under the tested conditions. Evidence: Register PERM computes exact ternary projections without expansion but measured schedules reach only 0.27-0.56 of native IU4 useful MAC throughput once accumulation and byte-lane draining are counted. The implemented materialized-LDS lookup family loses from table construction and traffic..

A fast isolated lookup does not substitute for a matrix instruction that also accumulates.

Comparison: Matched chain-swept IU4 issue-rate control and batch projections, not a bound on every table or shared-addition program.

Boundary: Negative is specific to measured lookups, lane layouts and table construction. Alternative fused consumers remain open.

Next decision: Only revisit with a consumer that absorbs accumulation or shares table preparation across enough distinct outputs, and price all accesses.

Sources: [research/ffn/batched/register-observer/README.md](../ffn/batched/register-observer/README.md), [research/ffn/batched/lookup/README.md](../ffn/batched/lookup/README.md).

<a id="ffn-seven-product"></a>
## Seven-product projection at batch

Category: Promising but not yet. Evidence: One Strassen level within a 128-scale block preserves the matched integer result. Seven products win 1.13-1.21x against identical-tiling eight-product control, and 1.13x at 32 rows, 1.04x at 64/128 against the fastest eight-product shape, but lose 1.17x at 256..

Fewer matrix instructions help until an extra live accumulator blocks the wider token tile.

Comparison: Own eight-product batch controls; its sum operands require A3 and incur 2.3x the projection quantization error of A4.

Boundary: No accepted model-quality threshold or full-model comparison for A3.

Next decision: Find an A4-quality operand encoding or a register schedule that retains the wider 256-row tile, then measure whole-model quality and rate.

Sources: [research/ffn/batched/seven-product/README.md](../ffn/batched/seven-product/README.md).

<a id="discovery-joint-observer-constructed"></a>
## Shared eleven-state carrier for a constructed gated family

Category: Promising but not yet. Evidence: Exact linear algebra and Lean prove a six-parameter family of three-trit ReLU networks through one eleven-state carrier. The assembled data region takes eleven instructions, eight for its odd subfamily, without recovering original hidden channels..

Choosing producer and observer together can produce a small exact family that no per-stage recovery requirement would find.

Comparison: Constructed integer-weight gated networks; no native timing or trained Bonsai speed result.

Boundary: The same eleven-state carrier collides on every tested trained region, so the construction itself does not transfer exactly.

Next decision: Keep the method but seek an injective trained-region carrier, possibly with a costed sideband and quantizer-cell continuation.

Sources: [research/discovery/joint-observer/README.md](../discovery/joint-observer/README.md), [research/discovery/joint-observer/SIDEBAND.md](../discovery/joint-observer/SIDEBAND.md).

<a id="quant-direct-cpu"></a>
## Sign-folded direct CPU consumption of ternary codes

Category: Promising but not yet. Evidence: On a real 5,120x128 block, the exact SIMD direct consumer takes 7.835 microseconds including fresh table preparation versus 13.464 for its paired AVX-512 VNNI dense control, 1.72x faster, with 2.68% more storage than HALO. A shorter preparation DAG is optimal within its scalar add/sub grammar. A two-query consumer shares code extraction and table preparation..

Packed labels can index input-dependent response tables directly rather than reconstructing the weights first.

Comparison: Named dense single-core integer-block control and paired query panel, not a full GPU or whole-model SOTA benchmark.

Boundary: Scales, GPU scheduling and full FFN are excluded. CPU table costs and access pattern differ from a wave-register lookup.

Next decision: Compare shared multiple-output direct consumers at a native boundary where preparation amortizes and charge actual tables and scale operations.

Sources: [research/quantization-discovery/DIRECT.md](../quantization-discovery/DIRECT.md), [research/quantization-discovery/DIRECT-NATIVE.md](../quantization-discovery/DIRECT-NATIVE.md), [research/quantization-discovery/DIRECT-PROOFS.md](../quantization-discovery/DIRECT-PROOFS.md), [research/quantization-discovery/SIMD.md](../quantization-discovery/SIMD.md), [research/quantization-discovery/SIMD-PROOFS.md](../quantization-discovery/SIMD-PROOFS.md), [research/quantization-discovery/SIMD-CODEGEN.md](../quantization-discovery/SIMD-CODEGEN.md), [research/quantization-discovery/sign-orbit-prep/README.md](../quantization-discovery/sign-orbit-prep/README.md), [research/quantization-discovery/paired-consumer/README.md](../quantization-discovery/paired-consumer/README.md).

<a id="discovery-relabeling"></a>
## Simultaneous family relabeling with costed boundaries

Category: Promising but not yet. Evidence: Exact finite-state searches show per-operation equivalence need not give one shared relabeling: six-state two-permutation families have 121 per-operation classes but 901 family orbits. A relational screen separates a point/plane action that composite cycle tests cannot; boundary programs are synthesized in a declared grammar..

A shared labeling across a family can eliminate connectors, but only a realizable boundary map gives an execution plan.

Comparison: Finite permutation families and abstract boundary charges, not gfx1151 throughput.

Boundary: An unimplemented semantic bijection is not a free instruction; no trained-region native speedup.

Next decision: Search one label compatible with consecutive real consumers and synthesize only the entry/exit conversion under source-grounded charges.

Sources: [research/discovery/relabeling/README.md](../discovery/relabeling/README.md).

<a id="quant-direct-gpu"></a>
## Single-query GPU sign-orbit register lookup

Category: Strictly bad under the tested conditions. Evidence: The exact real-block sign-orbit wave lookup measures 9.299 microseconds versus 3.505 for packed two-bit and 3.287 for dense int8 controls. All 12 integer query panels match..

The CPU direct-consumption speedup does not transfer to this single-query gfx1151 lowering.

Comparison: Matched 5,120x128 integer-block HIP kernels and paired GPU events, with no FP16 scale work.

Boundary: Does not reject shared-query, multi-output consumers or a different table layout.

Next decision: Only revisit if several outputs share index extraction and table work enough to overcome the measured single-query gap.

Sources: [research/quantization-discovery/gpu-direct/README.md](../quantization-discovery/gpu-direct/README.md).

<a id="ffn-full-map-native"></a>
## Single-row whole-FFN paired WMMA, table and preexpanded maps

Category: Strictly bad under the tested conditions. Evidence: Real layer-10 one/eight-token paired and direct-table captures were bit-exact but whole intervals and even best intervals did not beat the matched baseline. Preexpanded weights remove recurring decode yet increase gate/up to 181 MB and lose across tested sweeps..

Matrix instruction savings were consumed by streamed weight size, table traffic, address generation and decode. Offline preparation did not make recurring reads free.

Comparison: At one token baseline 0.287 ms, paired 0.335 ms, table 0.378 ms; at eight tokens 0.463, 0.502 and 1.739 ms medians respectively.

Boundary: Negative for measured one/eight-token schedules and layouts, not every table or fused region. The paired floating WMMA also needs a proved error bound for changed numerical maps.

Next decision: Keep the exact spanning identities, but reject these particular whole-image schedules; a new proposal must avoid the demonstrated traffic and pay full recurring cost.

Sources: [research/ffn/full-map/README.md](../ffn/full-map/README.md), [research/ffn/full-map/harness/README.md](../ffn/full-map/harness/README.md), [research/ffn/full-map/preexpanded/README.md](../ffn/full-map/preexpanded/README.md).

<a id="ffn-quantized-separators"></a>
## Small hidden-code separators do not make the producer cheap

Category: Promising but not yet. Evidence: All twelve trained 27-state cubes admit an identifying pair of A8 hidden codes; A4 needs at least three and has six/seven-code witnesses. Each of 136 float64 block scales also separates all 27 states in those cubes..

Information sufficiency at a fully computed boundary differs from the cost of creating a selected code or dynamic scale.

Comparison: Finite exhaustive CPU witness, not a native or model-wide timing comparison.

Boundary: The selected codes depend on whole gate/up and hidden Hadamard work; scales require 128-entry max reductions.

Next decision: Search before the hidden transform and price one selected scale reduction and its downstream continuation against the original full path.

Sources: [research/ffn/quantized-separators/README.md](../ffn/quantized-separators/README.md).

<a id="discovery-whole-map-lookup"></a>
## SMT whole-map ternary observer with native wave gather

Category: Promising but not yet. Evidence: An exact three-trit observer is one wave gather from a prescaled radix-3 address or an address instruction plus gather from packed bytes; the gfx1151 program and required wait are checked. Template negatives, solver timeouts and unrun cells are distinguished..

A complete observed map can fit in a register table without recovering hidden intermediate weights.

Comparison: Bounded straight-line grammar with a declared input coordinate; no throughput gain measured.

Boundary: The pre-lookup index may preserve more distinctions than final output, and table placement, wait and input conversion still cost work.

Next decision: Benchmark an exact map and its strongest direct-compute control under a common packed-input and table-residency contract.

Sources: [research/discovery/whole-map-search/README.md](../discovery/whole-map-search/README.md), [research/discovery/whole-map-search/RANK.md](../discovery/whole-map-search/RANK.md).

<a id="discovery-resource-bounds"></a>
## State potentials and finite-machine lower-bound certificates

Category: Promising but not yet. Evidence: Lean and replayable finite-machine certificates bound instruction counts for declared grammars. A two-bit target takes three instructions without requiring its recognizable AND intermediate, but four if that state must appear..

Lower bounds must quantify over complete states and alternate representations, then separate service demand from latency, schedule and register capacity.

Comparison: Tiny exact machine grammar and symbolic resource certificates; no whole-FFN gfx1151 optimum.

Boundary: The gfx1151 profile names missing native facts; restricted-family cuts cannot be promoted to full ISA claims.

Next decision: Instantiate a bounded, source-grounded native instruction family around the best concrete complete map and check its dual certificate.

Sources: [research/discovery/resource-bounds/README.md](../discovery/resource-bounds/README.md), [research/discovery/resource-bounds/core/README.md](../discovery/resource-bounds/core/README.md), [research/discovery/resource-bounds/finite-machine/README.md](../discovery/resource-bounds/finite-machine/README.md), [research/discovery/resource-bounds/finite-machine/MULTI-OUTPUT.md](../discovery/resource-bounds/finite-machine/MULTI-OUTPUT.md), [research/discovery/resource-bounds/formal/README.md](../discovery/resource-bounds/formal/README.md), [research/discovery/resource-bounds/gfx1151/README.md](../discovery/resource-bounds/gfx1151/README.md), [research/discovery/resource-bounds/gfx1151/SCHEMA.md](../discovery/resource-bounds/gfx1151/SCHEMA.md).

<a id="discovery-algebra-certificates"></a>
## Ternary normal forms, gated reflection and checkable rewrite certificates

Category: Promising but not yet. Evidence: Exact rational ternary quotient normal forms and Lean export certify finite identities and reject out-of-domain substitution. A bias-free gated network's even part is quadratic; for two, three and four trits the allowed coefficient dimensions are 7, 19 and 50 instead of 9, 27 and 81..

Canonicalize and prune complete small regions before asking the hardware to implement them.

Comparison: Algebraic basis size and finite examples, not instruction counts or a native speed result.

Boundary: Full tables scale as 3^n; floating quantizers and dynamically varying scales do not obey unqualified polynomial identities.

Next decision: Feed exact small-region identities into a priced packed-ISA search with domain-closure checks and actual consumer observations.

Sources: [research/discovery/README.md](../discovery/README.md), [research/discovery/ternary-algebra/README.md](../discovery/ternary-algebra/README.md), [research/discovery/certificates/README.md](../discovery/certificates/README.md), [research/discovery/whole-map-search/RANK.md](../discovery/whole-map-search/RANK.md).

<a id="ffn-triple-packed-fp16"></a>
## Three independent ternary rows in FP16 WMMA

Category: Strictly bad under the tested conditions. Evidence: The tested positive-radix triple separates after only one K16 instruction; its decoder uses 49 VALU slots against an estimated 16-slot break-even. Register-resident core is 1.73x slower than three IU4 instructions; whole FFN loses 1.27-1.84x with zero wins in twenty rounds per size..

The exact algebraic payload gain is eaten by early separation and native floating-error recovery.

Comparison: Matched three-IU4 control for this independent-channel ladder and measured 32-256-row FFN.

Boundary: Not a lower bound on different representations or a downstream consumer that keeps the packed value.

Next decision: Retain as a rejection for this ladder; any new carrier should carry a compatible observation across more than one K slice.

Sources: [research/ffn/batched/triple-packing/README.md](../ffn/batched/triple-packing/README.md).

<a id="discovery-trained-carrier-collision"></a>
## Trained-region capacity rejects lossy eleven-state observer

Category: Strictly bad under the tested conditions. Evidence: On twelve trained Bonsai three-trit cubes, even an arbitrary decoder of the eleven-state carrier loses about 55-68% output variation. A carrier of 26 states has a 7.6-13.4% variation-error floor; exact high-capacity enumeration finds 25-state optima at 10.69-19.02% over 36 tables..

The tested carrier destroys distinctions the trained consumer needs; no relabeling or better decoder can restore them.

Comparison: All 27 computed input states and 5,120 output coordinates per cube, against free arbitrary decoders, not measured whole-model quality.

Boundary: The bound assumes the carrier is the entire dynamic state; retaining another register or full input evades it. CPU float64 tables are not native-bit proof.

Next decision: Keep all 27 states and model hidden quantizer cells; price the smallest injective packed carrier rather than smoothing away collisions.

Sources: [research/discovery/joint-observer/TRAINED.md](../discovery/joint-observer/TRAINED.md), [research/discovery/joint-observer/trained-results/summary.md](../discovery/joint-observer/trained-results/summary.md), [research/discovery/joint-observer/high-capacity/README.md](../discovery/joint-observer/high-capacity/README.md).
