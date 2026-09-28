# Integer-only group reduction for binary factors

The paid one-bit U/V factors have a better activation coordinate than either a single global A8 scale or a separate floating scale for every 32-coordinate group. Choose each group's A7 step from a shared power-of-two ladder, optionally inserting `3/4` of the next larger step. Both factors then reduce their signed integer dots with integer shifts, an optional multiply by three and integer additions. Only the final output needs a floating scale. On the frozen Qwen3-0.6B images, the two-choice A7 ladder has lower mean response RMS than global A8 in all four measured projection families, at seven rather than eight AND/popcounts per sign word. It does **not** beat unconstrained group-32 A7 quality, nor establish a native speedup or good model loss.

## The complete two-factor map

For signed `b`-bit activations `a` and a group `g` of 32 signs, let `Q=2^(b-1)-1`, `M=max_i |a_i|` over the vector and `m_g=max_{i in g}|a_i|`. Set `e_g=min(C, floor(log2(M/m_g)))`, with zero groups assigned `C`. The larger admissible step is `s_g=M/(Q 2^e_g)`. For the two-choice arm, use `3s_g/4` when `m_g/Q <= 3s_g/4` and `e_g<C`; otherwise use `s_g`. Rounded-to-even signed codes are `q_i=clip(round(a_i/step_g),-Q-1,Q)`.

With common `B=M/(Q 2^(C+1))`, the two-choice group step is either `B 2^(C+1-e_g)` or `B 3·2^(C-1-e_g)`. The one-choice ladder instead uses `B=M/(Q 2^C)` and `2^(C-e_g)`. The code `measure.py` computes each group's signed integer dot and reduces it with those integer multipliers. The same dot can consume the stored sign bits by the [bitplane identity](../binary-bitplane-dot/README.md); no weight or activation needs to expand to int4. Let the first stage's integer output be `h_int` and its common scale `B_1`. The second stage chooses its group steps from `h_int`, so scaling all its inputs by `B_1` cancels inside quantization. Its integer output `y_int` is converted only at the final boundary: `y = y_int (B_1 B_2) scale_post`. The pre-scale is applied to the original input as in the parent binary image.

This is exact integer arithmetic after each chosen rounding, not equality to the original real binary-factor response or to an FP32 contraction. At `C=8,b=7`, the maximum absolute group multiplier is 512. For the largest factor input here, `K=3072`, `|y_int| <= K·64·512 = 100,663,296`, so signed int32 suffices even on an adversarial A7 input. The script uses int64 for its CPU sums. For other ranks, bit widths or caps, check `K·2^(b-1)·2^(C+1)` before choosing an accumulator. The optional three-way product is a constant integer multiply or shift-plus-add, not a free scale.

## Frozen paid-image measurement

`OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-shifted-scales/measure.py` reads sixteen `.55` paid binary-factor images and the same first four previously inspected validation rows/image used by the parent bitplane study. The denominator is each image's own FP64 response, with pre/post scales. Means of sixteen relative RMS errors per projection:

| Projection | Global A8 | Group-32 A7 float scales | A7 power ladder, C=8 | A7 two-choice ladder, C=8 | Two-choice wins over global A8 |
| --- | ---: | ---: | ---: | ---: | ---: |
| MLP down | .042752 | .015625 | .020606 | .018230 | 16/16 |
| MLP up | .019066 | .014146 | .018380 | .015923 | 11/16 |
| Attention O | .022141 | .015064 | .020308 | .017554 | 13/16 |
| Attention Q | .019520 | .012984 | .015568 | .014525 | 7/16 |

The extra `3/4` step recovers much of the quality lost by coarse power steps, but the Q and up wins are inconsistent across inputs. A7 has seven bitplane AND/popcounts per sign word, versus eight for global A8. For `mlp_up`, both factors together contain 49,152 sign words, so that saves 49,152 such pairs. Group-32 float scaling requires 49,152 floating partial products plus group reduction; this arm replaces them with 49,152 integer constant multiplies/shifts and integer reductions, then `N` final floating output scales. It also pays `K/32+R/32` maxima, exponent choices, quantization steps and bitplane preparation per query, the rank intermediate and unchanged pre/post weight scales. The exact grouping changes the floating reduction map. None of these instruction classes has been timed on gfx1151.

The receipt at `/path/to/workspace/data/kelana-subbit/binary-shifted-scales/receipt.json` records source SHA-256 `9535bd8843ea071abdc67e3ebc3309b24cbc5516fde793b1ffceb493b246d94d`, every input image/fixture SHA-256, four per-input errors for A5/A6/A7 at caps 4/8/12, group-float and global A8 controls, exponent ranges and integer maxima. The CPU implementation uses unpacked signs to evaluate the same group dot, and the parent study separately checks the packed-bitplane identity; this receipt is a response-quality/cost-construction experiment, not a native packed-reader timing.

Next compare this *complete* two-factor A7 reduction against global A8 and grouped floating A7 on gfx1151, including exponent selection, both quantizers, the rank intermediate, final scales and output writes. If shifts and exponent preparation cost more than the saved popcount and floating reductions, co-design the activation code with the sign-factor rows rather than increasing ladder resolution blindly. Check composed Qwen loss on quantized-upstream text before selecting a lossy engine map. No GPU, Bonsai executable, service or default changed.
