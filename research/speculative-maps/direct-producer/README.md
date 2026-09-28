# Direct candidate IDs without target output rows

The residual drafter carries 4,096 frozen rows of Qwen's 1,024-wide embedding. This CPU experiment replaces that borrowed target projection with a learned 64-to-4,096 ID head. Its input is the same saved 1,024-wide normalized hidden feature; the previous target token is retained as the first tree node. A 128-wide trunk makes five 64-wide position states. Learned 16-dimensional predecessor and successor codes adjust the score for each distinct position/predecessor row. There is no target output head in the producer.

Training uses the same 2,048 target-generated continuations and exactly the same 4,096 candidate IDs, in the same order, as `residual-v4096-s200`. The IDs were selected from training data by that experiment. Validation and test use its separate original 32-context fixtures. The 200-step AdamW run saves the checkpoint with the lowest validation in-vocabulary cross entropy at steps 50, 100 and 200; step 100 won. The selected validation loss was 5.6297 versus the residual model's 5.9600, but lower cross entropy did not give better 64-node path coverage. No test label enters vocabulary selection, training, checkpoint selection or tree construction.

The tree builder, path-probability heap, 16-token pools and budgets are the residual experiment's own `proposed` and `depth` functions. Static pools use position base scores; adaptive pools rerank after predecessor conditioning. Every row normalizes over all 4,096 IDs. Means include the retained first token and one target-produced exit token, so subtract two for newly accepted residual tokens.

| Split / nodes | Residual static | Residual adaptive | Direct static | Direct adaptive |
| --- | ---: | ---: | ---: | ---: |
| Validation / 6 | 2.7188 | 2.7188 | 2.4688 | 2.4688 |
| Validation / 18 | 2.8438 | 2.8438 | 2.6563 | 2.6563 |
| Validation / 32 | 3.0000 | 3.0000 | 2.7188 | 2.7813 |
| Validation / 64 | 3.0625 | 3.0938 | 2.7813 | 2.8438 |
| Test / 6 | 2.4063 | 2.4063 | 2.4688 | 2.4688 |
| Test / 18 | 2.5313 | 2.5313 | 2.5313 | 2.5313 |
| Test / 32 | 2.5938 | 2.5938 | 2.5313 | 2.5313 |
| Test / 64 | 2.6250 | 2.5938 | 2.5313 | 2.5313 |

On test, 86 of 160 residual labels miss the direct static top-16, versus 90 for the residual static pool. Yet their paths enter fewer 64-node trees: a shortlist hit at a position is not enough when its predecessors lose the heap ranking. The direct adaptive pool misses 91. All models share 12 out-of-vocabulary residual labels on test. On validation the direct model loses at every budget. Thus removing the borrowed head is an actual cost reduction, not an established candidate-quality improvement or a speedup.

The direct producer has 572,896 FP32 learned values, about 2.19 MiB, and 32 KiB of int64 vocabulary IDs. It stores no frozen output rows. The residual producer has 696,256 learned values and another 4,194,304 frozen FP32 target-head values, about 16 MiB. One direct static shortlist pass makes five 64-by-4,096 projections, 1.31M scalar products, versus five 1,024-by-4,096 projections, 20.97M products, in the residual model. If the head alone streams once, its weights cost 1 MiB versus 16 MiB. Both still pay five trunk/gate computations, heap selection and a 4,096-element softmax for every cached conditioned tree row. A direct conditioned row uses 65,536 code products, versus 131,072 for the residual model. Tree construction scored 1,125/1,084 static and 1,182/1,134 adaptive rows on validation/test for direct, versus 926/961 static and 987/1,002 adaptive for the matched 4,096-row residual model. The direct producer explores more distinct rows, which offsets some of its per-row arithmetic savings. These are reference operation counts, not measured GPU traffic or verifier time.

The retained first token is available only when the previous target pass hands it over. Without that handoff both designs need the target full-vocabulary decision. Greedy prefix membership does not implement tree attention, KV continuation or exact sampling.

The [continued-generation experiment](../online/README.md) subsequently integrates both producers with target verification and KV adoption. The direct 18-node draft takes about 1.21 ms versus 2.28 ms for residual in separate FP32 panels, but reduced progress leaves throughput at 41.33 versus 42.09 tokens/s. Both beat their paired FP32 serial baseline, and neither establishes a lossless BF16 speedup.

## Reproduce

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
S=$PWD/research/speculative-maps/direct-producer/experiment.py
$P "$S" fit --steps 200
$P "$S" evaluate --steps 200
```

The script writes `direct-s200.pt`, fit/evaluation JSON receipts and content-addressed source copies under `/path/to/workspace/data/kelana-speculative/direct-producer/`. The [data directory README](/path/to/workspace/data/kelana-speculative/direct-producer/README.md) owns artifact custody. No GPU or new capture is needed.
