# Changing the candidates, not just the node count

[experiment.py](experiment.py) reads the frozen `conditional-s200.pt` Qwen3-0.6B drafter and the 32 validation and 32 test target-greedy traces. It changes the six-position producer's support and scoring without retraining or capturing new target outputs. [results.json](results.json) contains every context's observable root features, selected-action counts and candidate-pool ceilings. The 32 test contexts have already appeared in other research reports. Treat this as a diagnostic, not a fresh held benchmark.

Each action constructs an ancestor-closed tree using proposal scores, then counts exact matches against the saved target trajectory plus one exit/bonus token. The independent arm omits the conditional predecessor correction. Static pools rank the backbone's positionwise 2,048 shortlist once, before any branch; dynamic pools rerank all 2,048 tokens using the actual predecessor at every expanded prefix. Both normalize corrected scores across the full shortlist. The chain greedily commits six nodes. All trees are compared at the same 6, 18 or 64 verified candidate nodes. Nobody looks at the held target tokens while constructing these trees.

| Test action | Six nodes | 18 nodes | 64 nodes | Corrected rows at 64, mean |
| --- | ---: | ---: | ---: | ---: |
| Corrected, static top 16 | 1.9063 | 2.0625 | 2.1875 | 33.4 |
| Corrected, static top 64 | 1.9063 | 2.0625 | 2.1875 | 41.8 |
| Corrected, static top 256 | 1.9063 | 2.0625 | 2.1875 | 41.8 |
| Corrected, predecessor top 16 | 1.9063 | 2.0625 | 2.1563 | 34.4 |
| Corrected, predecessor top 64 | 1.9063 | 2.0625 | 2.1875 | 41.8 |
| Independent, static top 16 | 1.8438 | 2.0000 | 2.1250 | 0 |

The greedy corrected chain scores 1.8438 at six nodes. At 64 nodes, predecessor top 16 loses one context to static top 16 and wins none. Enlarging the static pool from 16 to 256 produces **no accepted-prefix gain at any of these budgets**. The wider alternatives are not free: they expand 41.8 distinct position/predecessor corrected rows on average, versus 33.4 for static 16. The full-vector correction is about 131,072 FLOPs per distinct row, in addition to the shared roughly 27.7-million-FLOP backbone and 2,048-row shortlist projection. Static and dynamic top-k also scan/rank the shortlist. These are operation counts, not GPU timings or memory-traffic measurements. The frozen target rows alone occupy about 8 MiB in the reference FP32 checkpoint; the target projection, its memory traffic and tree/KV verification still need native pricing.

Why didn't width work? The target's correct first token lies outside the fixed top-16 pool in six of 32 test contexts. None of those six is recovered by static top 256. At the suffix, static top 256 extends the pool oracle's first uninterrupted in-pool run in 12 contexts; its mean ceiling rises from 2.4063 to 3.4063 tokens. But these newly supported suffixes are too low under the learned path score to enter a 64-node proposal tree. Predecessor-ranked top 16 actually adds a seventh root miss; its oracle ceiling is 2.3125. A different producer or an already available target decision is needed at the root, while rescoring and allocating nodes would be needed to exploit the recovered suffixes. More width from the same ranking does neither. Root misses and suffix misses must not be conflated: the latter cannot matter until all their ancestors survive.

A separate **retained-first-token boundary** supplies the first token of the saved target trajectory as a declared handoff input, then spends the same node budget on static-top-16 residual branches. It reaches 2.2500, 2.5000 and 2.5625 test tokens at budgets 6, 18 and 64, improving 10, 10 and 8 contexts, respectively, with no losses here. These numbers are not a label-free producer action and are excluded from the routing comparisons. They are executable only when a target step has already computed and retained exactly this token. Reconstructing it from the anchor hidden state requires the complete 151,936-by-1,024 output head, about 311 million FLOPs and 311 MB of BF16 weights streamed if uncached; see [candidate repair](../candidate-repair/README.md). The head's BF16 rounding matters to its argmax. Do not add the retained action to a cycle-rate numerator while omitting either its earlier target step or this extra projection.

## Priced action routing

The script fits policies using validation outcomes only. It compares the validation-best fixed action, a validation-fit root-entropy threshold between two actions, and ridge-predicted action values using root entropy and the proposal mass in static root top 16. The predictions select the action that maximizes estimated `progress - rate * cycle_cost`. Corrected actions reuse the root row they already computed. A policy picking the independent action pays one extra corrected root row for its features; a fixed independent action needs no correction. Actual routing code, heap scheduling, branch KV traffic and hardware effects are not measured. The diagnostic hindsight selector sees test outcomes and pays for its chosen action plus any incremental feature row, but no lookup cost.

The sensitivity model charges a stipulated 0.12 dispatch unit, producer FLOPs divided by one complete target-head projection, corrected rows, six shared static-pool scans, extra dynamic-pool scans and `max(1,(nodes+1)/knee)` target verification units. Each scan costs one comparison per shortlist value in this abstract scenario. Actual top-k/argsort time is not measured. Its knee and conversion of draft arithmetic into target-head units are **assumptions**, not a measured backend. This makes the route a falsifiable allocation study rather than a tokens/second claim.

| Assumed target-row knee | Validation-best fixed action | Fixed test tokens/cost | Entropy route | Action-value route | Hindsight |
| ---: | --- | ---: | ---: | ---: | ---: |
| 8 | Corrected static16, 6 | 1.5731 | 1.5750 | 1.5732 | 1.6019 |
| 16 | Corrected static16, 6 | 1.5731 | 1.5656 | 1.5732 | 1.6894 |
| 32 | Independent static16, 18 | 1.6544 | 1.6792 | 1.7046 | 1.7305 |

At knee 32, action value routes four of 32 contexts to corrected variants and improves mean progress from 2.0000 to 2.0625 with the same 18 verified nodes on average. This small positive result depends on the assumed flat verification range and the inspected panel. At knees 8 and 16 it does not beat fixed. Entropy-only does not reliably identify an action that repairs a pool miss. Hindsight is a ceiling for the offered label-free action menu under this cost curve, not an implementable policy; it does **not** include the retained-token boundary.

## What to try next

The immediate missing operation is target-aligned retrieval at the root. Increasing top-k on the same fixed shortlist wastes producer and verifier work. On a new independent set, measure a producer that adds candidates outside the static top 256, log whether the correct root is actually retrieved, then fit the gain predictor on separate contexts. For residuals, improve path scoring or targeted allocation before paying to enlarge every node's pool. A real server must measure target tree verification, KV adoption, head reuse, shortlist reads and draft dispatch before claiming a speedup. The direct greedy-prefix membership here is not a lossless stochastic target-sampling contract.

Run in under a minute on the existing CPU runtime:

```sh
cd /path/to/workspace/projects/kelana
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/speculative-maps/action-value/experiment.py
```

The script writes only `action-value/results.json`. Its receipt hashes the source, immutable checkpoint and captures. It never modifies target weights or requests the GPU.
