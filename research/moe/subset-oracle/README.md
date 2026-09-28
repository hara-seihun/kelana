# Exhaustive subset floor for the actual routed expert sum

Can a better ordering of Qwen's eight routed experts make early omission worthwhile without adding replacement vectors? I enumerated all 256 subsets at each of 113 train and 126 held layer-0 tokens from the selected GGUF observer. The candidate returns the original score-weighted outputs of the retained experts, with no rescaling. A hindsight oracle sees every omitted vector and selects the subset with the smallest local Euclidean error at each retained count. This is an optimistic floor on *unmodified-output omission*, not a runnable decision rule.

The captured contribution is `v_e = float64(score_e) * float64(down_e)` and the target is `y = sum_e v_e`. For an omitted mask `m`, `||y - sum_{e not in m} v_e||² = mᵀ G m`, where `G_ij = v_i · v_j`. Eight contributions yield just 256 masks, so this enumerates cancellation between omissions as well as individual contribution strength. The script scores every subset in FP64, chooses the best mask at fixed cardinality, and finds the largest omission count whose *per-token* relative norm error does not exceed the stated tolerance. Router-score prefix selection is the executable-order control, but its tolerance decision still cheats by inspecting the true error. No paid stopping certificate could outperform this oracle within the same unchanged-vector family.

| Held local error limit | Hindsight omitted assignments / 1,008 | Score-prefix omitted | Hindsight local RMS | Maximum whole-model one-read byte saving if all 40 layers behaved identically |
| ---: | ---: | ---: | ---: | ---: |
| 1% | 0 | 0 | 0 | 0% |
| 5% | 73 | 62 | .03217 | 1.686% |
| 10% | 219 | 179 | .08350 | 5.059% |
| 20% | 418 | 369 | .17377 | 9.656% |

The 1% result is stronger than the previous norm-certificate failure: *even knowing all eight outputs*, no nonempty omitted subset on either capture falls below 1% relative error. At 5% the held oracle skips one expert on 39 tokens, two on 10, three on two and four on two; the other 73 need all eight. Train skips 48/904 assignments at 5%, with the same zero at 1%. Across held rows, the best two omitted contributions never cancel to a smaller residual than the best single omission. A different subset improves on router-score prefix, but only from 62 to 73 omitted assignments at 5% even when the decision is free and clairvoyant. With four retained experts, the best mask gives .21124 held aggregate relative RMS, compared with .26429 for score order; it changes the ordering, not the need for new output directions.

One selected expert image contributes 76,439,552 modeled bytes per token across forty layers; the conditional complete stream is 2,626,187,904 bytes. Dividing the oracle's saved assignments by held token count gives the table's ceiling. This deliberately charges zero for observing missing outputs, selecting masks, gathering or changing grouped execution. The eight outputs, route scores and producer activations are captured at one layer through callback graph cuts; other layers, generated decode routes, native FP32 reduction order, model-loss effects and physical DRAM traffic are outside this bound. The result does not reject a learned replacement direction or changed expert weights, where the omitted contribution can be reconstructed rather than thrown away. That is the next representation question. For the exact engine, benchmark real Q8 and Q4/Q5 phases rather than betting on an oracle worth under 2% of modeled bytes at 5% local error.

`study.py` runs without the GPU and writes `/path/to/workspace/data/qwen-moe/subset-oracle/receipt.json`, which hashes source, captured score and down arrays, token IDs and text for each split. The [capture provenance](../../../../bonsai-halo/docs/qwen-moe-routes.md) names the pinned model, installed binary and callback contract. Recompute with:

```sh
python3 research/moe/subset-oracle/study.py /path/to/workspace/data/qwen-moe/route-capture \
  --out /path/to/workspace/data/qwen-moe/subset-oracle/receipt.json
```
