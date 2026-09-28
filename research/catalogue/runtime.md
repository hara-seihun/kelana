# Bonsai and Qwen runtime research

[Research desk](README.md)

Generated from `runtime.json`; the JSON owns classifications.

<a id="runtime-qwen-gdn-gate-precompute"></a>
## Accepted Qwen GDN gate preparation

Category: Promising but not yet. Evidence: Native on-demand Qwen revision b4c67ced against Prism llama.cpp 1a07bfa5f: all 7,946,240 reference logit bits and 32 greedy tokens agree on a 465-token real prompt. The activated-gate device phase is 33.641841 ms off versus 31.235749 ms on, a 7.15% phase reduction. The packaged runtime measured 879.9334 prompt tokens/s at 512 tokens and 52.2933 decode tokens/s at occupied depth 1024; separate prompt panels did not establish a useful full-model gain..

For prompts, precompute recurrent gate exponentials once per token/head rather than repeating them in GDN. The later selected runtime also includes the independently accepted MMQ width change.

Comparison: Bitwise identity and a device-phase gain against the named original native Qwen build. This is not a measured full-model prompt speedup attributable to the gate change, nor an external SOTA claim.

Boundary: Single-token decode does not use the change; the activated-gate trace does not measure the raw-gate arm.

Next decision: Attribute a whole-model prompt gain only from a paired same-binary GDN on/off benchmark under controlled host load.

Sources: [../bonsai-halo/docs/qwen-moe-speedups.md](../../../bonsai-halo/docs/qwen-moe-speedups.md), [../bonsai-halo/docs/qwen-moe-performance.md](../../../bonsai-halo/docs/qwen-moe-performance.md).

<a id="runtime-qwen-mmq-routed-width"></a>
## Accepted routed-expert MMQ J=64 prompt tiles

Category: Promising but not yet. Evidence: Pinned 22,134,528,992-byte Qwen3.6-35B-A3B Q4_K_M image on native gfx1151 revision f60e4fb. At 512 synthetic prompt tokens, batch 512 / ubatch 256, packaged binary, J=128 reference 872.92 and J=64 candidate 1138.18 tokens/s (+30.4%). Median shader clocks were near-paired at 2689/2704 MHz. The selected binary matched all 7,946,240 FP32 reference-logit bits and 32 greedy IDs on a separate 465-real-token prompt; installed candidate decode measured 51.58 tokens/s..

Routed expert groups padded to J=128 were executing nearly twice the useful matrix tile positions. Choosing an already compiled J=64 kernel for 65–256 routed prompt rows cuts empty work without repacking weights or changing the numerical map. This is selected in the on-demand Qwen runtime, not the resident Bonsai server.

Comparison: A 30.4% full-model prompt gain over the preceding native global-width dispatcher on the same GGUF and packaged implementation. It is not a claim over external MoE engines or SOTA; single-token decode uses a different MMVQ path.

Boundary: The throughput panel used synthetic prompt tokens; bitwise acceptance used a different real-text prompt. Interleaved multi-sequence generation and device-duration/physical-traffic attribution remain unmeasured. An earlier original-width diagnostic transiently changed output, but repeated diagnostics and installed 32-step acceptance agreed.

Next decision: Run an interleaved generation panel at multiple sequences and compare expert-device duration at J=64/J=128 before widening the policy or adding adaptive expert widths.

Sources: [../bonsai-halo/docs/qwen-moe-mmq-width.md](../../../bonsai-halo/docs/qwen-moe-mmq-width.md), [../bonsai-halo/docs/qwen-moe-mmq-work.md](../../../bonsai-halo/docs/qwen-moe-mmq-work.md), [../bonsai-halo/docs/qwen-moe-speedups.md](../../../bonsai-halo/docs/qwen-moe-speedups.md).

<a id="runtime-bonsai-batched-ternary-8060s"></a>
## Bonsai 27B batched ternary generation on Radeon 8060S

Category: Better than SOTA on something. Evidence: Installed canonical build 5eb5fcb runs 64 streams at 597.5 and 600.0 aggregate tokens/s, about 9.3 per stream. Same-process pair-only 32-stream control gives 440.3 and 440.2. Earlier 64-stream runs give 597.7 and 596.4; the preceding 128-stream panel gives 517.73 median on a different build. All 64 model layers execute..

A model-and-device-specific throughput record for Bonsai 2 27B ternary generation on the Radeon 8060S. Packed pair-code FFNs, shared batched weight work and the recurrent execution route sustain roughly 600 aggregate tokens/s at 64 streams without a speculative drafter.

Comparison: Installed model/device generation record in these panels, not a claim about other GPUs or models. A later opt-in packed-state candidate reaches 616.5/610.7 but retains an unresolved mixed-state acceptance failure. The installed paired comparison gains 36% over 32 streams with the same image arm. The normal 32-stream image selector previously reached about 477 tokens/s. This record designation does not require a new external implementation to exist for every batch shape.

Boundary: Mode 19, A4 activations, INT8 recurrent state and defer 4 are an approximate numerical route. Context capacity is 256 with short starting prompts; timing covers 16 greedy generation steps, excluding load and prefill. Cross-width token agreement does not establish BF16 quality equivalence. Aggregate throughput is not single-user token rate or HTTP serving throughput.

Next decision: Preserve this as the hardware-specific batch record and compare new work against its complete-model boundary. Extend generation length, occupied contexts and quality measurement separately; remeasure 128 streams on the same build before inferring a batch-size limit.

Sources: [../bonsai-halo/docs/decode-streams.md](../../../bonsai-halo/docs/decode-streams.md), [../bonsai-halo/docs/generation-128.md](../../../bonsai-halo/docs/generation-128.md), [../bonsai-halo/docs/full-tps-20260921.md](../../../bonsai-halo/docs/full-tps-20260921.md).

<a id="runtime-bonsai-document-prefill-8060s"></a>
## Bonsai 27B full-model document prefill on Radeon 8060S

Category: Better than SOTA on something. Evidence: Complete-model approximate mode19 panels report 862.22 median tokens/s for a 768-token document with 256-row passes; selected A4 sequence input reaches 924.1 for a 1536-token document at 256 rows; installed shape-specific GDN layout reaches 930.2 versus 908.4 on a 384-token/128-row document. A quiet-host control reports 1048.6 on that latter shape..

Model/device-specific prefill achievements, separate from generation throughput. Full-layer batched ternary execution and shape-specific recurrent layout exceed 900 prompt tokens/s on the recorded document workloads.

Comparison: These are hardware-specific achieved records with named shapes, not one interchangeable benchmark. A4 versus A8 reaches 924.1 versus 828.2 on the 1536-token/256-row panel; the installed GDN layout comparison is five paired rounds. The 1048.6 quiet-host number changes host contention, not the algorithm.

Boundary: INT8 recurrent state and A4 inputs are approximate routes. Tail-only vocabulary head, document length, pass width and package contention affect rates. These are batch-driver prefill figures, not HTTP request throughput or BF16-equivalent quality.

Next decision: Compare future prefill work at the same document, row width, numerical route and host load; preserve serving ingestion as a distinct endpoint.

Sources: [../bonsai-halo/docs/full-tps-20260921.md](../../../bonsai-halo/docs/full-tps-20260921.md), [../bonsai-halo/docs/seq-a4-default.md](../../../bonsai-halo/docs/seq-a4-default.md), [../bonsai-halo/docs/gdn-lane-layout.md](../../../bonsai-halo/docs/gdn-lane-layout.md), [../bonsai-halo/docs/power-budget.md](../../../bonsai-halo/docs/power-budget.md).

<a id="runtime-bonsai-serving-routes"></a>
## Bonsai native serving ingestion and concurrent decode

Category: Better than SOTA on something. Evidence: Same-binary 932-token drafted ingestion: selected wide-deployed route 465.7 versus 171.0 tokens/s, later 485.8 versus 167.8; generation remains about 51. At 32 concurrent HTTP requests, exact mode4 improves aggregate completion throughput from 83.5 to 107.1 tokens/s with all 32 completions identical. Its separate engine route ladder improves from 146.6 to 220.4; that is not HTTP throughput..

Model/device-specific serving achievements have their own request boundary. They are not represented by the faster offline batch-driver numbers.

Comparison: Measured improvements over the preceding Bonsai serving routes on Radeon8060S, designated as the recorded best serving implementation for those workloads rather than a cross-server external contest.

Boundary: The prefill and concurrent-generation panels measure different operations. Their numerical and scheduler contracts are those of the linked reports; neither the offline 600-token/s batch result nor drafted single-stream throughput substitutes for these request measurements.

Next decision: Keep these endpoints in acceptance when changing kernels or scheduling; test ingestion, concurrent generation and output agreement separately.

Sources: [../bonsai-halo/docs/serve-prefill-route.md](../../../bonsai-halo/docs/serve-prefill-route.md), [../bonsai-halo/docs/serve-decode-route.md](../../../bonsai-halo/docs/serve-decode-route.md).

<a id="runtime-qwen-topk-disable-cost"></a>
## Disabling fused Qwen MoE top-k restores width identity at a decode cost

Category: Strictly bad under the tested conditions. Evidence: Top-k-only fusion disable on source branch 2573923a gives zero bit differences over 40 full-vocabulary rows across batch widths 1, 2, 4 and 8, 9,932,800 compared floats. Same-binary depth-1024 64-token sequential three-sample panel averaged fused 52.1825 and unfused 49.3624 tokens/s; the unfused route took 5.81% more whole-model decode time over three samples, 3.86% over the final two..

The fusion pattern changes router arithmetic with graph width. Disabling only that fusion, while retaining other fusions, supplies a diagnostic width-invariant map but is slower and was not selected.

Comparison: Exact compared logits versus the singleton map improve at the measured widths, but time loses against the selected native fused router. This rejects an unconditional fusion-disable speedup, not a fused numerical repair.

Boundary: Arms were sequential with no recorded clocks and competing load was not paired; the precise 5.81% penalty is not established as stable. Forty rows are not a full MTP long-response acceptance.

Next decision: Match singleton and multi-row router IDs and normalized scores while retaining fused dispatch, then recheck MTP and full-model prompt/batch/decode.

Sources: [../bonsai-halo/docs/qwen-moe-graph-dispatch.md](../../../bonsai-halo/docs/qwen-moe-graph-dispatch.md), [../bonsai-halo/docs/qwen-moe-batch-logits.md](../../../bonsai-halo/docs/qwen-moe-batch-logits.md).

<a id="runtime-bonsai-dflash-target-verification"></a>
## Eight-row DFlash2 target verification

Category: Promising but not yet. Evidence: Ordered-target ten-prompt native panel: 1,212 generated tokens per arm, serial 32.91 versus eight-row DFlash2 80.92 decode tokens/s, 1,212 versus 322 target calls. Every speculative arm matched all ten serial token paths and final next decisions. The separate September 21 full-model panel measured 69.45 tokens/s median of ten per-prompt medians with FP32 state and Q4 DFlash on its own timing boundary..

One target pass verifies a block from the installed Q4 DFlash2 drafter. Target-state replay commits the accepted prefix and avoids recomputing GDN state for rejected rows.

Comparison: About 2.46 times the same native serial arm on the ordered-target panel. This is an internal exact-output gain, not DSpark or a comparable external SOTA result; its measurement boundary differs from the production CLI and the September 21 panel.

Boundary: The ten selected prompts were known from prior native studies, not a new held quality set. Target reduction ordering was fixed for the comparison, and drafter floating-point splits can change proposal choices between runs.

Next decision: Compare against an actually ported, correctly aligned Bonsai-2 DSpark checkpoint or the cross-target RadixArk DSpark candidate using target-verified output and the same request timing boundary.

Sources: [../bonsai-halo/docs/speculative-compare.md](../../../bonsai-halo/docs/speculative-compare.md), [../bonsai-halo/docs/full-tps-20260921.md](../../../bonsai-halo/docs/full-tps-20260921.md), [../bonsai-halo/PLAN.md](../../../bonsai-halo/PLAN.md).

<a id="runtime-bonsai-concurrent-drafted-serve"></a>
## Four-client drafted serving loses to plain batching

Category: Strictly bad under the tested conditions. Evidence: Same executable, full 32,768-token context and 64 completion tokens/request: four-client plain aggregate 93.6 versus speculative 85.2 tokens/s, 173/581 draft proposals accepted; earlier four-client panel 87.7 versus 77.8. Two clients improved 59.6 to 81.8 but one speculative completion diverged where the two-client control repeat agreed. The candidate scheduler was removed; the five-plane capture fix was separately retained..

Packing independent draft chains into one mode-4 target pass did not provide an accepted serving route. The capture investigation repaired four missing DFlash2 feature planes, but that repair is separate from the rejected batch scheduler.

Comparison: At four HTTP clients it is both slower than installed plain serving and fails an exact-output case at two clients. Reject this tested default policy, not the capture repair or speculation for a single stream.

Boundary: The two-client divergence has not been conclusively attributed to replay bookkeeping versus target atomic reductions. The 5% feature RMS regression threshold is not a bitwise-state proof.

Next decision: Only revisit concurrent speculation with matched target outputs and logical state at the same concurrency, plus a four-client end-to-end gain.

Sources: [../bonsai-halo/docs/serve-drafted-batch.md](../../../bonsai-halo/docs/serve-drafted-batch.md), [../bonsai-halo/orchestration/RESEARCH.md](../../../bonsai-halo/orchestration/RESEARCH.md).

<a id="runtime-qwen-q8-expert-decode-budget"></a>
## Measured Qwen MoE decode work, not an active-parameter speed forecast

Category: Promising but not yet. Evidence: Pinned Qwen3.6-35B-A3B GGUF plain decode is about 50–52 tokens/s at occupied depth 1024. A counter-free eight-token trace sums 20.398 ms/device token: Q8 projections 8.333 ms, routed Q4/Q5/Q6 experts 4.462 ms, Q6 vocabulary head 1.786 ms. Active encoded weight stream is 2.626 GB/token, against 5.647 GB for the separate Bonsai dense target; measured plain rate is only roughly 1.5 times the Bonsai short-context 33.70–34.5, a context-mismatched diagnostic..

The largest decode phase is nonexpert Q8, but routed experts have nearly as much conditional room against a one-image-read bandwidth reference. The fused shared gate/up path, GDN register state and one-row FlashAttention already exist, so simply porting those named Bonsai optimizations would duplicate the native route.

Comparison: Q8's 8.333 ms versus an idealized one-read 6.169 ms and experts' 4.462 versus 2.527 ms are scheduling opportunities under a 242 GB/s conditional model, not observed physical DRAM traffic or lower bounds. The output head is near that comparator.

Boundary: The GL2C panel has 395 consecutive executed matvec dispatches with zero read counts and roughly half-image readings otherwise. Its prior fourfold scaling and 8–10% excess interpretation were invalid. A profiler wall interval cannot be subtracted from unprofiled throughput.

Next decision: Resolve zero-valued per-dispatch counters and compare counter-free, shape-controlled Q8 and routed-expert phases to the installed grouped dispatch, including gather and reduction.

Sources: [../bonsai-halo/docs/qwen-moe-performance.md](../../../bonsai-halo/docs/qwen-moe-performance.md), [../bonsai-halo/docs/qwen-moe-q8-unprofiled.md](../../../bonsai-halo/docs/qwen-moe-q8-unprofiled.md), [../bonsai-halo/docs/qwen-moe-q8-native.md](../../../bonsai-halo/docs/qwen-moe-q8-native.md), [../bonsai-halo/docs/qwen-moe-speedups.md](../../../bonsai-halo/docs/qwen-moe-speedups.md).

<a id="runtime-sglang-awq-packed-gfx1151"></a>
## Packed AWQ GEMM against upstream SGLang HIP

Category: Better than SOTA on something. Evidence: On gfx1151, nine alternating paired GPU-graph rounds with actual official Bonsai AWQ checkpoint tensors give 1222.43 versus 169.60 microseconds for attention BF16 at one row (7.22x); 2116.53 versus 321.31 microseconds for gate BF16 at 16 rows (6.65x); and 2089.41 versus 279.21 microseconds for gate FP16 at one row (7.48x). Activation inputs were seeded rather than model captures. Relative squared error against FP32 decoded-weight matmul is 2.64e-6/2.75e-6 on BF16 and 4.27e-8 on FP16, essentially the reference's output-rounding error. Six Qwen2.5-0.5B AWQ greedy FP16 prompts matched the upstream route for all 72 tokens..

The proposed upstream SGLang gfx1151 HIP AWQ path consumes packed four-bit weights for 1–16 rows instead of dequantizing whole matrices before torch.matmul. It uses FP32 partial accumulation and leaves checkpoint storage unchanged.

Comparison: A scoped better-than-current-upstream result: the named SGLang HIP AWQLinearKernel dequantize-plus-matmul path at revision 28be39f, same real matrices and paired graph workload. Quality error against FP32 is matched at these shapes; the whole-model six-prompt FP16 identity check is small. This is a best-measured gfx1151 AWQ kernel result, not a whole-model, NVIDIA, or cross-checkpoint SOTA claim.

Boundary: Submitted as SGLang PR #40863, not evidence of an upstream production deployment. No HTTP/server throughput or whole-model speedup was measured. The Bonsai-1 AWQ fixture differs from Halo's Bonsai-2 ternary checkpoint, and BF16 AWQ has no upstream whole-model reference.

Next decision: Measure full-model latency and quality on the same SGLang checkpoint and shapes before extending a SOTA claim beyond the paired HIP kernels.

Sources: [../bonsai-halo/docs/sglang-awq.md](../../../bonsai-halo/docs/sglang-awq.md).

<a id="runtime-bonsai-packed-state-batch-candidate"></a>
## Packed state regions lift measured batch throughput beyond the installed record

Category: Promising but not yet. Evidence: State-region-stride panel: 64 streams with both A4 images reaches 616.5/610.7 aggregate tokens/s; pair-only gives 609.2/607.9. A separate managed-allocation 128-stream run gives 615.4, versus 578.0 at 64 in that same process. Packed regions reduce 64-slot preparation from 30.63 to 26.37 GB..

The best measured candidate exceeds the roughly 600-token/s installed batch record, but is opt-in rather than an accepted default.

Comparison: Same 64-stream mode19, INT8 state, defer4, A4 input, context256 and 16-step timing scope; both-image residency becomes possible under ordinary allocation. The 128-stream panel uses a different allocation policy.

Boundary: Mixed packed-state commit/replay/rollback acceptance fails on the candidate's base with or without the region change. The address change passes its 32-stream token and prompt-logit controls, but those do not resolve the broader failure. No deployed-record claim for this candidate.

Next decision: Repair the mixed packed-state acceptance and repeat complete batch panels before promoting the opt-in region selector.

Sources: [../bonsai-halo/docs/state-region-stride.md](../../../bonsai-halo/docs/state-region-stride.md).

<a id="runtime-bonsai-persistent-decode"></a>
## Persistent ternary decode on Radeon 8060S

Category: Promising but not yet. Evidence: Bonsai 2 27B, single stream, 20–60 greedy tokens after a five-token prompt: native per-operation HIP graph 31.5 tokens/s, persistent cooperative engine 34.0, and llama.cpp HIP PTQ1_0 21.0. The measured persistent matvec phases average 227 GB/s over 5.90 GB per token. The newer ordered-target speculative panel measures serial at 32.91 tokens/s on a different ten-prompt workload..

A cooperative persistent kernel reduces launch overhead and streams packed ternary rows directly. Ordered K-part accumulation later removed a same-prefix greedy-output race in the target. The engine and its deployment remain Bonsai's responsibility.

Comparison: The named llama.cpp HIP PTQ1_0 reference on this machine is 21.0 tokens/s versus 34.0 for Bonsai on the original short-prompt panel. This is a substantial local whole-model speed result, not a SOTA claim: the later reduction order and prompt set differ, and the cited CPU-reference logits predate ordered accumulation.

Boundary: The 41-token/s streaming roof presumes this weight/state representation and one target token per pass; it is not a universal bound. The benchmark does not establish matched held quality across the later reduction-order change.

Next decision: Retain the installed ordered-reduction map and compare any replacement at equal prompt, occupied context, output contract and complete-model time.

Sources: [../bonsai-halo/PLAN.md](../../../bonsai-halo/PLAN.md), [../bonsai-halo/README.md](../../../bonsai-halo/README.md), [../bonsai-halo/docs/speculative-compare.md](../../../bonsai-halo/docs/speculative-compare.md).

<a id="runtime-qwen-mmq-width-rejected-arms"></a>
## Qwen eight/two-wave decode split regresses

Category: Strictly bad under the tested conditions. Evidence: At occupied depth 1024 and 64 generated tokens, native Q8 eight-wave / Q6 two-wave candidate ran 51.6350 and 51.5708 versus controls 52.1299 and 52.1505 in alternating panels, roughly a 1% loss, and was reverted. Q8 two-wave / Q6 one-wave complete panels include 47.7 and 44.4 despite warm samples 52.7–53.1, so no repeatable gain. J=16 versus J=32 at a 32-token prompt measured 420.65 versus 408.10 tokens/s, too noisy to select..

The eight-wave Q8 and two-wave Q6 decode split is slower than the original dispatch and was reverted. Other noisy width panels remain inconclusive diagnostics, not established regressions.

Comparison: The eight/two wave policy loses to the original same-runtime Qwen dispatch in alternating panels. This negative classification applies only to that measured policy; the narrower-wave and J=16 prompt panels do not establish a strict ordering.

Boundary: Host clocks and package load varied, particularly in the narrower wave panels. No claim about alternative implementations or other prompt widths follows.

Next decision: Spend new native effort on measured grouped expert MMQ and counter-free decode bottlenecks, not an unqualified wave-width port.

Sources: [../bonsai-halo/docs/qwen-moe-speedups.md](../../../bonsai-halo/docs/qwen-moe-speedups.md), [../bonsai-halo/docs/qwen-moe-mmq-width.md](../../../bonsai-halo/docs/qwen-moe-mmq-width.md).

<a id="runtime-qwen-mtp-plain-map-fork"></a>
## Qwen MTP draft is fast but not accepted as greedy-equivalent

Category: Strictly bad under the tested conditions. Evidence: On the same pinned target GGUF, 96-token list request, temp 0, seed 1: plain 49.40 versus Q4-MTP 73.90 tokens/s, with 59/70 draft proposals accepted. Plain selected token ' Start' at generated index 71 and Q4/BF16 MTP selected ' Numbers'. A 32-token compass answer matched, but the longer request failed. Target-only teacher forcing of the same prefix at batch width four reproduces the MTP choice without a draft model; width-one replay preserves every vocabulary float..

A separately acquired MTP block can draft cheaply in Q4 while preserving the target GGUF, but the present batched verification path changes a greedy near-tie. The Q4 path is opt-in and has not passed the exact-output acceptance required for a default runtime gain.

Comparison: The 73.90 versus 49.40 rate is not a valid exact-output speedup because the compared answers differ. Strictly bad here means the tested default-adoption candidate under the declared greedy identity contract, not that all MTP speculation is intrinsically bad.

Boundary: Batch arithmetic explains a possible fork but neither proves actual verifier alignment nor excludes another indexing defect. Short-response acceptance does not license long responses.

Next decision: Reconcile target top-k fusion and target batch-width numerical map, then replay the token-71 fork with per-sequence state rollback and measure net gain only after full greedy identity.

Sources: [../bonsai-halo/docs/qwen-moe-mtp.md](../../../bonsai-halo/docs/qwen-moe-mtp.md), [../bonsai-halo/docs/qwen-moe-batch-logits.md](../../../bonsai-halo/docs/qwen-moe-batch-logits.md), [../bonsai-halo/docs/qwen-moe-graph-dispatch.md](../../../bonsai-halo/docs/qwen-moe-graph-dispatch.md).

<a id="runtime-bonsai-recycled-proposals"></a>
## Recycled stale DFlash2 candidate maps lose target progress

Category: Strictly bad under the tested conditions. Evidence: In the ordered-target ten-prompt panel the installed eight-row DFlash2 arm emitted 1,212 tokens at 80.92 decode tokens/s with 322 target calls. Recomputing Markov selection over saved top-16 tables after rejection gave 66.90 tokens/s and 448 target calls, a 17.33% slowdown despite mean draft cost falling from 6.93 to 3.02 ms per target call. Both matched the ten serial paths and final next decisions..

Cached hidden rows came from an obsolete mask block. Reusing them saved proposal work but supplied too little accepted progress, so target weight passes dominated.

Comparison: A complete same-target, same-prompt negative against the installed DFlash2 method. The nearby copy-arbitration arm's initial 0.94% gain also reversed to a 2.42% loss in opposite-order repetition, so no hybrid gain was established.

Boundary: Rejects this stale-table suffix and short-prompt copy policy, not all speculative recycling or an actual DSpark implementation. Package power limits varied in the panel.

Next decision: Seek proposals with full-block target progress or compare a faithfully implemented DSpark on this target; do not increase stale-row reuse on the present result.

Sources: [../bonsai-halo/docs/speculative-compare.md](../../../bonsai-halo/docs/speculative-compare.md), [../bonsai-halo/tools/speculative_compare.cpp](../../../bonsai-halo/tools/speculative_compare.cpp).

<a id="runtime-qwen-mmq-two-body-bound"></a>
## Two routed MMQ widths approach the tile-work floor

Category: Promising but not yet. Evidence: CPU replay of actual forty-layer train and held routes. On the held 126-token prompt, J=16/64 cuts issued gate/up positions from 328,138,752 to 112,902,144 at unchanged 5,007 logical image passes. A checked indirect schedule encodes 75,088 gate/up tiles in 300,352 bytes of descriptors, reused for 150,176 down tiles. The naive two-body full grids schedule 1,474,560 gate/up entries, of which 1,399,472 return..

Two native J bodies recover 93.23% of the available position saving; a CPU-checked 17-bit coordinate and per-expert prefix construction makes compact device dispatch concrete without a second route sort. The indirect option pays forty scan/emit passes, 225,264 gate/up-plus-down tile claims and extra launches.

Comparison: Installed J=64 is the control. Exhaustive two-width enumeration and exact descriptor checks establish static work and storage in the stated grammar, not a hardware-time lower bound.

Boundary: The device builder and persistent queue have not run on GPU. Queue atomics, occupancy, launch overhead, different thread geometry and actual DRAM traffic remain unpaid online work; no whole-model speedup follows from positions or compact task counts.

Next decision: Compare device-indirect dispatch, filtered full grids and installed J=64 on matched whole-model prompt and independent-stream generation, preserving installed logit bits.

Sources: [../bonsai-halo/docs/qwen-moe-mmq-hybrid-bound.md](../../../bonsai-halo/docs/qwen-moe-mmq-hybrid-bound.md), [../bonsai-halo/docs/qwen-moe-mmq-two-width.md](../../../bonsai-halo/docs/qwen-moe-mmq-two-width.md), [../bonsai-halo/docs/qwen-moe-mmq-split-plan.md](../../../bonsai-halo/docs/qwen-moe-mmq-split-plan.md), [../bonsai-halo/docs/qwen-moe-mmq-indirect.md](../../../bonsai-halo/docs/qwen-moe-mmq-indirect.md).
