# One-byte cache for the paid shared-value consumer

The rank-28 shared V/O image stores .53060 bits per V/O weight, but its narrow BF16 value cache still costs 448 logical bytes per token per layer. I asked whether a single static scale per GQA group lets each of its 224 coordinates use one byte without changing the packed weight image or rebuilding a 128-coordinate value. On the original-producer causal captures, E4M3 does, with a small additional post-O error. This is a cache-coordinate result, not a new sub-bit weight rate or a native speedup.

Decode the *same frozen paid* `layerXX-joint-r28.npz` factors as the value-observer study. For each group, form `z=(x Bᵀ).bf16.float()`. Pick one static E4M3 or E5M2 scale by minimizing train-coordinate mean squared error among sixteen candidates derived from the 95th, 99th, 99.9th and 100th percentiles times {.5, 1, 2, 4} divided by the finite format's largest code. The int8 group-scale control uses the same rule. An int8 control with 28 separate scales per group uses the same train selection independently for each coordinate. Freeze every scale before four validation windows. The two query heads share the rounded cache and use their original causal Q/K probabilities and paid O slices. Both the BF16 cache and one-byte candidates are compared with the original V/O causal post-O output.

| Layer | BF16 cache | E4M3 group | E5M2 group | Int8 group | Int8 per coordinate |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 held relative squared post-O error | .378887 | .379186 | .379788 | .378972 | .378895 |
| 14 held relative squared post-O error | .326195 | .326527 | .327328 | .336933 | .326377 |
| 0 train | .222819 | .223209 | .224103 | .222931 | .222867 |
| 14 train | .164176 | .164520 | .165933 | .177320 | .164581 |

Layer 14 is the discriminating control: one int8 step for all 28 coordinates raises held error by .010738, while one E4M3 scale per group raises it by only .000332. Paying for 28 int8 scales recovers most of the gap, at 448 FP16 metadata bytes per layer rather than E4M3's 16. On layer 0 the per-coordinate int8 cache nearly reproduces the BF16 post-O error. E4M3 changes the *candidate versus BF16 output* relative squared norm by .000444/.000570 on train and .000436/.000542 on held for layers 0/14. The receipts record every window. The two formats are different numerical maps, so closeness to BF16 is not an exactness statement.

The weight image stays 208,640 bytes per layer, .53060 V/O BPW, with the same 688,128 signed factor terms per token. Logical V cache falls 448→224 bytes/token/layer and full K+V falls 2,496→2,272 because the original K remains 2,048. A straightforward group-padded layout uses eight 32-byte slots instead of eight 64-byte BF16 slots, so the realizable V cache falls 512→256 bytes and K+V 2,560→2,304. This does **not** change the 28-coordinate producer or the two-head score work. E4M3 writes require 224 conversions and scale divisions per token; reading codes needs conversion and group scaling, which may be applied to the weighted narrow result once per head/group if a changed FP rounding map is acceptable. Native hardware timing must price those conversions, cache-line requests and accumulation. The per-coordinate int8 arm instead needs 224 separately scaled values per token and potentially per-key reconstruction unless its coordinate scales are carried through attention; it is a stronger quality control, not a free native competitor.

The evidence is eight 256-token train windows and four repeatedly inspected validation windows for each of layers 0 and 14. The hidden states come from the original BF16 model, not a repaired quantized producer. There is no fresh gold loss, native latency, executable change or service interruption. Both one-byte arms use a fixed scale per group across tokens, so no token-dependent scale is hidden outside the counted work. The next useful experiment is a direct narrow-V cache consumer that reads packed E4M3 at a real context and compares its *complete* attention and O time with BF16 narrow V, per-coordinate int8 and the equally paid independent binary V/O image. Freeze a quantized-producer language-quality panel before selecting the map for serving.

The source is `measure.py`. `/path/to/workspace/data/kelana-subbit/value-fp8-cache/layer{00,14}.json` holds image, capture, model and source SHA256s, all scales, train coordinate MSE, and every train/held causal response error. From a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-fp8-cache/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-fp8-cache/measure.py --layer 14
```
