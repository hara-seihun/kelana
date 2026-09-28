# Speculative decoding as a whole-map computation

the project lead commissioned this research on September 23, 2026 in thread `55878d53-abd5-4cde-a82b-2b42014a9ac0`, after discussing DFlash, DFlash 2, DSpark and tree verification. The goal is faster single-stream generation on the existing hardware by choosing the candidate representation, its producer and its consumer together. The current tensor graph and recognizable intermediate scores are not required observations.

## Current investigation

The [sixth-round larger-target report](realistic-runtime/README.md) tests Qwen3-1.7B on [24 frozen public prompts](realistic-workload/README.md), with 256–2,048-token contexts and 64-token continuations. A target-independent copy tree gives 1.666x decoding throughput and 1.422x including prefill. All 1,536 emitted token IDs and all 24 final next decisions match the FP32 serial target. Code, prose and JSON-style families all improve. A reverse-order repeat of the initially power-limited stage gives nearly the same ratio.

Twelve smaller-target controls expose weaker transfer of the learned producer. Its tree alone gives 0.971x, while adding one retrieved edge gives 1.258x. Actual variable-field JSON conversions on the larger target produce exact requested records but have no singleton token decisions and no eliminated target calls. The earlier canonical-token protocol's 9.61x does not transfer to this full-token grammar.

## Fifth-round investigation

The [fifth-round coupled report](online/COUPLED.md) combines optimized retrieval, on-generation training, measured dispatch and forced-span execution. On eight prompts, the original direct tree plus one retrieved edge reaches 38.35 versus paired serial 30.12 tokens/s across two opposite-order panels. A validation-selected producer trained on 5,632 additional on-generation states reaches 40.66 versus paired serial 30.25 with that graft. All emitted tokens and final next decisions match their FP32 serial references.

The broader panel also exposes limitations. The original residual tree's gain falls from the earlier four-prompt 1.39x to 1.14x on eight different prompts. [Measured-cost allocation](measured-policy/README.md) loses online to fixed trees. [Prefix weighting and global root conditioning](prefix-producer/README.md) do not justify replacing the original model. [Rollout training](rollout-producer/README.md) improves continued generation despite losing slightly on the earlier initial-prefix diagnostic.

The same report tests actual causal prefill of forced runs. A deliberately canonical-token JSON protocol reaches 9.61x at 44 tokens by reducing target calls from 44 to four. Admitting all tokenizations of the same output byte strings reduces the gain to 1.022x in the longest case. The consumer contract determines which internal decisions may disappear. These are different constrained target laws, not interchangeable implementations of one law. [Lazy structured JSON support](structured-runtime/README.md) extends the all-ordinary-token contract to bounded batches with variable strings and numbers, without listing complete strings. Its two sampled paths have no singleton token steps.

## Fourth-round investigation

The fourth round adds [continued generation with target verification and KV adoption](online/README.md). On four fresh prompts with two repetitions, the FP32 target's 18-node tree produces 42.09 tokens/s versus serial 30.25, with all emitted tokens and final next decisions matching. A larger-tree panel exposes the limit: 64 nodes yield only 9.7% more progress per cycle than 18, while cycle time rises 52.7%, eliminating the speedup. These measurements include CPU drafting, transfers, full target projection and cache gathering.

The BF16 target does not preserve the ordinary serial path in this implementation. An identical-history, one-token diagnosis isolates a body-output difference caused by explicit attention-mask execution; a rounded logit tie changes the greedy token. FP32 matching is an observed result on this panel, not a lossless BF16 deployment claim.

Two parallel experiments accompany the loop. [Direct candidate-ID production](direct-producer/README.md) removes borrowed target output rows and cuts shortlist projection products sixteenfold; its cheaper but less accurate producer retains most of the online gain. [Learned-map structure](map-structure/README.md) finds an exact byte-CDF encoding for the frozen tables, halving their storage with a small native lookup gain across 32 contexts, but no cheap full-map shortcut for fresh single paths. The fifth round's [retrieved token spans](retrieved-spans/README.md) build on that direct producer; optimized lookup and the online comparison are in the coupled report.

## Third-round investigation

The third round combines five parallel experiments with [a unifying theory and exact witnesses](theory/README.md). The objective is exact emitted progress per elapsed time, including the continuation state and reusable machine work. Extra arithmetic helps when it avoids costly reads or resolves a prefix bottleneck. Target entropy alone does not price that work.

- [Target-generated residual drafting](residual-drafter/README.md) trains on 2,048 new target continuations after a retained first token. A larger head raises 64-node test coverage from the unchanged graft's 2.5625 to 2.6563, including the known root and target bonus. It also costs more projection work. No timed verifier is installed.
- [Support-changing actions](action-value/README.md) find that widening the existing pool from 16 to 256 yields no test gain at matched node budgets. Added suffix support remains too low-ranked to enter the useful tree. Routing has a small gain under one assumed cost curve, not a measured runtime advantage.
- [Native learned-map consumption](native-learned/README.md) loses the synthetic threshold toy's win. Fresh byte-map construction plus prefixes takes 23.57 ns per six-step learned stream, versus 17.80 ns for direct AVX2 visited-row sampling. Producing unvisited successors is the cost to beat.
- [Real tokenizer spans](tokenizer-spans/README.md) enumerate every supported tokenization of finite JSON/code languages. Sixteen JSON strings admit 296,960 token paths; known bytes do not generally force a token ID. Genuine singleton edges permit parser contraction, while target state updates remain required.
- [Lazy exact sampling](lazy-sampling/README.md) reads only enough integer-weight bytes to decide a rejection sample. Favorable recurring reads are 8.242 versus a full scan's 16 bytes. An identical output law in another weight scale costs 65.939 bytes under the same envelope, separating output entropy from implementation cost.

The theory's finite witnesses show why shared pages can defeat nodewise benefit/cost ranking and why the next dispatch state can defeat immediate tokens/time maximization. Together these results favor jointly choosing the producer, representation, consumer and action policy. The fourth-round loop now measures continued generation and KV adoption, and records the numerical contract separately from mathematical tree correctness.

## Second-round investigation

[Compute, bandwidth and uneven token difficulty](IDEAS.md) records the September 23 second round: 27 worker proposals with overlap, a measured difficulty gradient, a validation-fitted allocation study, target-token handoff repair, and exact forced-span and head-certificate toys. Reusing the retained target token raises the pilot's test coverage from 2.1875 to 2.5625 at the same 64 candidate nodes. Confidence-only budget adaptation does not establish a win under the studied flat-to-compute-bound cost curves. Improving missing candidate support and choosing useful extra work are stronger next questions than simply allocating more nodes to uncertain tokens.

The new records are [adaptive allocation](adaptive/README.md), [candidate repair](candidate-repair/README.md), [forced spans](forced-spans/README.md) and [compute/bandwidth ideas](compute-bandwidth/README.md). The second round used CPU and existing traces; no target or runtime changed.

## First-round platform

The first round combines two independent experiments:

- [Finite maps and native CPU consumers](finite/README.md). Integer-grid random functions reproduce exact conditional sampling. Prefix trees beat chains on uncertain toy distributions at a fixed node budget. A 16-byte map consumed directly by a SIMD shuffle is much cheaper than an eight-byte nibble map composed by scalar extraction. Complete construction, serial prefixes and consumption take 14.7 ns versus 297.7 ns on the 32-step threshold toy. The direct visited-state chain takes 31.5 ns. The byte construction wins despite twice the map storage; its cheap threshold producer is part of that result, not a property of arbitrary neural tables.
- [Qwen3-0.6B pilot and learned-map bridge](qwen/README.md). A frozen real target supplies causal features to approximately 0.6M-parameter learned drafters. On 32 test contexts, the conditional six-position chain covers 1.8438 tokens including bonus, versus 2.1875 with a 64-node tree. The top-16 candidate oracle is only 2.4063: more branches cannot repair missing candidates. The learned local selector is also compiled into packed finite maps, with identical sampled paths in 1,024 serial/scan comparisons.

These results establish an executable small-model research platform, a concrete representation/consumer CPU win on a toy, and a real-model proposal-quality comparison. They do not install a new inference engine, establish a GPU speedup, or claim state-of-the-art drafting quality.

## Required observations

For the draft generator, an output may be a candidate tree and the probability information needed by the chosen verifier. A direct target-sampling tree verifier need not consume exact proposal probabilities; rejection sampling does. Changing that boundary can remove work from the producer.

For exact target generation, accepted tokens and the state required for future generation both matter. A changed KV encoding is allowed when its continuation consumes it correctly. Greedy argmax, a stochastic sample, target probabilities and log-probability reporting are different observations. Success at one does not establish the others.

For a first-order candidate selector, an independent random draw at each position makes a deterministic predecessor-to-successor map. Associative composition removes the sequential sampling dependency at the map level, but constructing all hypothetical successors costs work. The native byte-shuffle result and the learned-map bridge deliberately keep that bill visible. The bridge uses a top-16, 256-grid proposal, not the original continuous softmax distribution.

## Next measurements

Resolve the BF16 verifier's numerical contract before calling it lossless relative to ordinary serial execution; forcing SDPA math did not remove every shape-dependent mismatch. Extend the completed larger-target panel to long task-quality workloads with a native candidate scheduler and cache adoption. Fit action value on on-generation states rather than assuming a policy trained on initial prefixes transfers. For structured output, choose the observable grammar contract explicitly before attributing forced-span savings.

The target-generated residual experiment improves the candidate producer modestly; widening the same ranking does not. Train for useful prefix inclusion and accepted residual progress on new independent contexts. Compare the additional head traffic against saved verifier rounds. The current small held panel is a diagnostic reused across these studies, not a fresh benchmark for each proposal.

For native computation, the actual learned-CDF experiment establishes a stronger direct visited-row baseline than the threshold toy. A future map producer must exploit a cheaper jointly trained representation, useful reuse across many paths, or parallel critical-path savings. Simply materializing every counterfactual CDF successor is not a single-thread CPU win here. GPU realization must price its own instructions, layout and complete pool/score/table/map path.

## Operations and custody

The durable source is Kelana's local Git repository. Each experiment has short reproduction commands and scoped receipts. The real-model artifacts, checkpoints and source snapshots live in [/path/to/workspace/data/kelana-speculative](/path/to/workspace/data/kelana-speculative/README.md), separate from the pinned source model and corpus under `kelana-subbit`. Existing Bonsai GPU admission serializes model runs; no extra service, scheduler or compute has been created.

The initiating conversation owns these completed rounds. Further work can use the existing [Bonsai/Kelana research lane](../../../bonsai-halo/orchestration/README.md) and peer board with a specific `research/speculative-maps/` claim. This small-model programme is a direct user-requested experiment alongside, not a replacement for, the MoE inference priority.

The mathematical approach comes from [the 2×2 radix-64 map](../toy2/radix64/README.md), [composition across representations](../composition/README.md), and [observer search](../discovery/observer-search/PLAN.md). These govern the distinction between a sufficient state, a composable state and a cheap implementation.
