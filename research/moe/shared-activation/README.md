# A shared activation code for routed Qwen experts

The selected experts already share their gate/up input quantization in llama.cpp's HIP `mul_mat_id` implementation. The question here is narrower: can a *route-aware choice of one common activation scale* improve that code's weighted post-SwiGLU/down output enough to justify more work? We used the first sixteen official layer-0 BF16 experts and compared four symmetric quantizers on the **same** input vector and eight-expert route. This is a CPU quality/rate experiment, not a replacement for llama.cpp's particular Q8_1 arithmetic or a model-speed result.

The 128-sample panel uses 64 synthetic unit-normal inputs for selecting a static clip factor and 64 distinct inputs for evaluation. Each token selects eight distinct experts uniformly from sixteen and independently draws Gaussian-softmax router coefficients. The source and image hashes, seed, exact route generator and all candidate results are in [the receipt](/path/to/workspace/data/qwen-moe/shared-activation/receipt-128.json). Input codes are shared by all eight experts, including gate and up. BF16 weights are decoded to FP32, and the observation is the complete score-weighted sum of eight FP32 expert down outputs after SwiGLU. The shared expert, other layers and model state are outside the panel.

| Common activation code | Clip 1.0 held RMS | Train-selected clip | Selected held RMS | Held per-token preactivation oracle | Held per-token composed-output oracle |
| --- | ---: | ---: | ---: | ---: | ---: |
| Signed 4-bit | .20237 | .75 | .15841 | .15403 | .15083 |
| Signed 8-bit | .01141 | 1.0 | .01141 | .01141 | .01141 |

RMS is `sqrt(sum ||estimated weighted output - original weighted output||² / sum ||original weighted output||²)` over held samples. The Q4 static clip reduces squared routed error by 38.7% against max-based Q4, yet remains about fourteen times the Q8 RMS. At Q8 every held token's best composed candidate is the max scale, even with an oracle that evaluates all four complete expert responses. For Q4 that oracle gains only 4.8% relative RMS beyond the train-selected static scale. The 24-sample exploratory panel selected .625 on its twelve training inputs and lost to .75 on the other twelve; its receipt also contains a misindexed `held_composed_oracle_sse` diagnostic, fixed in the 128-sample source. The other preliminary fields use the correct indexing. Do not use that panel for selection.

## Finite-family certificate and charge

For a fixed token input `x`, route `R`, scores `a`, and four common codes `Q_c(x)`, let `Y` be the original weighted expert sum and `Y_c` the weighted sum after feeding the same `Q_c(x)` to all routed experts. Then `min_c ||Y_c-Y||²` is the exact per-token minimum **within this four-code shared-input family**. Summing these minima before taking the square root gives a lower bound on its held RMS for any selector, including one with free knowledge of the true output. The receipt enumerates all four responses and certifies this finite-family bound for the observed 64 tokens. It says nothing about other clip factors, per-expert codes, vector/group scales, trained weights or actual hidden states. The preactivation oracle minimizes `sum_e a_e² ||W_e(Q_c(x)-x)||²`; it is not generally the composed-output optimum because SwiGLU and cross-expert output interference change the objective.

At eight routed experts a Q4 input code occupies 1,024 packed bytes instead of 2,048 for Q8 before any block scales or alignment. That is a payload comparison, not a memory saving for this runtime: Q4 inputs need a new packed consumer or expansion, and the GGUF expert weights still dominate streaming. One scale and code creation per token costs one input scan and 2,048 round/clamp operations; choosing among four candidates by the measured composed objective needs four activation preparations and four complete eight-expert gate/up, SwiGLU and down evaluations, at least 4x those expert products plus scoring and code storage. The preactivation oracle still needs 4x gate/up products. Even the unattainable free Q4 selector barely improves the static Q4 result, and the Q8 selector has no headroom on these inputs. This rules out building a route-conditioned scalar clip chooser **for this family** on the strength of these synthetic outputs.

Actual routing and producer activations remain the necessary next input. Capture them under the pinned whole-model baseline, then compare an inexpensive *learned shared Q4 input code* with strong matched-rate controls and held language quality before pricing a packed HIP consumer. The complete-model sub-bit pilot lost language quality despite improving isolated responses, so this .158 routed RMS is not a reason to reduce the serving activation precision. A distinct exact-map question is whether Q8 activation preparation can be moved across more of the grouped consumer without changing its FP32 operation order; the existing gate/up sharing must be its control.

Reproduce without a GPU:

```sh
OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 python3 research/moe/shared-activation/measure.py \
  --samples 128 --output /path/to/workspace/data/qwen-moe/shared-activation/receipt-128.json
```
