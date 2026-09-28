# Paid binary up-scale gains through a complete MLP

The Qwen3-0.6B layer-0 `mlp_up` image has 3,072 FP16 post-scale slots. Replacing their values after a 256-row teacher-response fit lowers complete held MLP response error, including the SiLU gate and down projection. The gain persists when the layer-0 input comes from a damaged Q/K, norm and narrow V/O producer rather than the original producer. It uses the same 204,800-byte up image, .520833 bits per up-weight, and the same two-stage packed-sign A7 consumer. No int4 expansion, new scale read, or additional online multiply is needed.

We used the paid .55-target binary up image, its safe `.75` seven-bit integer ladder at *both* factor boundaries, and the actual BF16 MLP inputs captured by the [quantized-producer study](../full-model/mlp_quantized_scale_fit.py). The teacher target for each input `x` is `W_down [SiLU(W_gate x) ⊙ (W_up x)]`. The control substitutes the complete direct binary-factor A7 response for `W_up x`, keeping original BF16 gate/down weights. Matrix products and SiLU are replayed in FP64 here. This is a complete nonlinear MLP observation, not a language-model NLL result or an installed native reader. The damaged producer changes the input, but this experiment does not quantize the gate/down projections. The capture's validation windows were examined in earlier work; the 128 held rows below are disjoint from this fit, not untouched model acceptance text.

The exact same 256 train positions `[320,576)` and 128 validation positions `[576,704)` are paired across original and damaged producers. Each output scale is fitted to the *original up-weight response at that producer input*, with nonnegative least squares, then rounded to FP16. A 64-row arm uses the last 64 train positions. A paired 512-row fit concatenates both producers. Scalar MLP fits serve as low-variance controls; they round their shared gain through the same existing FP16 slots.

| Held MLP relative FP64 RMS | Original producer | Damaged producer |
| --- | ---: | ---: |
| Parent A7 up image | .627981 | .610348 |
| 64 original-producer up response fit | .613601 | .594218 |
| 256 original-producer up response fit | .611295 | .590512 |
| 256 damaged-producer up response fit | .611935 | **.587859** |
| Paired 512-response up fit | .611112 | .588679 |
| Original-producer fitted scalar on full MLP | **.608140** | .606461 |
| Damaged-producer fitted scalar on full MLP | .608865 | .602062 |

The damaged-producer 256-row fit reduces complete held MLP RMS 3.68% relative to its parent, and beats the original-producer row fit by .002653 absolute RMS on the same damaged held inputs. A scalar chosen on the original MLP beats either rowwise fit *there* while badly trailing on damaged held inputs. This is why a projection-only scalar choice is not a reliable serving choice after the producer changes. The 64-row original fit that lost held *up projection* RMS in the earlier study still improves the nonlinear MLP output, an explicit example of the observation changing the ranking. On original held inputs, the original-producer up response fit reproduces the earlier projection result .671464→.666439; the new reader's integer output matches its source implementation bit for bit on a checked held row.

The gain is a concrete free-scale candidate, not a selected model image. The original and damaged producer results should be compared on fresh complete-model gold loss with *paid* gate/down maps and BF16 execution. A good next construction fits these already-paid scales directly to the full quantized-producer MLP endpoint or gold loss, then compares to a joint sign/scale fit. An expanded int4 or BF16 replay cannot supply native speed evidence; the promised cheap consumer is still the packed-sign A7 program, and its complete native runtime against matched alternatives remains unmeasured.

`measure.py` reproduces the CPU panel with `OPENBLAS_NUM_THREADS=6 python3 research/quantization-discovery/subbit/binary-up-composed-gain/measure.py`. [The receipt](/path/to/workspace/data/kelana-subbit/binary-up-composed-gain/receipt.json) binds source, parent reader, paid image, captured producer, gate/up/down weights, replacement FP16 scales, per-arm responses and both row splits. No GPU, Bonsai executable or service changed.
