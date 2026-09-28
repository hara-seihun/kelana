# Per-group A7 selector fit loses on held binary-factor responses

The [two-boundary A7 fit](../binary-second-selector/README.md) uses one first-stage ladder threshold for all 32-coordinate groups of a paid `mlp_up` projection. Would a learned threshold for each group improve the *complete* two-factor response at the same online work? On frozen Qwen3-0.6B layers 0 and 14, the group fit lowers train error but worsens held error in two disjoint data panels. More thresholds are not a free quality gain on these images.

## Map and search

Keep the parent paid one-bit U/V signs, pre/post scales, A7 signed codes, cap eight, integer group multipliers and second-stage threshold `.77`. Given a group's current maximum ratio `r_g`, choose the lower `3/4` ladder step when `r_g <= t_g`. The parent's global first-stage thresholds are `.77` at layer 0 and `.78` at layer 14. We replace the common threshold with one static `t_g` per 32-input group, still chosen by the same comparison and the same integer dot/shift/add schedule. There are 32 thresholds per projection in offline metadata instead of one scalar; the 32 comparisons already exist in the group quantizer. Weight bits, activation bitplane products, output rows and floating scale placement do not change. Fetching distinct constants and addressing them in a native reader would still have a cost.

For each group, hold other thresholds fixed, test all thirteen values `.70,.71,...,.82`, and choose the lowest **complete final-response** train sum of squares. Recompute the second quantizer for affected input rows, since a first-stage change can move its global maximum and every second-stage code. Accept only strict train improvements. One pass through 32 groups is a coordinate descent, not a global optimum over `13^32` choices. In the 32-row panel we take two passes; the 128-row panel takes one. The script checks that its incremental response cache equals a fresh full response after every pass. This is CPU FP64 comparison with the same frozen paid image's unquantized two-factor response, not bit-identical FP32 inference.

| Train / held input split | Layer | Global train RMS | Group train RMS | Global held RMS | Group held RMS | Changed thresholds |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| train `[0:32]`, validation `[32:64]` | 0 | .017769 | .017569 | .017412 | .017632 | 19/32 |
| train `[0:32]`, validation `[32:64]` | 14 | .016038 | .015805 | .016311 | .016486 | 21/32 |
| train `[512:640]`, validation `[512:640]` | 0 | .017413 | .017237 | .017360 | .017387 | 23/32 |
| train `[512:640]`, validation `[512:640]` | 14 | .015883 | .015780 | .016066 | .016138 | 23/32 |

The larger train panel reduces but does not reverse the generalization loss. These are two independent train/validation slices of the existing original-producer activation fixture, not a complete-model test. The local fit targets final response, so the earlier failed *linear pre-quantizer* group fit cannot explain this reversal. The global pair itself was selected on the first 32 train inputs; the fresh 128-row panel holds that parent constant rather than retuning its control.

## Custody and next question

`OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-group-choice/measure.py` writes the 128-row receipt. Add `--small` for the 32-row receipt. `/path/to/workspace/data/kelana-subbit/binary-group-choice/receipt-{32,128}.json` stores source and parent hashes, paid-image and fixture hashes, per-arm response hashes, training path, threshold choices and clipped-group counts. The data owner indexes these files. No GPU, native reader, installed executable, service state or whole-model NLL changed.

A different per-group objective could still work. Here each threshold controls only a few activated lower-step decisions in 32 or 128 examples, while second-stage rounding couples the groups. Do not add 31 constants per projection to these frozen readers on the strength of their train fit. Carry the cheaper common pair, and jointly learn group decisions with the binary factors and quantized-producer composed loss on more independent text. Then compare the native fetch/preparation cost against the matched global reader before selecting an engine map.
