# Refit the scales already paid for in layer 0

The layer-0 binary MLP has 3,072 gate scales, 3,072 up scales and 1,024 down scales in its three packed images. Its initializer and individual response sweeps did not jointly fit those scales through `down(silu(gate(x)) * up(x))`. Fitting them as one composed response improves held post-MLP relative squared error from **.65752 to .63294**, with unchanged code bits, payload, dimensions and online work. The gain is larger than the paid rank-8 frozen-hidden correction's .63765 on the same 2,048-row train and 1,024-row held captures. The paid rank-32 correction still wins at .61904 but adds 264,192 bytes and 131,072 factor terms per token.

| Image, original-producer MLP input | Train relative squared error | Held relative squared error | Incremental payload |
| --- | ---: | ---: | ---: |
| Binary gate/up/down | .55581 | .65752 | 0 |
| Joint scales after 16 train steps, FP16 stored | .50414 | **.63294** | 0 |
| Frozen binary hidden plus paid rank-8 ridge | .51728 | .63765 | 67,584 bytes |
| Frozen binary hidden plus paid rank-32 ridge | .44955 | .61904 | 264,192 bytes |

This comparison is about matched held response, not model loss. The scale fit and the ridge corrections target different families and could be composed, but that composition has not been measured.

The script fixes the binary factor signs and input scales. With the reconstructed binary projections `G,U,D`, it trains log multipliers `a,b,c` on the complete FP32 map

`f(x;a,b,c) = (silu((x G^T) * exp(a)) * ((x U^T) * exp(b))) D^T * exp(c)`.

Adam takes 16 full-batch steps at learning rate .025 on 2,048 train positions, minimizing relative squared post-MLP error plus `.002 * (mean(a²)+mean(b²)+mean(c²))`. It never reads held positions to fit or stop. Each multiplier is merged into the corresponding existing row `scale_post` and rounded to FP16 before scoring. The packed U/V planes, `scale_pre`, shapes and number of scale slots remain unchanged; each of the three matrices retains 204,812 logical payload bytes. The NPZ container sizes differ slightly because compression ratios change. No new multiplication is needed at inference: the row scales were already used. Gate changes are genuinely nonlinear before down; up scales may equivalently be folded into the down input scales for a consumer that prefers that coordinate.

The end-of-fit ablations, not separately trained candidates, help locate the effect. Held error with only gate/up/down stored gains is .63833/.64282/.65412; gate plus up gives .63080, better than all three's .63294. That ranking was observed on the repeatedly inspected validation capture and must not be used as a blind image selection. It suggests that fitting down scales independently may overfit the original-producer sample. A train-only early-stop or shrinkage rule and a separate held corpus could settle that question.

`mlp_scale_fit.py --train-rows 2048 --steps 16` regenerates `full-model/mlp-scale-fit-2048.json` and the three paid packed matrices under `mlp-scale-fit-2048-image/` in `/path/to/workspace/data/kelana-subbit/`. The receipt hashes source, all six parent images, the BF16 capture and every output image. All arithmetic in the response panel is FP32 apart from rounding the stored FP16 scales; the full-model BF16 forward has not been run. The inputs come from the original layer-0 producer, not the damaged binary prefix or narrow V/O. CPU only; Bonsai's executable and service did not change.

This construction advances the next experiment from a hypothetical joint-code fit to a cheaper control. Capture the layer-0 MLP inputs after the quantized prefix and narrow V/O, refit the same existing scale slots on those inputs, then test gold loss through the remaining quantized model. Compare against a jointly refitted gate/up/down code image at equal bytes. Do not choose a native consumer from this original-producer squared-error result alone.
