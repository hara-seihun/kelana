# Compute, bandwidth and uneven token difficulty

the project lead asked three investigation workers and the initiating agent to step back from current speculative-decoding implementations. This September 23 round produced 27 worker proposals, with overlap, and a local adaptive-allocation experiment. The proposals are hypotheses and engineering directions, not 27 claimed inventions. The linked reports give their contracts, prior art and first discriminating experiments.

The useful general rule is **spend extra work where its expected contribution to progress exceeds its latency price**. For expected progress `N` and time `T`, an optional change improves the ratio when `delta_N > (N/T)*delta_T`. Changes in candidate support, memory access, verification work and continued state all belong in that comparison. Conditional entropy can help predict opportunity, but is not itself a computation lower bound.

## Results from this round

- [Unequal difficulty and allocation](adaptive/README.md). On the frozen pilot's 32 test contexts, low-entropy draft quartile chains cover 2.125 tokens including bonus; the highest-entropy quartile covers 1.500. Increasing tree budget six to 18 helps five contexts; 18 to 64 helps four. A validation-calibrated confidence policy does not produce a convincing difficulty-adaptation win. Under broad nearly flat verification curves it simply selects the largest cheap budget for everyone. A hindsight oracle can save many nodes with little latency gain under those curves. Cost curves are hypothetical, not GPU measurements.
- [Reuse the already computed first decision](candidate-repair/README.md). Supplying the target's retained first token raises test coverage from 2.1875 to 2.5625 at 64 candidate nodes, and 1.90625 to 2.2500 at six. This is correcting the pilot's handoff, not discovering a new drafting algorithm: established target-feature methods already use an anchor or bonus token. A fresh full-head projection costs approximately 311 MB BF16 weight traffic and 311 million FLOPs per context, so the token must really be retained to call the handoff cheap. FP32 versus BF16 output rounding exposed a tie; respecting the BF16 decision reproduces all 64 captured first tokens.
- [Forced-span map contraction](forced-spans/README.md). A fixed four-token affine state transition compiles to one affine map, preserving state and the next free-choice distribution for all 97 toy input states. Simply emitting the forced tokens without their state updates changes that distribution in 94 states. The construction is exact in its finite recurrent model, not a transformer replacement.
- [A compute-for-bandwidth certificate toy](compute-bandwidth/README.md). An exact eight-class greedy head can stop before reading all sixteen feature columns. Large-feature-first order omits 45.78% of counted weight bytes on 4,096 seeded contexts, compared with .42% for reverse order. Metadata, bounds and hardware transactions are outside that byte count. Existing real Bonsai certificates have a much smaller modeled 7–11% head-traffic opportunity, so the toy is not a new whole-model speedup.

No GPU run, target weight change or serving deployment was needed for this round. The work uses existing target traces, exact finite constructions and CPU arithmetic.

## The strongest routes to try next

### 1. Preserve paid information at the handoff

Do not spend a learned predictor and branch slots rediscovering a target decision already returned by the previous pass. Retain the token and useful features, then train and evaluate a residual continuation generator from that boundary. Count its known token separately from newly predicted tokens. The current pilot measures a real benefit from this repair; it does not establish superiority over DFlash or DSpark.

### 2. Learn the benefit of extra computation

An uncertain token can be repairable, intrinsically broad, or absent from the drafter's vocabulary. Train a policy on paired action outcomes: cheap pool, expanded pool, branch-conditioned correction, extra draft depth and direct target execution. Predict the gain from each action under surviving prefixes, rather than treating low confidence as an instruction to do more of the same work. Use a fixed hardware budget to ask which action yields the most useful coverage.

### 3. Improve candidate support before widening the same tree

The original top-16 oracle is close to the 64-node tree's coverage. Spend compute on a context- and predecessor-conditioned candidate pool, target-generated training labels, or a directly learned compact candidate code. Keep static vocabulary bytes, retrieval work, normalization requirements and the corrected target anchor in the cost. Train on broader independent text rather than taking more steps on the overfitting pilot.

### 4. Turn deterministic spans into known-input computation

Under a declared locally masked grammar, a token-singleton transition needs no model decision. Advance a uniquely tokenized run with known-token prefill and a boundary output head, or contract its state transition where a valid map exists. Byte-level certainty alone is not token-level certainty. This avoids unnecessary sequential decisions without pretending the future model state is free.

### 5. Carry branch labels into their next consumer

The same predecessor candidate at the same draft position has the same first-order correction row, irrespective of the earlier tree path. Compute or cache that row once; use packed labels to compose transitions without repeated vocabulary reconstruction. On the current 64-node trees, approximately half the conditional-row requests reuse an existing position/predecessor result. The target still needs distinct histories and continued state. The first round's byte-shuffle toy shows how a larger code can lower complete computation cost.

### 6. Refine decisions until they are certified

For exact greedy output, preserve an argmax certificate instead of every intermediate logit. Cheap bounds can eliminate losing candidates; difficult cases complete the full calculation. This is an algorithm with a proof-based stopping rule, not silent approximate decoding. Stochastic sampling requires its own exact probability-mass decision, and accepted KV state remains an observable. Compare against the existing real-head certificate study before constructing another native variant.

## Worker proposal catalogue

The numbering records the workers' individual proposals; related items intentionally remain linked rather than being presented as distinct inventions.

| # | Proposal | Owner/report | Main resource exchange |
| --- | --- | --- | --- |
| 1 | Early exact greedy-head certificate | [Compute/bandwidth](compute-bandwidth/README.md) | Bounds and comparisons for omitted head-weight reads |
| 2 | Progressively sharpened certified target | Same | Refine uncertain nodes instead of completing every node |
| 3 | Ancestor-aware tree allocation by byte cost | Same | Selection compute for useful coverage at a memory budget |
| 4 | Joint branch state in consumer-native labels | Same | Counterfactual map construction for fewer conversions and dependencies |
| 5 | Node-specific draft fidelity | Same | Extra correction only at valuable surviving prefixes |
| 6 | Emit draft labels while target features are resident | Same | Extra local arithmetic for avoided draft weight/activation traffic |
| 7 | Reusable model-specific draft preparation | Same | Offline storage/preparation for cheaper recurring maps |
| 8 | Short-KV draft with full-context verification | Same | Less draft KV traffic against possible lower acceptance |
| 9 | Hardware- and context-dependent horizon | Same | Larger blocks until marginal compute/KV cost dominates |
| 10 | Exact equivalent-state coalescing | Same | Equality/certificate work for shared target-state computation |
| 11 | Candidate-specific exact refinement | Same | Bound-guided irregular reads instead of full head work |
| 12 | Fused branch layout and accepted-state writes | Same | Address/register work for omitted temporary traffic |
| 13 | Elide singleton-token decision heads | [Forced spans](forced-spans/README.md) | Parser certainty for avoided projection/sampling |
| 14 | Grammar/tokenizer product automaton | Same | Prepared alignment for sound token-level jumps |
| 15 | Prefill uniquely known runs | Same | Parallel compute for fewer weight rereads and launches |
| 16 | Contract affine recurrent forced spans | Same | Prepared composed state update instead of repeated updates |
| 17 | Compile finite reachable-state spans | Same | Tables/instructions replacing the whole observed map |
| 18 | Fixed-template final observers | Same | Compute variable fields and required boundary state, not redundant output decisions |
| 19 | Grammar quotient plus separately proved model boundary | Same | Smaller parser/mask state without incorrectly merging neural histories |
| 20 | Deterministic tree edges and shared-template batching | Same | Spend decision slots at choices while processing known states efficiently |
| 21 | Retain the true next token at the verifier handoff | [Candidate repair](candidate-repair/README.md) | Avoid a repeated full-head projection or a fallible learned rediscovery |
| 22 | Preserve numerical decision semantics in captures | Same | Avoid changing target choices through altered output precision/ties |
| 23 | Target-generated residual-only training | Same | Training effort for better continuation support from a known anchor |
| 24 | Condition pool retrieval on the known root | Same | Added pool scoring for candidates absent from position-wise marginals |
| 25 | Context-adaptive vocabulary | Same | Retrieval/index work for less irrelevant head traffic and higher coverage |
| 26 | Allocate nodes by residual uncertainty | Same | Corrected confidence for useful post-anchor width/depth |
| 27 | Compare first-head rescoring with richer residual proposals | Same | Spend the same bytes/FLOPs on the more valuable boundary |

## What the information intuition supports

One expensive pass can expose a plan or state that makes many following outputs easy to produce. In that situation, small maps should expand the resolved decision into a long span. A model architecture that exposes those decisions well may beat one that repeatedly derives them through opaque token states.

There is not a fixed bit allotment per forward pass. Independent fair random tokens have high entropy and can be generated cheaply; a deterministic hard computation has zero conditional output entropy and can still require work. The practical object is the frontier of **prediction/verification quality versus paid compute and traffic, conditional on the state already available**.

The phrase "a difficult token needs more compute" is therefore incomplete. A useful policy asks which computation can actually change that token's candidate coverage or certify its decision. If all extra candidate verification is free, restricting the batch because a token is difficult saves little time. Spend the spare capacity differently, or improve the producer.

This round does not prove a universal compute-allocation law for language models. It provides an optimization rule with explicit costs, the first small measurements, and executable constructions worth extending without retaining their original intermediate representations.
