# A partial second nibble dot does not recover the causal score

The [direct integer consumer](../nibble-query-lowering/README.md) needs two full signed-nibble dots against each cached key to approximate a floating query. I tested whether the second dot can cover only a fixed subset of query coordinates. At 16 of 32 coordinates per head and group, the extra dot arithmetic falls by half, but layer-14 held causal KL stays .01364 above a full second dot. Even 24 coordinates leave .00573. This fixed sparse correction is not a convincing replacement for the second full dot.

| Layer | One dot | +4/32 | +8/32 | +16/32 | +24/32 | Full second dot | Prior dynamic eight-bit split |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .290584 | .287649 | .284792 | .281867 | .277886 | .275381 | .275431 |
| 14 | .362763 | .357986 | .354146 | .346036 | .338124 | .332397 | .332396 |

Values average teacher-to-candidate causal KL over two query heads, eight KV groups and four previously inspected validation windows of 256 tokens each. All arms use the same frozen Qwen3-0.6B binary Q/K weights, 128 RoPE planes, train-selected group key arm and coordinate-scaled signed-nibble keys. The 128-byte paid key cache and full 1,024-row K norm producer do not change. The original-producer captures are exploratory, not fresh model-loss evidence. The train-only coordinate ordering and per-group/window scores are in the JSON receipts; no validation label or statistic chose a coordinate.

For each query and group, let `a_j=q_j*s_j`, `d=max_j|a_j|/7`, `z_j=round(a_j/d)` clamped to `[-7,7]`, and `r_j=round(16(a_j/d-z_j))` clamped to `[-8,7]`. The direct score against stored signed nibble `c_j` is

```
(d / sqrt(128)) * (sum_{j=0}^{31} z_j c_j + sum_{j in S} r_j c_j / 16).
```

Both inner sums are exact signed integers within int32. The full second sum approximates the prepared floating query with at most `d/32` per coordinate except for the asymmetric `+8` correction clipped to `+7`, where the bound is `d/16`; the one-dot bound is `d/2`. This is a different quantization grid from the earlier dynamic signed-eight-bit split, which selects `d8=max|a|/119`. The two full-dot results agree to .00005/.000002 mean KL at layers 0/14. The real score formula is not a bit-identical FP32 GPU assertion.

For each group, the fixed order `S` sorts the 32 coordinates by their eight-train-window mean of `(d*r/16)^2` multiplied by the train key-code second moment. This diagonal score-error proxy is cheap and uses no teacher labels. It is not the finite causal optimum. The order is shared by the group's two query heads. A model image could permute its 32 stored key coordinates once to put the selected prefix next to each other, and permute the corresponding query preparation and step table. Without that layout, a selected key gather is an extra online cost; the CPU replay does not time either layout.

The base dot costs 512 nibble products per key per layer across both heads. An `m`-coordinate correction costs another `16m` products/key, so 4, 8, 16 and 24 cost 576, 640, 768 and 896, versus 1,024 for the full second dot. It also costs `16m` query residual rounds/token/layer, one full 512-coordinate step preparation, per-query scale, and a second scaled score contribution per head/group/key. The fixed order costs at most `5m` bytes/layer if stored as 5-bit coordinate IDs over eight groups, or can be absorbed by a fixed offline key/query permutation. Group centers still cancel in real causal softmax. No full-key expansion into int4 or BF16 is needed. A native implementation must price query packing, two-dot scheduling, key layout, FP scaling and occupancy before any speed claim.

The layer-14 train ordering does improve all four aggregate held windows at each correction width, yet the 16-coordinate arm recovers only about 55% of the one-to-two-dot KL improvement while retaining 75% of the two-dot product count. At 24 coordinates it recovers about 82% with 87.5% of that count. Those are quality/work tradeoffs, not native runtime ratios. A different query/key coordinate learned for one-dot score quality, or an adaptive correction with its selection and gather costs paid, is a better next question than adding sparse fixed coordinates to this frozen image. Fresh quantized-upstream and complete-model loss are still needed before timing a native consumer.

`measure.py` replays the frozen image, chooses each group's coordinate order on eight train windows and records every train/validation window and group, plus source/model/capture/image hashes, in `/path/to/workspace/data/kelana-subbit/nibble-query-sparse/layer{00,14}.json`. From a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/nibble-query-sparse/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/nibble-query-sparse/layer$(printf '%02d' "$layer").json"
done
```

CPU only; no Bonsai executable, GPU or resident service changed.
