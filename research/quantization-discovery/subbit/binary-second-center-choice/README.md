# How far should the paid binary A7 rank groups move their center?

The second-stage centered A7 consumer improves Qwen3-0.6B `mlp_up` response without adding weight bits. Its earlier midpoint choice was geometric, not fitted to the final output. I tested whether moving each input's group center toward or away from its mean improves the complete two-factor response. It does not on this fresh panel: the midpoint wins among ten rules on both training and held inputs at layers 0, 7, 14 and 27. This closes a cheap one-scalar calibration of the frozen group's activation center, not jointly learned factor signs or downstream model loss.

For the 32 integer first-stage responses in group `g`, put `m=(min+max)/2` and `u=mean`, and choose the integer center `c_α=floor(m+α(u-m))`. The sweep uses `α ∈ {-1,-.75,-.5,-.25,0,.25,.5,.75,1,1.5}`. It recomputes the group radii, shared base, eight-step ladder choice, zero point and clipped signed-A7 codes for every input and candidate. The exact selected integer consumer is

```
q_gi = clip(round_even(h_gi/d_g) - round_even(c_g/d_g), -64, 63)
Y_o = sum_g w_g [sum_i q_gi s_ogi + round_even(c_g/d_g) sum_i s_ogi]
y_o = Y_o B_1 B post_o
```

This is the same packed-sign, seven-activation-bitplane reader and dynamic sign-sum correction as [the midpoint construction](../binary-affine-rank/README.md). Every candidate has the same 204,800-byte frozen sign/scale image and the same logical popcount/dot/correction bill. A nonzero `α` also pays a group mean and multiply in the input-dependent preparation; it does not save a sign-word product. The response remains intentionally approximate to the FP64 same-image two-factor output.

The midpoint minimizes the maximum absolute distance to a group's endpoints among *all real scalar centers*: `max(|lo-c|,|hi-c|)=(hi-lo)/2+|c-m|`. For integer centers, either closest integer to `m` minimizes that radius. This does not prove it minimizes final response error, since clipping, rounding, correlated sign rows and group-step choices matter. It does mean a meanward move cannot lower the centered-range bottleneck within a fixed group; a final-response win must come from a changed error pattern. In this measured family no such win appears.

The paid `.55` binary-factor image and original-producer activation fixtures are frozen. Sixty-four training rows `[704,768)` choose one global `α` per projection; 128 different validation rows `[832,960)` evaluate it. Those held rows are disjoint from the midpoint report's `[576,704)` and earlier rank-gauge panels. The reference is each image's unquantized FP64 two-factor response, not the original dense model's logits. The first A7 stage, factor order, sign bits and scales remain fixed.

| Layer | Symmetric A7 held RMS | Midpoint held RMS | Mean center `α=1` held RMS | Train-selected `α` | Held RMS at `α=-.25/.25` |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .017460 | .016539 | .017326 | 0 | .016604/.016604 |
| 7 | .016315 | .015290 | .016189 | 0 | .015509/.015509 |
| 14 | .016115 | .015099 | .015951 | 0 | .015370/.015370 |
| 27 | .011848 | .011327 | .011785 | 0 | .011438/.011439 |

All 40 layer/candidate train and held scores, per-input held errors, exact integer-output hashes, source/parent/image/fixture/first-stage hashes and maximum observed integer/zero-point magnitudes are in [the CPU receipt](/path/to/workspace/data/kelana-subbit/binary-second-center-choice/receipt.json). Reproduce with `OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-second-center-choice/measure.py` from Kelana. The paired signs are unpacked only for this CPU experiment; the stated direct consumer uses the paid packed signs. No GPU, model NLL, native time, Bonsai executable or service changed.

The next useful quality question is not a denser scalar-center sweep on this frozen image. Fit factor signs and rank groups against quantized-producer composed MLP loss, or allow response-aware group codes instead of shifting an existing group around its mean. Native work is justified by the already stronger midpoint construction, not by this losing meanward preparation. Compare its complete two-factor reader, including zero-point correction and both activation quantizers, against int4 expansion and group-float A7 before selecting a runtime map.
