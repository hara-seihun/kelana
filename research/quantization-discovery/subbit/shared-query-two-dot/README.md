# Two shared nibble dots do not beat independent heads

Two heads in one Qwen3-0.6B GQA group share a signed-nibble key cache. Could they also share one of their two query dots? I tested nine fixed affine query coordinates per group against independent one-dot-per-head scores on the frozen paid Q/K image. The train-selected coordinate barely moves held causal KL: layer 0 goes **.290584 to .290844**, and layer 14 goes **.362763 to .362415**. The latter gain is .000347 nat, with a regression on one of four inspected held windows. Unlike the preceding shared *three*-dot result, two-dot sharing does not buy enough quality on this image to justify its additional online preparation.

| Layer | Independent, train / held KL | Best fixed shared midpoint, held | Train-selected affine, train / held | Four-dot control, held |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .269119 / .290584 | .294719 | .269034 / .290844 | .275431 |
| 14 | .323905 / .362763 | .364371 | .323753 / .362415 | .332396 |

All KL figures compare teacher to candidate causal attention distributions across both query heads, eight groups and eight 256-token train or four repeatedly inspected validation windows. Inputs come from the original producer; Q/K projections use the paid binary image and K uses the parent train-selected signed-nibble cache. The four-dot control comes from the [same image and captures](../shared-query-base/README.md), not this script's execution. This is a CPU score-map negative inside a stated nine-coordinate family, not a universal two-dot impossibility or a new model-loss measurement.

## The map and its price

For two prepared real queries `a0,a1` and one cached integer key `c`, fix `alpha` per GQA group on the grid `{0,1/8,...,1}`. Prepare `m=(1-alpha)*a0+alpha*a1` and `d=a1-a0`. Quantize each independently to a dynamic signed nibble and dot them directly with the packed key. The scores are `dot(m,c)-alpha*dot(d,c)` and `dot(m,c)+(1-alpha)*dot(d,c)`, with their respective quantizer scales and the same `1/sqrt(128)` normalization. Without rounding this is the *exact real two-head score map* for any `alpha`; no original weight, BF16 key or int4-expanded intermediate is required. Rounding makes different `alpha` values different approximate maps. Endpoints share a base head, while `alpha=1/2` shares a midpoint. The independent control quantizes each head to one nibble and makes two dots, with the same frozen keys and full K-norm producer.

Both routes spend 512 signed-nibble coordinate products per cached key per layer and keep the 128-byte/token/layer K cache. The shared route additionally prepares 256 differences and 256 weighted combinations per query/layer and combines 16 head scores per key/layer with scaled additions. The non-endpoint arms require fractional coefficients or a scale folded into their prepared queries. Both routes find sixteen dynamic maxima and apply 512 key-step products per query/layer. The shared route has longer score lifetime; native register and instruction cost is unmeasured. Signed-nibble integer dots fit int32 since `32*7*7=1,568`. Floating scale association and softmax are not bit-identical across arms.

Every *globally fixed* non-endpoint grid point loses to independent one-dot heads on both held layers. Choosing a point on train per group wins just .000347 nat at layer 14 and loses .000259 at layer 0. The best train selection does not settle a learned query-dependent coordinate, joint integer rounding, a different paid producer or a finer affine grid. It does settle the cheap fixed shared-coordinate shortcut on this image. The third dot buys a real held gain: the [shared base plus difference](../shared-query-base/README.md) reaches .278608/.334929, at 768 instead of 512 nibble products/key/layer. Spend the next quality effort on training the paid producer and score consumer together on quantized-producer text, not on a native two-dot affine reader for these frozen codes.

## Reproduction and custody

`measure.py` uses the previous Q/K paid-image and key-code loaders, evaluates all nine alphas and the independent arm, and chooses each group's alpha only on eight train windows. Its two receipts at `/path/to/workspace/data/kelana-subbit/shared-query-two-dot/layer{00,14}.json` include every group's train/held window KL and selection, complete aggregate windows, source/model/capture/paid-image/parent hashes and online arithmetic counts. Run one layer with the installed CPU PyTorch environment:

```sh
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/quantization-discovery/subbit/shared-query-two-dot/measure.py --layer 14 \
  --output /path/to/workspace/data/kelana-subbit/shared-query-two-dot/layer14.json
```

No GPU, Bonsai executable or resident service changed.
