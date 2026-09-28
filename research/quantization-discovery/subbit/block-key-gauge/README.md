# Block-anchor keys at unchanged nibble rate

A key code can use its first token in a short block as a predictor for the other keys without storing another anchor or adding a score dot. The predictor must be shrunk toward the existing static center. Copying the anchor outright damages causal quality; a train-selected blend improves the frozen layer-14 paid Q/K observation modestly and loses at layer 0. This is a different representation/consumer map, not lossless compression of the old key labels.

## Complete score map

For one GQA group, let `b_i` and `s_i` be the existing static origin and positive coordinate step. A block of width `B` begins with the ordinary signed-nibble code `a_i = clip(round((k_0i-b_i)/s_i),-7,7)`. Decode its anchor `h_i=b_i+s_i a_i`, then set `c_i=b_i+α s_i a_i`. For later keys store `r_ti=clip(round((k_ti-c_i)/s_i),-7,7)`. The first decoded key remains `h`, while subsequent decoded keys are `c+s*r_t`. No additional key-cache bits or static step/center entries are needed. The next block begins with its own absolute anchor and can append without rewriting previous codes.

For either observing query head, write `A=Σ_i q_i s_i a_i`, `R_t=Σ_i q_i s_i r_ti` and `C=Σ_i q_i b_i`. The score of the first key is `C+A`, and that of every later key is `C+αA+R_t`. The shared `C` cancels from the causal softmax across *all* blocks. Compute the first key's existing packed-nibble dot once, keep its scalar `A`, and add `αA` to the later residual dots. Both heads may use different `A` against the same codes. No key, source weight or expanded int4 vector appears in the score program. This is an exact real-arithmetic identity for the changed decoded keys. The replay constructs FP32 decoded keys and scores in FP64; reassociating the native FP32 score need not reproduce those bits.

There are still 256 selected key coordinates per layer and 128 packed cache bytes/token/layer. At real-query precision, both heads take the same 512 coordinate products per token/layer as the static nibble control. In the existing two-nibble query lowering, both maps instead take the same 1,024 nibble products. The new cost is one scalar multiply and addition per later key/head, an anchor-score lifetime through at most `B` keys, first-key detection, and producer work to materialize each block's 32-coordinate center per group and subtract it when appending later keys. An alpha from the measured set `1/8,1/4,1/2,1` has no metadata beyond a group policy, though native shift/FP scheduling and occupancy are unmeasured. The full raw K normalization producer, paid binary Q/K projection, query preparation and two-head softmax remain unchanged.

## Frozen paid-image experiment

`measure.py` reuses the Qwen3-0.6B paid binary Q/K projections, the 128 selected planes, BF16 key affine and the fixed train-selected static signed-nibble origin/FP16 coordinate steps from [the nibble cache](../key-nibble-cache/README.md). The original Q/K is the teacher. It fits no weights or steps: for each of eight GQA groups it selects from static `B=1` and `B=8,32` with `α=1/8,1/4,1/2,1` using eight original-producer train windows and sixteen query positions per window. Four previously inspected 256-token validation windows score all causal positions. This is CPU original-producer causal KL, not quantized-upstream language loss.

| Layer | Static KL | Direct anchor, B=8 | Fixed B=32, α=1/4 | Train-selected group policy |
| ---: | ---: | ---: | ---: | ---: |
| 0 | **.275403** | .320159 | .276037 | .276025 |
| 14 | .332292 | .340521 | .330219 | **.330806** |

At layer 14, the fixed `B=32, α=1/4` arm improves three of four inspected held windows, but that fixed arm was not the train-selected group policy. The actual train selection improves all four windows: baseline `.318938/.340820/.314126/.355285`, selected `.316455/.338575/.313393/.354803`. Layer 0's train selection loses overall. The unshrunk anchor loses on both layers, and group-by-group selection does not reliably find the held winner. The gain at layer 14 is .001486 nat/query over the static cache at exactly the same stored bytes and logical nibble products; it buys no weight-rate or complete-model result.

Receipts under `/path/to/workspace/data/kelana-subbit/block-key-gauge/layer{00,14}.json` retain every group/configuration train loss, four held-window losses, selected policies, source and parent receipt hashes, model, capture, paid Q/K images and the selected-plane image. The direct-score decomposition is checked against the reconstructed-key dot within 5e-5 unscaled dot units on the inspected first group for `α=1`. The comparison's unchanged 1x0 arm reproduces the parent `.275403/.332292` exactly.

This small layer-14 quality lead warrants fitting the block predictor with changed paid K signs, query scores and quantized upstream on broader text, not a native reader for the frozen image. A larger causal or post-O gain would then justify pricing anchor lifetime, append/center preparation, scheduling and the actual packed two-dot query consumer at occupied context. The strong direct-anchor failure rules out treating a position-local translation as a free softmax gauge: every block has a different center, so its query-dependent offset must be restored by the reused anchor score.

Run without the GPU or service interruption:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/block-key-gauge/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/block-key-gauge/layer$(printf '%02d' "$layer").json"
done
```
