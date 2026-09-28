# Selecting the shared key-score base against the complete output

The frozen signed-nibble Q/K image has a three-dot score consumer for two GQA heads. One head uses a two-nibble query dot; the other adds a single-nibble difference dot to that base score. Which head is the base can vary by GQA group without changing the 768 signed-nibble products per cached key/layer or the 128-byte packed key cache. The preceding [quantized-upstream transfer](../shared-query-producer-transfer/README.md) chose the eight bases by causal KL. I tested whether selecting them against the complete attention/O response helps after quantizing the preceding fourteen layers.

It does not. Exhaustive train-only selection among all 256 base masks lowers the pooled train post-O relative squared error from .04703379 for the quantized-producer KL choice to .04688295. On four separate, previously inspected validation windows it **worsens** .02058570 to .02059130. The original-producer KL choice scores .02059087. Even a held-label oracle over all 256 masks reaches only .02057292, still behind the four-dot control's .02048744 on the same input. Thus base-head selection cannot recover that four-dot response gap within this frozen per-group three-dot family, even with free held selection. This is not a bound on jointly learned Q/K labels or on other score programs.

| Frozen base choice | Four train windows | Four held windows |
| --- | ---: | ---: |
| Original-producer causal KL | .04737245 | .02059087 |
| Quantized-producer causal KL | .04703379 | .02058570 |
| Quantized-producer complete post-O | **.04688295** | .02059130 |
| Held-only post-O oracle | .04725523 | **.02057292** |
| Four-dot control, held | | .02048744 |

The train choice is `[1,1,1,0,1,0,0,1]`, versus `[1,1,1,0,0,0,1,1]` for train KL. These maps have the same static base metadata size and three-dot score cost. Four dots require 1,024 signed-nibble products/key/layer but do not need shared-score additions. The complete post-O error is dominated by the frozen paid projection and changed upstream input; this experiment measures a tiny choice within it, not the isolated score-rounding error or a complete-model language result.

## Finite calculation

For each group `g`, each 256-token causal window and each base `b`, compute the original V/O output `Y[g,b]` from the exact integer-key score reconstruction and FP64 softmax/output accumulation used in the parent replay. Compute the teacher `T` using original Q/K and the same changed hidden input and V/O. With `R = sum_g Y[g,0] - T` and `D[g] = Y[g,1] - Y[g,0]`, every mask `z` has exactly the evaluated response `R + sum_g z[g] D[g]`. Its squared error is `uᵀ G u`, where `u=(1,z[0],...,z[7])` and `G` is the nine-by-nine Gram matrix of these response vectors. Summing window errors weighted by each teacher's squared norm gives the pooled relative error. Enumerating all `2^8` masks gives a global optimum for this finite frozen family. The held oracle is evaluated separately and never used to select the train mask. Real-valued score reconstruction is not a bit-identical FP32 native scheduling claim.

`measure.py --split train|validation --output PATH` records each window's Gram, denominator and both base-head KLs; its final mode enumerates masks. The CPU receipts are `/path/to/workspace/data/kelana-subbit/shared-score-post-o-selection/{train,validation,result}.json`. The split receipts hash the source, parent replay, original model, BF16 capture, paid Q/K images, key image, affine and parent result. `result.json` hashes both Grams and contains every reported per-window value. Source input is Qwen3-0.6B layer 14, four train and four validation 256-token windows from the prior upstream capture. No GPU, native latency, executable or service changed.

The next useful experiment changes the paid Q/K producer and score-label fit on broader quantized-upstream composed text. Another selector over these eight frozen base bits has at most .00001837 held relative-error headroom against the original-producer choice, even with held labels, and cannot catch four dots on this panel.
