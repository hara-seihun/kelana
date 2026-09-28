# Route-fitted down gains on Qwen's actual Q5_K image

The first cheap route-aware correction does not pay. In the pinned UD-Q4_K_M model, routed layer-0 down weights are Q5_K. Their first sixteen expert slices differ from the official BF16 weights by .04219 relative weight RMS. On 96 held synthetic routed inputs, their weighted down sum has .02993071 relative output RMS. Fitting a scalar gain for every expert to the **whole routed sum** lowers train error and raises held error; rounding those gains to the proposed FP16 representation makes the held regression slightly larger. This closes the frozen scalar-gain arm on this input distribution. It says nothing about a newly coded down matrix, real producer inputs, real router scores, or gold language loss.

## Observation and exact fit

For shared input `x`, use the official BF16 gate/up tensors to form each `h_e(x) = SiLU(G_e x) * U_e x`. Let `D_e` be official BF16 down, `Q_e` the dequantized GGUF Q5_K down, and `a_e` the top-eight router coefficient. The observed real map is `y = sum_e a_e D_e h_e`; the proposed approximate map is `sum_e a_e g_e Q_e h_e`. The same `x` enters all experts, so fitting one expert at a time is not generally optimal for the sum.

Stack `v_e = a_e Q_e h_e` across all training outputs and `y` across the same rows. For unrestricted real scalar gains, the global squared-error minimum obeys `G g = b`, with `G_ef = <v_e,v_f>` and `b_e = <v_e,y>`. The script solves this 16-by-16 positive-definite system (condition 5.315 on the panel). Independent fitting instead minimizes each expert's own response error and ignores its off-diagonal interactions. This is an exact least-squares optimum within the **fixed 16-scalar linear-gain family on these train observations**; it is neither a full-model optimum nor an FP32 bit-identity. The output arithmetic in NumPy may associate differently from llama.cpp.

## Held comparison at one declared rate

[The receipt](/path/to/workspace/data/qwen-moe/routed-down-gains/README.md) uses separate 96-input train and held panels, normal FP32 inputs shared across experts, eight experts uniformly drawn without replacement from the available sixteen per input, and independently softmaxed normal scores. The two panels share no input/route draws. Gate/up and the teacher down are original BF16; only the selected down image comes from the **actual mixed-Q4 GGUF**. The Q5_K decoder is `dequantize_row_q5_K` in the pinned local `libggml-base`. The absolute model's router, producer distribution, attention and shared expert are not represented.

| Down arm | Train routed relative RMS | Held routed relative RMS | Added payload |
| --- | ---: | ---: | ---: |
| Actual Q5_K, no gain | .03032640 | .02993071 | 0 |
| Independent expert gain, unrestricted FP64 oracle | .03032502 | .02993024 | Not a paid image |
| Joint route-sum gain, unrestricted FP64 oracle | .03032353 | .02993398 | Not a paid image |
| Independent gain rounded to FP16 | .03032687 | .02993139 | 512 bytes/layer for 256 experts |
| Joint gain rounded to FP16 | .03032411 | .02993487 | 512 bytes/layer for 256 experts |

The joint fit can remove only 0.0094% of train RMS against unadjusted Q5, while held error rises 0.0109% in the FP64 oracle and 0.0139% in the paid FP16 arm. The sixteen FP16 gains take only three distinct values. On held inputs the cross-expert Q5 error term is -0.13% of total squared route error; on train it is +0.25%. There is no persistent aligned quantization error for one scalar per expert to cancel here. The independent FP64 oracle's tiny held improvement disappears at FP16 rate.

A 256-expert gain vector would add 512 FP16 bytes per layer, 20,480 bytes for forty layers, beyond the 184,549,376-byte Q5_K layer-0 down bank. At inference the selected eight router coefficients each need one additional multiplication to absorb `g_e` before the down projection; the expert matmul and weighted output reduction stay. A new scale load and any separate scatter or launch would make the price worse. No native consumer, GPU time, full-model TPS or NLL changed. Even a zero-cost real-gain oracle has too little headroom under this synthetic observation to justify that engineering.

The next question is *where the error lives*, not a more elaborate scalar correction on these draws. Capture real router IDs/scores and the routed `h_e` from the baseline, then compare the complete weighted down sum with (1) Q5_K, (2) equal-byte expert-aware recoding, and (3) output-coordinate codes trained on separate text. A route-composed advantage there must survive held logits or language loss and a native packed consumer. The dense sub-bit pilot's complete-image failures are the reason to keep that final check instead of selecting by one layer's response RMS.

Run from a Kelana writer checkout:

```sh
OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/moe/routed-down-gains/measure.py --train 96 --held 96 \
  --output /path/to/workspace/data/qwen-moe/routed-down-gains/receipt.json
```
