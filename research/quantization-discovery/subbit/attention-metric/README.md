# Fitting Q's attention consumer, not its raw projection

Qwen3 does not consume its Q projection as a raw Euclidean vector. It reshapes it into 16 heads of width 128, applies a learned per-head RMSNorm and RoPE, computes causal Q/K logits, and uses the resulting probabilities to mix V. RMSNorm strongly reduces sensitivity to positive per-head Q rescaling and removes it exactly when epsilon is zero. A logit change constant across one query's visible keys disappears at softmax. The useful error therefore depends on K, positions and the later O projection. The [rank-88 packed four-bit Q image](../SPECTRAL.md) has lower raw projection error than the initial NanoQuant binary image but worse complete-model teacher KL. This study targets that mismatch without buying another parameter.

The seed image is `/path/to/workspace/data/kelana-subbit/spectral-quant/layer00-self_attn_q_proj-b0.539062-l4r4-g128-s0.5-f1.npz`. Its two factor planes, per-group FP16 scales and 32 descriptor bytes total **140,704 payload bytes**, `.53674` bits per original Q weight, and 270,336 logical factor terms per vector. The output is still `A(Bx)`. `refine.py` changes only the **4-bit left-factor code plane**. Right codes, both scale arrays, rank, groups, two-stage calculation and packed row layout remain identical. The final image is `/path/to/workspace/data/kelana-subbit/attention-metric/final/layer00_q_rank88_attention_refined.npz`, SHA256 `c4cc8051e4a10e60edacb5010e98967f0b1223b8a0217d61c7c2cdadc250774a`. Its serialized `.npz` has 142,248 bytes. The parent programme subsequently measured this exact image with the existing direct packed consumer and ran complete-model single-projection continuation. [The combined result](../RESULTS.md) records both, including the stronger binary control and the validation/test difference.

## Consumer and calibration

The pinned Qwen3-0.6B layer-0 `q_proj` fixture supplies eight nonoverlapping WikiText-2 raw train windows and four disjoint validation windows of 256 tokens each. The script reads the original K, V and O weights, Q/K RMSNorm weights and Q fixture inputs from the pinned model. It computes BF16-rounded Q/K/V projections, per-head RMSNorm, RoPE with theta 1,000,000, 16 Q heads to 8 repeated K/V heads, causal log-softmax, attention-weighted V and O projection. CPU float32 matmuls implement the consumer; BF16 casts at projection and norm boundaries approximate the model path. It is not a byte-identical GPU SDPA implementation or complete-model continuation. Raw projection response, post-norm Q error, causal attention KL and post-O response error are all reported separately.

There are two binary controls. The [binary-postfit image](../spectral-residual/README.md) keeps ADMM signs and input scales while fitting its output scales. The stronger four-sweep image at `/path/to/workspace/data/kelana-subbit/block-factor/control-layer0-q.npz`, SHA256 `f6c620ec721b81e50a6bbc6cf98cebc246b0041918ee161cdbea41a33a889f87`, uses [block-factor's exact train-response output-coordinate updates](../block-factor/fit.py) and costs `.53906` matrix BPW. Its packed bytes are the worker's original artifact, not a reconstruction in this study.

The final rank-88 fit used 30 Adam steps, learning rate `.3`, and a straight-through rounded/clamped left code in `[0,15]`. The objective is mean causal teacher-to-candidate attention KL plus `2 ×` relative squared response error after attention V and O, plus `.5 ×` squared relative post-norm/rotary Q error. Teacher K and V remain original. Training uses all eight windows; validation does not enter an optimizer step. The 30 CPU steps took **3.64 wall seconds on eight threads** and changed **124,461 of 180,224** four-bit left codes. This is a large code reassignment, not a scale adjustment. Hyperparameters were explored on validation with additional KL-only and output-weighted runs; the final result is exploratory, not an unseen-test estimate. The parent programme's subsequent frozen pilot check uses its separate test windows; [RESULTS.md](../RESULTS.md) records that continuation.

## Matched held-out consumer responses

All numbers below use the same four validation windows and original K/V/O. Smaller is better. The raw Q column is squared relative projection error, while the post-O column is squared relative error after causal attention and the O projection. Attention KL averages over visible-key distributions for each query and head.

| Q image | Raw Q error | Post-norm Q error | Causal attention KL | Post-O error |
| --- | ---: | ---: | ---: | ---: |
| Rank-88 four-bit seed, .53674 BPW | **.08145** | .18618 | .11204 | .03308 |
| Binary ADMM with train-response scales, .53906 BPW | .09296 | .18307 | .10490 | .02239 |
| Binary with four output-coordinate sweeps, .53906 BPW | .06962 | **.15075** | .08164 | .02165 |
| Rank-88 four-bit Q-consumer fit, .53674 BPW | .15121 | .16950 | **.07776** | **.01964** |

The refined image improves the stronger binary control's attention KL by `.00388`, about 4.7%, and post-O squared error by `.00201`, about 9.3%. Its raw Q error is **more than twice as large**. That contrast is the useful result: the attention consumer has equivalence classes and directions that raw projection MSE penalizes incorrectly. The stronger binary control still has better post-norm Q error and much better raw Q error. Train attention KL for the refined image is `.02684` versus `.07776` on validation, so it has considerable train/validation gap. An earlier unregularized KL-only 20-step fit reached train `.03303`, validation `.09958`, and post-O validation `.02763`. Adding the Q-direction term produces a better held-out attention response without giving up the original two-factor storage and work budget.

The post-O error is the output of the isolated attention subgraph on original layer input, not a language-model loss or teacher-distribution KL. The parent programme's `continuation.py` consumed the final NPZ unchanged and compared it with the same binary-coordinate control. Test NLL and teacher KL improve, while validation NLL and teacher KL remain slightly worse. The [combined report](../RESULTS.md) retains that split-dependent result rather than substituting the isolated attention score for model quality.

## Reproduce

```bash
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/attention-metric
O=/path/to/workspace/data/kelana-subbit/attention-metric/final
$P "$D/refine.py" --steps 30 --lr .3 --output-weight 2 \
  --q-direction-weight .5 --out "$O"
```

The report beside the image records source paths, code-change count, the full loss trace and train/validation values. No GPU reservation or serving change was used.
