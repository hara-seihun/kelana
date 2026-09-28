# Existing representation research

This is the common map for quantization decomposition work. The linked reports
own source, data provenance and measurements. Keep results there rather than
copying datasets or maintaining another version of their conclusions here.
New experiments should link their closest controls from this map.

## What is encoded?

| Object or decomposition | Current owners | What they establish or leave open |
| --- | --- | --- |
| Scalar codes with group scales | [Complete ternary conversion](../../ternary/README.md), [expanded recovery](../../ternary/expanded-training.md), [mixed layer rates](../../ternary/layer-rate.md) | Complete packed images and whole-model NLL. Better independent four-bit weights do not automatically improve a region of a jointly recovered ternary model. |
| A sum of dictionary vectors, lattice labels or a trellis path | [Prior-art review](../PRIOR-ART.md) | AQLM, QuIP#, VPTQ and QTIP already explore non-scalar families. Exact assignment inside a fixed family is not global optimality over families. |
| Two quantized factors instead of one matrix | [Spectral rate design](../subbit/SPECTRAL.md), [binary factors](../subbit/binary-factors/README.md), [factor-rate grammar](../subbit/factor-rate-grammar/README.md), [joint right codes](../subbit/joint-right/README.md) | Rank, alphabet, scale placement and intermediate precision interact. Equal matrix bytes need not mean equal recurring work. |
| Shared value/output coordinates carried through attention | [Value observer](../subbit/value-observer/README.md), [shared output rank](../subbit/value-cohead-output-rank/README.md), [preserved output columns](../subbit/value-column-skeleton/README.md) | A narrow value representation can survive cache and attention. Re-quantizing a continuous factorization can destroy its gain. |
| A tied embedding and output map | [Tied sub-bit studies](../subbit/README.md), [joint spectrum](../subbit/joint-spectrum/README.md), [occurrence ablation](../subbit/occurrence-ablation/README.md), [exact toy](../../ternary-toys/tied-consumers/README.md) | The same stored object serves two consumers. A good head surrogate can damage embedding propagation; shared coordinate design is a separate option. |
| A joint residual/gated operator | [Nonlinear gauges](../../ternary-toys/nonlinear-gauges/README.md), [composed error](../../ternary-toys/composed-error/README.md), [paid allocation](../../ternary-toys/rate-allocation/README.md) | Local fits can impose an unrepairable invariant; joint factorization can exploit cross-error terms. Gauges have exact gate/norm constraints and paid boundaries. |
| The weighted sum of routed experts | [MoE research](../../moe/README.md), [actual-route rank](../../moe/real-sum-rank/README.md), [exact rank witness](../../moe/exact-route-rank/README.md), [route covariance](../../moe/route-covariance/README.md), [routed-sum toy](../../ternary-toys/routed-sums/README.md) | Frozen shared linear bases lose on real experts; four BF16 down matrices already have full output rank for unrestricted inputs. A toy succeeds by fitting the actual quantized routes and cross-expert errors instead. |
| An observed state, not weights | [Composition](../../composition/README.md), [observer search](../../discovery/observer-search/README.md), [joint observer](../../discovery/joint-observer/README.md), [reachable quotients](../../ternary-toys/reachable-quotients/README.md), [observed logits](../../ternary-toys/observed-logits/README.md) | Equal current observations may diverge under continuation. Equal fibers establish a reachable relabeling; mere equal cardinalities do not. |

The tied-image studies also compare [rare-row residuals](../subbit/tied-rare/README.md),
[softmax-weighted factors](../subbit/tied-softmax/README.md),
[gold/embedding-aware exact rows](../subbit/gold-row/README.md), and
[selected-set row allocation](../subbit/set-greedy/README.md). Their differing
head, embedding and gold-loss rankings explain why one local distortion
measure cannot select a complete tied representation.

## Where do magnitudes and scales go?

The absence of an explicit scale field does not itself make a format cheaper.
Magnitude can reappear in a codebook, exponent, dictionary, extra code plane,
normalization, accumulator width or a boundary transform. The consumer decides
whether moving it is useful.

- [Compact scaled FP16](../../ffn/batched/compact-scaled/README.md) constructs
  exact scaled ternary weight operands by byte selection. It removes per-block
  integer drains and scale epilogues, changes the accumulator representation,
  and permits wider token tiles. It measures about 1.11–1.12 times the compact
  A8 control at 256 rows on two layers, not a uniform low-batch win. This is a
  direct counterexample to treating the source scale multiply as mandatory
  online arithmetic.
- [Integer group scales](../subbit/binary-shifted-scales/README.md),
  [binary bitplane dots](../subbit/binary-bitplane-dot/README.md), and
  [centered rank coordinates](../subbit/binary-affine-rank/README.md) move
  precision into shared ladders, shifts and correction terms. They retain
  response measurements and explicit popcount/correction costs, not full-model
  speed claims.
- [Two-nibble query lowering](../subbit/nibble-query-lowering/README.md) and
  [partial second dots](../subbit/nibble-query-sparse/README.md) compete on
  actual score consumers rather than scalar query MSE. The extra digit costs
  a second dot or a paid sparse correction.
- [Direct signed-byte value consumer](../subbit/value-int8-consumer/README.md)
  moves static coordinate scales after integer attention mass aggregation.
  [Sparse overflow](../subbit/value-mass-overflow/README.md) avoids a second
  dense byte dot for large counts; list construction and native gathers remain
  part of the bill.
- [Q radial gauge](../subbit/attention-radial/README.md),
  [RoPE commutant](../subbit/rope-commutant/README.md), and
  [query-temperature toy](../../ternary-toys/reachable-quotients/README.md)
  expose producer-consumer freedoms. A transform valid for one query or one
  nonlinearity need not be valid for every live consumer.

## Direct codes and reusable responses

- [Direct response construction](../DIRECT.md), [CPU SIMD result](../SIMD.md),
  and [GPU direct result](../gpu-direct/README.md) form one comparison chain.
  The real block's CPU sign-orbit consumer wins with fresh table preparation
  included. Its tested gfx1151 lowering loses to packed two-bit and dense
  integer controls. Changing hardware can reverse the ranking.
- [Binary half tables](../subbit/binary-half-table/README.md),
  [partitioned tables](../subbit/binary-partition-table/README.md),
  [table widths](../subbit/binary-table-width/README.md),
  [masked-byte exceptions](../subbit/binary-a7-exception-table/README.md), and
  [sparse carries](../subbit/binary-a7-carry-fold/README.md) trade table
  preparation, register capacity, gathers and correction work. A smaller
  table can require more recurring instructions.
- [Sign-orbit code fitting](../subbit/binary-orbit-fit/README.md) changes the
  allowed weight labels to reduce response preparation. Equally fitted
  unrestricted signs remain a necessary quality control.
- [Paired-template toy](../../ternary-toys/coupled-codebooks/README.md) wins
  on noisy motifs and loses on unstructured weights at equal physical bytes.
  [MoE code sharing](../../moe/code-sharing/README.md) finds no whole-block
  repeats in sampled real expert banks. Dictionary overhead must be amortized
  by measured structure, not presumed reuse.
- [Whole-FFN maps](../../ffn/full-map/README.md),
  [consumer-directed hidden codes](../../ffn/consumer-quotient/README.md), and
  [contracted maps](../../ffn/contracted-map/README.md) study direct response
  programs beyond independent matrix reconstruction. Their native and
  real-weight controls prevent semantic simplification being mistaken for
  cheaper execution.

## Entropy, addressing and appendable state

- [Response-first fibers](../FIBER.md) store an observation and a rank within
  its fiber. Exact reconstruction and finite storage bounds are available;
  cold workspace and miss behavior are expensive.
- [Key microstreams](../subbit/key-entropy-microstreams/README.md),
  [bounded stream lengths](../subbit/key-length-bounded/README.md), and
  [packed directories](../subbit/key-segment-frontier/README.md) charge
  restarts and addressability while computing scores from labels directly.
- [Absolute value rows](../subbit/value-absolute-entropy/README.md),
  [fixed-width value pairs](../subbit/value-pair-absolute/README.md), and
  [paged streams](../subbit/value-paged-entropy/README.md) show that better
  entropy can lose after mutable tails, pointers, padding and parsing.
- [Mass-aware physical access](../subbit/value-active-entropy/README.md)
  distinguishes logical sparse work from cache lines touched across all
  observing heads. [Grouped label overflow](../subbit/value-label-overflow/README.md)
  and [duplicate-only aggregation](../subbit/value-selective-label-aggregation/README.md)
  combine exact repeated values before their integer reader, with explicit
  histogram work still to price.
- [Packed recurrence](../../ternary-toys/packed-realization/README.md) measures
  native byte labels across eight stages. Full route fusion wins on its tiny
  domain at much greater table and preparation cost. [Learned map structure](../../speculative-maps/map-structure/README.md)
  is another consumer-specific example of tables and direct code producers.

## Search, observation and acceptance

- [Mathematics](../MATHEMATICS.md), [certificates](../CERTIFICATES.md),
  [producer domains](../PRODUCER.md) and [enclosures](../ENCLOSURE.md) own exact
  finite-family bounds and state reduction. A stopped heuristic is a feasible
  candidate, not an optimum.
- [Discrete interactions](../../ternary-toys/discrete-geometry/README.md) and
  [calibration witnesses](../../ternary-toys/calibration-sufficiency/README.md)
  ask which edits and observations deserve expensive evaluation.
- [Recurrent stability](../../ternary-toys/recurrent-stability/README.md)
  warns that one-step matrix error can delete sensitive feedback.
- [Complete sub-bit model](../subbit/full-model/README.md),
  [fresh projection evaluation](../subbit/fresh-evaluation/README.md), and
  [complete ternary model](../../ternary/README.md) are the quality checks.
  Real-weight response improvements, even on all matrices, do not imply lower
  held token loss.

## Owners outside Kelana

Kelana owns representation research and mathematical constructions. Bonsai
owns adopted runtime behavior, installed artifacts and service operations.
The machine handbook already links both. Keep that ownership split:

- [Bonsai batched adoption](../../../../bonsai-halo/tools/batch-compare/README.md)
  owns full-model acceptance for adopted compact arithmetic paths.
- [Qwen MoE programme](../../../../bonsai-halo/docs/qwen-moe.md) owns the
  pinned model, native engine and performance receipts. Kelana's MoE reports
  own its representation experiments.
- [Joint research coordination](../../../../bonsai-halo/orchestration/RESEARCH.md)
  owns ongoing shared-resource work, not a competing copy of Kelana's proofs.

The [representation index](README.md) owns the current decomposition round and
its synthesis. Detailed historical experiment narratives stay at these owners.
