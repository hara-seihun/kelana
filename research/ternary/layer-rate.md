# Paying four bits for seven ternary layers

The selected Qwen3-0.6B ternary image has 197 packed matrices, including the tied head, at 128,678,649 payload bytes and 1.72709 BPW. Its group scales were trained through the complete model. The existing independent group-128 scalar-four-bit image wins as a *complete* model on frozen test text, 4.4513 versus 4.6464 NLL. Does spending extra bits on one quarter of the transformer body buy a comparable gain without changing the other three quarters?

`layer-rate.py` loads the selected `expanded-scale384` image, swaps seven complete layers at a time to the saved scalar-four-bit matrices, measures actual complete-model next-token loss, then restores the ternary weights before the next group. The tied head stays ternary. Every group replaces 49 matrices and exactly 23,749,992 ternary payload bytes with 56,771,344 four-bit bytes. Norms and the other matrices do not change. All four resulting image specifications therefore cost **161,700,001 bytes, 2.170288 BPW**, a 33,021,352-byte increment. These are counted saved packed code/scale/rotation payloads, not an entropy estimate. The quality forward expands each component into BF16, as in the existing pilot; no mixed-image packed native reader or throughput is claimed.

| Replaced layers | Validation NLL, eight 256-token windows | Delta against paired 1.72709-BPW baseline | Windows worse |
| --- | ---: | ---: | ---: |
| none | 4.733112 | 0 | 0/8 |
| 0–6 | 4.826601 | +.093489 | 7/8 |
| 7–13 | 4.786242 | +.053131 | 8/8 |
| 14–20 | 4.772191 | +.039079 | 5/8 |
| 21–27 | 4.914076 | +.180964 | 8/8 |

The best validation group, 14–20, was then scored on all 32 frozen test windows, 8,160 predictions. It moves test NLL **4.646432 → 4.645854**, an improvement of only .000578 nats for +.443202 BPW. Fourteen of 32 test windows worsen; paired per-window changes range from −.14197 to +.24864 nats. The test set was already reported in earlier rounds, so it is a confirmation panel, not a new blind selection set. Even the selected mixed arm remains .19455 nats behind the complete 4.1264-BPW scalar-four-bit control on this test.

This rejects the simple policy of substituting an independently calibrated four-bit block into the jointly scale-trained ternary model at a quarter-body budget. It does **not** say a four-bit layer is intrinsically worse. The scalar control was fitted independently, while the retained ternary scales adapted to ternary producers and consumers. Replacing one contiguous region shifts their inputs without recovering the rest. Nor does the positive complete four-bit result imply that its gains add layer by layer: the four disjoint singleton substitutions all lose on validation at the same rate. A better next question is to train the retained ternary scales against a fixed mixed image, then compare that recovered mix with equal-budget alternatives on fresh held text. Only a material quality gain would justify a packed mixed-rate reader and native timing.

The receipts are `/path/to/workspace/data/kelana-subbit/ternary/quality/layer-rate-validation-8-0-1.json`, `layer-rate-validation-8-2-3.json` and `layer-rate-test-32-2.json`. They include per-window sums, packed byte counts, image-manifest and scalar-accounting hashes, fixture and model-source hashes, and script hash. All three runs used Bonsai's `tools/run-batch-compare` with a 45-second payload limit and 20 GiB process limit. The resident service was restored after each run. No serving image or executable changed.
