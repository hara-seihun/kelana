# Sub-bit models, attention and cache representations

[Research desk](README.md)

Generated from `subbit.json`; the JSON owns classifications.

<a id="subbit-binary-a7-byte"></a>
## A7 masked byte response and sparse carry

Category: Promising but not yet. Evidence: exact CPU construction.

One mask bit per four-sign byte-table entry corrects every full-domain A7 response; a sparse carry pass can defer exceptional sign updates.

Comparison: Only .626-.886% of 25.166m paid selections/layer need correction; sparse pass revisits 1.069m-1.526m sign quartets instead of masking all uses.

Boundary: All byte lookups still pay mask traffic; no native whole-reader comparison or model loss.

Next decision: Time masked-byte, sparse-carry, int16 quartet and two-sign byte readers end to end.

Sources: [research/quantization-discovery/subbit/binary-a7-exception-table/README.md](../quantization-discovery/subbit/binary-a7-exception-table/README.md), [research/quantization-discovery/subbit/binary-a7-carry-fold/README.md](../quantization-discovery/subbit/binary-a7-carry-fold/README.md).

<a id="subbit-binary-rank-gauge"></a>
## Binary rank-order gauge

Category: Promising but not yet. Evidence: held projection.

Repacking paid one-bit factors by train energy changes A7 second-stage groups without changing their real product, bits or logical factor work.

Comparison: Held RMS improves across four up layers, including layer 0 .017512 to .017419 and layer 27 .011547 to .011249.

Boundary: Original-producer same-image response, no model quality or native latency.

Next decision: Choose rank order with producer and full consumer jointly.

Sources: [research/quantization-discovery/subbit/binary-rank-gauge/README.md](../quantization-discovery/subbit/binary-rank-gauge/README.md).

<a id="subbit-fixed-transform-factor"></a>
## Butterfly and patterned input factors

Category: Strictly bad under the tested conditions. Evidence: held projection.

Learned butterfly transforms and patterned binary input factors reduce selected work, but lose the matched .55-bit response comparison to equally fitted binary factors.

Comparison: Pattern arms recover capacity over butterflies but remain behind activation-fitted binary on the measured projections.

Boundary: Frozen grammar and calibration scope, not a universal transform lower bound.

Next decision: Co-design reusable input stages and full downstream response rather than accelerate these losing images.

Sources: [research/quantization-discovery/subbit/fast-transform/README.md](../quantization-discovery/subbit/fast-transform/README.md), [research/quantization-discovery/subbit/block-factor/README.md](../quantization-discovery/subbit/block-factor/README.md).

<a id="subbit-value-dictionary-merging"></a>
## Causal first-seen V dictionary merging

Category: Strictly bad under the tested conditions. Evidence: held post-O.

Reducing the exact dictionary to 128 frozen centers damages response quality too much for the saved bytes and labels.

Comparison: Layer-0 bytes/key 125.273 to 112.805 but held error .378889 to .403381; layer-14 .326373 to .434637.

Boundary: Fixed first-seen centers/nearest key-local paid-O assignment, not a limit on jointly learned dictionaries.

Next decision: Train causal centers and cheap assignment with producer.

Sources: [research/quantization-discovery/subbit/value-online-merging/README.md](../quantization-discovery/subbit/value-online-merging/README.md).

<a id="subbit-scalar-control"></a>
## Complete scalar rounding controls

Category: Strictly bad under the tested conditions. Evidence: held whole-model.

The group-128 two-bit LS scalar control collapses and is a poor benchmark for a superiority claim; four-bit is much better but remains a plain rather than reconstructed quantizer.

Comparison: Two-bit 2.12657 BPW test NLL 15.55316; four-bit 4.12635 BPW test NLL 4.05740 versus BF16 3.31076.

Boundary: This classifies the two-bit construction on Qwen3-0.6B, not scalar quantization generally.

Next decision: Use GPTQ/QuIP#/NanoQuant-class matched quality and rate before a SOTA claim.

Sources: [research/quantization-discovery/subbit/full-scalar/README.md](../quantization-discovery/subbit/full-scalar/README.md), [research/quantization-discovery/subbit/PILOT.md](../quantization-discovery/subbit/PILOT.md).

<a id="subbit-full-model"></a>
## Complete sub-bit binary-factor images

Category: Promising but not yet. Evidence: held whole-model.

Complete .62454/.76000/.89546-BPW packed images account for all body, tied head and norms, but none retains useful language quality. Existing-scale end-to-end fitting partly repairs the .62454 image.

Comparison: At .62454 BPW, test NLL 9.65603 after response sweeps and 9.11738 after scale repair versus BF16 3.31076 and scalar RTN4 4.05740 at 4.12635 BPW.

Boundary: No full-model native consumer, strong quantizer comparator or acceptable sub-bit language quality.

Next decision: Fit coupled layer-0 V/O and MLP with the quantized tied image and later body in the objective.

Sources: [research/quantization-discovery/subbit/full-model/README.md](../quantization-discovery/subbit/full-model/README.md), [research/quantization-discovery/subbit/model-tuning/README.md](../quantization-discovery/subbit/model-tuning/README.md), [research/quantization-discovery/subbit/batched-fit/README.md](../quantization-discovery/subbit/batched-fit/README.md), [research/quantization-discovery/subbit/RESULTS.md](../quantization-discovery/subbit/RESULTS.md).

<a id="subbit-key-nibble"></a>
## Direct nibble K and shared three-dot score

Category: Promising but not yet. Evidence: held causal + native local.

Signed-nibble K rows use 128 bytes/token with a two-dot integer query; sharing one head base cuts score products by a quarter and gives a small native local speedup.

Comparison: Three-dot versus four-dot held KL .278608/.334929 versus .275431/.332396; native score/softmax 17.101 to 15.588 us but append/prep boundary only 30.524 to 29.155 us at 1,024 keys.

Boundary: No paid K producer/value/O timing or quality-matched SOTA win; quantized-upstream NLL not measured.

Next decision: Train Q/K labels for complete downstream attention; compare full native boundary.

Sources: [research/quantization-discovery/subbit/key-nibble-cache/README.md](../quantization-discovery/subbit/key-nibble-cache/README.md), [research/quantization-discovery/subbit/nibble-query-lowering/README.md](../quantization-discovery/subbit/nibble-query-lowering/README.md), [research/quantization-discovery/subbit/shared-query-base/README.md](../quantization-discovery/subbit/shared-query-base/README.md), [research/quantization-discovery/subbit/shared-query-producer-transfer/README.md](../quantization-discovery/subbit/shared-query-producer-transfer/README.md), [research/quantization-discovery/subbit/shared-score-native/README.md](../quantization-discovery/subbit/shared-score-native/README.md).

<a id="subbit-binary-packed-consumers"></a>
## Direct packed binary factor readers

Category: Promising but not yet. Evidence: exact CPU construction.

Bitplane dots, half-orbit response tables, partitioned byte tables and a routed quartet consume the existing paid sign factors without an int4 intermediate.

Comparison: Routed quartet cuts signed updates to 45.12% for an up projection before 294,912 routes; balanced two-subtable program needs sixteen rather than 128 table entries but doubles lookup and row-add work.

Boundary: No matched complete native reader or full-model A7 quality result; operation counts are not speed.

Next decision: Compare complete packed two-factor gfx1151 readers with table prep, scale and rank traffic charged.

Sources: [research/quantization-discovery/subbit/binary-bitplane-dot/README.md](../quantization-discovery/subbit/binary-bitplane-dot/README.md), [research/quantization-discovery/subbit/binary-half-table/README.md](../quantization-discovery/subbit/binary-half-table/README.md), [research/quantization-discovery/subbit/binary-partition-table/README.md](../quantization-discovery/subbit/binary-partition-table/README.md), [research/quantization-discovery/subbit/binary-pair-map/README.md](../quantization-discovery/subbit/binary-pair-map/README.md), [research/quantization-discovery/subbit/binary-table-width/README.md](../quantization-discovery/subbit/binary-table-width/README.md), [research/quantization-discovery/subbit/binary-shifted-scales/README.md](../quantization-discovery/subbit/binary-shifted-scales/README.md).

<a id="subbit-key-temporal"></a>
## Direct temporal K difference scores and entropy streams

Category: Promising but not yet. Evidence: exact CPU rate.

Temporal nibble differences can feed exact two-head scores directly; Huffman four/eight-row streams reduce frozen layer-14 storage further.

Comparison: Layer-14 32-key direct difference 106.737 versus static mixed 112 bytes/token; four-row Huffman 96.837, eight-row 95.669, with exact score recurrence.

Boundary: Layer 0 loses static on bytes; append, parser, scan, K producer and native timing unpaid.

Next decision: Time fixed segment reader and jointly learn independently decodable K differences.

Sources: [research/quantization-discovery/subbit/key-delta-cache/README.md](../quantization-discovery/subbit/key-delta-cache/README.md), [research/quantization-discovery/subbit/key-delta-score/README.md](../quantization-discovery/subbit/key-delta-score/README.md), [research/quantization-discovery/subbit/key-delta-parallel/README.md](../quantization-discovery/subbit/key-delta-parallel/README.md), [research/quantization-discovery/subbit/key-entropy-direct/README.md](../quantization-discovery/subbit/key-entropy-direct/README.md), [research/quantization-discovery/subbit/key-entropy-microstreams/README.md](../quantization-discovery/subbit/key-entropy-microstreams/README.md), [research/quantization-discovery/subbit/key-length-bounded/README.md](../quantization-discovery/subbit/key-length-bounded/README.md), [research/quantization-discovery/subbit/key-segment-frontier/README.md](../quantization-discovery/subbit/key-segment-frontier/README.md), [research/quantization-discovery/subbit/key-second-order/README.md](../quantization-discovery/subbit/key-second-order/README.md).

<a id="subbit-binary-a7-centering"></a>
## Dynamic rank-group A7 center

Category: Promising but not yet. Evidence: held projection.

Input-dependent midpoint centering of the second factor A7 code lowers frozen paid-image response error while retaining seven packed bitplanes; midpoint wins ten tested center rules.

Comparison: Held layer-0/7/14/27 RMS .017568/.016352/.016095/.011046 to .016578/.015208/.015146/.010462 for one schedule.

Boundary: Extra sign sums/corrections and min/max prep are unpaid natively; no composed language quality.

Next decision: Measure full A7 reader and fit on quantized-producer composed loss.

Sources: [research/quantization-discovery/subbit/binary-affine-rank/README.md](../quantization-discovery/subbit/binary-affine-rank/README.md), [research/quantization-discovery/subbit/binary-second-center-choice/README.md](../quantization-discovery/subbit/binary-second-center-choice/README.md).

<a id="subbit-value-mass-direct"></a>
## Exact conserved-mass V dot and sparse overflow

Category: Promising but not yet. Evidence: exact integer + held post-O.

A 4,095-unit count map lets packed narrow V labels remain integer through causal attention; sparse high-count corrections avoid a second dense byte dot.

Comparison: Correction products 1.071m/1.142m versus 58.950m in second dense pass on layers 0/14; integer responses and quality unchanged.

Boundary: Count formation, irregular gathers, paid O and native latency not measured.

Next decision: Time complete fused reader against two-dot and E4M3 alternatives.

Sources: [research/quantization-discovery/subbit/value-integer-consumer/README.md](../quantization-discovery/subbit/value-integer-consumer/README.md), [research/quantization-discovery/subbit/value-mass-residual/README.md](../quantization-discovery/subbit/value-mass-residual/README.md), [research/quantization-discovery/subbit/value-mass-radix/README.md](../quantization-discovery/subbit/value-mass-radix/README.md), [research/quantization-discovery/subbit/value-mass-overflow/README.md](../quantization-discovery/subbit/value-mass-overflow/README.md), [research/quantization-discovery/subbit/value-high-prefilter/README.md](../quantization-discovery/subbit/value-high-prefilter/README.md), [research/quantization-discovery/subbit/value-high-scheduling/README.md](../quantization-discovery/subbit/value-high-scheduling/README.md), [research/quantization-discovery/subbit/value-overflow-union/README.md](../quantization-discovery/subbit/value-overflow-union/README.md).

<a id="subbit-tied-row-selection"></a>
## Exact tied-row allocation and joint rank-eight fit

Category: Promising but not yet. Evidence: held head.

Occurrence-weighted rank-eight fitting improves same-budget NLL/embedding error; exact row selection by embedding error improves KL with little NLL change.

Comparison: Same 128 train inputs: rank-eight occurrence NLL 4.749 versus curvature-only 4.912 at .886111 BPW; embedding-selected exact rows KL 1.00130 versus frequent 1.06488 at .895325 BPW.

Boundary: Frequent exact rows still win NLL; 64 held original-hidden positions and no native time.

Next decision: Fit on independent head data and measure propagated shared-image loss.

Sources: [research/quantization-discovery/subbit/gold-row/README.md](../quantization-discovery/subbit/gold-row/README.md), [research/quantization-discovery/subbit/joint-spectrum/README.md](../quantization-discovery/subbit/joint-spectrum/README.md), [research/quantization-discovery/subbit/occurrence-ablation/README.md](../quantization-discovery/subbit/occurrence-ablation/README.md).

<a id="subbit-value-exact-labels"></a>
## Exact V dictionary and signed-byte grouped reader

Category: Promising but not yet. Evidence: exact CPU construction.

Repeated layer-0 producer inputs allow whole-row signed-byte V deduplication and a one-byte append ID; selective duplicate grouping plus paired-head differences reduces byte-dot row uses.

Comparison: Layer-0 cache 125.273 versus 224 bytes/key; grouped byte products 36.14m versus raw 58.95m plus correction work; paired rows 1,290,736 to 1,081,333 over four windows.

Boundary: Layer 14 unique rows bypass indexing; histogram, append, O and native latency unpaid.

Next decision: Build one fused token-ID append/count/paired byte-dot/O reader, not isolated logical-work claims.

Sources: [research/quantization-discovery/subbit/value-label-histogram/README.md](../quantization-discovery/subbit/value-label-histogram/README.md), [research/quantization-discovery/subbit/value-label-overflow/README.md](../quantization-discovery/subbit/value-label-overflow/README.md), [research/quantization-discovery/subbit/value-selective-label-aggregation/README.md](../quantization-discovery/subbit/value-selective-label-aggregation/README.md), [research/quantization-discovery/subbit/value-paired-label-difference/README.md](../quantization-discovery/subbit/value-paired-label-difference/README.md), [research/quantization-discovery/subbit/value-cohead-mass-share/README.md](../quantization-discovery/subbit/value-cohead-mass-share/README.md), [research/quantization-discovery/subbit/value-shortlist-radix/README.md](../quantization-discovery/subbit/value-shortlist-radix/README.md), [research/quantization-discovery/subbit/value-token-id-cache/README.md](../quantization-discovery/subbit/value-token-id-cache/README.md), [research/quantization-discovery/subbit/value-dictionary-blocks/README.md](../quantization-discovery/subbit/value-dictionary-blocks/README.md).

<a id="subbit-binary-a7-first-affine"></a>
## First-stage A7 affine endpoints and stationary weight centers

Category: Strictly bad under the tested conditions. Evidence: held projection.

Sparse first-stage endpoint shifts barely help frozen codes; fitted stationary input-sum corrections lose held despite added payload and operations.

Comparison: First-stage midpoint error layer 0 .017370 to .017359 but layer 27 .010931 to .010934; held-only weight-center oracle improves same-image RMS at most .43%.

Boundary: Frozen image only; sparse corrections could matter with jointly trained codes.

Next decision: Prioritize dynamic second-stage center and composed model fit.

Sources: [research/quantization-discovery/subbit/binary-input-affine/README.md](../quantization-discovery/subbit/binary-input-affine/README.md), [research/quantization-discovery/subbit/binary-weight-center/README.md](../quantization-discovery/subbit/binary-weight-center/README.md).

<a id="subbit-spectral-shortcuts"></a>
## Fixed-right higher rank and radial precision

Category: Strictly bad under the tested conditions. Evidence: held attention.

Increasing frozen-right Q rank or reducing left precision without a new fit does not preserve the attention-trained 4/4 map.

Comparison: Frozen-right rank 108 two/four held KL .20130 versus rank 88 .19934 on its seed; attention-trained rank-88 two/four reaches .11290 but 3/4 reaches .09242.

Boundary: Rejects these frozen-basis/rate shortcuts, not joint right-code fitting.

Next decision: Choose precision and right basis jointly for causal loss.

Sources: [research/quantization-discovery/subbit/factor-rate-grammar/README.md](../quantization-discovery/subbit/factor-rate-grammar/README.md), [research/quantization-discovery/subbit/attention-radial/README.md](../quantization-discovery/subbit/attention-radial/README.md).

<a id="subbit-binary-a7-admission"></a>
## Frozen A7 static four-sign byte admission

Category: Strictly bad under the tested conditions. Evidence: exact CPU domain.

Most observed individual quartet tables fit bytes, but a uniformly byte-safe fixed rank-table position is rare; centering adds too many corrections.

Comparison: Only 5-18% of rank positions are byte-safe across 64 inputs; centered admission rises to 30-47 of 96 positions but costs 6.97m-7.31m rank corrections/layer.

Boundary: Named static admission/frozen code grammar, not the masked-byte exact map or jointly trained code.

Next decision: Compare uniform or masked complete readers before changing admission rules.

Sources: [research/quantization-discovery/subbit/binary-a7-byte-admission/README.md](../quantization-discovery/subbit/binary-a7-byte-admission/README.md), [research/quantization-discovery/subbit/binary-a7-centered-byte/README.md](../quantization-discovery/subbit/binary-a7-centered-byte/README.md).

<a id="subbit-binary-orbit-selectivity"></a>
## Frozen binary half-orbit selective preparation

Category: Strictly bad under the tested conditions. Evidence: exact occupancy + held projection.

Nearly every frozen sign orbit is used, and fitting a 96-orbit cap loses the equal-fit 128-label quality control on both examined layers.

Comparison: First plane occupies 62,285/65,536 and output plane 24,576/24,576; best selective preparation saves at most 3.64% Gray updates.

Boundary: Only frozen signs or the tested capped fit, not learned direct-address alphabets.

Next decision: Co-train factor signs under an addressable small alphabet if consumer work warrants it.

Sources: [research/quantization-discovery/subbit/binary-sign-orbits/README.md](../quantization-discovery/subbit/binary-sign-orbits/README.md), [research/quantization-discovery/subbit/binary-orbit-fit/README.md](../quantization-discovery/subbit/binary-orbit-fit/README.md).

<a id="subbit-value-cache-calibration"></a>
## Frozen byte-cache scale and affine fitting

Category: Strictly bad under the tested conditions. Evidence: held post-O.

Training only frozen E4M3 group scales or affine int8 code shifts buys negligible or reversed held quality at extra work.

Comparison: E4M3 causal scales .37918583 to .37917539 layer 0 but .32652724 to .32653087 layer 14; affine int8 layer 14 .32640123 to .32643822.

Boundary: Narrow frozen scale/grid objective, not a negative for joint producer-consumer training.

Next decision: Learn new value codes and basis on quantized-producer loss.

Sources: [research/quantization-discovery/subbit/value-fp8-causal-scale/README.md](../quantization-discovery/subbit/value-fp8-causal-scale/README.md), [research/quantization-discovery/subbit/value-int8-affine/README.md](../quantization-discovery/subbit/value-int8-affine/README.md).

<a id="subbit-key-temporal-failures"></a>
## Frozen K predictor and selector overhead

Category: Strictly bad under the tested conditions. Evidence: exact CPU rate.

Second differences, per-coordinate alphabets, two-bit escapes, paired dictionaries and adaptive segment selection fail rate or practical-work tests on frozen keys.

Comparison: Layer-14 second-order row 125.561 versus first-order 105.521 bytes/token; coordinate seven-symbol held oracle 106.593 exceeds Huffman 96.837; two-bit delta 121,260 versus 109,299 bytes.

Boundary: Only named frozen grammars and charged metadata; not a bound on learned K codes.

Next decision: Keep fixed first-difference reader or train new temporal labels.

Sources: [research/quantization-discovery/subbit/key-second-order/README.md](../quantization-discovery/subbit/key-second-order/README.md), [research/quantization-discovery/subbit/key-coordinate-alphabet/README.md](../quantization-discovery/subbit/key-coordinate-alphabet/README.md), [research/quantization-discovery/subbit/key-two-bit-delta/README.md](../quantization-discovery/subbit/key-two-bit-delta/README.md), [research/quantization-discovery/subbit/key-pair-delta/README.md](../quantization-discovery/subbit/key-pair-delta/README.md), [research/quantization-discovery/subbit/key-segment-dynamic/README.md](../quantization-discovery/subbit/key-segment-dynamic/README.md), [research/quantization-discovery/subbit/key-block-score/README.md](../quantization-discovery/subbit/key-block-score/README.md), [research/quantization-discovery/subbit/block-key-gauge/README.md](../quantization-discovery/subbit/block-key-gauge/README.md).

<a id="subbit-joint-kv-huffman"></a>
## Frozen K/V conditional entropy tables

Category: Strictly bad under the tested conditions. Evidence: exact CPU rate.

One frozen cache supplies too little predictive information for a second conditional Huffman table to beat separate static/entropy-coded layouts.

Comparison: Best layer-0 V condition saves 886 bytes/1,024 tokens but costs 114.35 bytes/token versus static nibble 112 and group Huffman 103.36; layer-14 conditional streams grow.

Boundary: Frozen independently learned K/V labels and same-token two-table grammar only.

Next decision: Jointly train K/V labels and causal/post-O consumers with the side decode charged.

Sources: [research/quantization-discovery/subbit/joint-kv-entropy/README.md](../quantization-discovery/subbit/joint-kv-entropy/README.md).

<a id="subbit-key-norm-shortcuts"></a>
## Frozen key norm Gram and naive sketch limits

Category: Strictly bad under the tested conditions. Evidence: exact rank + held KL.

Frozen paid K missing-row Grams have full rank; cheap dense Gram or naive sampled-row energy does not reproduce the denominator across layers.

Comparison: Exact Gram needs 800 forms/204,800 terms; 32 sampled rows save 26.6% K factor terms but layer-0 held KL .263253 to .304696.

Boundary: Exact bound is for frozen factor-coordinate quadratic; trained positive sparse rows remain promising.

Next decision: Train support on finite causal loss, not norm reconstruction error.

Sources: [research/quantization-discovery/subbit/key-rms-factor/README.md](../quantization-discovery/subbit/key-rms-factor/README.md), [research/quantization-discovery/subbit/key-norm-sketch/README.md](../quantization-discovery/subbit/key-norm-sketch/README.md), [research/quantization-discovery/subbit/key-gram-sketch/README.md](../quantization-discovery/subbit/key-gram-sketch/README.md).

<a id="subbit-value-mass-phase-negative"></a>
## Frozen low-rank, fixed-phase and one-digit shortcuts

Category: Strictly bad under the tested conditions. Evidence: held post-O.

A fixed 15-unit phase cannot meet the declared 1e-4 budget for any frozen head; low-rank phase metrics remain costly and inaccurate.

Comparison: Best one-head fixed-phase train errors .00010574/.00089142; rank-one phase score worsens layer-14 held response .000464 to .000543.

Boundary: Applies to frozen codes and selected budgets, not learned phase-aware codes.

Next decision: Learn cheap query state jointly with the cache, not another frozen phase sweep.

Sources: [research/quantization-discovery/subbit/value-nibble-phase/README.md](../quantization-discovery/subbit/value-nibble-phase/README.md), [research/quantization-discovery/subbit/value-nibble-one-digit/README.md](../quantization-discovery/subbit/value-nibble-one-digit/README.md), [research/quantization-discovery/subbit/value-phase-lowrank/README.md](../quantization-discovery/subbit/value-phase-lowrank/README.md), [research/quantization-discovery/subbit/value-three-mass-allocation/README.md](../quantization-discovery/subbit/value-three-mass-allocation/README.md), [research/quantization-discovery/subbit/value-min-variance-carrier/README.md](../quantization-discovery/subbit/value-min-variance-carrier/README.md), [research/quantization-discovery/subbit/value-affine-coreset/README.md](../quantization-discovery/subbit/value-affine-coreset/README.md).

<a id="subbit-binary-group-threshold"></a>
## Frozen per-group A7 threshold overfit

Category: Strictly bad under the tested conditions. Evidence: held projection.

Group-specific thresholds improve train response but lose held to one common first-stage selector.

Comparison: Layer-0/14 held RMS .017360/.016066 to .017387/.016138 while adding 31 constants.

Boundary: Only frozen signs, 128 train rows and fitted second threshold.

Next decision: Fit group choices jointly with codes on complete model loss, if needed.

Sources: [research/quantization-discovery/subbit/binary-group-choice/README.md](../quantization-discovery/subbit/binary-group-choice/README.md).

<a id="subbit-key-query-dead-ends"></a>
## Frozen query precision and sharing dead ends

Category: Strictly bad under the tested conditions. Evidence: held causal KL.

Single-dot scale policies, sparse second dots, covariance selectors, dynamic bases and two-dot affine sharing do not supply a cheaper quality-matched frozen reader.

Comparison: Layer-14 single-dot covariance scale worsens KL .362763 to .476919; sparse 24-coordinate correction .338124 still loses full second dot .332397; dynamic base deployable selector worsens .334929 to .335671.

Boundary: Bounded frozen labels and selector grammars, not jointly learned scores.

Next decision: Change producer and fit causal observer, not another frozen selector.

Sources: [research/quantization-discovery/subbit/nibble-plane-step/README.md](../quantization-discovery/subbit/nibble-plane-step/README.md), [research/quantization-discovery/subbit/nibble-query-scale/README.md](../quantization-discovery/subbit/nibble-query-scale/README.md), [research/quantization-discovery/subbit/nibble-query-causal/README.md](../quantization-discovery/subbit/nibble-query-causal/README.md), [research/quantization-discovery/subbit/nibble-query-sparse/README.md](../quantization-discovery/subbit/nibble-query-sparse/README.md), [research/quantization-discovery/subbit/nibble-query-adaptive/README.md](../quantization-discovery/subbit/nibble-query-adaptive/README.md), [research/quantization-discovery/subbit/shared-query-adaptive-base/README.md](../quantization-discovery/subbit/shared-query-adaptive-base/README.md), [research/quantization-discovery/subbit/shared-query-covariance/README.md](../quantization-discovery/subbit/shared-query-covariance/README.md), [research/quantization-discovery/subbit/shared-query-two-dot/README.md](../quantization-discovery/subbit/shared-query-two-dot/README.md), [research/quantization-discovery/subbit/shared-score-post-o-selection/README.md](../quantization-discovery/subbit/shared-score-post-o-selection/README.md), [research/quantization-discovery/subbit/query-gated-dot/README.md](../quantization-discovery/subbit/query-gated-dot/README.md).

<a id="subbit-binary-rank-overfit"></a>
## Frozen rank and sign-gauge searches

Category: Strictly bad under the tested conditions. Evidence: held projection.

Train-only rank swaps optimized for intermediate reconstruction or complete Gram response reverse on larger held panels; sign flips affect only rare asymmetric A7 cells.

Comparison: Layer-14 held rank-pair safe fit .016117 to .016249; complete-Gram fit .015769 to .015817 on larger panel; sign-gauge changes RMS by millionths.

Boundary: Rejects frozen search objectives, not new factor-code training.

Next decision: Move selection to quantized-producer composed loss.

Sources: [research/quantization-discovery/subbit/binary-rank-pairing/README.md](../quantization-discovery/subbit/binary-rank-pairing/README.md), [research/quantization-discovery/subbit/binary-composed-rank/README.md](../quantization-discovery/subbit/binary-composed-rank/README.md), [research/quantization-discovery/subbit/binary-sign-gauge/README.md](../quantization-discovery/subbit/binary-sign-gauge/README.md).

<a id="subbit-value-output-factor-failures"></a>
## Frozen shared-output factor shortcuts

Category: Strictly bad under the tested conditions. Evidence: held post-O.

Independent low-rank output rounding, single-group swaps, wrong-head attention substitution and paired-difference rank do not provide a good cheap frozen decoder.

Comparison: Rounded rank-256 error .590752/.631886; rank-24 difference changes paid output .027455/.017171 for four saved dots; partner-attention substitution raises layer-0 error .413157 to .456104.

Boundary: Real rank-256 is useful; rejects these two-bit rounding and frozen-head approximations only.

Next decision: Co-fit paid shared output basis, both attention paths and value codes.

Sources: [research/quantization-discovery/subbit/value-cohead-output-rank/README.md](../quantization-discovery/subbit/value-cohead-output-rank/README.md), [research/quantization-discovery/subbit/value-column-selection/README.md](../quantization-discovery/subbit/value-column-selection/README.md), [research/quantization-discovery/subbit/value-transfer-commutation/README.md](../quantization-discovery/subbit/value-transfer-commutation/README.md), [research/quantization-discovery/subbit/value-paired-difference/README.md](../quantization-discovery/subbit/value-paired-difference/README.md).

<a id="subbit-value-pruning-limits"></a>
## Frozen V allocation and scale-only selection limits

Category: Strictly bad under the tested conditions. Evidence: held causal response.

Non-prefix mask exchanges barely improve the best prefix, robust train-window weighting cannot fix a fresh NLL reversal, and frozen group-gain refits have little held benefit.

Comparison: Non-prefix layer-0 .391723 to .390890; layer-14 exact same mask; paid group gains .336551 to .336186 while held oracle can reach .312639.

Boundary: Only frozen masks, scales and inspected train distributions are rejected.

Next decision: Learn basis, producer and target jointly rather than shuffle old coordinates.

Sources: [research/quantization-discovery/subbit/value-observer/README.md](../quantization-discovery/subbit/value-observer/README.md), [research/quantization-discovery/subbit/value-softmax-rank/README.md](../quantization-discovery/subbit/value-softmax-rank/README.md), [research/quantization-discovery/subbit/value-observer/FREE-MASK.md](../quantization-discovery/subbit/value-observer/FREE-MASK.md), [research/quantization-discovery/subbit/value-observer/FRESH-LOSS.md](../quantization-discovery/subbit/value-observer/FRESH-LOSS.md), [research/quantization-discovery/subbit/value-observer/ROBUST-ALLOCATION.md](../quantization-discovery/subbit/value-observer/ROBUST-ALLOCATION.md), [research/quantization-discovery/subbit/value-observer/CAUSAL-GROUP-GAIN.md](../quantization-discovery/subbit/value-observer/CAUSAL-GROUP-GAIN.md).

<a id="subbit-value-cache-entropy-fail"></a>
## Frozen V differential and parser dead ends

Category: Strictly bad under the tested conditions. Evidence: exact CPU rate.

Simple temporal three-bit differences, fixed-five-bit zero runs, paged coordinate streams and phrase rows lose to static nibble or the row Huffman reader after paying append metadata.

Comparison: Layer-0 delta 114.845 versus 112 static bytes/token; paged optimum 125.219/121.898 and phrase optimum 124.850/123.154 on layers 0/14, both above 112.

Boundary: Bounded frozen grammars, not entropy limits on jointly trained labels.

Next decision: Use appendable key rows or retrain repeat-rich labels.

Sources: [research/quantization-discovery/subbit/value-delta-suffix/README.md](../quantization-discovery/subbit/value-delta-suffix/README.md), [research/quantization-discovery/subbit/value-zero-run/README.md](../quantization-discovery/subbit/value-zero-run/README.md), [research/quantization-discovery/subbit/value-paged-entropy/README.md](../quantization-discovery/subbit/value-paged-entropy/README.md), [research/quantization-discovery/subbit/value-phrase-stream/README.md](../quantization-discovery/subbit/value-phrase-stream/README.md), [research/quantization-discovery/subbit/value-coordinate-entropy/README.md](../quantization-discovery/subbit/value-coordinate-entropy/README.md).

<a id="subbit-value-nibble-alternatives"></a>
## Frozen V palette and mixed-bit shortcuts

Category: Strictly bad under the tested conditions. Evidence: held post-O.

Sharing the learned byte palette and spending two equal-byte fifth-bit coordinate pairs do not improve the frozen nibble image.

Comparison: Shared pairs layer-14 error .335839 versus uniform nibble .334500 with more table bytes; mixed-rate .334550 versus parent .334500.

Boundary: Only these frozen code/decoder and original-producer fits.

Next decision: Change the basis and consumers instead of reallocating frozen labels.

Sources: [research/quantization-discovery/subbit/value-shared-palette/README.md](../quantization-discovery/subbit/value-shared-palette/README.md), [research/quantization-discovery/subbit/value-cache-mixed-rate/README.md](../quantization-discovery/subbit/value-cache-mixed-rate/README.md).

<a id="subbit-tied-row-greedy"></a>
## Gold-selected tied exact-row overfit

Category: Strictly bad under the tested conditions. Evidence: held head.

Exact greedy selected-set optimization does not repair the gold-row selection failure on 128 head inputs.

Comparison: Gold-row held NLL 4.692; joint-set greedy 4.695 versus frequent exact rows 4.629 at identical .895325 BPW.

Boundary: Finite candidate pool and small original-hidden panel, not a general greedy theorem.

Next decision: Increase independent training data and learn rare responses instead of reshuffling exact IDs.

Sources: [research/quantization-discovery/subbit/set-greedy/README.md](../quantization-discovery/subbit/set-greedy/README.md), [research/quantization-discovery/subbit/gold-row/README.md](../quantization-discovery/subbit/gold-row/README.md).

<a id="subbit-value-nibble-code"></a>
## Half-byte V code and paid decoder fitting

Category: Promising but not yet. Evidence: held post-O.

Coordinate steps, endpoint code, paid O refits and learned byte LUT reduce the half-byte cache error while keeping narrow values direct.

Comparison: Layer-14 half-byte error .365386 to .334500 with paid O refit, then .330807 with LUT, versus equally refitted E4M3 .325434.

Boundary: Still loses E4M3 held quality; LUT adds 4,032 static bytes and two dot passes, no native or model loss.

Next decision: Co-train V basis/cache/O against quantized-producer language loss.

Sources: [research/quantization-discovery/subbit/value-centered-int4/README.md](../quantization-discovery/subbit/value-centered-int4/README.md), [research/quantization-discovery/subbit/value-cache-post-o-select/README.md](../quantization-discovery/subbit/value-cache-post-o-select/README.md), [research/quantization-discovery/subbit/value-nibble-response-step/README.md](../quantization-discovery/subbit/value-nibble-response-step/README.md), [research/quantization-discovery/subbit/value-nibble-code-fit/README.md](../quantization-discovery/subbit/value-nibble-code-fit/README.md), [research/quantization-discovery/subbit/value-nibble-joint-fit/README.md](../quantization-discovery/subbit/value-nibble-joint-fit/README.md), [research/quantization-discovery/subbit/value-nibble-basis/README.md](../quantization-discovery/subbit/value-nibble-basis/README.md), [research/quantization-discovery/subbit/value-nibble-lut/README.md](../quantization-discovery/subbit/value-nibble-lut/README.md).

<a id="subbit-value-mass-precision"></a>
## Headwise count precision and nibble mass dots

Category: Promising but not yet. Evidence: held post-O + modeled work.

Train-selected 255/4,095-unit head allocation and direct packed-nibble mass dots reduce estimated dot slots at controlled output error.

Comparison: At 1e-4 train rounding budget, fifteen/four 255-unit heads reduce modeled four-lane slots 50.2%/12.3% at held errors 8.79e-5/6.06e-5; three-nibble full-count map cuts modeled slots 36.1%/41.1% against byte dots.

Boundary: No native count/list/dot/O timing; frozen nibble cache still loses E4M3 quality.

Next decision: Train code and mass precision together; time entire consumer.

Sources: [research/quantization-discovery/subbit/value-mass-allocation/README.md](../quantization-discovery/subbit/value-mass-allocation/README.md), [research/quantization-discovery/subbit/value-nibble-255/README.md](../quantization-discovery/subbit/value-nibble-255/README.md), [research/quantization-discovery/subbit/value-nibble-mass-dot/README.md](../quantization-discovery/subbit/value-nibble-mass-dot/README.md), [research/quantization-discovery/subbit/value-mass-frontier/README.md](../quantization-discovery/subbit/value-mass-frontier/README.md).

<a id="subbit-joint-right"></a>
## Jointly adapted lower-bit Q basis

Category: Promising but not yet. Evidence: held attention.

Refitting both factors makes a rank-108 two/four-bit attention image useful at the three/four-byte cap.

Comparison: Held KL .09985 versus equal-fit rank-88 two/four .10367; rank-88 three/four still wins .09242 at 1,728 more bytes and fewer terms.

Boundary: Original producer, fixed Q only; native latency and model loss not measured.

Next decision: Test new factor bases and extra rank against the stronger three/four control on fresh model loss.

Sources: [research/quantization-discovery/subbit/joint-right/README.md](../quantization-discovery/subbit/joint-right/README.md).

<a id="subbit-prefix-repair"></a>
## Layer-0 coupled V/O and MLP repair

Category: Promising but not yet. Evidence: held model prefix.

Fresh substitutions identify a large damaged layer-0 prefix and non-additive V/O-to-MLP interaction; binary Q/K can remain while exact V/O and MLP restore most local loss.

Comparison: Restoring layer 0 cuts 16-window prefix NLL 13.014 to 7.626 but costs .40830 whole-model BPW; narrow V/O plus original MLP test/validation NLL 10.579/8.819.

Boundary: Exact restoration is not sub-bit; single/two MLP projection restorations do not suffice.

Next decision: Fit compressed coupled V/O, gate, up and down on quantized producer.

Sources: [research/quantization-discovery/subbit/full-model/README.md](../quantization-discovery/subbit/full-model/README.md), [research/quantization-discovery/subbit/full-model/PREFIX-ABLATION.md](../quantization-discovery/subbit/full-model/PREFIX-ABLATION.md), [research/quantization-discovery/subbit/full-model/NARROW-PREFIX.md](../quantization-discovery/subbit/full-model/NARROW-PREFIX.md), [research/quantization-discovery/subbit/full-model/COUPLED-SUBSTITUTION.md](../quantization-discovery/subbit/full-model/COUPLED-SUBSTITUTION.md), [research/quantization-discovery/subbit/full-model/MLP-SPLIT.md](../quantization-discovery/subbit/full-model/MLP-SPLIT.md).

<a id="subbit-token-memo"></a>
## Layer-0 token-ID paid projection reuse

Category: Promising but not yet. Evidence: exact CPU fibers.

At original Qwen3-0.6B layer 0, repeated token IDs have bit-identical QKV inputs; pre-RoPE Q/K and V projections can be reused while rotation and position append still run.

Comparison: Across twelve windows 1,326/3,072 repeated IDs save 304,152,576 of 704,643,072 V right-factor terms; four-window Q/K reuse skips 732,168,192 of 1,644,167,168 factor terms.

Boundary: Layer 14 token IDs do not imply same inputs; rotated values cannot be reused, and native lookup/table/append cost not measured.

Next decision: Price fused layer-0 Q/K/V append and score path.

Sources: [research/quantization-discovery/subbit/value-token-id-cache/README.md](../quantization-discovery/subbit/value-token-id-cache/README.md), [research/quantization-discovery/subbit/qk-token-orbit/README.md](../quantization-discovery/subbit/qk-token-orbit/README.md).

<a id="subbit-spectral-local"></a>
## Low-rate spectral factors and attention-aware Q fitting

Category: Promising but not yet. Evidence: native local.

Rank-88 4/4-bit Q factors fit at .53674 BPW; attention-fitted codes trade raw response error for causal quality, and the exact image runs faster than the stronger binary control in paired native tests.

Comparison: Initial early-Q response error .08145 versus ADMM binary .09666; attention fit held KL .07776 versus response-refined binary .08164. Paired native speedups 1.114x/1.725x at 1/16 queries.

Boundary: Fresh 64-window test removes the quality advantage: NLL 3.61148 versus 3.61078, KL .05807 versus .05278. Single projection only; not matched SOTA.

Next decision: Fit a complete causal map on fresh quantized-producer text before deployment.

Sources: [research/quantization-discovery/subbit/attention-metric/README.md](../quantization-discovery/subbit/attention-metric/README.md), [research/quantization-discovery/subbit/fresh-evaluation/README.md](../quantization-discovery/subbit/fresh-evaluation/README.md), [research/quantization-discovery/subbit/native-factors/README.md](../quantization-discovery/subbit/native-factors/README.md), [research/quantization-discovery/subbit/SPECTRAL.md](../quantization-discovery/subbit/SPECTRAL.md), [research/quantization-discovery/subbit/RESULTS.md](../quantization-discovery/subbit/RESULTS.md), [research/quantization-discovery/subbit/native-factors/NANO.md](../quantization-discovery/subbit/native-factors/NANO.md).

<a id="subbit-mlp-proxy-failure"></a>
## MLP response-selected sign and gain shortcuts

Category: Strictly bad under the tested conditions. Evidence: held model prefix.

Improved frozen-hidden endpoint error and train-selected gain pairs fail to select the best held NLL image.

Comparison: Two-sweep down signs lower endpoint error .83064 to .82140 but worsen six-window test NLL 11.56619 to 11.83990; complete gain train choice 2/1.5 loses to 2/1.75 on held panels.

Boundary: Rejects these response and tiny-grid selectors, not jointly trained MLP codes.

Next decision: Train broader complete-model gold/teacher continuation.

Sources: [research/quantization-discovery/subbit/full-model/README.md](../quantization-discovery/subbit/full-model/README.md), [research/quantization-discovery/subbit/full-model/MLP-QUANTIZED-CODES.md](../quantization-discovery/subbit/full-model/MLP-QUANTIZED-CODES.md), [research/quantization-discovery/subbit/full-model/DOWN-SWEEP-SELECTION.md](../quantization-discovery/subbit/full-model/DOWN-SWEEP-SELECTION.md), [research/quantization-discovery/subbit/full-model/COMPLETE-GAIN-TRANSFER.md](../quantization-discovery/subbit/full-model/COMPLETE-GAIN-TRANSFER.md), [research/quantization-discovery/subbit/full-model/COMPLETE-PAID-GAIN.md](../quantization-discovery/subbit/full-model/COMPLETE-PAID-GAIN.md), [research/quantization-discovery/subbit/full-model/gain-validation/README.md](../quantization-discovery/subbit/full-model/gain-validation/README.md).

<a id="subbit-binary-reference"></a>
## NanoQuant-derived binary factor baseline

Category: Promising but not yet. Evidence: held projection.

Pinned ADMM initializer supplies matched real-activation sub-bit factor images and packed direct-reader controls.

Comparison: At .55 target BPW, held response squared errors across 16 projections range .0342 to .4810; it is the internal matched adversary, not published NanoQuant quality.

Boundary: No published reconstruction/KD stages, complete quality claim or universal speed estimate.

Next decision: Compare full model and native consumers at matched endpoints.

Sources: [research/quantization-discovery/subbit/binary-factors/README.md](../quantization-discovery/subbit/binary-factors/README.md), [research/quantization-discovery/subbit/batched-fit/README.md](../quantization-discovery/subbit/batched-fit/README.md).

<a id="subbit-value-layout"></a>
## Narrow V cache and output layouts

Category: Promising but not yet. Evidence: modelled only.

Packed unequal-rank layouts and selected-output column preservation expose a smaller paid V/O rate and fewer logical terms.

Comparison: Ten preserved head groups with two-bit transfer cost .428472 V/O BPW and error .413157/.375237 versus separately rounded rank-256 .454834 and .590752/.631886.

Boundary: Original .530599 image remains more accurate; line requests and factor terms are not native latency.

Next decision: Measure complete two-stage V/O/cache consumers, then co-train output codes.

Sources: [research/quantization-discovery/subbit/value-column-skeleton/README.md](../quantization-discovery/subbit/value-column-skeleton/README.md), [research/quantization-discovery/subbit/value-observer/README.md](../quantization-discovery/subbit/value-observer/README.md), [research/quantization-discovery/subbit/value-observer/LAYOUT-OPT.md](../quantization-discovery/subbit/value-observer/LAYOUT-OPT.md), [research/quantization-discovery/subbit/value-observer/CACHE-COST.md](../quantization-discovery/subbit/value-observer/CACHE-COST.md).

<a id="subbit-value-rank-allocation"></a>
## Narrow V rank allocation, pruning and refit

Category: Promising but not yet. Evidence: held causal response.

Equal-byte rank allocation and 192-coordinate causal pruning beat uniform frozen allocations; paid code refitting and ridge recover further post-O quality.

Comparison: Selected 192-coordinate .466797-BPW images held post-O .385779/.330364 versus equal-rate uniform .407794/.340384 at original producers; quantized-producer ridge layer-14 .336551 to .303868.

Boundary: Fresh layer-0 validation NLL reverses selected-rank advantage; quantized-producer uniform/selected converge and original V/O remains competitive.

Next decision: Fit new right bases and codes with broader complete-model loss before native layout choice.

Sources: [research/quantization-discovery/subbit/value-observer/README.md](../quantization-discovery/subbit/value-observer/README.md), [research/quantization-discovery/subbit/value-observer/RANK-ALLOCATION.md](../quantization-discovery/subbit/value-observer/RANK-ALLOCATION.md), [research/quantization-discovery/subbit/value-observer/CAUSAL-PRUNE.md](../quantization-discovery/subbit/value-observer/CAUSAL-PRUNE.md), [research/quantization-discovery/subbit/value-observer/CAUSAL-REFIT.md](../quantization-discovery/subbit/value-observer/CAUSAL-REFIT.md), [research/quantization-discovery/subbit/value-observer/RIGHT-TRANSFER.md](../quantization-discovery/subbit/value-observer/RIGHT-TRANSFER.md), [research/quantization-discovery/subbit/value-observer/CAUSAL-RANK-FLOOR.md](../quantization-discovery/subbit/value-observer/CAUSAL-RANK-FLOOR.md), [research/quantization-discovery/subbit/value-observer/RIDGE-MODEL-LOSS.md](../quantization-discovery/subbit/value-observer/RIDGE-MODEL-LOSS.md), [research/quantization-discovery/subbit/value-observer/LAYER0-RIDGE.md](../quantization-discovery/subbit/value-observer/LAYER0-RIDGE.md), [research/quantization-discovery/subbit/value-observer/PRODUCER-TRANSFER.md](../quantization-discovery/subbit/value-observer/PRODUCER-TRANSFER.md), [research/quantization-discovery/subbit/value-observer/RIGHT-MODEL-LOSS.md](../quantization-discovery/subbit/value-observer/RIGHT-MODEL-LOSS.md).

<a id="subbit-key-nibble-selector"></a>
## Nibble K rate and conditional query controls

Category: Promising but not yet. Evidence: held causal KL.

Mixed three/four-bit keys save cache bytes and exact conditional shared-query rounding slightly improves held KL at unchanged three key dots.

Comparison: Mixed 112 versus 128 bytes/token scores .282826/.345606; fifteen-choice shared fit KL .278608 to .278049 and .334929 to .333448.

Boundary: Rounding costs up to 3,840 candidate evaluations/query/layer; native selector/producer and model loss unpaid.

Next decision: Fit cheaper causal query preparation and paid key codes together.

Sources: [research/quantization-discovery/subbit/key-three-bit/README.md](../quantization-discovery/subbit/key-three-bit/README.md), [research/quantization-discovery/subbit/shared-query-joint-round/README.md](../quantization-discovery/subbit/shared-query-joint-round/README.md), [research/quantization-discovery/subbit/shared-query-pruning/README.md](../quantization-discovery/subbit/shared-query-pruning/README.md), [research/quantization-discovery/subbit/shared-query-neighbor/README.md](../quantization-discovery/subbit/shared-query-neighbor/README.md).

<a id="subbit-value-fp8-int8"></a>
## One-byte narrow V cache and integer consumer

Category: Promising but not yet. Evidence: held post-O.

E4M3 halves paid narrow-V cache to 224 bytes/token with little original-producer error; signed-byte labels permit exact conserved-count integer dots and late scale factoring.

Comparison: E4M3 held error .379186/.326527; 4,095-count int8 .378890/.326401 at layers 0/14, plus 432 FP16 metadata bytes/layer.

Boundary: Native append/count/dot/O and quantized-producer NLL not measured; cache format is not weight BPW.

Next decision: Compare full fused int8, E4M3 and nibble readers at occupied context.

Sources: [research/quantization-discovery/subbit/value-fp8-cache/README.md](../quantization-discovery/subbit/value-fp8-cache/README.md), [research/quantization-discovery/subbit/value-int8-consumer/README.md](../quantization-discovery/subbit/value-int8-consumer/README.md), [research/quantization-discovery/subbit/value-integer-consumer/README.md](../quantization-discovery/subbit/value-integer-consumer/README.md).

<a id="subbit-full-residual"></a>
## Original-producer FP16 residual allocation

Category: Strictly bad under the tested conditions. Evidence: held whole-model.

Rank-8/16 residuals improve every isolated matrix response but make complete-model test loss worse while consuming more bytes.

Comparison: Median response error .232794 to .226669/.221202; test NLL 9.65603 to 9.72919/9.84258 at .62454 to .76000/.89546 BPW.

Boundary: Rejects this frozen original-producer quadratic allocation, not all residual training.

Next decision: Select extra bytes by composed model loss.

Sources: [research/quantization-discovery/subbit/model-residual/README.md](../quantization-discovery/subbit/model-residual/README.md), [research/quantization-discovery/subbit/full-model/README.md](../quantization-discovery/subbit/full-model/README.md).

<a id="subbit-key-radix"></a>
## Packed paired Q/K score radix bound

Category: Strictly bad under the tested conditions. Evidence: exact proof.

A single exact paired signed-nibble dot needs radix at least 3,099 on the full 32-coordinate cube, exceeding signed-byte query lanes; the two-key quotient barely saves entropy.

Comparison: Every smaller positive radix has a two-head score collision; at 256 keys common translation saves under one millionth bit/group relative to base-15 coding.

Boundary: Exact unrestricted cube and named single-dot decoder only, not learned approximate codes.

Next decision: Retain practical two/three-dot score programs or change the representation family.

Sources: [research/quantization-discovery/subbit/nibble-paired-query/README.md](../quantization-discovery/subbit/nibble-paired-query/README.md), [research/quantization-discovery/subbit/paired-score-radix/README.md](../quantization-discovery/subbit/paired-score-radix/README.md), [research/quantization-discovery/subbit/nibble-score-quotient/README.md](../quantization-discovery/subbit/nibble-score-quotient/README.md), [research/quantization-discovery/subbit/query-span-fibers/README.md](../quantization-discovery/subbit/query-span-fibers/README.md).

<a id="subbit-binary-ladder-selectors"></a>
## Paid A7 scalar threshold selection

Category: Promising but not yet. Evidence: held projection.

Two-boundary first/second factor thresholds improve complete frozen two-factor response without changing packed signs, scales or dot count.

Comparison: Held layer-0/14 RMS .017775/.016480 to .017412/.016311 versus safe pair; first-only fit helps layer 0 .017775 to .017573.

Boundary: Original-producer same-image result, no native time or whole-model quality.

Next decision: Choose ladders against quantized-producer MLP/gold response.

Sources: [research/quantization-discovery/subbit/binary-scale-selector/README.md](../quantization-discovery/subbit/binary-scale-selector/README.md), [research/quantization-discovery/subbit/binary-second-selector/README.md](../quantization-discovery/subbit/binary-second-selector/README.md).

<a id="subbit-binary-paid-scales"></a>
## Paid binary output scales and composed MLP gain

Category: Promising but not yet. Evidence: held nonlinear MLP.

Teacher-response scales already present in the packed up image lower held projection errors and improve a complete SiLU gate/up/down response after damaged upstream production.

Comparison: On held damaged-producer inputs, up-scale fit lowers complete MLP RMS .610348 to .587859 at unchanged .520833 up BPW and factor work.

Boundary: Gate/down remain original and FP64 replay is not full quantized model NLL or native time.

Next decision: Fit paid scales with gate/down and actual quantized producer through gold loss.

Sources: [research/quantization-discovery/subbit/binary-output-gain/README.md](../quantization-discovery/subbit/binary-output-gain/README.md), [research/quantization-discovery/subbit/binary-up-composed-gain/README.md](../quantization-discovery/subbit/binary-up-composed-gain/README.md).

<a id="subbit-mlp-paid-fit"></a>
## Paid MLP scale and gold gain fitting

Category: Promising but not yet. Evidence: held model prefix.

Refitting already-paid input/output scales and choosing down/O gains on gold labels improves damaged-prefix loss without new image bytes or factor work.

Comparison: Input/output scales lower held post-MLP error .65752 to .62089; down gain lowers 18-window test NLL 11.32575 to 9.54966 and joint O gain lowers another test panel 9.58521 to 8.75417.

Boundary: Prefix has original downstream layers and remains badly damaged; gains transfer poorly to complete image.

Next decision: Fit gains and factor codes through quantized tied and downstream layers.

Sources: [research/quantization-discovery/subbit/full-model/README.md](../quantization-discovery/subbit/full-model/README.md), [research/quantization-discovery/subbit/full-model/MLP-SCALE-FIT.md](../quantization-discovery/subbit/full-model/MLP-SCALE-FIT.md), [research/quantization-discovery/subbit/full-model/MLP-INPUT-SCALE.md](../quantization-discovery/subbit/full-model/MLP-INPUT-SCALE.md), [research/quantization-discovery/subbit/full-model/MLP-QUANTIZED-SCALE.md](../quantization-discovery/subbit/full-model/MLP-QUANTIZED-SCALE.md), [research/quantization-discovery/subbit/full-model/GOLD-DOWN-GAIN.md](../quantization-discovery/subbit/full-model/GOLD-DOWN-GAIN.md), [research/quantization-discovery/subbit/full-model/JOINT-GAIN.md](../quantization-discovery/subbit/full-model/JOINT-GAIN.md).

<a id="subbit-key-paid-plane"></a>
## Paid selected-plane Q/K and sparse normalization

Category: Promising but not yet. Evidence: held causal KL.

Paid binary Q/K images can use selected planes, existing affine slots and unused padded cache lines; positive sparse raw K rows approximate full RMSNorm while saving output terms.

Comparison: 128-plane full-norm held KL .252318/.308216; 16-extra-row sparse .253286/.325664, train-exchanged rows .246907/.308927 at unchanged 512-byte padded cache.

Boundary: Four original-producer windows and CPU map; native time, BF16 norm equivalence and quantized-upstream language loss not measured.

Next decision: Jointly learn paid K row support, Q/K codes and score observer.

Sources: [research/quantization-discovery/subbit/paid-qk-plane-gain/README.md](../quantization-discovery/subbit/paid-qk-plane-gain/README.md), [research/quantization-discovery/subbit/paid-qk-plane-allocation/README.md](../quantization-discovery/subbit/paid-qk-plane-allocation/README.md), [research/quantization-discovery/subbit/paid-qk-cache-slack/README.md](../quantization-discovery/subbit/paid-qk-cache-slack/README.md), [research/quantization-discovery/subbit/causal-key-norm/README.md](../quantization-discovery/subbit/causal-key-norm/README.md), [research/quantization-discovery/subbit/cache-slack-norm/README.md](../quantization-discovery/subbit/cache-slack-norm/README.md), [research/quantization-discovery/subbit/norm-row-support/README.md](../quantization-discovery/subbit/norm-row-support/README.md), [research/quantization-discovery/subbit/norm-sensitivity/README.md](../quantization-discovery/subbit/norm-sensitivity/README.md), [research/quantization-discovery/subbit/norm-row-exchange/README.md](../quantization-discovery/subbit/norm-row-exchange/README.md).

<a id="subbit-post-o-head-rate"></a>
## Post-O head-rate allocation

Category: Promising but not yet. Evidence: held post-O.

An exact finite sixteen-head quadratic reallocates frozen 2/3-bit Q precision for the downstream attention output.

Comparison: At .40778 BPW, train-selected mask lowers held post-O squared error .024280 to .022787 versus an attention-KL selected mask at equal bytes/work.

Boundary: Frozen two-bit/three-bit Q arms and inspected original-producer data; no fresh model NLL or native mixed-bit reader.

Next decision: Select with fresh quantized-producer model loss, then price mixed-bit execution.

Sources: [research/quantization-discovery/subbit/post-o-allocation/README.md](../quantization-discovery/subbit/post-o-allocation/README.md), [research/quantization-discovery/subbit/head-rate/README.md](../quantization-discovery/subbit/head-rate/README.md).

<a id="subbit-key-quotient"></a>
## Post-RoPE translation gauge and one-byte cache

Category: Promising but not yet. Evidence: exact identity + held KL.

Post-RoPE constant-key translation cancels from softmax; centering the paid selected-score cache supports a one-byte key representation.

Comparison: Centered int8 selected groups lower layer-0 held KL .309766 to .260361 while padded cache shrinks 512 to 256 bytes/token/layer.

Boundary: Layer-14 BF16 rounding of the exact quotient reverses its tiny KL gain; native read and model loss not measured.

Next decision: Co-fit centering with paid query/key labels on quantized producers.

Sources: [research/quantization-discovery/subbit/softmax-key-gauge/README.md](../quantization-discovery/subbit/softmax-key-gauge/README.md), [research/quantization-discovery/subbit/centered-key-cache/README.md](../quantization-discovery/subbit/centered-key-cache/README.md).

<a id="subbit-mlp-rank-response"></a>
## Reduced-rank MLP response repair

Category: Promising but not yet. Evidence: held post-MLP.

A covariance-aware rank-32 paid FP16 residual repairs the earlier coefficient-truncation negative on the same frozen hidden responses.

Comparison: Held post-MLP error .65752 to .61904 at rank 32 versus .66098 for coefficient truncation.

Boundary: Costs 264,192 extra bytes and 131,072 terms/token; model loss and native time not measured.

Next decision: Compare with zero-byte scale refits on quantized-producer model loss.

Sources: [research/quantization-discovery/subbit/full-model/README.md](../quantization-discovery/subbit/full-model/README.md), [research/quantization-discovery/subbit/full-model/REDUCED-RANK-RESPONSE.md](../quantization-discovery/subbit/full-model/REDUCED-RANK-RESPONSE.md), [research/quantization-discovery/subbit/full-model/MLP-FACTOR-RESPONSE.md](../quantization-discovery/subbit/full-model/MLP-FACTOR-RESPONSE.md).

<a id="subbit-key-rope-phase"></a>
## RoPE commuting phase and finite-cell fitting

Category: Promising but not yet. Evidence: exact structural + toy.

Fixed Q/K basis transformations commuting with all RoPE positions reduce to one complex multiplier per plane; phase changes rounding cells without changing real unrounded scores.

Comparison: Checked synthetic rounded two-head case KL .038051 to .017398; dynamic-max synthetic KL .014947 to .005113, convex bracket tightens to .00000136.

Boundary: Synthetic/fixed-step or numerical search; Qwen held attention and native phase/append cost not measured.

Next decision: Fit phase and labels on quantized-upstream Qwen causal text.

Sources: [research/quantization-discovery/subbit/rope-commutant/README.md](../quantization-discovery/subbit/rope-commutant/README.md), [research/quantization-discovery/subbit/phase-cell-fit/README.md](../quantization-discovery/subbit/phase-cell-fit/README.md), [research/quantization-discovery/subbit/rounded-phase-cells/README.md](../quantization-discovery/subbit/rounded-phase-cells/README.md), [research/quantization-discovery/subbit/dynamic-phase-cells/README.md](../quantization-discovery/subbit/dynamic-phase-cells/README.md), [research/quantization-discovery/subbit/dynamic-phase-convex/README.md](../quantization-discovery/subbit/dynamic-phase-convex/README.md), [research/quantization-discovery/subbit/rope-integer-shift/README.md](../quantization-discovery/subbit/rope-integer-shift/README.md).

<a id="subbit-key-rope-bound"></a>
## RoPE key-orbit and stationary recurrence barriers

Category: Strictly bad under the tested conditions. Evidence: exact proof + modeled geometry.

A generic fixed post-RoPE narrow linear decoder or stationary query recurrence does not cheaply carry a rank-one key through all active positions.

Comparison: Pinned first-column heads excite all 64 RoPE planes and require 128 cached coordinates or 128 stationary oscillator states under named exact grammars; best rank-28 isotropic rotated-key projection retains .380/.444 energy.

Boundary: Restricted unrestricted-query/fixed-linear or stationary recurrence claims, not a limit on learned approximate position-aware scores.

Next decision: Fit selected planes and producer with both causal heads.

Sources: [research/quantization-discovery/subbit/rope-key-orbit/README.md](../quantization-discovery/subbit/rope-key-orbit/README.md), [research/quantization-discovery/subbit/rope-recurrence/README.md](../quantization-discovery/subbit/rope-recurrence/README.md).

<a id="subbit-key-plane"></a>
## RoPE-compatible selected-plane score geometry

Category: Promising but not yet. Evidence: held causal KL.

Whole-plane masks commute with RoPE and preserve direct narrow score maps; causal fitting improves fixed-budget text attention far more than weight covariance masks.

Comparison: At 112 planes, covariance mask held KL 1.460/2.782 versus causal-fitted .367/.489, then finite exchanges .301/.448 and shared gains .229977/.343686 at layers 0/14.

Boundary: Original-producer attention only; selected-row Q/K images, native timing and model loss not measured.

Next decision: Fit paid Q/K signs, mask, gains and norm against quantized-producer downstream loss.

Sources: [research/quantization-discovery/subbit/rope-plane-consumer/README.md](../quantization-discovery/subbit/rope-plane-consumer/README.md), [research/quantization-discovery/subbit/rope-plane-rate-allocation/README.md](../quantization-discovery/subbit/rope-plane-rate-allocation/README.md), [research/quantization-discovery/subbit/rope-causal-mask/README.md](../quantization-discovery/subbit/rope-causal-mask/README.md), [research/quantization-discovery/subbit/rope-finite-kl/README.md](../quantization-discovery/subbit/rope-finite-kl/README.md), [research/quantization-discovery/subbit/rope-exhaustive/README.md](../quantization-discovery/subbit/rope-exhaustive/README.md), [research/quantization-discovery/subbit/rope-causal-gain/README.md](../quantization-discovery/subbit/rope-causal-gain/README.md), [research/quantization-discovery/subbit/rope-gain-fold/README.md](../quantization-discovery/subbit/rope-gain-fold/README.md), [research/quantization-discovery/subbit/rope-group-affine/README.md](../quantization-discovery/subbit/rope-group-affine/README.md), [research/quantization-discovery/subbit/rope-selected-affine/README.md](../quantization-discovery/subbit/rope-selected-affine/README.md), [research/quantization-discovery/subbit/rope-rank-control/README.md](../quantization-discovery/subbit/rope-rank-control/README.md), [research/quantization-discovery/subbit/rope-half-plane/README.md](../quantization-discovery/subbit/rope-half-plane/README.md), [research/quantization-discovery/subbit/rope-plane-block/README.md](../quantization-discovery/subbit/rope-plane-block/README.md).

<a id="subbit-shared-qkv"></a>
## Shared first binary Q/K/V factors

Category: Strictly bad under the tested conditions. Evidence: held projection.

Sharing a first factor improves K/V but worsens Q at matched aggregate .44922 BPW; the wider second factor consumes its saved first-stage work.

Comparison: Equal aggregate rate and signed-work comparison against separate binary factors, recorded in shared-qkv.md.

Boundary: Only the tested shared architecture and original-producer objectives are rejected.

Next decision: Train the shared map on the complete attention response.

Sources: [research/quantization-discovery/subbit/binary-factors/README.md](../quantization-discovery/subbit/binary-factors/README.md), [research/quantization-discovery/subbit/binary-factors/shared-qkv.md](../quantization-discovery/subbit/binary-factors/shared-qkv.md).

<a id="subbit-value-narrow"></a>
## Shared narrow GQA value observer

Category: Promising but not yet. Evidence: held model layer.

A rank-28 shared V basis and two paid output decoders carry narrow coordinates through cache and both attention heads.

Comparison: At .53060 V/O BPW versus independent .53652, held post-O error .37889/.32619 versus .39579/.35247 at layers 0/14; layer-0 single-layer test NLL 4.90511 versus 8.73188.

Boundary: Layer-14 NLL slightly reverses, no complete-model native reader or simultaneous all-layer quality.

Next decision: Jointly fit upstream and both downstream consumers on fresh text; price narrow cache and paid O.

Sources: [research/quantization-discovery/subbit/value-observer/README.md](../quantization-discovery/subbit/value-observer/README.md), [research/quantization-discovery/subbit/RESULTS.md](../quantization-discovery/subbit/RESULTS.md).

<a id="subbit-tied-shared"></a>
## Shared tied head and embedding mixed image

Category: Promising but not yet. Evidence: held whole-model.

One sub-bit image serves input embeddings and output head; mixed exact/codebook/RTN4 rows win only when both consumers propagate through the model.

Comparison: At .893824 tied BPW, shared replacement test/validation NLL 4.32659/4.96719 versus .895325 exact-row 4.36930/4.98173; head-only ranking reverses.

Boundary: All other body weights original; no native reader or strong SOTA comparator.

Next decision: Fit rare rows and both consumers on larger fresh model panels.

Sources: [research/quantization-discovery/subbit/tied-head/README.md](../quantization-discovery/subbit/tied-head/README.md), [research/quantization-discovery/subbit/tied-factors/README.md](../quantization-discovery/subbit/tied-factors/README.md), [research/quantization-discovery/subbit/full-model/README.md](../quantization-discovery/subbit/full-model/README.md).

<a id="subbit-response-codebook"></a>
## Short-vector response codebooks

Category: Strictly bad under the tested conditions. Evidence: held projection + native CPU.

The all-row codebook shortlist loses rate/response quality to the ADMM-derived factor control; scalar packed-table CPU lowering is much slower than dense VNNI on the same quantized map.

Comparison: Three Qwen projections: .882-.891 BPW codebooks have larger held squared error than .771-.773 BPW binary; 14.869 us fresh-table versus 4.665 us dense VNNI on one Bonsai block.

Boundary: Rejection applies to this fitted family and scalar CPU reader, not jointly learned codebooks or vectorized hardware.

Next decision: Change shared response structure and fit whole consumers before new kernels.

Sources: [research/quantization-discovery/subbit/response-codebooks/README.md](../quantization-discovery/subbit/response-codebooks/README.md).

<a id="subbit-value-int8-exact-work"></a>
## Signed-byte two-head correction schedule

Category: Promising but not yet. Evidence: exact CPU construction.

One base dot and a signed difference, bounded high lists and padded high-byte correction expose a direct GQA reader with exact integer responses.

Comparison: Ideal low-byte products fall 15.7%/16.4% at layers 0/14 versus two dense dots; four-row padded high lists 99,040/84,220 versus 32-padding 513,600/510,400.

Boundary: Correction/list preparation and native whole path not measured.

Next decision: Compare fused short high-byte dot with scalar correction on real cache.

Sources: [research/quantization-discovery/subbit/value-cohead-mass-share/README.md](../quantization-discovery/subbit/value-cohead-mass-share/README.md), [research/quantization-discovery/subbit/value-shortlist-radix/README.md](../quantization-discovery/subbit/value-shortlist-radix/README.md), [research/quantization-discovery/subbit/value-overflow-union/README.md](../quantization-discovery/subbit/value-overflow-union/README.md).

<a id="subbit-value-mass-work-negative"></a>
## Sparse list and count-work illusions

Category: Strictly bad under the tested conditions. Evidence: modelled only.

Fewer logical high/low products, compacted zeros or lower-radix counts often fail once issued lanes, support construction and shared physical reads enter the bill.

Comparison: Prefix radix 256 versus compact radix 128 costs 2.229m versus 2.211m layer-0 four-lane slots; optimal rounding saves only 1.32%/.96% complete slots; sparse low compaction saves 4.1% layer-0 slots before compaction.

Boundary: These are frozen 256-token slot/read models, not GPU timing or universal lower bounds.

Next decision: Price fused count prep, append, cache gathers and paid O at occupied contexts.

Sources: [research/quantization-discovery/subbit/value-prefix-gauge/README.md](../quantization-discovery/subbit/value-prefix-gauge/README.md), [research/quantization-discovery/subbit/value-radix-sweep/README.md](../quantization-discovery/subbit/value-radix-sweep/README.md), [research/quantization-discovery/subbit/value-mass-optimal-rounding/README.md](../quantization-discovery/subbit/value-mass-optimal-rounding/README.md), [research/quantization-discovery/subbit/value-zero-compaction/README.md](../quantization-discovery/subbit/value-zero-compaction/README.md), [research/quantization-discovery/subbit/value-low-occupancy-bound/README.md](../quantization-discovery/subbit/value-low-occupancy-bound/README.md), [research/quantization-discovery/subbit/value-mass-local/README.md](../quantization-discovery/subbit/value-mass-local/README.md), [research/quantization-discovery/subbit/value-mass-repair/README.md](../quantization-discovery/subbit/value-mass-repair/README.md).

<a id="subbit-value-physical-read"></a>
## Sparse V row traffic and mixed streams

Category: Strictly bad under the tested conditions. Evidence: modeled physical traffic.

Per-head zero masses rarely remove a row shared by sixteen heads, and mixed absolute/difference coding saves little storage while adding parses.

Comparison: Only 7/131,584 layer-0 causal pairs have all-head zero mass; eight group streams raise cold lines 10.8% versus one; mixed layer-14 saves 1.052 bytes/token but adds 16.6% parses.

Boundary: CPU cold-line/parser model on frozen rows, no native time.

Next decision: Measure one-parser complete reader or co-train group-union support.

Sources: [research/quantization-discovery/subbit/value-active-entropy/README.md](../quantization-discovery/subbit/value-active-entropy/README.md), [research/quantization-discovery/subbit/value-short-mass-physical/README.md](../quantization-discovery/subbit/value-short-mass-physical/README.md), [research/quantization-discovery/subbit/value-absolute-work/README.md](../quantization-discovery/subbit/value-absolute-work/README.md).

<a id="subbit-binary-hybrid"></a>
## Spectral modes and fair binary scale control

Category: Promising but not yet. Evidence: held projection.

Allocating a few real response modes within the same byte budget helps selected binary-factor images; a zero-byte output-scale refit is a stronger universal local control.

Comparison: With the same scale refit on both arms, hybrid wins 8 of 16 .55-bit matrices; binary-only scale refit improves all sixteen.

Boundary: No uniform advantage, native latency or full-model loss.

Next decision: Allocate residual modes by composed sensitivity and charge their direct runtime.

Sources: [research/quantization-discovery/subbit/spectral-residual/README.md](../quantization-discovery/subbit/spectral-residual/README.md).

<a id="subbit-spectral-transfer"></a>
## Spectral rate, calibration and larger-model transfer

Category: Promising but not yet. Evidence: held projection.

Rank/precision and train-window sweeps expose a real low-rate trade on Qwen3-0.6B, but 1.7B does not sustain a spectral quality advantage.

Comparison: Early 0.6B Q .53674-BPW error .08145 versus .53906 binary .09666; 1.7B early Q .07042 spectral versus .05385 refitted binary despite fewer spectral bytes.

Boundary: Three transferred matrices and four-window continuations do not establish scaling or whole-model quality.

Next decision: Train against larger-model consumer on independent text, with calibration budget controlled.

Sources: [research/quantization-discovery/subbit/size-transfer/README.md](../quantization-discovery/subbit/size-transfer/README.md), [research/quantization-discovery/subbit/SPECTRAL.md](../quantization-discovery/subbit/SPECTRAL.md).

<a id="subbit-value-direction"></a>
## Static GQA value-head direction

Category: Strictly bad under the tested conditions. Evidence: exact CPU construction.

A static B-first order saves corrections, but per-query orientation buys too little before selector/routing cost.

Comparison: Layer-0 paired-label B-first corrections 76,826 to 69,010; dynamic minimum removes 4,050 more, only .334% of 32-padded byte-dot uses.

Boundary: Rejects dynamic orientation as an isolated feature on inspected windows, not a jointly routed reader.

Next decision: Price fused static B-first grouped reader.

Sources: [research/quantization-discovery/subbit/value-paired-direction/README.md](../quantization-discovery/subbit/value-paired-direction/README.md), [research/quantization-discovery/subbit/value-cohead-direction/README.md](../quantization-discovery/subbit/value-cohead-direction/README.md).

<a id="subbit-external-frontier"></a>
## Strong quantization comparator map

Category: Promising but not yet. Evidence: primary literature.

The frontier report separates NanoQuant PTQ, LittleBit/ParetoQ QAT, QTIP/QuIP# structured PTQ, and direct-consumer CPU/GPU controls with their different model, rate and compute denominators.

Comparison: Published Llama-2/Llama-3 quality and CUDA/CPU times are context, not a matched Kelana win.

Boundary: No same-model strong SOTA head-to-head or quality-matched native comparison has been completed.

Next decision: Reproduce strong competitors on the same model, data, compute budget and measured native boundary.

Sources: [research/quantization-discovery/subbit/frontier/README.md](../quantization-discovery/subbit/frontier/README.md).

<a id="subbit-value-cache-temporal"></a>
## Temporal and rowwise V entropy coding

Category: Promising but not yet. Evidence: exact CPU rate.

Exact canonical Huffman and independently appendable row streams compress frozen narrow-V labels; absolute layer-0 rows remove the suffix-score dependency.

Comparison: Layer-0 absolute row 92.851 versus static nibble 112 bytes/token; layer-14 difference row 101.713 versus 112, with exact code and integer response.

Boundary: Native Huffman parser, append, mass scan, O and model quality not measured.

Next decision: Time one/two-parser absolute and difference readers with actual shared physical traffic.

Sources: [research/quantization-discovery/subbit/value-entropy-ceiling/README.md](../quantization-discovery/subbit/value-entropy-ceiling/README.md), [research/quantization-discovery/subbit/value-coordinate-entropy/README.md](../quantization-discovery/subbit/value-coordinate-entropy/README.md), [research/quantization-discovery/subbit/value-row-entropy/README.md](../quantization-discovery/subbit/value-row-entropy/README.md), [research/quantization-discovery/subbit/value-absolute-entropy/README.md](../quantization-discovery/subbit/value-absolute-entropy/README.md), [research/quantization-discovery/subbit/value-pair-absolute/README.md](../quantization-discovery/subbit/value-pair-absolute/README.md).

<a id="subbit-tied-covariance-failure"></a>
## Tied factor head-coordinate covariance

Category: Strictly bad under the tested conditions. Evidence: held head.

Covariance-weighted rank-eight residual improves raw head loss but loses after the matched rare-logit calibration and harms the embedding consumer.

Comparison: At .886111 BPW, calibrated held NLL 4.74903 to 4.81208 and embedding RMS .45853 to .46017 for alpha one.

Boundary: Only the sampled head metric, rank-eight sketch and 32-position calibration are rejected.

Next decision: Use more disjoint calibration and propagated tied-model gold loss.

Sources: [research/quantization-discovery/subbit/covariance-factor/README.md](../quantization-discovery/subbit/covariance-factor/README.md).

<a id="subbit-tied-bias"></a>
## Tied head frequency buckets and code-label shortcut

Category: Promising but not yet. Evidence: held head.

Paid frequency buckets lower fixed-input held NLL with a small rate increase, but existing code labels cannot replace the extra frequency IDs.

Comparison: Bucket NLL 4.38285 versus matched global 4.40296 at +56,988 bytes; code-label choice 4.48083 versus global 4.40296 on its matched panel.

Boundary: Teacher KL slightly worsens for bucket fit, no quantized-embedding propagation or native timing.

Next decision: Test whether bucket gain survives full-model tied use and whether routing cost is worth it.

Sources: [research/quantization-discovery/subbit/tied-bias/README.md](../quantization-discovery/subbit/tied-bias/README.md), [research/quantization-discovery/subbit/tied-code-bias/README.md](../quantization-discovery/subbit/tied-code-bias/README.md).

<a id="subbit-tied-rare-factors"></a>
## Tied rare-row low-rank corrections

Category: Strictly bad under the tested conditions. Evidence: held head.

Unweighted rank-16 residual worsens head NLL despite lower logit RMS; curvature-only rank-eight and signed rank-64 mixed residuals also lose to frequent exact rows.

Comparison: Unweighted rank-16 NLL 5.945 versus K256 alone 5.795; at .886111 BPW curvature rank eight NLL 4.932 versus 2,560-exact .895325-BPW 4.629.

Boundary: Fixed original final-hidden inputs; no quantized embedding propagation.

Next decision: Fit gold-token and occurrence objectives through both tied consumers.

Sources: [research/quantization-discovery/subbit/tied-rare/README.md](../quantization-discovery/subbit/tied-rare/README.md), [research/quantization-discovery/subbit/tied-softmax/README.md](../quantization-discovery/subbit/tied-softmax/README.md), [research/quantization-discovery/subbit/tied-factors/README.md](../quantization-discovery/subbit/tied-factors/README.md).

<a id="subbit-value-mass-phase"></a>
## Value-aware rounded mass and cheap phase policies

Category: Promising but not yet. Evidence: held post-O + toy.

Exact phase event search improves a frozen count map; a cached byte sketch and 16-phase policy capture part of the gain without dense per-query code projections.

Comparison: Inspected sketch policy error .00019788/.00094393 versus fixed phase .00035732/.00122964 at layers 0/14; exact search .000464 to .000281 on sampled layer-14 rows.

Boundary: Append sketch/query scans and native cost not measured; even chosen phase may miss complete-layer eligibility.

Next decision: Co-learn the phase selector, sketch and V/O codes on fresh quantized-producer text.

Sources: [research/quantization-discovery/subbit/value-adaptive-phase/README.md](../quantization-discovery/subbit/value-adaptive-phase/README.md), [research/quantization-discovery/subbit/value-phase-grid/README.md](../quantization-discovery/subbit/value-phase-grid/README.md), [research/quantization-discovery/subbit/value-phase-policy/README.md](../quantization-discovery/subbit/value-phase-policy/README.md), [research/quantization-discovery/subbit/value-phase-sketch/README.md](../quantization-discovery/subbit/value-phase-sketch/README.md), [research/quantization-discovery/subbit/value-mass-discrepancy/README.md](../quantization-discovery/subbit/value-mass-discrepancy/README.md).

<a id="subbit-pilot-walsh"></a>
## Whole-model Walsh response atoms

Category: Strictly bad under the tested conditions. Evidence: held whole-model.

Signed Walsh-8 labels give a cheap 0.6267-BPW direct response map but destroy Qwen3-0.6B language quality.

Comparison: Test NLL 14.626 versus BF16 3.311 and plain RTN4 4.242.

Boundary: Rejection is for this isotropic atom family on the pilot, not all response codebooks.

Next decision: Learn activation-sensitive codes and composed consumers.

Sources: [research/quantization-discovery/subbit/PILOT.md](../quantization-discovery/subbit/PILOT.md), [research/quantization-discovery/subbit/README.md](../quantization-discovery/subbit/README.md).
