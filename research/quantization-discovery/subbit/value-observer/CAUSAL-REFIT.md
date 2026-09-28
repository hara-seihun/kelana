# Refit the causal consumer after pruning its value basis

The 192-coordinate shared V/O image at .466797 BPW was made by deleting blocks from an already trained rank-28 image. Its left codes still solve the old 224-coordinate problem. Two train-only coordinate sweeps over the retained two-bit left codes and their FP16 row/head scales recover held causal response error without storing another byte. This is useful even though the ranks, right codes and right scales remain frozen.

| Layer | 192-coordinate image | Held error before | Held error after | Train error after |
| ---: | --- | ---: | ---: | ---: |
| 0 | uniform rank 24 | .416947 | .407794 | .251509 |
| 0 | train-optimal frozen prefix allocation | .391723 | **.385779** | .233558 |
| 14 | uniform rank 24 | .353041 | .340384 | .178130 |
| 14 | train-optimal frozen prefix allocation | .339522 | **.330364** | .170966 |

Each refitted allocation beats the corresponding uniform control at the same rate. The fitted selected images reduce held error 5.40% at layer 0 and 2.94% at layer 14 against fitted uniform 24, and all four validation windows improve over their own pre-fit images in both layers. They still lose to the more expensive rank-28 images at .378887 and .326195. The remaining gap is .006891 and .004169; this particular low-rate construction has not matched the full-rank image.

## Observation and payment

The training observation is the complete 1,024-dimensional causal post-O output on eight disjoint 256-token original-producer windows. Q/K, their normalization, RoPE and attention probabilities come from the original BF16 model. The validation observation uses four separate 256-token windows. The right factor projects each original layer input into group-specific narrow values; those values round to BF16 before attention, just as in the prior causal-pruning study. With the right codes, scales and rank frozen, the output is linear in each left code. `causal_refit.py` caches the 384-dimensional train feature Gram, selects each two-bit row code by its conditional squared-error optimum, and then fits one nonnegative FP16 scale per row and query head. Two sweeps update codes on train only. The script reopens every packed image and checks its decoded left coefficients against the fitted coefficients.

Each paid image remains 183,552 parameter bytes for 3,145,728 original V/O weights, or .466797 BPW. The train-selected layer-0 ranks are 28,28,28,28,28,4,28,20 and the layer-14 ranks 28,28,28,8,28,16,28,28. Their 589,824 signed-grid terms per token, 384 BF16 logical value-cache bytes per token and the original K cache are unchanged. FP16 scale fitting and code selection happen offline. Native instruction count, rank-padding effects and cache behavior are not measured.

The records `/path/to/workspace/data/kelana-subbit/value-observer/layer{00,14}-causal-refit-{uniform_24,train_causal_optimum}.json` bind source, model, capture, input image, output image, rates, train/validation errors and every validation-window score. Their paid packed NPZ images sit beside them. Selected image SHA256 is `ae9baecdeb801e6fedfe654a258e2991715c3624d3c4e8ea38d72af914d0f48d` for layer 0 and `08970299931d4daad1e5ace941517e96dceb2eefcb110cae0353b92b898b0abb` for layer 14.

Run one bounded CPU fit per invocation from Kelana:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-observer/causal_refit.py
OPENBLAS_NUM_THREADS=1 "$P" "$D" --layer 0 --arm train_causal_optimum --sweeps 2
OPENBLAS_NUM_THREADS=1 "$P" "$D" --layer 0 --arm uniform_24 --sweeps 2
OPENBLAS_NUM_THREADS=1 "$P" "$D" --layer 14 --arm train_causal_optimum --sweeps 2
OPENBLAS_NUM_THREADS=1 "$P" "$D" --layer 14 --arm uniform_24 --sweeps 2
```

This is a conditional fit with frozen original-producer right factors, not an all-layer quantized model or native speed result. The next useful test substitutes the selected and equal-rate uniform images one layer at a time on fresh text, then refits the right basis on quantized-producer causal features if the quality ranking survives. A larger search over frozen 28-coordinate block masks is less promising than changing the basis that the consumer sees.
