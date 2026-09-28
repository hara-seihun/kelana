# Mixture of experts and speculative decoding

[Research desk](README.md)

Generated from `moe-speculation.json`; the JSON owns classifications.

<a id="spec-full-token-json-forced-runs"></a>
## All-token JSON grammar leaves few or no forced decisions

Category: Strictly bad under the tested conditions. Evidence: Sixteen finite JSON strings admit 296960 legal token paths under Qwen3-0.6B ordinary vocabulary; 152 of 200 canonical-path steps remain ambiguous under full support. A lazy variable-field JSON grammar has zero token-singleton steps on its measured 63- and 121-token paths. On Qwen3-1.7B two actual conversions emit valid 49- and 98-token records but eliminate zero target calls and achieve .996 times serial decode throughput..

Assuming known punctuation bytes force token IDs fails on these complete ordinary-token JSON contracts.

Comparison: Canonical-token restriction versus all legal ordinary-token byte continuations, with Qwen3-1.7B serial and singleton-run contraction at the identical grammar.

Boundary: Specific finite languages, bounded ASCII variable-field fixture and two actual conversion traces; another grammar/path can have genuine singleton runs. Canonical-token protocols remain valid if the consumer permits that changed law.

Next decision: Measure token support on intended production schemas; avoid claiming the canonical protocol's 9.61 times gain for full-byte-law JSON.

Sources: [research/speculative-maps/tokenizer-spans/README.md](../speculative-maps/tokenizer-spans/README.md), [research/speculative-maps/structured-runtime/README.md](../speculative-maps/structured-runtime/README.md), [research/speculative-maps/realistic-runtime/README.md](../speculative-maps/realistic-runtime/README.md).

<a id="spec-retrieved-copy-edge"></a>
## Cheap retrieved continuation graft in a learned proposal tree

Category: Promising but not yet. Evidence: A token-offset retrieval index cuts paired query latency 6.00 to .0625 ms with the same candidates and 20.75 MB resident data. On two opposite-order eight-prompt online panels, adding one copied edge in the same eighteen-node tree raises throughput 36.75 to 38.35 tokens/s versus paired serial 30.12; paths and final decisions match..

A complementary prompt/train-corpus copy edge earns a small measured whole-loop gain after retrieval itself becomes cheap.

Comparison: Identical learned direct eighteen-node tree without copy, paired serial Qwen3-0.6B FP32 and offline copy-only chains/trees.

Boundary: Index preparation is outside per-request timing but separately recorded; original training corpus and eight short prompts, PyTorch FP32 rather than production BF16/native serving.

Next decision: Evaluate disjoint domains and longer contexts, including index preparation amortization and a production-precision numerical contract.

Sources: [research/speculative-maps/retrieved-spans/README.md](../speculative-maps/retrieved-spans/README.md), [research/speculative-maps/online/COUPLED.md](../speculative-maps/online/COUPLED.md).

<a id="moe-corouted-down-output-rank"></a>
## Co-routed original down maps defeat exact dense route-specific output factors

Category: Strictly bad under the tested conditions. Evidence: Three original BF16 layer-0 down experts 10,3,1 selected together by an actual held installed-GGUF route have stacked rank at least 1530 modulo 251; an exact dense route-specific eight-expert factor costs at least 1.120605 times direct down MACs, while a saving requires rank at most 1365..

Even co-selection of the available original down experts does not lower their exact output span into the dense common-factor arithmetic-winning range.

Comparison: Direct eight down maps versus one route-specific dense basis and eight route-specific factors, unrestricted independent hiddens and real-arithmetic equality.

Boundary: The rank is original BF16 whereas the route is selected GGUF; it is a lower bound, not an exact real rank or a claim about nonlinear reachable hiddens, lossy representations, packed maps, native FP32 identity or TPS.

Next decision: Fit paid approximate packed representations to broad quantized producer activations and scores and evaluate frozen complete-model language loss; do not retry exact route-specific dense bases on the same triple.

Sources: [research/moe/output-factor-rank/README.md](../moe/output-factor-rank/README.md).

<a id="moe-actual-down-output-bases"></a>
## Common down-output bases on real routes and full-bank priors

Category: Strictly bad under the tested conditions. Evidence: A rank-512 basis from 904 layer-0 train slots loses .709 held routed-sum RMS despite .088 train RMS; even that train span loses .599. On a separate 64/64-token capture across all forty layers, the entire per-layer rank-512 train-slot span loses .704919 pooled held RMS, with every layer over .5585. Uniform full-bank sampled weight columns yield .813 layer-0 held RMS; mixing capture and full-bank columns improves .708799 to only .704294 at the best tested prior..

Train-fitted and sampled-weight fixed output bases fail to generalize on actual routed producers, even with a free optimal output projection and with all forty layers observed.

Comparison: The installed Q5_K eight-expert down sum on disjoint actual routed train/held producers; the forty-layer test covers 2,560 layer-token cases per split. Free orthogonal projection is the strongest consumer for each fixed subspace.

Boundary: The negative is for these finite-data, fixed-basis constructions, not a learned full-model code or an optimal covariance from broader routes. FP64 local sums are not native FP32 logits or language loss. The conditional equal-byte rank-512 stream prize is at most 6.55% across forty layers.

Next decision: Collect more diverse routed producers and fit a paid weight-informed or newly trained coordinate, choosing on disjoint complete-model language loss before any packed image or native reader.

Sources: [research/moe/real-sum-rank/README.md](../moe/real-sum-rank/README.md), [research/moe/weight-informed/README.md](../moe/weight-informed/README.md), [research/moe/route-covariance/README.md](../moe/route-covariance/README.md), [research/moe/all-layer-output-span/README.md](../moe/all-layer-output-span/README.md).

<a id="moe-shared-down-basis"></a>
## Common output basis after the Qwen expert sum

Category: Strictly bad under the tested conditions. Evidence: On sixteen official layer-0 BF16 experts, a rank-512 basis fitted to eight loses .835 held expert-weight RMS and .832 held synthetic routed-sum RMS; even the all-sixteen in-sample basis loses .674 weight RMS. Rank 1536 exceeds direct down MACs..

The proposed shared output coordinate reduces ideal rank-512 down arithmetic to 37.5% but loses too much of the tested response.

Comparison: Direct eight-expert BF16 down projections; eight-expert fit versus disjoint eight-expert holdout, and an all-sixteen in-sample oracle.

Boundary: Only sixteen layer-0 experts and synthetic isotropic hidden inputs; neither native quantized factors nor complete-model loss or timing were measured.

Next decision: Fit composed covariance on separate real routed activations and price a quantized native factor only if held complete-model quality survives.

Sources: [research/moe/README.md](../moe/README.md).

<a id="spec-entropy-budget-policy"></a>
## Confidence-only adaptive tree budgets

Category: Strictly bad under the tested conditions. Evidence: Across 32 pilot test contexts, root-entropy quartile chains range from 2.125 to 1.500 covered tokens. Yet a validation-calibrated budget policy selects one fixed budget for all test cases under several flat verification knees; at knees 4 and 8 it loses to the validation-selected fixed control..

The tested confidence-based allocator does not deliver reliable value-of-computation gains from known heterogeneity.

Comparison: Validation-selected fixed tree budgets, 0-to-64 nodes, assumed flat-to-compute-bound cost curves and a free hindsight selector.

Boundary: Cost curves are scenarios, not GPU timing; this result does not rule out action-specific gain predictors or changing candidate support.

Next decision: Predict measured marginal gain of specific actions and fit actual verifier cost on disjoint continued-generation states.

Sources: [research/speculative-maps/adaptive/README.md](../speculative-maps/adaptive/README.md), [research/speculative-maps/IDEAS.md](../speculative-maps/IDEAS.md).

<a id="spec-online-qwen-verifier"></a>
## Continued target tree verification with accepted KV adoption

Category: Promising but not yet. Evidence: On four Qwen3-0.6B FP32 prompts repeated in opposite order, eighteen-node trees emit 42.09 tokens/s against serial 30.25 with all 256 token IDs and final decisions matching. Sixty-four nodes raise progress only 9.7% and cycle time 52.7%, falling to 29.70 versus 29.92 serial tokens/s..

The online tree pays CPU draft, mask, full head and KV gathering; a moderate tree beats its paired serial baseline while too much branching loses.

Comparison: One-token serial and six-token chain, six-, eighteen- and sixty-four-node trees on the same PyTorch target implementation.

Boundary: FP32 promoted from BF16 weights, short corpus prefixes and no tuned native serving engine. Ordinary BF16 single-token SDPA and explicit tree masks differ in body output and one greedy near tie, so this is not a lossless BF16 claim.

Next decision: Define consistent production attention/reduction semantics and test longer task-quality workloads with native tree/KV scheduling.

Sources: [research/speculative-maps/online/README.md](../speculative-maps/online/README.md), [research/speculative-maps/online/COUPLED.md](../speculative-maps/online/COUPLED.md).

<a id="spec-measured-action-routing"></a>
## Cost-fitted tree dispatch fails the paid online comparison

Category: Strictly bad under the tested conditions. Evidence: An offline direct-producer policy predicts 43.242 versus 42.667 tokens/s for fixed six-node depth, but in continued FP32 generation reaches 35.10 tokens/s versus fixed six-node depth 35.98 and fixed eighteen-node mass 36.59. It makes 57 serial choices yet loses to the fixed control..

The validation-fit measured-cost selector's predicted gain does not survive online histories and full dispatch costs.

Comparison: Fixed serial, six-node depth and eighteen-node mass trees under the same Qwen3-0.6B online verifier.

Boundary: Eight short prompts, Python/PyTorch FP32 target; this rejects this learned policy, not hardware-aware allocation in general.

Next decision: Collect on-generation action outcomes and fit next-state-aware gains before another adaptive dispatch trial.

Sources: [research/speculative-maps/measured-policy/README.md](../speculative-maps/measured-policy/README.md), [research/speculative-maps/online/COUPLED.md](../speculative-maps/online/COUPLED.md).

<a id="moe-q3-robust-allocation"></a>
## Cross-validated support-aware Q3 expert choice on actual routes

Category: Strictly bad under the tested conditions. Evidence: At 32 paid layer-0 Q3 experts, four-fold train-only frequency/error shrinkage changes 20 expert IDs and worsens held routed-sum RMS .009186 to .015660 at the same 293076992-byte gate/up bank rate. The unsmoothed independent ranking agrees with the prior joint greedy at 32/64 experts..

Selecting a Q3 expert bank through cross-validation on this short producer capture does not improve the useful individual allocation point; the fold-selected support pattern transfers worse.

Comparison: Frozen native-format Q3_K/Q4_K gate/up images, actual layer-0 quantized producers, scores and unchanged Q5_K down; 113 train and 126 disjoint held tokens, 16 train-only hyperparameter candidates.

Boundary: One layer and short text, CPU FP32/FP64 local output RMS, no complete-model language loss or native timing. Rejects this risk estimator and data size, not broad-data paid mixed allocation.

Next decision: Capture diverse quantized-producer routes across layers and freeze complete paid images for disjoint language loss rather than tune another risk smoother on these folds.

Sources: [research/moe/q3-robust-allocation/README.md](../moe/q3-robust-allocation/README.md).

<a id="spec-direct-id-producer"></a>
## Direct candidate IDs without borrowed target output rows

Category: Promising but not yet. Evidence: A 572896-parameter direct producer reduces five shortlist projections from 20.97M to 1.31M scalar products and removes roughly 16 MiB of frozen target-head rows versus the 4096-row residual producer. In continued FP32 generation its 18-node draft costs 1.21 ms versus the residual panel's 2.28 ms; complete throughput remains 41.33 versus 42.09 tokens/s in separate panels..

The learned direct ID head removes real draft work while preserving most of the online gain, but its lower acceptance prevents a throughput lead here.

Comparison: Matched residual drafter and Qwen FP32 serial baseline, with proposal-tree coverage at equal node budgets and paired online serial rates.

Boundary: Panels are separate and small; not BF16-preserving or native-engine timings. The direct model loses validation coverage despite lower validation CE.

Next decision: Train for accepted-prefix coverage on larger on-generation states, retaining the cheap direct head.

Sources: [research/speculative-maps/direct-producer/README.md](../speculative-maps/direct-producer/README.md), [research/speculative-maps/online/README.md](../speculative-maps/online/README.md).

<a id="moe-gateup-q3-recode"></a>
## Direct paid Q3_K gate/up recoding on actual MoE routes

Category: Strictly bad under the tested conditions. Evidence: Complete layer-0 Q3_K gate/up image 230686720 bytes versus installed Q4_K 301989888 bytes; actual 126-token held routed-sum RMS .084997 versus unchanged decoded Q4_K, 113 train-token RMS .089569. Conditional forty-layer one-read saving is 3.394% of model bytes..

Straight static quantization of decoded installed gate/up Q4_K into native Q3_K damages the complete routed expert output for a modest logical weight-byte saving.

Comparison: Pinned decoded installed Q4_K gate/up and unchanged Q5_K down against native-format Q3_K recodes through actual producer inputs, routed IDs and scores.

Boundary: One layer, two short capture splits and CPU FP32/FP64 local observation; no complete-model language loss, native packed timing or original-BF16 fidelity.

Next decision: Train a paid mixed-rate gate/up image on broader actual producer routes, then freeze it for complete-model held loss before building a Q3_K native selection.

Sources: [research/moe/gateup-q3-recode/README.md](../moe/gateup-q3-recode/README.md).

<a id="moe-cross-bank-rate"></a>
## Disjoint native-format expert-bank allocation on real routed sums

Category: Promising but not yet. Evidence: On 126 held actual layer-0 routed producer tokens, a paid train-selected 16-Q3-gate/up plus 32-Q4-down disjoint image loses .007387 relative RMS at .411754% conditional forty-layer one-read saving. Thirty-two Q3 alone loses .009186 at .424232%, and 64 Q4 down alone .006928 at .399277%. Thirty-two Q3 plus 64 Q4 down loses .020779 at .823508%. Cross-bank error cosine for 16+32 is .0003..

Composing different expert-bank recodes gives a measured small local rate/quality frontier, but static recode errors do not cancel enough for large savings.

Comparison: Frozen Q3_K gate/up and paid Q4_K down image choices with distinct expert IDs, train-only allocation, recomputed identical offline Q4 gate/up producer on 113/126 actual train/held tokens; complete score-weighted sum against decoded Q4 gate/up/Q5 down.

Boundary: Only layer-0 CPU FP32 products and FP64 sum; no whole-model language loss, physical DRAM, native bit identity or mixed-dispatch time. Conditional forty-layer rate extrapolation is not a complete image.

Next decision: Capture broader quantized producers across all layers, freeze a paid complete image, test disjoint held language loss before any native mixed-format reader.

Sources: [research/moe/cross-bank-rate/README.md](../moe/cross-bank-rate/README.md).

<a id="spec-byte-cdf-rows"></a>
## Exact byte CDF encoding of frozen learned transition rows

Category: Promising but not yet. Evidence: All 15 nonterminal cumulative thresholds in the frozen 3072-row tensor fit in one byte; CDF storage halves from 98304 to 49152 bytes across 32 contexts. Paired visited-row lookup drops 12.03 to 10.98 ns per stream at 32 active contexts, but at one context remains 10.16 versus 10.20 ns; converting existing tables costs 22.4 microseconds for 32 contexts..

A precise finite-image byte encoding can trim resident tables and a narrow CPU lookup, conditional on direct producer output or enough reuse.

Comparison: Original AVX2 uint16 visited-row lookup against SSE uint8 on identical frozen learned CDF rows; conversion cost separately charged.

Boundary: This dataset's thresholds fit; future rows may reach 256 earlier. The roughly 1 ns gain amortizes conversion only after about 21000 paths at 32 contexts, and no neural producer or native verifier was changed.

Next decision: Emit checked byte thresholds directly from the producer, then measure complete proposal/verification timing and memory residency.

Sources: [research/speculative-maps/map-structure/README.md](../speculative-maps/map-structure/README.md).

<a id="spec-whole-map-control-witnesses"></a>
## Exact continuation and shared-cost control witnesses

Category: Promising but not yet. Evidence: Finite exact witnesses show a greedy immediate tokens/time policy yields 3/23 while a stationary policy reaches one token per cost unit by changing phase, and a shared-page budget favors three 1/5-probability nodes on one page over a single 2/5 node despite nodewise ranking. A joint next-output/next-encoded-state condition states the reusable quotient requirement..

Structural examples explain why future state and shared reads belong in action selection, rather than output entropy or nodewise score alone.

Comparison: Exhaustive 27 stationary policies with Bellman potential, and exact rational prefix-mass/shared-page alternatives.

Boundary: Stipulated finite costs and interfaces, not a transformer speedup or an algorithm that finds the global whole-map optimum.

Next decision: Fit action gains and continuation value on paid online states and measure producer, verifier and state adoption together.

Sources: [research/speculative-maps/theory/README.md](../speculative-maps/theory/README.md), [research/speculative-maps/README.md](../speculative-maps/README.md), [research/speculative-maps/IDEAS.md](../speculative-maps/IDEAS.md).

<a id="spec-finite-maps-native-toy"></a>
## Exact finite transition composition with byte-shuffle CPU consumption

Category: Promising but not yet. Evidence: Exact enumeration checks 102 reachable paths and all 1024 uniform streams in a three-state model; 200 seeded cases check larger maps. On the 32-step cache-resident threshold toy, complete 16-byte map construction plus serial prefix consumption takes 14.7 ns, versus 31.5 ns for direct visited-state sampling and 297.7 ns for compact nibble maps..

Carrying a larger byte labeling directly into VPSHUFB beats a smaller packed nibble labeling on a complete toy computation.

Comparison: Direct visited-row CPU sampling and scalar nibble composition with identical conditional rows, uniforms and output paths.

Boundary: Threshold tables make every counterfactual row cheap; learned neural CDF construction is different. Warming, single CPU core and no target verifier or GPU.

Next decision: Measure the complete producer and consumer on learned transitions and use parallel prefix only when its extra work earns its span reduction.

Sources: [research/speculative-maps/finite/README.md](../speculative-maps/finite/README.md).

<a id="spec-greedy-head-cert-toy"></a>
## Exact partial-head winner certificate in a finite byte model

Category: Promising but not yet. Evidence: On 4096 seeded integer contexts with eight classes and sixteen features, a large-feature-first exact interval certificate omits 45.78% of counted head-weight bytes versus a full GEMV while matching every greedy winner; reverse feature order omits .42%..

Feature order and valid tail bounds expose a conditional compute-for-weight-read trade on the finite exact head.

Comparison: Full exact integer GEMV, fixed random and reverse orders; existing real Bonsai head certificates offer only 7–11% modeled transaction-aware head-traffic savings.

Boundary: No bounds/read metadata, cache transaction or launch pricing in the toy result; not a real model, stochastic sampler or entire decoder gain.

Next decision: Beat the existing real-head certificate using a tiled native bound with an optimized full-head GEMV and whole-request timing.

Sources: [research/speculative-maps/compute-bandwidth/README.md](../speculative-maps/compute-bandwidth/README.md).

<a id="spec-lazy-integer-sampling"></a>
## Exact rejection sampling with lazily read integer weights

Category: Promising but not yet. Evidence: An exhaustive 1472-cell check proves identical integer-weight output law and accepted-rank coupling. With a reusable certified envelope, concentrated weights use 8.242 recurring read bytes per sample versus full-CDF 16; scaling the same normalized law by eight raises reads to 65.939 under the same envelope..

High-byte stopping can save source reads without changing a finite stochastic law, but envelope fit, not entropy alone, decides the cost.

Comparison: Full two-byte reads of all eight dynamic weights and a full integer CDF, with 32 bytes of one-time envelope preparation charged across samples.

Boundary: Exact finite toy and logical byte counts, not real head-score production, cache transactions, unbiased RNG cycle time or model throughput. A poor envelope loses badly.

Next decision: Find a real producer supplying cheap valid bounds and price online envelope, irregular reads, RNG, state continuation and native sampling.

Sources: [research/speculative-maps/lazy-sampling/README.md](../speculative-maps/lazy-sampling/README.md).

<a id="spec-forced-span-map"></a>
## Exact state contraction for forced-token spans

Category: Promising but not yet. Evidence: In an F97 affine model, composing a four-token forced transition preserves the state and next free-choice distribution for all 97 input states; skipping the updates changes that distribution in 94 states. In a deliberately canonical-token Qwen JSON protocol, causal prefill reduces 44 serial target calls to four and raises throughput 35.79 to 343.91 tokens/s with matching token path and final next decision..

Token-singleton decisions can disappear while state updates remain; batching a canonical forced run gives a large scoped runtime win.

Comparison: Uncontracted per-token locally masked state transitions in the finite model and Qwen FP32 serial forced-token execution under the same canonical-ID protocol.

Boundary: The finite affine proof is not a transformer shortcut. Canonical IDs change the target law relative to all ordinary tokenizations; on the latter grammar the longest experiment gains only 1.022 times.

Next decision: Specify consumer token law first, then batch only proved singleton edges with causal KV updates and complete boundary-state comparison.

Sources: [research/speculative-maps/forced-spans/README.md](../speculative-maps/forced-spans/README.md), [research/speculative-maps/online/COUPLED.md](../speculative-maps/online/COUPLED.md).

<a id="moe-packed-xor-route-deltas"></a>
## Exact XOR delta coding between co-routed expert images

Category: Strictly bad under the tested conditions. Evidence: On four train and four held actual layer-0 routes, all 96 held bank-images cost more as the best co-routed-parent XOR/zlib delta than independently compressed. The held best route-local star is 7.33% larger than independent zlib despite free parent choice; independent zlib itself shrinks raw image bytes 15.13%..

The tested frozen-image parent/delta representation loses before paying decode or parent residency.

Comparison: Independent zlib level-1 compression of the same physical Q4_K gate/up and Q5_K down bytes.

Boundary: Eight layer-0 tokens, this compressor and physical-image representation only; neither direct entropy consumption nor a learned relabeling is evaluated.

Next decision: A different packed consumer must demonstrate that its decode/traffic bill is lower than any standalone storage gain.

Sources: [research/moe/packed-bank-delta/README.md](../moe/packed-bank-delta/README.md).

<a id="moe-seven-vector-reconstruction"></a>
## Free seven-output reconstruction and learned residual directions

Category: Strictly bad under the tested conditions. Evidence: Even per-token hindsight coefficients for the best seven of eight outputs lose .06257 held RMS and no train or held token meets 1% local error. A train-learned 32-direction missing-output basis improves held score-prefix RMS only .08228 to .08096 with free coefficients despite .04762 train RMS..

The tested seven-vector span and small global residual SVD cannot cheaply recover the omitted expert's direction.

Comparison: Complete original weighted eight-expert sum, best-of-eight oracle, top-seven-by-score oracle and train-fit rank-wise scalar gains.

Boundary: One layer, short capture and one-expert-at-most omission; learned route-specific nonlinear replacements on more data remain open.

Next decision: Capture larger disjoint real routes and assess paid route-conditional directions against complete-model held quality.

Sources: [research/moe/span7/README.md](../moe/span7/README.md).

<a id="moe-shared-compensation"></a>
## Free shared-expert scalar cannot replace a routed expert

Category: Strictly bad under the tested conditions. Evidence: On 113 train/126 held actual layer-0 routes, best one-expert omission of the combined shared+routed FFN output incurs .062208/.055047 RMS; a free hindsight per-token optimal scalar of the existing shared output reaches only .062145/.054936. Held tokens below 1% remain 1/126; median absolute cosine of the easiest omitted contribution with shared is .0388..

The existing shared expert supplies no useful replacement direction for one routed output under this captured complete-FFN local observation.

Comparison: Actual captured Q4_K/Q5_K routed down outputs/scores and offline decoded Q8_0 shared output from installed GGUF; best-of-eight omission control and free per-token shared-gain oracle.

Boundary: One layer, short train/held texts and a mixed native-captured/offline-real arithmetic CPU map; no complete-model loss, native FP32 identity or speed bound. Retrained directions are outside the frozen-vector oracle.

Next decision: Train paid input-dependent replacement directions on broader quantized producers and freeze a complete image for held language loss rather than alter the existing shared gate alone.

Sources: [research/moe/shared-compensation/README.md](../moe/shared-compensation/README.md).

<a id="spec-learned-map-native-cost"></a>
## Fresh learned CDF maps versus direct visited-row sampling

Category: Strictly bad under the tested conditions. Evidence: Across 32 contexts and six positions, vector map construction plus prefix composition takes 23.57 ns per learned stream versus 17.80 ns for direct AVX2 visited-row CDF lookup; prepared prefix alone is 3.52 ns but excludes 23.88 ns per-stream preparation and 96-byte maps..

The finite threshold toy's win fails when the learned producer must form unvisited CDF successors for each fresh path.

Comparison: Same frozen 16-state learned CDFs, uniforms and sampled paths, with scalar, AVX2, inverse-table, prepared-map, vector and nibble consumers.

Boundary: Single-thread warmed CPU lookup only; neural scoring, table generation, verifier and GPU parallel critical path are outside both timings.

Next decision: Find a cheaper jointly trained map producer, reuse maps across many streams or earn parallel span savings before moving this consumer online.

Sources: [research/speculative-maps/native-learned/README.md](../speculative-maps/native-learned/README.md), [research/speculative-maps/finite/README.md](../speculative-maps/finite/README.md).

<a id="moe-expert-index-factor"></a>
## Frozen expert-index sharing before SwiGLU

Category: Strictly bad under the tested conditions. Evidence: On sixteen original BF16 experts, the best seven shared full-matrix gate/up maps retain 56.50% isotropic response and lose .616 synthetic routed post-SwiGLU/down RMS. Seven costs 87.84% of direct gate/up products; fourteen maps are needed for 90% energy and cost 175.68%..

The tested frozen global expert-index factor lacks enough redundancy in its arithmetic-winning range.

Comparison: Direct eight-expert original BF16 gate/up maps versus optimal low-rank expert-axis factors and composed synthetic-route outputs.

Boundary: Sixteen of 256 experts, synthetic routes and inputs; no real activations, learned codes, native quantized consumer or full-model loss.

Next decision: Try route-aware shared activation preparation with expert-specific coded residuals rather than another frozen weight-only factor.

Sources: [research/moe/expert-axis/README.md](../moe/expert-axis/README.md).

<a id="moe-q3-scalar-correction"></a>
## Frozen Q3 expert directions resist paid scalar repair

Category: Strictly bad under the tested conditions. Evidence: A 512-byte FP16 expert-gain bank fitted on 113 real layer-0 producer tokens worsens held complete routed-sum RMS from .084997 to .086240. Even free hindsight eight-gain least-squares projections on each of 126 held tokens leave .081500 RMS..

Neither a train-fitted static scalar table nor any per-token scalar reweighting of the frozen Q3 expert directions rescues this local loss.

Comparison: Decoded installed Q4_K gate/up with unchanged Q5_K down and native routes/scores; frozen paid Q3_K image with and without scalar gains.

Boundary: One layer, 113 train/126 held producers and local FP64 routed-sum RMS; the bound fixes Q3 directions and does not establish model language quality, native FP32 identity or inference speed.

Next decision: Fit codes or new paid vector directions on broader producers, then assess a complete image on held language loss rather than another scalar fit.

Sources: [research/moe/q3-scalar-correction/README.md](../moe/q3-scalar-correction/README.md).

<a id="moe-exact-down-rank"></a>
## Full exact rank of four BF16 down experts

Category: Strictly bad under the tested conditions. Evidence: A 2048-by-2048 concatenation of layer-0 experts 4–7 has determinant 32 modulo 251. Exact common linear output factoring on unrestricted independent hiddens needs rank 2048, costing 1.5 times direct routed-down MACs and 1.015625 times equal-precision bank storage..

A narrow lossless common linear output basis for these original experts is impossible under the stated unrestricted-hidden map.

Comparison: Four original BF16 down maps, with direct eight-expert products and coefficients as the cost control.

Boundary: Does not bound producer-reachable correlated hiddens, nonlinear or route-specific coding, packed full-width representations, or native FP32 identity.

Next decision: Investigate producer-reachable approximation and direct packed consumers, not another unrestricted exact narrow linear basis.

Sources: [research/moe/exact-route-rank/README.md](../moe/exact-route-rank/README.md).

<a id="moe-routed-jacobian"></a>
## Full local dimension of the combined routed and shared expert sum

Category: Promising but not yet. Evidence: On a held layer-0 producer and fixed top-eight neighborhood, a .400211475 inverse-residual enclosure certifies rank 2048 for the combined real-arithmetic Q4_K/Q5_K routed branch plus sigmoid-gated Q8_0 shared branch and F32 router. The routed-only certificate bounds its inverse residual by .781664775..

Even including the ninth, shared expert, the exact combined FFN output cannot factor through a narrow differentiable common input coordinate locally; full-width packed labels remain open.

Comparison: Decoded installed expert and router matrices; routed-only rank and fixed-score route-independent 2041 bound are controls.

Boundary: One layer and one neighborhood; ideal real arithmetic, not native FP32 bit identity, a discrete packed-code lower bound or throughput proof.

Next decision: Keep all 2048 local dimensions in cheaper packed labels and measure a consumer that uses them directly on broad producer routes and held language loss.

Sources: [research/moe/routed-jacobian/README.md](../moe/routed-jacobian/README.md).

<a id="moe-packed-byte-sharing"></a>
## Identical frozen packed expert fragments on co-routed paths

Category: Strictly bad under the tested conditions. Evidence: All forty installed Q4_K gate/up layers on disjoint 64/64 actual routes have no repeated full block among selected experts. Free same-K matching four-byte low-code reuse saves at most 114356.375 held code bytes/token or 0.00435446% of conditional complete one-read weights; layer 0 supplies 99.85% of repeats. The earlier three-layer synthetic-route study agrees qualitatively..

A dictionary of unchanged same-position frozen bytes cannot remove meaningful complete-model co-routed work.

Comparison: Direct packed Q4_K gate/up low-code fragments with free route-local sharing versus 2626187904 conditional complete one-read bytes/token; prior Q5/Q6 sampled controls.

Boundary: Finite 64/64-token actual prompt captures and direct same-K unchanged-code grammar; collisions generously ignore scale/metadata, and modeled logical bytes are not native DRAM or TPS. Learned labels, changed complete images and ISA compositions are open.

Next decision: Design paid expert labels jointly with the packed consumer on broad actual routes and require disjoint complete-model language loss; independently measure native Q8/expert physical time.

Sources: [research/moe/code-sharing/README.md](../moe/code-sharing/README.md), [research/moe/code-sharing-all-route/README.md](../moe/code-sharing-all-route/README.md).

<a id="moe-full-axis-gate-rank"></a>
## Installed 256-expert gate bank has full expert-index rank

Category: Strictly bad under the tested conditions. Evidence: A sampled 256-by-256 rational coefficient minor from decoded layer-0 Q4_K gates has determinant 42514 modulo 65521, certifying expert-axis rank 256. An exact global common linear bank needs 256 full gate maps, 32 times eight direct maps' products per token..

No smaller exact frozen full-bank linear gate basis exists for unrestricted inputs in this representation.

Comparison: Direct eight selected gate maps versus a global bank of shared full-width maps.

Boundary: The theorem concerns all gate preactivations, not route-specific nonlinear weighted sums, reachable producer inputs or learned lossy codes.

Next decision: Couple route selection, producer inputs and nonlinear downstream observation when designing a different representation.

Sources: [research/moe/full-axis-rank/README.md](../moe/full-axis-rank/README.md).

<a id="moe-installed-down-rank"></a>
## Installed Q5_K co-route duplicates still defeat exact dense output factors

Category: Strictly bad under the tested conditions. Evidence: An actual held layer-20 route's first four selected installed Q5_K down experts have full exact rank 2048 modulo 251; a dense exact eight-expert common factor therefore needs 1.5 times direct scalar products. On a contrasting actual layer-0 eight-expert route, 2006 of 4096 decoded columns are distinct and independent, giving rank 2006 and a 1.469238 ratio..

Layer-0 quantization collapses the installed route's output span by 42 dimensions, but a middle-layer co-route exhausts the 2048-dimensional space with only four experts. Neither route makes exact dense output factoring cheaper.

Comparison: Same eight selected installed GGUF experts, unrestricted independent hidden vectors and exact real linear factoring versus direct down projections.

Boundary: Two specific held layer/token routes, unrestricted independent hidden vectors; decoded FP32 rational coefficient rank is not the native FP32 accumulation map or a coupled-producer-domain bound. Repeated layer-0 columns alone do not save densely packed Q5 image bytes, and one-token producer zeros do not prove reachability across the model.

Next decision: Fit paid approximate packed codes on broad quantized producer routes across layers, then test frozen complete-model held language loss and native cost; do not retry exact dense bases on these installed routes.

Sources: [research/moe/installed-down-rank/README.md](../moe/installed-down-rank/README.md).

<a id="moe-seven-exp-router"></a>
## Normalize the Qwen top-eight router in seven logit coordinates

Category: Promising but not yet. Evidence: For finite real logits, eight selected IDs and seven differences recover exact normalized selected weights; their local Jacobian has rank seven and the native clamp is inactive because top-eight probability mass is at least 1/32. The construction removes 249 exponentials and a 256-way sum per row. On all 239 actual layer-0 producer routes, raw top-eight agrees with captured IDs and the alternative seven-exp FP32 weighted sum changes at most 5.59e-6 relative L2 on held..

A complete router-observation algebraic shortcut has a small local real-route numerical difference and deserves a fused full-model trial.

Comparison: Installed fused SOFT_MAX/top-k normalization with 256 exponentials, plus width-invariant unfused execution as a necessary future engine control.

Boundary: It is not FP32 bit-identical. A host rounded-softmax counterexample flips the eighth ID; no native fused replacement, model loss or measured latency exists.

Next decision: Implement an alternative fused raw-top-eight path and compare all-layer IDs, scores, near-tie decisions, held loss and prompt/decode time against both native controls.

Sources: [research/moe/router-observer/README.md](../moe/router-observer/README.md), [research/moe/router-observer/real-routes.md](../moe/router-observer/real-routes.md).

<a id="moe-router-exact-bit-dependence"></a>
## Omitted logits affect a declared rounded router grammar

Category: Strictly bad under the tested conditions. Evidence: Holding selected eight FP32 logits and IDs fixed while lowering 248 omitted logits changes normalized scores on 125 of 126 held rows in a declared host FP32 softmax grammar, with up to 1.85e-7 weighted-sum relative L2 difference..

The selected eight logits alone cannot reproduce that host grammar bit-for-bit over unrestricted logit vectors.

Comparison: Full 256-way NumPy FP32 exponential/probability normalization versus an eight-logit-only consumer on the witnessed pairs.

Boundary: Not a native HIP reduction replay, not proof that modified logits are reachable, and not a lower bound of 256 exponentials for every algorithm.

Next decision: Treat seven-exp native work as a measured alternative numerical map or retain enough omitted-logit information if installed FP32 bits are required.

Sources: [research/moe/router-observer/precision.md](../moe/router-observer/precision.md).

<a id="spec-rollout-state-training"></a>
## On-generation state training for the direct producer

Category: Promising but not yet. Evidence: Fine-tuning on a 1:1 mix including 5632 correlated rollout states gives 18-node online FP32 throughput 39.51 versus paired serial 30.25 tokens/s on eight prompts; adding one copy edge reaches 40.66. The old initial-prefix test actually slips from 2.5313 to 2.5000 coverage..

Training on histories the verifier visits improves the paid continued-generation panel without increasing online model size or products.

Comparison: Frozen original direct producer on the same eight prompts in a different panel, plus paired serial and identical retrieval graft.

Boundary: Separate panels, eight short prompts and the unchanged 4096-ID vocabulary; old static test and online trajectories disagree. No BF16-preserving native result.

Next decision: Compare on a larger independent mixed-domain continued-generation panel and tune candidate support, not only cross entropy.

Sources: [research/speculative-maps/rollout-producer/README.md](../speculative-maps/rollout-producer/README.md), [research/speculative-maps/online/COUPLED.md](../speculative-maps/online/COUPLED.md).

<a id="moe-route-omission"></a>
## Oracle bounds on dropping original routed contributions

Category: Strictly bad under the tested conditions. Evidence: At 1% local error no nonempty subset can be dropped on any of 239 train/held tokens. At 5%, a hindsight oracle over all 256 masks saves only 73 of 1008 held assignments, at most 1.686% conditional whole-model one-read bytes; a free norm triangle certificate in router order saves 40 tokens and .365 experts/token..

Neither score-ordered norm stopping nor clairvoyant unchanged-vector omission offers a large tight-tolerance opportunity.

Comparison: All eight captured layer-0 original weighted outputs; score-prefix and contribution-norm orders are controls, with exhaustive subset selection as the favorable oracle.

Boundary: One layer, FP64 recombination of callback captures and local relative error, not full-model language loss or native dispatch. Replacement vectors and downstream-insensitive observers are outside the bound.

Next decision: Fit a paid predictor for missing directions on independent routes if replacing rather than omitting contributions is worthwhile.

Sources: [research/moe/score-order/README.md](../moe/score-order/README.md), [research/moe/subset-oracle/README.md](../moe/subset-oracle/README.md).

<a id="moe-gateup-q3-asymmetry"></a>
## Paid asymmetric Q3_K gate/up recoding on actual routed sums

Category: Strictly bad under the tested conditions. Evidence: At equal one-bank paid 266338304-byte layer-0 gate/up images, Q3 gate/Q4 up loses .058834 held routed-sum RMS and Q4 gate/Q3 up loses .061111; both Q3 loses .084997. One-bank savings are only 1.697% conditional whole-model one-read bytes. Flattened gate/up error cosine is .00441 held and a free per-token choice reaches only .056765 RMS..

Neither unchanged static gate nor up recoding is nearly free; the two errors barely cancel, so asymmetric bank choice does not rescue direct Q3_K conversion.

Comparison: Pinned actual 113/126 routed layer-0 producers, decoded installed Q4_K gate/up/Q5_K down and the already paid native Q3_K image shards; compare both one-bank arms, both-bank arm and a free per-token oracle.

Boundary: CPU FP32/FP64 local layer-0 observation on limited text. No full-model language loss, GPU packed timing, original-BF16 fidelity or trained recode.

Next decision: Fit codes against the nonlinear weighted routed sum on broad producer data and freeze a complete-model held language-loss image; expert-specific allocation is an independent rate decision.

Sources: [research/moe/gateup-asymmetry/README.md](../moe/gateup-asymmetry/README.md).

<a id="moe-expert-mean-replacement"></a>
## Paid fixed expert-output prototype on actual routes

Category: Strictly bad under the tested conditions. Evidence: On 126 held layer-0 real producer tokens a train-only 1,048,608-byte FP16 prototype bank worsens lowest-score trained-expert replacement RMS from omission .088760 to .100251; a free hindsight best-prototype choice still loses .079126 and reaches 1% local error on only one token..

A fixed expert output mean overfits sparse per-expert observations and fails as a high-fidelity one-expert compute skip on this capture.

Comparison: Complete FP64 score-weighted eight-expert captured sum; omission of the same selected expert and hindsight prototype choice, with separate 113/126 train/held tokens.

Boundary: One layer, short callback captures and local Euclidean output; no input-dependent predictor, complete-model held loss, native FP32 identity or dispatch speed.

Next decision: Collect broader real producer inputs and fit a paid input-dependent missing-direction predictor, then freeze complete-model held language quality before native porting.

Sources: [research/moe/expert-mean-replacement/README.md](../moe/expert-mean-replacement/README.md).

<a id="moe-q3-group-allocation"></a>
## Paid fixed-shard Q3_K/Q4_K gate/up selection on actual routed sums

Category: Strictly bad under the tested conditions. Evidence: Exhaustive selection among eight 32-expert Q3_K/Q4_K gate/up shard images: at four Q3 shards train-selected held routed-sum RMS .055581 versus a held-choice oracle .050570, for conditional 1.696927% complete one-read byte saving. Even the best one-shard held oracle loses .023045 RMS..

Coarse static mixed-bank allocation of the straight recode cannot give a high-fidelity local route sum at useful whole-model byte savings.

Comparison: Decoded installed Q4_K complete eight-expert layer-0 sum with Q5_K down unchanged, 113 train and 126 held actual producer tokens; paid native-format Q3_K bank and exact held-choice subset control.

Boundary: Only eight 32-expert fixed shards of a direct recode, one layer and local CPU FP32/FP64 observation; not a bound on per-expert trained codes, full-model language loss or native time.

Next decision: Fit paid codes on broader quantized-producer routes and assess a complete forty-layer image against frozen held language loss before native format dispatch.

Sources: [research/moe/q3-group-allocation/README.md](../moe/q3-group-allocation/README.md).

<a id="moe-q3-expert-allocation"></a>
## Paid individual-expert Q3_K/Q4_K gate/up selection on actual routed sums

Category: Promising but not yet. Evidence: At 32 individual train-seen Q3_K expert images, layer-0 held complete routed-sum RMS is .009186 versus .024878 for one 32-expert shard at the same 293076992-byte gate/up bank rate. Conditional forty-layer complete one-read saving is .424232%; 64 experts lose .020940 for .848463%. The train capture sees 169/256 experts, held 188/256, with 35 held-only..

Expert-granular static allocation crosses a 1% held local routed-sum error threshold at a small paid logical byte saving, where the fixed-shard allocation failed.

Comparison: Same native-format frozen Q3_K recode and decoded installed Q4_K reference, actual layer-0 producers and scores; train-seen-only greedy allocation and held-seen greedy hindsight comparator.

Boundary: One layer, short texts, CPU FP32 products/FP64 sum and greedy rather than optimal subset search. Conditional bytes exclude mixed-format dispatch and physical traffic; no full-model language loss or native timing.

Next decision: Capture broader quantized producers across layers, train and freeze a paid complete mixed image, then test disjoint whole-model language loss before porting a native reader.

Sources: [research/moe/q3-expert-allocation/README.md](../moe/q3-expert-allocation/README.md).

<a id="moe-mixed-down-allocation"></a>
## Paid mixed Q4_K/Q5_K down allocation

Category: Strictly bad under the tested conditions. Evidence: Keeping 128 of 256 experts Q5_K gives .00887 held local routed-sum RMS for only .7985% conditional whole-model one-read saving. On the fixed-recode train capture, normalized cross-expert Gram eigenvalues lie in [-.091123,.089609], bounding independent ranking within 1.199 times optimal fixed-cardinality train squared error. Joint greedy and swap optimization give no held improvement at 32/64/128 kept Q5 experts; with 192, train error is zero but held RMS remains .00743 because 35 held experts were unseen on train..

Both independent and whole-routed-sum selection of these paid down recodes offer a weak rate/response tradeoff on the sparse actual-producer capture.

Comparison: Complete layer-0 down bank at paid native block sizes, from all-Q4 to installed all-Q5; train-frequency, held-hindsight, joint greedy and one-exchange rankings are controls.

Boundary: No mixed GGUF, native timing or complete-model language loss. The spectral bound is only for fixed recodes and captured producers, not every representation or input.

Next decision: Broader disjoint routes, gate/up-inclusive recoding, complete-model loss and native format timing before adopting any mixed image.

Sources: [research/moe/down-rate-allocation/README.md](../moe/down-rate-allocation/README.md), [research/moe/down-joint-allocation/README.md](../moe/down-joint-allocation/README.md), [research/moe/down-route-quant/README.md](../moe/down-route-quant/README.md).

<a id="moe-q3-residual-corrector"></a>
## Paid producer-conditioned correction of frozen Q3 routed errors

Category: Strictly bad under the tested conditions. Evidence: On 113/126 real layer-0 producer tokens, a train-LOO-selected rank-112 FP16 input-to-error factor (917504 bytes/layer) changes held routed-sum RMS .084997 to .083133; a free held-token projection onto its train-error basis still leaves .077126. Net forty-layer one-read saving falls from 3.394% to 1.996% before correction arithmetic..

A paid shared new output direction cannot repair the frozen Q3_K expert bank at this capture's size; the train-error subspace itself generalizes poorly.

Comparison: Native-format frozen Q3 gate/up plus Q5 down against decoded installed Q4 gate/up routed sum on actual inputs and scores; paid FP16 rank factors and free held projection control.

Boundary: One layer, short captures and local CPU output RMS. The projection bound fixes the train-error basis, not learned expert codes, broader producers, complete-model loss or native throughput.

Next decision: Fit new packed expert codes on broad quantized-producer routes and freeze a complete paid image for held language loss before porting another native reader.

Sources: [research/moe/q3-residual-corrector/README.md](../moe/q3-residual-corrector/README.md).

<a id="moe-rms-fibers"></a>
## Positive-epsilon post-MoE RMSNorm retains the complete vector

Category: Promising but not yet. Evidence: All forty installed next-RMSNorm gains are finite and nonzero, with positive epsilon. The complete ideal-real normalization has an explicit inverse on its image; on a bounded ball its radial lower modulus is positive but very small..

A positive-ray label is not an exact carrier for the complete next-normalized vector, even with fixed residual/shared addition.

Comparison: The epsilon-zero positive-ray quotient versus the installed positive-epsilon nonzero-gain complete-vector observation.

Boundary: Ideal real arithmetic and full-vector observation; not native rounded FP32 fibers, logits, an ISA cost bound or model quality.

Next decision: Capture actual post-add producer and select a paid changed representation by complete-model held language loss; price the direct packed consumer.

Sources: [research/moe/rms-observer/README.md](../moe/rms-observer/README.md).

<a id="spec-prefix-weight-root-conditioning"></a>
## Prefix-weighted and globally root-conditioned direct heads

Category: Strictly bad under the tested conditions. Evidence: Validation selects gentle position weighting and depth reward, raising six/eighteen-node coverage 2.4688/2.6563 to 2.6250/2.7188; on test it ties 2.4688 at six and falls to 2.5000 at eighteen. Adding 5120 root-conditioning weights fails to beat unchanged direct on validation..

These small fine-tunes overfit or fail to improve the frozen direct producer.

Comparison: Unchanged direct checkpoint, weighted-loss fine-tunes, reward-adjusted heap and zero-initialized root-conditioned model.

Boundary: 32-context validation/test fixture and no online verifier; a better root-dependent architecture or more diverse data is not excluded.

Next decision: Change the training-state distribution and evaluate longer continued paths before replacing the original model.

Sources: [research/speculative-maps/prefix-producer/README.md](../speculative-maps/prefix-producer/README.md).

<a id="spec-qwen-small-pilot"></a>
## Qwen3-0.6B target-generated paths and learned finite-map bridge

Category: Promising but not yet. Evidence: On 32 test contexts, the conditional six-position drafter covers 1.8438 tokens including bonus as a chain and 2.1875 with 64 proposal nodes, versus 1.6875 for the independent chain. The top-16 pool oracle is 2.4063; packed map serial and balanced prefix paths agree on 1024 random streams across real contexts..

A real-target proposal feeds exact finite transition-map composition, but missing candidate support limits further branching.

Comparison: Independent trunk-matched drafter, six-node chain, 6/18/32/64-node proposal trees and static top-16 pool oracle.

Boundary: Greedy prefix membership rather than timed tree verification or adopted KV; 2048-token shortlist covers only 69.53% of held validation labels and borrowed target rows cost about 8 MiB.

Next decision: Train on target continuations and repair candidate support while pricing head traffic, verifier state and native map construction.

Sources: [research/speculative-maps/qwen/README.md](../speculative-maps/qwen/README.md).

<a id="spec-large-target-copy-tree"></a>
## Qwen3-1.7B copy-tree decoding across frozen public continuations

Category: Promising but not yet. Evidence: On 24 preregistered public code, WikiText prose and JSON-style prompts at 256–2048 context tokens, a target-independent eighteen-node copy tree gives 18.43 versus 11.06 serial decode tokens/s, 1.666 times throughput; including prefill gives 11.84 versus 8.33, 1.422 times. All 1536 emitted IDs and 24 final next decisions match FP32 serial; a reverse-order repeat of the power-limited first stage gives 1.678 times decoding versus 1.672 originally..

A complete paid PyTorch verifier and KV-adoption loop scales the copy proposal to a larger target and all three fixed workload families.

Comparison: Paired one-token serial Qwen3-1.7B FP32 across the same 24 cases; twelve Qwen3-0.6B controls show frozen learned tree alone at .971 times and learned-plus-copy at 1.258 times.

Boundary: Not compared against named speculative state of the art or a tuned native engine; no quality-of-answer improvement, long task-quality run or BF16 numerical equivalence. Gains decline to 1.528 times decoding at 2048 context tokens.

Next decision: Port the verifier to a production-precision target with shape-consistent numerical behavior, then measure longer independent task-quality workloads.

Sources: [research/speculative-maps/realistic-runtime/README.md](../speculative-maps/realistic-runtime/README.md), [research/speculative-maps/realistic-runtime/PLAN.md](../speculative-maps/realistic-runtime/PLAN.md), [research/speculative-maps/realistic-workload/README.md](../speculative-maps/realistic-workload/README.md).

<a id="spec-target-anchor-and-residual-draft"></a>
## Retained target first token and residual drafting

Category: Promising but not yet. Evidence: On the original 32 test contexts, passing the already-computed target first token lifts a 64-node baseline from 2.1875 to 2.5625 covered tokens including bonus. Training a 4096-row residual drafter on 2048 target-generated continuations reaches 2.6250 with 64 static-tree nodes, against 2.5625 for the unchanged first-token graft..

Reusing a paid exact first decision and training the following positions on target-generated data improves this local proposal-quality diagnostic.

Comparison: Frozen original Qwen conditional checkpoint/tree, first-token graft, 4096/8192-row residual heads, fixed 6/18/32/64 candidate budgets.

Boundary: The root is free only after a real target pass retains it; reconstructing from hidden reads about 311 MB of BF16 full-head weights. Prefix membership is not throughput or state adoption; static top-16 still misses 90 of 160 residual labels on test.

Next decision: Use the paid target handoff in continued decoding and train a small candidate pool on independent on-generation histories.

Sources: [research/speculative-maps/candidate-repair/README.md](../speculative-maps/candidate-repair/README.md), [research/speculative-maps/residual-drafter/README.md](../speculative-maps/residual-drafter/README.md).

<a id="moe-down-scalar-gains"></a>
## Route-fitted scalar gain corrections for Q5_K down

Category: Strictly bad under the tested conditions. Evidence: A joint 16-gain least-squares fit changes train RMS .03032640 to .03032353 but raises synthetic held RMS .02993071 to .02993398; paid FP16 rounding raises it to .02993487..

The tested frozen expert-gain correction cannot usefully repair actual Q5_K down quantization on synthetic routes.

Comparison: Decoded Q5_K without gain, independent gain fits, joint whole-route optimum and rounded FP16 paid gains, against original BF16 down outputs.

Boundary: First sixteen experts and synthetic inputs/routes; actual producer scores, full-model loss and native reader not tested.

Next decision: Use real routed hiddens and compare equal-byte expert-aware recoding or output-aware codes instead of scalar adjustments.

Sources: [research/moe/routed-down-gains/README.md](../moe/routed-down-gains/README.md).

<a id="moe-route-conditioned-down-rank"></a>
## Route-specific down-output bases on sixteen original experts

Category: Strictly bad under the tested conditions. Evidence: Separate optimal rank-512 bases on three synthetic eight-expert routes lose .582–.606 isotropic relative RMS; rank 1024 loses .310–.342 at 75% of direct down MACs before selection. Storing rank-512 bases for all 12,870 routes among sixteen experts takes 26.99 GB BF16 before factors..

The tested free route oracle cannot make frozen output factors accurate or cheap on the isotropic objective.

Comparison: Direct original BF16 down maps and one shared all-sixteen basis, with the optimal per-route orthogonal projection as a favorable control.

Boundary: Three constructed equal-score routes, not actual producer hidden covariance or router-score concentration; compressed basis generators were not tested.

Next decision: Measure actual routed hidden/score covariance and complete-model loss rather than materialize an exhaustive route catalogue.

Sources: [research/moe/route-rank/README.md](../moe/route-rank/README.md).

<a id="moe-router-partial-dot"></a>
## Router top-eight partial-dot Cauchy–Schwarz certificates

Category: Strictly bad under the tested conditions. Evidence: The fixed weight-energy order certifies held routes only after 2028.59 of 2048 input columns on average; none certify by 1920. Even an uncharged input-dependent order saves at most a conditional .231% of modeled whole-model one-read weight bytes if layer 0 generalizes to forty layers..

The tested shared prefix plus norm-envelope certificate does not spare meaningful router traffic.

Comparison: Full F32 router dot and top-eight; stored order, static energy order, free input-energy order and an omitted-product-reading absolute-tail oracle.

Boundary: Layer-0 capture and mathematical real-dot certificate, not native FP32 or a bound on a tighter data structure.

Next decision: Prioritize seven-exp normalization or large expert/head traffic rather than this router-weight prefix family.

Sources: [research/moe/router-observer/partial-certificate.md](../moe/router-observer/partial-certificate.md).

<a id="moe-score-observation-rank"></a>
## Seven score dimensions survive the actual complete routed sum

Category: Promising but not yet. Evidence: On all 5,120 actual layer/token captures, a nonzero 7×7 integer minor modulo 251 of the eight FP32 down-output differences certifies rank seven of the complete score-weighted sum. The first seven output coordinates witness 5,092 cases; each of the other 28 has another seven-coordinate witness..

Seven selected-logit differences are dimension-minimal even for the observed complete output, not only the eight intermediate scores, within a smooth score-only carrier grammar.

Comparison: Eight captured down vectors and seven independent positive normalized selected scores at fixed route, against a hypothetical narrower smooth score-only coordinate.

Boundary: Exact real affine observation of fixed captured FP32 outputs; not a native FP32 reduction identity, bound on exponentials or packed labels, model loss or inference time.

Next decision: Spend native effort on unprofiled Q8/expert physical-time diagnosis, not fewer score dimensions; any changed paid joint carrier needs broad producer data and held whole-model loss.

Sources: [research/moe/score-observation-rank/README.md](../moe/score-observation-rank/README.md).

<a id="moe-common-activation-clips"></a>
## Shared gate/up activation clipping on synthetic and real routes

Category: Strictly bad under the tested conditions. Evidence: On synthetic BF16 routes, train-selected Q4 clip improves held composed RMS .20237 to .15841 but a free four-clip per-token oracle reaches only .15083, versus Q8 .01141. On actual Q4_K/Q5_K routes, group-32 Q4 max loses .09349 held RMS versus matched Q8 .00543; even a free choice of two Q4 clips picks max on every held token..

The tested shared scalar-clip selectors and Q4 input-buffer saving do not warrant a native change.

Comparison: Uncoded weighted routed output; shared Q4 max/static/per-token clip controls and matched Q8 code, including all 256 selected GGUF experts for real routes.

Boundary: Synthetic BF16 and one-layer real-route CPU maps differ from native Q8_1 and FP32 execution. Q4 saves at most .00156% of modeled whole-model one-read weight bytes if only the shared buffer changes; packed dot work is unmeasured.

Next decision: Jointly train weight and input labels with a direct packed gate/up consumer, then evaluate held language loss and native traffic.

Sources: [research/moe/shared-activation/README.md](../moe/shared-activation/README.md), [research/moe/real-gate-input/README.md](../moe/real-gate-input/README.md).

<a id="moe-shared-gate-input-rank"></a>
## Shared gate/up input factors and paired-route exact rank

Category: Strictly bad under the tested conditions. Evidence: The optimal common rank-512 input basis retains 53.48% isotropic preactivation energy across sixteen original experts; rank 1397 is needed for 90%. A co-routed BF16 pair has exact real rank 2043 and three original experts on a held GGUF route reach 2048. The installed Q4_K image reaches exact rank 2048 from five co-routed experts on a held layer-0 route. Across all forty layers' held token-1 routes, the first two experts already reach full rank in 37 layers; layer 0/1/3 have exact ranks 1022/1996/1808, with every deficiency an exactly zero row and every nonzero row independent modulo 251. An exact dense eight-consumer factor costs at least 1.25 times un-compacted direct scalar products on every full-rank route..

The tested weight-only narrow common input coordinate has poor energy retention; actual-route witnesses exclude a narrow exact shared linear preactivation coordinate, and two installed co-routed experts already saturate the input in 37 of forty layers.

Comparison: Direct original BF16 gate/up products and the Eckart–Young-optimal common factor; train-captured co-route IDs identify the exact pair.

Boundary: The spectral experiment uses isotropic unweighted preactivations; exact rank applies to exposing gate/up preactivations on unrestricted inputs. Original BF16 and installed GGUF are different maps and may route differently; layer-0 zero rows do not generalize across forty layers. Packed full-width codes, finite FP32 bit identity and direct nonlinear whole-sum observers remain open.

Next decision: Test jointly coded actual quantized-producer activations and expert weights against routed sums, held full-model loss and actual packed-consumer cost.

Sources: [research/moe/shared-gate-input/README.md](../moe/shared-gate-input/README.md), [research/moe/paired-gate-rank/README.md](../moe/paired-gate-rank/README.md), [research/moe/route-input-rank/README.md](../moe/route-input-rank/README.md), [research/moe/installed-input-rank/README.md](../moe/installed-input-rank/README.md), [research/moe/installed-gateup-rank/README.md](../moe/installed-gateup-rank/README.md).

<a id="moe-actual-input-pca"></a>
## Short-capture PCA shared input bottleneck

Category: Strictly bad under the tested conditions. Evidence: A rank-113 train-input span loses .854 held routed-sum RMS. A rank-160 basis including 63 calibration tokens still loses .788 on the independent final 63; fitting the evaluated held inputs themselves deceptively yields .042 at rank 112..

The tested uncentered PCA coordinate overfits tiny actual-route captures and fails to transfer through gate/up, SwiGLU and down.

Comparison: Decoded installed 256-expert GGUF and its unprojected actual-route sum; transductive held fit is identified as an unavailable oracle.

Boundary: Only layer 0 and limited captures; no claim about broader-data trained codes, packed full-width maps or downstream model loss.

Next decision: Capture much more disjoint producer text before fitting a shared bottleneck, then charge the complete image and native boundary.

Sources: [research/moe/input-subspace/README.md](../moe/input-subspace/README.md).

<a id="moe-down-recoding-local"></a>
## Train-weighted Q4_K down recoding at native format rate

Category: Promising but not yet. Evidence: Against decoded installed Q5_K on 126 held actual-route tokens, plain Q4_K down recoding loses .04901 routed-sum RMS and train-weighted Q4_K loses .04611 at the same 589824 bytes per expert. The weighted image improves 99 held token errors..

A small local same-rate recoding gain exists, but it is not enough to choose a model image.

Comparison: GGML reference Q4_K versus train-only coordinate-weighted Q4_K; decoded installed Q5_K is the output reference.

Boundary: Only down at layer 0; full forty-layer one-read stream savings are a conditional 1.597%, not native latency. Offline Q5 reconstruction itself differs from native captured outputs and no full image or model loss exists.

Next decision: Jointly recode gate/up and down with broader expert activations, full-image held loss and native Q4/Q5 timing.

Sources: [research/moe/down-route-quant/README.md](../moe/down-route-quant/README.md).

<a id="spec-candidate-pool-widening"></a>
## Widening the same learned candidate ranking

Category: Strictly bad under the tested conditions. Evidence: On 32 previously inspected Qwen test contexts, static top-16, top-64 and top-256 pools yield exactly the same 2.1875-token coverage at 64 nodes, despite top-256 raising the pool oracle ceiling from 2.4063 to 3.4063. Corrected rows rise from 33.4 to 41.8 per context..

More suffix support from the same ranking is too low-scored to enter the useful tree at the tested budgets; six root misses remain.

Comparison: Frozen corrected/static top-16 tree, wider static pools, predecessor-ranked pools and independent head at equal verified-node budgets.

Boundary: Untimed existing 32-context prefix fixture with hypothetical cost curves; different trained ranking or root handoff is not rejected.

Next decision: Retrieve genuinely missing candidates and train a survival-aware score on independent contexts, then measure paid verifier throughput.

Sources: [research/speculative-maps/action-value/README.md](../speculative-maps/action-value/README.md).
