# Four-bit keys need coordinate scales

A signed-nibble cache for the existing 128-plane paid binary Q/K observer gets within .0231/.0241 two-head causal KL of its real-coordinate cache at layers 0/14, while storing one quarter of the BF16 key bytes. The fit uses a separate FP16 step for each selected post-RoPE coordinate and train-selected centering per group. One group-wide step fails badly at layer 0. This is a useful rate/attention-quality point, not yet a weight-BPW or inference-speed result.

| Layer | Real selected K | Prior train-selected int8 group step | Int4 group step, train-selected center | Int4 coordinate steps, raw | Int4 coordinate steps, train-selected center |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .252318 | .260361 | .753152 | .290594 | **.275403** |
| 14 | .308216 | .307843 | .397003 | .334744 | **.332292** |

Each number is mean teacher-to-candidate causal attention KL across four already inspected validation windows, eight KV groups and both query heads. The layer-0 coordinate-selected arm improves on its raw arm on all four windows, with paired values .278391/.286910/.263400/.272911 against .301711/.305195/.272662/.282810. At layer 14, the first window slightly favors raw, .318540 against .318938; the train-selected mix wins the four-window mean. Train selection used sixteen strided queries per 256-token window across eight train windows. It chose the minimum finite causal KL among clipping quantiles .99, .995, .999 and 1 for each group and each raw/centered candidate. Only train data determined each step and group arm. Coordinate steps are quantiles independently for each coordinate, then the *common* quantile for a group is selected by causal KL. These inspected held windows were not used for fitting, but they have appeared in many previous research decisions; this panel cannot claim fresh-text or quantized-producer transfer.

The 256 selected coordinates occupy 128 packed nibble bytes per token/layer, with four groups per 64-byte cache line if groups are placed contiguously. The int8 control occupies 256 and BF16 occupies 512. Coordinate steps cost 512 FP16 bytes/layer. Train-selected centered groups are six at layer 0 and five at layer 14, costing another 384/320 FP16 center bytes/layer. Other paid weight factors, the group key affine, full 1,024-row K denominator, the 128 selected planes and both heads are unchanged. Encoding a key costs 256 optional center subtractions, 256 reciprocal-step multiplies, rounds, clips and nibble writes. Both heads prepare 512 query coordinates per query by multiplying each by its coordinate's step, then reuse them over all cached keys. Each key still needs 512 signed-nibble score products over the two heads, plus nibble extraction and final score conversion. There is no claim that a native int4 dot beats BF16 or int8 at that score width; no native consumer was built or timed.

The complete observed region has a simple quotient. For coordinate `j` of group `g`, store `c[t,j] = clip(round((k[t,j]-b[g,j])/s[g,j]), -7, 7)` in a signed four-bit field. For either head, prepare `q'[u,j] = q[u,j] s[g,j]`. The reconstructed score is `sum_j q'[u,j] c[t,j] + sum_j q[u,j] b[g,j]`. The last term does not depend on the key position `t` and disappears under a causal softmax over a fixed group's keys. Thus the score consumer can use packed codes directly and never needs to restore `b` or reconstruct a 128-dimensional key. This is an identity over real arithmetic for the *quantized* key map, including clipped codes, not a bit-identity claim for floating-point reductions. The CPU evaluator reconstructs `s*c` in float64 to measure causal KL, so it does not time or validate a native packed-dot lowering.

A group-wide step collapses because a few coordinates dominate its clipping range: at layer 0 raw int4 scores 1.410302 KL, centered int4 .753084, while coordinate steps score .290594/.274418. Centering recovers dynamic range but cannot substitute for coordinate allocation. The next useful question is whether nibble extraction and the 512 scaled query coordinates can be fused into a native score consumer at real contexts, with the full key producer and model loss measured under quantized upstream states. A fresh quantized-producer held set should choose the cache arm before runtime adoption. This cache experiment does not solve the programme's poor complete-model weight quality.

`measure.py` replays the pinned Qwen3-0.6B original-producer train/validation captures and paid Q/K factors. Full per-group candidates, scale vectors, train choices, held per-window KL, source/model/capture/paid-image/prior hashes and cost fields live at `/path/to/workspace/data/kelana-subbit/key-nibble-cache/layer{00,14}.json`. Regenerate without GPU:

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-nibble-cache/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/key-nibble-cache/layer$(printf '%02d' "$layer").json"
done
```

Bonsai's GPU, executable and resident service were not touched.
