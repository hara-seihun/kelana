# Model conversion and quantization representations

[Research desk](README.md)

Generated from `conversion.json`; the JSON owns classifications.

<a id="conversion-representation-discovery"></a>
## Alternatives to separate scalar codes and scales

Category: Promising but not yet. Evidence: The representation programme links joint operands, vector codes, direct operator codes, additive templates, response dictionaries and entropy/execution studies. Each measured construction is classified separately here..

Choose the stored object and its consumer together rather than assuming a scalar grid with a separate scale is optimal.

Comparison: The studies charge metadata, input preparation, shared consumers and native decoding where implemented. Local wins face fitted scalar controls and complete-model acceptance rather than a common weak rounding baseline.

Boundary: This is the programme and existing-work map, not evidence that one replacement format dominates scalar quantization. Most tested complete-model replacements lost.

Next decision: Use the per-study decisions to select a different representation only where actual model structure supports it, then compare equal paid bytes and end-to-end quality or execution.

Sources: [research/quantization-discovery/representations/README.md](../quantization-discovery/representations/README.md), [research/quantization-discovery/representations/BRIEF.md](../quantization-discovery/representations/BRIEF.md), [research/quantization-discovery/representations/MAP.md](../quantization-discovery/representations/MAP.md), [research/quantization-discovery/representations/SYNTHESIS.md](../quantization-discovery/representations/SYNTHESIS.md).

<a id="conversion-ternary-code-updates"></a>
## Broad and sparse trit updates against scale-only recovery

Category: Strictly bad under the tested conditions. Evidence: Matched 128-step joint code/scale training scores 5.3850 test NLL versus 4.8423 for scales alone; a train-accepted 256-trit update changes 4.6464 to 4.6453 test but worsens validation 4.7331 to 4.7405. Earlier 1,792 layer-0 trit transfers worsen test 5.4286 to 5.4564. On fresh unused train rows, eight matched whole-model steps from the latest image change 448 layer-14 trits and improve train NLL by .005037 beyond scales, but worsen newly frozen selection 4.574458 to 4.576849 and withheld complete-model NLL 4.768560 to 4.770172 (paired .001612 +/- .001404 nats). Fully decoded code/scale pages cost 122,975,935 coupled versus 122,975,948 scale-only bytes..

Neither broad STE changes nor the tested sparse first-order proposals justify replacing the scale-only image.

Comparison: The newest complete raw images all cost 1.727086 BPW; at the independently checked physical 1.650545-BPW rate the coupled arm saves 13 bytes versus the matched scale arm but loses held language quality.

Boundary: Negative for these optimization schedules and proposal families, not for all code learning. The later test panel had appeared in earlier rounds.

Next decision: A train-favorable first-order 448-trit update loses on both newly frozen selection and held text. Try multi-step composition-aware nominations with matched scales and select on complete-model loss before another held panel.

Sources: [research/ternary/expanded-training.md](../ternary/expanded-training.md), [research/ternary/joint-codes.md](../ternary/joint-codes.md), [research/ternary/coupled-fresh/README.md](../ternary/coupled-fresh/README.md), [research/ternary/coupled-fresh/run.py](../ternary/coupled-fresh/run.py).

<a id="conversion-calibrated-affine-q4"></a>
## Calibrated affine four-bit Qwen conversion

Category: Promising but not yet. Evidence: Sequential full-covariance compensation and affine group grids yield 3.795795 test NLL, 44.514 perplexity, at 316,749,352 payload bytes or 4.251313 BPW..

The apparent four-bit quality gap was largely a weak-converter problem; this is the stronger internal scalar baseline.

Comparison: BF16 scores 3.639218; simple symmetric rounding 4.451341; same-format affine rounding with the exact shared head 3.980601. Published stock Q4_K_M scores a better 3.709265 but uses 478,268,416 tensor bytes.

Boundary: This BF16 HF panel is not native runtime evidence. Native Q4_1 execution and its larger physical file are measured in a separate entry. The change from old symmetric rounding also changes both format and grid fitting.

Next decision: Compare new low-rate conversions against this image, with actual physical bytes and held complete-model NLL.

Sources: [research/quantization-discovery/q4-diagnostic/README.md](../quantization-discovery/q4-diagnostic/README.md), [research/quantization-discovery/q4-diagnostic/METHOD.md](../quantization-discovery/q4-diagnostic/METHOD.md), [research/quantization-discovery/q4-diagnostic/results.json](../quantization-discovery/q4-diagnostic/results.json).

<a id="conversion-observed-logit-state"></a>
## Code a state for present and future softmax observations

Category: Promising but not yet. Evidence: On the exact four-state population, a three-label affine-threshold code reduces weighted two-step excess NLL .150685 to .075342 versus a pointwise softmax code; raw-logit-MSE fitting gets .114735..

A common logit shift is invisible now but can become observable after a continuation; the code preserves the distinction with one trit.

Comparison: Same three-label rate and twelve-byte decoder tables for all trit arms. Four labels recover both steps exactly at higher rate.

Boundary: Finite analytic state population, not a ternary weight image or measured speed.

Next decision: Find live downstream consumers before merging states, then price encoding and table reads on a real captured continuation.

Sources: [research/ternary-toys/observed-logits/README.md](../ternary-toys/observed-logits/README.md), [research/ternary-toys/observed-logits/results.json](../ternary-toys/observed-logits/results.json).

<a id="conversion-ternary-recovery"></a>
## Complete packed ternary Qwen recovery

Category: Promising but not yet. Evidence: Qwen3-0.6B, 197 packed matrices: sixteen further independent-train whole-model scale updates after fresh-scale8 improve a newly frozen eight-window held test from 4.343739 to 4.330215 NLL (paired .013524 +/- .002129 nats, 8/8 wins). Sixteen additional steps on new train rows improve a separate newly frozen held panel from 4.502883 to 4.498337 (paired .004546 +/- .002020 nats, 6/8 wins). Complete raw rate is 1.727086 BPW throughout. The latter paid complete image costs 125,953,725 bytes / 1.690512432 BPW, 192 bytes more than its independently encoded predecessor. Both reconstruct all 4,656,128 scale words bitwise. Independent 16-KiB compressed code pages preserve every trit and lower the latest physical image to 122,975,884 bytes / 1.650544760 BPW. Sharing the checked signed-Hadamard vector as one 384-byte transformer prefix plus 128 distinct tied-head bytes lowers the exact complete image to 122,940,428 bytes / 1.650068880 BPW, with unchanged decoded 4.498337 held NLL. A complete 119,196,989-code-byte census bounds any static per-matrix IID arithmetic-coding improvement beyond the existing paid zlib pages to 766,263 bytes / .010285 complete BPW even with free models; more expressive context or changed codes remain open..

Independent-text gold-loss training improves held quality, while exact page-addressed code compression saves 2,977,841 additional complete-image bytes. A complete native C++/zlib cold-consumer panel takes 303.819 ms to inflate/observe all 7,360 pages against 15.457 ms for raw codes, with matching CRC; observing one shuffled code per page costs 293.488 vs 0.285 ms. Python overhead did not explain the previous negative. The lower paid storage rate is not a hot-reader gain or GPU inference result.

Comparison: BF16 scores 3.639218; the original simple four-bit control scores 4.451341, and calibrated four-bit scores 3.795795 at 4.25131 BPW.

Boundary: Still far from BF16 or Bonsai-like retention. The measured native host-CPU/zlib boundary omits trit arithmetic, device transfer and native GPU decode; quality evaluation expands the bit-identical decoded image to BF16.

Next decision: A fresh matched bounded code/scale update now loses to scale-only complete-model quality at nearly equal paid rate; nominate a composed multi-step code change rather than extending first-order train-favorable flips. Transfer MoE ideas only through real routed producers and a paid full-model image.

Sources: [research/ternary/README.md](../ternary/README.md), [research/ternary/shared-rotation/README.md](../ternary/shared-rotation/README.md), [research/ternary/code-pages/README.md](../ternary/code-pages/README.md), [research/ternary/code-pages/ENTROPY.md](../ternary/code-pages/ENTROPY.md), [research/ternary/code-pages/CONSUMER.md](../ternary/code-pages/CONSUMER.md), [research/ternary/code-pages/NATIVE.md](../ternary/code-pages/NATIVE.md), [research/ternary/fresh-duration32/README.md](../ternary/fresh-duration32/README.md), [research/ternary/fresh-duration/README.md](../ternary/fresh-duration/README.md), [research/ternary/fresh-duration/paid-rate.md](../ternary/fresh-duration/paid-rate.md), [research/ternary/fresh-recovery/README.md](../ternary/fresh-recovery/README.md), [research/ternary/scale-extrapolation/README.md](../ternary/scale-extrapolation/README.md), [research/ternary/exact-rate/README.md](../ternary/exact-rate/README.md), [research/ternary/exact-rate/bitplane.md](../ternary/exact-rate/bitplane.md), [research/ternary/expanded-training.md](../ternary/expanded-training.md), [research/ternary/results.json](../ternary/results.json).

<a id="conversion-composed-error-modes"></a>
## Coupled code and scale release a conserved mode

Category: Promising but not yet. Evidence: A train-selected two-block gated witness changes held composed MSE .46674 to .09171 through one downstream trit and one upstream scale; a sum-invariant proves a .44574 held floor for the original codes under any scales..

Locally selected codes can suppress an output direction that no scale refit can recover.

Comparison: Downstream trit alone gets .36586 held MSE; upstream scale alone gets 1.01241. The paid paired image changes no format bytes.

Boundary: Constructed two-dimensional teacher chosen by a train-only search, not an average real-model benefit.

Next decision: Look for suppressed directions in adjacent real residual blocks and accept any coupled repair by held gold loss.

Sources: [research/ternary-toys/composed-error/README.md](../ternary-toys/composed-error/README.md), [research/ternary-toys/composed-error/results.json](../ternary-toys/composed-error/results.json).

<a id="conversion-joint-bilinear-operator"></a>
## Encode the complete quadratic operator rather than three matrices

Category: Promising but not yet. Evidence: For eight unplanted 3-input bilinear gated teachers, a 32-byte direct int8 operator has .0037 median held relative RMS against .1929 for 166-byte scalar q4..

The 32-hidden bilinear map contracts algebraically to 24 quadratic coefficients without reconstructing hidden projections.

Comparison: Scalar q4 uses over five times the bytes. The numerical win applies to exact bilinear gates, not SiLU.

Boundary: No native packed reader timing; Qwen uses SiLU and has not been tested by this operator image.

Next decision: Test a direct consumer on real quantized-producer inputs with nonlinear boundary and matched scalar rate.

Sources: [research/quantization-discovery/representations/joint-operators/README.md](../quantization-discovery/representations/joint-operators/README.md), [research/quantization-discovery/representations/joint-operators/results.json](../quantization-discovery/representations/joint-operators/results.json).

<a id="conversion-packed-continuation"></a>
## Exact byte-state continuation across native residual maps

Category: Promising but not yet. Evidence: For 27 reachable states and eight shared conditional stages, AVX-512 staged lookups take 3.796 ns per 64 streams versus 14.326 for compiled ternary SIMD. Full route fusion takes 1.711 ns with 16 KiB of tables..

The packed output label can feed the next map without intermediate trit decoding, though complete fusion wins while the state and route sets fit cache.

Comparison: All methods have the same byte-label endpoints and exact map; fused lookup spends 32 times the staged table bytes.

Boundary: Register-resident toy with shared routes and prepaid input encoding; neither model quality nor full inference throughput measured.

Next decision: Increase reachable state and route diversity on a real region, accounting for producer encoding and preparation.

Sources: [research/ternary-toys/packed-realization/README.md](../ternary-toys/packed-realization/README.md), [research/ternary-toys/packed-realization/results.json](../ternary-toys/packed-realization/results.json).

<a id="conversion-affine-q4-native-gguf"></a>
## Exact calibrated Qwen3-0.6B affine image in native llama.cpp

Category: Better than SOTA on something. Evidence: Each of 197 saved group-128 affine images decodes exactly from an executable Q4_1 GGUF. On Radeon 8060S/upstream HIP over all 584 wikitext-2 test chunks, this 378,704,000-byte file reaches 25.4210 perplexity versus stock IQ3_M 26.4931/402,878,880 bytes and Q3_K_M 25.7607/413,979,040 bytes. An equally tied source-BF16 pure-Q4_1 control at exactly 378,704,000 bytes scores 27.5713, attributing 2.1503 perplexity to Kelana calibration. Fixed-prompt S1 runs 263.0 generated tok/s versus stock IQ3_M 247.6 and Q3_K_M 243.2; fixed distinct-prompt greedy S4 at eight streams reaches 1211 aggregate tok/s versus 1128/1053..

The exact executable Kelana image wins both bytes and native perplexity versus named published stock formats; its observed decode speed is also higher on this model/device/workload.

Comparison: The source research payload is 316,749,352 bytes; native Q4_1 tensor payload costs 372,752,384 bytes because scale and origin repeat four times. A secondary lossy pure-Q3_K requant loses to the matched BF16-source Q3_K control with Bartowski's pinned imatrix: 42.6399 versus 31.8092 perplexity at equal 262,300,800 bytes.

Boundary: This is a Qwen3-0.6B/Radeon 8060S result versus named formats, not a universal speed or quality record. Stock Q4_K_M gets lower perplexity at a much larger file. Shared-host power/clock varied; coordinator's quiet sweep owns headline speed. Ternary images have no native compressed reader.

Next decision: Price an exact 128-value native affine block to eliminate 56,003,032 bytes of repeated scales/origins; investigate why Q3_K requant of Kelana loses its matched BF16-source control.

Sources: [research/quantization-discovery/q4-diagnostic/EXECUTABLE.md](../quantization-discovery/q4-diagnostic/EXECUTABLE.md), [research/quantization-discovery/q4-diagnostic/README.md](../quantization-discovery/q4-diagnostic/README.md), [research/quantization-discovery/q4-diagnostic/export_gguf.py](../quantization-discovery/q4-diagnostic/export_gguf.py).

<a id="conversion-paged-scales-capacity"></a>
## Exact page-local FP16 scale deltas

Category: Promising but not yet. Evidence: A real 5,120-by-128 ternary Bonsai block shrinks from 143,360 to 139,948 bytes without changing a trit or FP16 scale bit..

Page-local deltas save 2.38% model capacity while retaining direct row addressability.

Comparison: A 64-row page includes offset and header bytes; lossless source/control consumers produce matching outputs.

Boundary: The directly decoded hot reader is slower, so this is a capacity or cold-storage result, not a native execution win.

Next decision: Price expansion once into raw hot scales against routed reuse and cache residency.

Sources: [research/quantization-discovery/representations/entropy-execution/README.md](../quantization-discovery/representations/entropy-execution/README.md), [research/quantization-discovery/representations/entropy-execution/results.json](../quantization-discovery/representations/entropy-execution/results.json).

<a id="conversion-discrete-pair-barriers"></a>
## Exact paired trit search crosses single-edit barriers

Category: Promising but not yet. Evidence: Across 40 gated teachers, radius-two descent lowers mean held NLL .553739 to .551065 versus exhaustive one-flip descent; 14 single-edit minima have beneficial pairs across positive barriers..

The choice of discrete neighborhood matters even with an exact composed-loss objective.

Comparison: Pair search scores about 330 candidates on average against 40 for singles and 6,561 for the full eight-trit oracle.

Boundary: Tiny eight-trit toy with fixed scales. Real Qwen single-group paired repair did not transfer its proposal gain.

Next decision: Nominate a small number of interacting real edits and check paired gold loss on independent train text.

Sources: [research/ternary-toys/discrete-geometry/README.md](../ternary-toys/discrete-geometry/README.md), [research/ternary-toys/discrete-geometry/results.json](../ternary-toys/discrete-geometry/results.json), [research/ternary/paired-repair/README.md](../ternary/paired-repair/README.md).

<a id="conversion-routed-sum-fit"></a>
## Fit the routed sum on quantized-producer routes

Category: Promising but not yet. Evidence: Across 12 held input panels, joint fitting under quantized routes gets .09284 mean MSE against .15439 under original routes and .16861 for independent experts..

The output code should compensate route changes made by its actual upstream producer, rather than optimize each expert alone.

Comparison: All arms use the same nine trits and exhaustive candidate book; the conditional fit wins every seed against the fixed-route joint fit.

Boundary: Only three top-two experts and partial expert quantization, not a full Qwen MoE image or language-loss result.

Next decision: Capture real quantized routes and compare jointly chosen expert edits against fixed-route and independent controls at equal bytes.

Sources: [research/ternary-toys/routed-sums/README.md](../ternary-toys/routed-sums/README.md), [research/ternary-toys/routed-sums/results.json](../ternary-toys/routed-sums/results.json).

<a id="conversion-folded-scalar-scale"></a>
## Fold redundant sign gain into the stored FP16 row scale

Category: Promising but not yet. Evidence: On the same Bonsai block, combining two separately stored scales saves 10,240 bytes, from 102,400 to 92,160, while held response RMS remains about .528731..

A consumer that never observes the original source scale separately does not need both FP16 scale fields.

Comparison: The folded result is stronger than the tested K16/K64 dictionaries in held response, though it spends more bytes.

Boundary: One consumer and block; another live reader needing the original scale would invalidate this fold.

Next decision: Identify all live consumers, then eliminate duplicate scale information at their common stored boundary.

Sources: [research/quantization-discovery/representations/response-dictionaries/README.md](../quantization-discovery/representations/response-dictionaries/README.md).

<a id="conversion-vector-full-same-rate"></a>
## Full-channel low-rate paired codes

Category: Strictly bad under the tested conditions. Evidence: At 88 bytes below the selected ternary MLP's 2,035,570-byte image, mixed three/four-bit pair codes worsen held response in all three tested layers. Three-bit layer-0 replacement scores 4.792683 test NLL versus selected ternary 4.646432..

The positive tiny slice does not survive a full-channel rate-matched substitution.

Comparison: Both use the selected ternary down and actual quantized-producer inputs; stronger scalar four-bit and learned pair controls are included.

Boundary: Negative for these weight-fitted codes and layer substitutions, not all paired formats or response-aware search.

Next decision: Test a code only if it improves held whole-model loss against the selected image at the paid byte rate.

Sources: [research/quantization-discovery/representations/vector-full/QUALITY.md](../quantization-discovery/representations/vector-full/QUALITY.md), [research/quantization-discovery/representations/vector-full/README.md](../quantization-discovery/representations/vector-full/README.md).

<a id="conversion-mixed-scale-recovery"></a>
## Gold-loss co-adaptation of a paid mixed ternary/Q4 image

Category: Promising but not yet. Evidence: At 2.170288 BPW, fixed symmetric-Q4 layers 14–20 plus eight complete-model updates score 4.711406 exploratory validation and 4.604734 previously inspected test NLL against matched all-ternary 4.725857 and 4.648968 at 1.727086 BPW. Frozen-image replay on untouched validation windows 8–15 reverses the sign: 5.289023 versus 5.262661, +.026362 ± .044097 paired nats (mixed minus ternary)..

Co-adaptation reverses a frozen mixed-splice penalty on the first panel, but the paid quality advantage does not transfer reliably to fresh validation.

Comparison: The mixed image pays 33,021,352 extra bytes for .044234 test nats on 32 previously reported windows; combined 16-window validation is +.005955 ± .023448 nats. The calibrated layer-17 splice costs 4,963,040 extra bytes and scores −.011877 ± .008433 on the same fresh half. Calibrated all-four-bit scores 3.7958 test NLL at 4.2513 BPW.

Boundary: The fresh mean is sensitive to one .305640-nat losing window. The Q4 block is the weaker symmetric converter, the test has been inspected before, and quality used BF16 expansion; no compressed native timing. Neither paid image is selected for serving.

Next decision: Select smaller calibrated four-bit substitutions on new train/validation text, fit remaining ternary scales, then assess untouched complete-model loss before pricing a mixed reader.

Sources: [research/ternary/mixed-recovery.md](../ternary/mixed-recovery.md), [research/ternary/README.md](../ternary/README.md).

<a id="conversion-mixed-layer-rate"></a>
## Independently converted four-bit regions in a ternary model

Category: Strictly bad under the tested conditions. Evidence: All four seven-layer substitutions worsen eight-window validation at 2.170288 BPW; the best improves test NLL just .000578 for 33,021,352 additional bytes. Two-region substitutions at 2.613491 BPW score 4.836586 and 4.908159 validation against 4.733112 ternary..

Simply splicing independently fitted four-bit regions into scale-trained ternary layers fails even when adjacent regions change together.

Comparison: The complete simple four-bit model does beat the complete ternary image, so its advantage cannot be allocated by adding these isolated substitutions.

Boundary: The independently converted frozen splice loses; matched retraining of retained ternary scales reverses the penalty for one region, recorded separately.

Next decision: Use the co-adapted result as a control before rejecting a new mixed-rate allocation; do not promote the frozen splice.

Sources: [research/ternary/layer-rate.md](../ternary/layer-rate.md), [research/ternary/mixed-interaction.md](../ternary/mixed-interaction.md), [research/ternary/mixed-recovery.md](../ternary/mixed-recovery.md).

<a id="conversion-tied-gauge"></a>
## Joint tied embedding and head coordinate choice

Category: Promising but not yet. Evidence: A six-token tied model has zero full-probability KL in an 18-byte ternary gauge; separately fitted embedding rows retain .080733 KL even when the body receives unrestricted real coefficients..

Two anchor logit columns identify a coordinate system that the tied encoder and observer can both use.

Comparison: An independently fitted ternary body gives .212883 KL at the same 18 bytes; the real-body control has a provable centered-column-space obstruction.

Boundary: Constructed teacher with known anchors, not evidence for a Qwen-wide cheap gauge.

Next decision: Measure tied logit-kernel rank and consumer compatibility before searching a paid shared basis in a real model.

Sources: [research/ternary-toys/tied-consumers/README.md](../ternary-toys/tied-consumers/README.md), [research/ternary-toys/tied-consumers/results.json](../ternary-toys/tied-consumers/results.json).

<a id="conversion-ternary-latest-extrapolation"></a>
## Latest complete ternary scale-update direction at fixed 1.5×

Category: Strictly bad under the tested conditions. Evidence: A frozen Qwen3-0.6B complete 197-matrix 1.5× extrapolation of fresh-duration16 to fresh-duration32 worsens eight-new-window selection NLL 4.656302 to 4.657089. Its disjoint withheld eight-window difference is +.000499 +/- .001339 nats in favor of extrapolation, 4/8 windows favorable. The fully decoded paid complete 16-KiB-code/256-row-scale image costs 122,976,108 bytes versus 122,975,884 for the control, 224 more bytes..

Do not select this fixed extrapolation: its tiny and uncertain held edge fails independent selection and spends more paid bytes.

Comparison: Same 128,678,649-byte raw complete image, unchanged trits/signs/norms, same fresh fixture and 2,040 next-token predictions per half; original BF16 and calibrated four-bit remain substantially better on their own panels.

Boundary: A bounded negative for one scale-update direction and one 1.5 coefficient, not a proof about further gold-loss training, other coordinates or MoE routed representations. Quality is BF16-expanded, not packed native time.

Next decision: Train on unused text and select between scale-only and genuinely coupled code/scale whole-model recovery at matched paid rate, then freeze a new held panel rather than extend this direction.

Sources: [research/ternary/latest-extrapolate/README.md](../ternary/latest-extrapolate/README.md), [research/ternary/README.md](../ternary/README.md).

<a id="conversion-silu-polynomial-shortcut"></a>
## Low-degree polynomial replacement for SiLU gates

Category: Strictly bad under the tested conditions. Evidence: On the same eight teachers, degree-two/three int8 SiLU approximation has .4105 median held RMS, worse than scalar q4's .1893; degree-five rises to .7553 and 25.79 on wider inputs..

Bilinear contraction is exact, but its cheap polynomial continuation does not preserve SiLU behavior over the tested input range.

Comparison: The low-degree candidate has 72 bytes versus 166 for scalar q4, so the failure is held accuracy rather than capacity.

Boundary: Rejects these Taylor approximations on the declared input panels, not every restricted-domain operator code.

Next decision: Require observed producer-domain bounds and held nonlinear quality before reviving polynomial folding.

Sources: [research/quantization-discovery/representations/joint-operators/README.md](../quantization-discovery/representations/joint-operators/README.md), [research/quantization-discovery/representations/joint-operators/results.json](../quantization-discovery/representations/joint-operators/results.json).

<a id="conversion-vector-native-reader"></a>
## Native paired gate/up and SiLU reader

Category: Promising but not yet. Evidence: For one full 3,072-channel gate/up invocation, polar, learned-pair and fitted-scalar code readers each take about 30 microseconds, against 42.523 for a simple expanded-FP16 wave-row control..

One-byte pair lookup avoids materializing gate/up weights and reaches the full nonlinear activation boundary.

Comparison: Learned pair and polar have nearly equal rate and latency; the learned codebook has lower response error. A scalar reader matches their speed.

Boundary: The control is not an optimized GEMM or serving baseline; down projection, preparation amortization and model loss matter.

Next decision: Pair complete-model quality acceptance with a full-path native execution comparison before claiming service gains.

Sources: [research/quantization-discovery/representations/vector-native/README.md](../quantization-discovery/representations/vector-native/README.md), [research/quantization-discovery/representations/vector-native/results.json](../quantization-discovery/representations/vector-native/results.json).

<a id="conversion-calibrated-splice"></a>
## One calibrated four-bit layer inside the recovered ternary model

Category: Promising but not yet. Evidence: A fixed layer-17 Q4 splice with eight matched whole-model scale updates scores 4.625448 previously inspected test NLL at 1.793698 BPW, versus 4.648968 at 1.727086 BPW for the matched ternary control. Its 4,963,040 extra image bytes yield no detectable gain on sixteen new disjoint validation windows: 4.593013 versus 4.592910, +.000103 ± .006164 paired nats, 7/16 wins. Across all 32 validation windows the Q4 edge is .002896 ± .004125 nats..

The paid layer-17 test edge fails to transfer to newly frozen disjoint validation text; do not select this image or build a mixed reader from its inspected test score.

Comparison: Exploratory validation rows 0–7 score 4.725945 versus matched ternary 4.725857; untouched rows 8–15 score 5.250784 versus 5.262661; sixteen further disjoint rows score 4.593013 versus 4.592910. Complete calibrated Q4 scores 3.795795 test NLL at 4.251313 BPW.

Boundary: This only assesses the frozen layer-17 image and short recovery schedule, using BF16-expanded quality, not other layer choices or packed inference time. The earlier test windows had been inspected.

Next decision: Choose a paid allocation and recovery duration on new train/selection text, then freeze one candidate and score independent complete-model quality; price native mixed execution only if the paid frontier survives.

Sources: [research/ternary/calibrated-splice.md](../ternary/calibrated-splice.md), [research/ternary/README.md](../ternary/README.md).

<a id="conversion-shared-input-coordinate"></a>
## One shared Q4 input coordinate across all routed experts

Category: Strictly bad under the tested conditions. Evidence: Across all 256 layer-0 experts and 126 held actual-producer tokens, a train-selected shared diagonal reduces complete routed-sum RMS .109739 to .074142 against symmetric Q4/Q4, but installed GGUF weights with a shared Q8 input score .005431..

A common input code really serves every expert, but this frozen Q4 recode loses too much local quality without reducing the expert weight stream. The preceding 16-expert study had only changed a subset of the route.

Comparison: The proposed 301,989,888-byte bank matches installed gate/up bytes plus a 4,096-byte common diagonal. Q4 saves just 1,024 activation bytes per token against Q8 before preparation.

Boundary: Layer-0 offline decoded FP32 BLAS local observation, not saved full image, native execution or complete-model language loss. Rejects this frozen recode, not jointly trained codes.

Next decision: Train expert codes on broader quantized producers and freeze a complete paid image for held language loss; measure native Q8/GDN traffic independently.

Sources: [research/quantization-discovery/representations/joint-operands/README.md](../quantization-discovery/representations/joint-operands/README.md), [research/quantization-discovery/representations/joint-operands/full-bank.md](../quantization-discovery/representations/joint-operands/full-bank.md), [research/quantization-discovery/representations/joint-operands/shared-held.json](../quantization-discovery/representations/joint-operands/shared-held.json).

<a id="conversion-vector-polar-slice"></a>
## One-byte polar gate/up pairs on real weights and a partial SiLU map

Category: Promising but not yet. Evidence: On 8,192 held Qwen weight pairs, isotropic error is 4.237e-5 versus 6.953e-5 for a fitted one-byte scalar control. On a 512-pair real-input nonlinear slice, held response RMS is .23275 versus the best tested scalar .31775 with quantized-producer inputs..

Joint direction/radius indexing can spend a byte better than separate scalar labels on this small consumer.

Comparison: The scalar control pays a 32-byte scale table; polar needs a 1,024-byte prepared table. A sum-dominant linear consumer reverses the quality ranking.

Boundary: Partial four-channel map with original down slice, not full-layer or language-loss superiority.

Next decision: Use the complete-channel and model substitutions rather than extrapolating the slice.

Sources: [research/quantization-discovery/representations/vector-geometry/README.md](../quantization-discovery/representations/vector-geometry/README.md), [research/quantization-discovery/representations/vector-geometry/consumer-results.json](../quantization-discovery/representations/vector-geometry/consumer-results.json).

<a id="conversion-paired-repair"></a>
## One-group coupled trit and scale repair

Category: Strictly bad under the tested conditions. Evidence: After screening 139,300 layer-12 down-projection pairs and full-model checks of six nominees, the selected packed pair worsens validation 4.733112 to 4.733498 and test 4.646432 to 4.646920 at unchanged bytes..

A genuine proposal-panel pair barrier did not survive separate train selection or held language loss.

Comparison: Matched trit-only and scale-only edits were scored; the check-selected pair lost its favorable interaction and did not beat the original 1.72709-BPW image.

Boundary: This rejects six locally nominated single-group edits, not coupled repair elsewhere or a broader code/scale search.

Next decision: Nominate from composed gold-loss sensitivities across multiple groups before another held pass.

Sources: [research/ternary/paired-repair/README.md](../ternary/paired-repair/README.md), [research/ternary/paired-repair/results.json](../ternary/paired-repair/results.json).

<a id="conversion-paged-scales-hot-reader"></a>
## Page-local scale deltas in a hot native dot reader

Category: Strictly bad under the tested conditions. Evidence: Sequential, random and sparse dot access take 42.13, 42.61 and 42.26 ns/row with paged scales versus 39.89, 40.54 and 39.98 for raw interleaved scales..

Saving 3,412 model bytes adds roughly two nanoseconds per visited row to this resident CPU reader.

Comparison: Both readers decode the same exact weight block and include integer dot and FP16 scaling; sparse visits can touch more metadata than they save.

Boundary: Hot CPU block with synthetic sparse access, not a real MoE route or a cold-to-hot lifecycle.

Next decision: Use the layout for capacity only if measured cold storage and expansion costs beat raw residency.

Sources: [research/quantization-discovery/representations/entropy-execution/README.md](../quantization-discovery/representations/entropy-execution/README.md), [research/quantization-discovery/representations/entropy-execution/results.json](../quantization-discovery/representations/entropy-execution/results.json).

<a id="conversion-joint-rate-oracle"></a>
## Paid joint allocation across two residual blocks

Category: Promising but not yet. Evidence: At seven physical bytes, exhaustive joint selection gets .035156 composed error versus .941406 for independently allocated downstream-weighted fits. At nine bytes a standard four-bit pair improves to .019531..

Large cross-error terms make the best complete map unlike the best individually fitted matrices.

Comparison: The stronger independent control sees original-network sensitivities, not merely coefficient error; a conventional four-bit pair wins with more bytes.

Boundary: Finite linear two-coordinate catalogue. Hidden-state drift may fail under real gates and norms; no native timing.

Next decision: Search a bounded paid joint catalogue on adjacent real blocks, including four-bit and high-precision exceptions.

Sources: [research/ternary-toys/rate-allocation/README.md](../ternary-toys/rate-allocation/README.md), [research/ternary-toys/rate-allocation/results.json](../ternary-toys/rate-allocation/results.json).

<a id="conversion-coupled-codebooks-unstructured"></a>
## Paired templates on unstructured weights

Category: Strictly bad under the tested conditions. Evidence: At identical four-byte group storage, paired templates lose all eight unstructured trials, with summed held error 6.518197 versus 2.313192 for scalar ternary..

Restricting unrelated columns to a shared sign-and-swap motif is harmful.

Comparison: Both arms use exact finite train code search and the same consumer; the pair also needs more arithmetic.

Boundary: Negative for this template and Gaussian target family, not for learned codebooks with demonstrable real structure.

Next decision: Use a real-weight motif census to decide whether a paired format merits further work.

Sources: [research/ternary-toys/coupled-codebooks/README.md](../ternary-toys/coupled-codebooks/README.md), [research/ternary-toys/coupled-codebooks/results.json](../ternary-toys/coupled-codebooks/results.json).

<a id="conversion-coupled-codebooks-motif"></a>
## Paired templates when correlated motifs exist

Category: Promising but not yet. Evidence: At four physical bytes for eight weights, paired codes win all eight noisy-motif trials; summed held error .128005 versus 4.852597 for exact scalar ternary search..

Shared paired-channel structure can pay for a joint codebook at the same physical byte count.

Comparison: Scalar search enumerates all 6,561 ternary matrices against the composed consumer, not nearest-weight rounding.

Boundary: Four BPW toy and more nonzero arithmetic; the motif is planted. Separate unstructured trials reverse the ranking.

Next decision: First measure how often paired motifs occur in real gate/up groups and charge native decoding before any model replacement.

Sources: [research/ternary-toys/coupled-codebooks/README.md](../ternary-toys/coupled-codebooks/README.md), [research/ternary-toys/coupled-codebooks/results.json](../ternary-toys/coupled-codebooks/results.json).

<a id="conversion-recurrent-link"></a>
## Preserve a sensitive recurrent feedback link

Category: Promising but not yet. Evidence: One-step ternary rounding makes a chosen two-state transition unstable, radius .966655 to 1.021973; scale search restores stability, but a paid FP16 link cuts white-input error from 10.208304 to .229601..

A small coefficient can control long-horizon state response more than its one-step matrix error suggests.

Comparison: The paid exception uses 57 bits versus 39 for ternary and 64 for dense FP16 in this tiny cell.

Boundary: Near-critical counterexample chosen deliberately; the seven-bit saving and unmeasured extra multiply do not establish a good compression format.

Next decision: Inspect real GDN Jacobian modes and multi-step held responses before assigning paid exceptions.

Sources: [research/ternary-toys/recurrent-stability/README.md](../ternary-toys/recurrent-stability/README.md), [research/ternary-toys/recurrent-stability/results.json](../ternary-toys/recurrent-stability/results.json).

<a id="conversion-reachable-quotient"></a>
## Preserve attention's reachable distinctions

Category: Promising but not yet. Evidence: Across all 27 finite inputs, the coefficient-best ternary producer has .167660 final residual MAE, while a worse coefficient fit is exact. Ordinary scale-two rounding also becomes exact by halving both query temperatures..

The best matrix approximation collapses states that attention must distinguish; a joint producer-consumer scale can avoid new codes.

Comparison: All producer images use six trits and one shared scale. Query-temperature adjustment is an equally strong consumer-side control.

Boundary: Exact only while consumers observe logit differences; a branch reading their sum breaks the quotient.

Next decision: Capture all real attention consumers before adopting a quotient and compare against jointly adjusted query scales.

Sources: [research/ternary-toys/reachable-quotients/README.md](../ternary-toys/reachable-quotients/README.md), [research/ternary-toys/reachable-quotients/results.json](../ternary-toys/reachable-quotients/results.json).

<a id="conversion-vector-response-repair"></a>
## Response-aware search of actual packed pair indices

Category: Promising but not yet. Evidence: Layer-0 three-bit paired image improves held full-MLP RMS .69242 to .61463 and complete-model test NLL 4.792683 to 4.702836 at unchanged bytes; validation improves 4.889163 to 4.808191..

A cached rank-one downstream response score can repair some low-rate code damage without dense training.

Comparison: Selected ternary remains better at 4.646432 test NLL; a separately response-fitted scalar scale control also improves both splits.

Boundary: The eight-bit pair overfits its train check and worsens held results. No image was adopted or timed in a full model.

Next decision: Use whole-model held loss to accept a rate-matched candidate and include scalar response controls.

Sources: [research/quantization-discovery/representations/vector-response/README.md](../quantization-discovery/representations/vector-response/README.md), [research/quantization-discovery/representations/vector-response/SCALAR.md](../quantization-discovery/representations/vector-response/SCALAR.md), [research/quantization-discovery/representations/vector-response/results.json](../quantization-discovery/representations/vector-response/results.json).

<a id="conversion-nonlinear-gauges"></a>
## Shared residual rotations with offline up/down gains

Category: Promising but not yet. Evidence: A planted RMSNorm/SwiGLU block becomes exactly ternary under a shared angle and hidden gain. In two perturbed or Gaussian draws with FP16 boundaries, train-output-selected joint gauges score .1256 versus .1391 and .0759 versus .1229 held RMSE against gain-only..

Orthogonal residual coordinates and reciprocal up/down gains preserve this nonlinear map without scaling the SiLU gate.

Comparison: Gain-only avoids boundary conversions; weight-error-selected joint gauges can lose to it even on the perturbed teacher.

Boundary: One planted construction and two fixed off-manifold draws, with no real-model or packed-runtime acceptance.

Next decision: Test a shared basis across consecutive real blocks and charge every entry, exit and incompatible consumer.

Sources: [research/ternary-toys/nonlinear-gauges/README.md](../ternary-toys/nonlinear-gauges/README.md), [research/ternary-toys/nonlinear-gauges/results.json](../ternary-toys/nonlinear-gauges/results.json), [research/ternary-toys/nonlinear-gauges/stress-results.json](../ternary-toys/nonlinear-gauges/stress-results.json).

<a id="conversion-additive-real-rows"></a>
## Shared templates on contiguous real Qwen rows

Category: Strictly bad under the tested conditions. Evidence: A 10,272-byte int8-template/int4-residual image has .113475 real-block response RMS versus .059448 for an independently scaled scalar5 image at 10,496 bytes..

These contiguous q_proj rows lack the shared row energy needed to amortize a template dot.

Comparison: The planted correlated-row control reverses this ranking, .006091 versus .049586, confirming the codec's conditional mechanism.

Boundary: One 128-by-128 Qwen block and simple native readers; does not reject learned grouping across other weights.

Next decision: Measure train-only row correlation before testing grouped templates against held contextual outputs.

Sources: [research/quantization-discovery/representations/additive-programs/README.md](../quantization-discovery/representations/additive-programs/README.md), [research/quantization-discovery/representations/additive-programs/results.json](../quantization-discovery/representations/additive-programs/results.json).

<a id="conversion-response-dictionaries"></a>
## Short learned dictionaries on a real Bonsai block

Category: Strictly bad under the tested conditions. Evidence: Top-sixteen eight-trit motifs cover 1.423% of rows versus 1.417% under an independent-trit control. Learned K16/K64 dictionaries get .754/.611 held response RMS; folded scalar sign gets .529..

This block does not show enough short repeated motifs for the tested dictionary families.

Comparison: K16 and K64 cost 55,296 and 88,064 bytes; folded scalar sign costs 92,160, and the original lossless ternary image 143,360.

Boundary: Different rate points and one block. Neither all dictionaries nor cross-layer or route-conditioned reuse is ruled out.

Next decision: Establish real motif reuse against an independent-trit control before implementing another dictionary reader.

Sources: [research/quantization-discovery/representations/response-dictionaries/README.md](../quantization-discovery/representations/response-dictionaries/README.md), [research/quantization-discovery/representations/response-dictionaries/results.json](../quantization-discovery/representations/response-dictionaries/results.json).

<a id="conversion-stock-gguf-controls"></a>
## Stock GGUF external quality controls

Category: Promising but not yet. Evidence: On identical BF16 scoring and frozen text, stock Q4_K_M scores 3.709265 test NLL at 478,268,416 tensor bytes, while stock IQ2_M scores 4.823108 at 325,809,152 bytes. Our calibrated Q4 scores 3.795795 at 316,749,352 bytes..

The stronger published Q4_K_M image wins quality with much more storage; the near-byte-budget IQ2_M image loses quality with a different body/head allocation.

Comparison: Per source-unique parameter, stock Q4_K_M costs 6.41917 BPW and IQ2_M 4.37291, versus our tied image at 4.25131. GGUF stores embedding and output separately and charges both.

Boundary: This is a matched decoded-weight comparison, not native llama.cpp loss or speed. No broad GGUF-format dominance follows from IQ2_M's measured point.

Next decision: Keep both stock images as external anchors and compare at honest source-unique bytes, accounting for the duplicated head.

Sources: [research/quantization-discovery/q4-diagnostic/STOCK-GGUF.md](../quantization-discovery/q4-diagnostic/STOCK-GGUF.md), [research/quantization-discovery/q4-diagnostic/stock-results.json](../quantization-discovery/q4-diagnostic/stock-results.json).

<a id="conversion-tiny-mechanisms-programme"></a>
## Tiny mechanism experiments and transfer decisions

Category: Promising but not yet. Evidence: Twelve runnable finite-map experiments with exhaustive controls, held examples, representation costs and explicit transfer tests. Their individual results have separate entries in this catalogue..

Small examples expose interacting code changes, consumer-dependent coordinates and failures of local error objectives without whole-model training.

Comparison: Controls are finite exhaustive oracles or matched toy representations, not external language-model SOTA. The first full-model paired code/scale transfer failed held acceptance.

Boundary: A constructed witness establishes a mechanism, not its prevalence in trained weights or a useful native implementation.

Next decision: Select further transfers by actual model structure and complete paid loss, keeping the failed paired-repair result attached to the toy lead.

Sources: [research/ternary-toys/README.md](../ternary-toys/README.md), [research/ternary-toys/BRIEF.md](../ternary-toys/BRIEF.md), [research/ternary-toys/SYNTHESIS.md](../ternary-toys/SYNTHESIS.md), [research/ternary/paired-repair/README.md](../ternary/paired-repair/README.md).

<a id="conversion-three-level-unrotated-gptq"></a>
## Unrotated signed and affine three-level GPTQ

Category: Strictly bad under the tested conditions. Evidence: Complete 197-image Qwen3-0.6B exports, same frozen 32-window test and 8-window validation. Strict signed costs 128,758,184 bytes at 1.728153 BPW, test NLL 7.584679 and validation 8.335283. Paid affine origin costs 138,070,440 bytes at 1.853139 BPW, test 7.977037 and validation 8.701291..

Transferring the successful four-bit sequential Hessian pipeline directly to three levels loses badly. Paying for a group origin worsens body and complete-model loss.

Comparison: The selected rotated and scale-repaired signed image costs less at 1.727086 BPW and scores test NLL 4.646432. Both new arms are dominated by that complete image; affine body-only NLL 7.914782 also loses to strict signed 7.002912.

Boundary: This rejects these unrotated range-fitted three-level conversions, not every three-level representation. Rotation, group fitting and subsequent scale repair differ from the selected image.

Next decision: Keep the selected image. Isolate coordinate choice and three-level group fitting before spending another full export on this pipeline.

Sources: [research/quantization-discovery/q4-diagnostic/THREE-LEVEL.md](../quantization-discovery/q4-diagnostic/THREE-LEVEL.md).

<a id="conversion-calibration-cover"></a>
## Weighted state coverage for code selection

Category: Promising but not yet. Evidence: Three probability-weighted teacher states choose the population-optimal gate trits; 10,000 iid draws still choose incorrectly with probability .220085..

A rare amplified route must receive its correct mass, not merely appear in a large calibration sample.

Comparison: Both selectors search the identical nine-code family; exact population risk confirms the weighted-cover choice.

Boundary: The three-state support and probabilities are supplied by construction. Discovering them in a model is not free.

Next decision: Compare loss-difference-preserving weighted captures with an equal-query random calibration on held complete-model NLL.

Sources: [research/ternary-toys/calibration-sufficiency/README.md](../ternary-toys/calibration-sufficiency/README.md), [research/ternary-toys/calibration-sufficiency/results.json](../ternary-toys/calibration-sufficiency/results.json).
