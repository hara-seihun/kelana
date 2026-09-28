# An affine A7 coordinate for the paid binary output factor

The second factor in the frozen Qwen3-0.6B `mlp_up` binary reader need not spend its signed seven-bit range around zero. Its 32-coordinate rank groups often have a nonzero center for a given input. Centering each group before the second A7 ladder, then restoring that center through the binary output factor, improves fresh held complete-response RMS by 5.3–7.0% on four layers. The paid factor signs, first A7 stage and FP16 scales stay fixed. This is a new approximate activation map, not a native speed or model-loss result.

## Exact consumer construction and bill

Let `h_g` be one group of 32 **integer** first-factor responses, `s_og ∈ {-1,+1}^32` one paid output-factor sign word, and `m_g = floor((min(h_g)+max(h_g))/2)`. Choose the usual two-choice A7 ladder from the group's centered radius `max_i |h_i-m_g|`, rather than `max_i |h_i|`. The global reference radius is the largest group radius, floored at one for the all-constant case. If `d_g = B w_g` is its group step, define `z_g = round_even(m_g/d_g)` and `q_g = clip(round_even(h_g/d_g)-z_g,-64,63)`. The exact integer response of this *chosen rounded map* is

```
Y_o = sum_g w_g [ dot(q_g,s_og) + z_g S_og ],   S_og = sum_i s_ogi.
y_o = Y_o B_1 B post_o.
```

`B_1` is the first stage's common scale and cancels when selecting second-stage codes. This algebra does not claim equality to the real binary product: the code clipping and rounding are intentional. The signed seven-bit packed activation bitplanes feed the same binary-sign popcount dot as before. `S_og` is an even integer from -32 to 32, so it can be computed from the sign word by one extra popcount, or stored offline as one of 33 six-bit values. The center correction is one integer product and addition per output/group; the group reduction and final float scale stay as before. Computing both extrema, zero points and centered quantization adds input-dependent preparation at each of twelve rank groups. There is no int4 weight expansion.

For this 3072-by-384 output factor, dynamic sign sums add 36,864 sign-word popcounts per token to its 258,048 A7 sign-word/bitplane pairs, plus 36,864 integer product/add corrections. The first factor's 86,016 bitplane pairs are untouched. A stored sign-sum alternative adds 27,648 bytes, exactly 0.0703125 bits per original 3072-by-1024 dense weight, to the existing 204,800-byte sign-and-FP16-scale image. That alternative trades offline bytes and sign-sum loads for the extra popcounts; it is not free. Packing six-bit sums also needs a reader, whose latency is unpaid. No new sign-sum payload is required for the dynamic-popcount arm.

A second, simpler coordinate quantizes `q_g = clip(round_even((h_g-m_g)/d_g),-64,63)` and computes `y_o = B_1 [ B sum_g w_g dot(q_g,s_og) + sum_g m_g S_og ] post_o`. It avoids a potentially huge integer zero point and reconstructs the center through a separate scalar correction after the common second-stage scale. That correction and the scaled dot must be summed before the final output scale, so the numerical FP32 map and native cost differ. Each `m_g S_og` fits signed int32 at this shape; their sum may require int64 or a floating reduction. The code stage retains the existing int32 accumulator bound. It also removes the division and rounded zero-point computation, while still requiring min/max, group subtraction and sign sums. Neither arm is declared the native winner before measurement.

For arbitrary signed first-stage A7 inputs at this shape, `|h_i| ≤ 1024·64·512 = 33,554,432`. The radius floor of one and the minimum positive group step imply `|z_g| ≤ 33,554,432·63·512 + 1/2`. The loose bound `12·512·(32·64 + 32·(33,554,432·63·512+1)) < 2.2·10^17` puts the entire second-stage corrected accumulator in signed int64. The old int32 guarantee does **not** apply to this affine form, because a nearly constant large group has a large zero point. The observed maxima are much smaller, below 7.7 million. An efficient native implementation must bound and narrow the zero points on its reachable producer or pay for int64 corrections. That is a real cost, not an ignored overflow.

## Fresh held response

`measure.py` uses the `.55` paid one-bit U/V `mlp_up` images at layers 0/7/14/27. It selects an optional rank-energy sort using 64 train rows `[512,576)` only. Validation rows `[576,704)` are fresh relative to the preceding rank-gauge panels. Both arms share the same first-stage integer response and compare against each image's FP64 unquantized two-factor response including pre/post scales. The symmetric control is the existing safe `.75` two-choice A7/C8 ladder. No teacher labels or original dense weight fit enter the affine choice.

| Layer | Identity symmetric / zero-point / separate-center RMS | Zero-point wins / 128 | Sorted symmetric / zero-point / separate-center RMS |
| ---: | ---: | ---: | ---: |
| 0 | .017568 / .016578 / .016624 | 110 | .017507 / .016522 / .016540 |
| 7 | .016352 / .015208 / .015328 | 124 | .016196 / .015247 / .015245 |
| 14 | .016095 / .015146 / .015182 | 116 | .015881 / .015127 / .015046 |
| 27 | .011046 / .010462 / .010407 | 103 | .010641 / .010259 / .010263 |

The gain persists with the rank coordinate sorted, but the sorted zero-point layer-7 map loses slightly to identity zero-point. The separate-center map wins the layer-14 sorted comparison without a zero point and wins layer 27 in identity order. Rank layout and group center are not interchangeable knobs. The symmetric-to-affine percentages for identity are 5.64%, 7.00%, 5.90% and 5.29%. These numbers describe a complete *two-factor response conditional on original-producer inputs*, not complete model NLL or an inference speedup. Groupwise floating A7 remains a stronger error control in earlier panels and spends separate floating partial scales; the consumer cost is why this integer alternative matters.

Run `OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-affine-rank/measure.py` to regenerate the [receipt](/path/to/workspace/data/kelana-subbit/binary-affine-rank/receipt.json). It binds the source, parent reader, paid images, activation fixtures, first-stage and final integer responses, per-input errors and zero points. No GPU reservation, Bonsai executable or resident service changed.

The next decisive comparison is a native *complete two-factor* center-aware reader against symmetric A7 and groupwise floating A7, including min/max prep, both correction schedules, int64 or proved narrower accumulators, both activation quantizers, factor traffic, output writes and one versus multiple rows. Before choosing a model image, test composed loss with quantized producer activations. A useful further code design would absorb sign-sum correction into the factor's native reduction or constrain learned rank groups so the center fits a narrow accumulator; simply reporting seven bitplanes as cheaper than eight conceals the offset work.
