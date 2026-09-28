# Tying nibble-key steps to RoPE planes

The frozen 128-plane paid Q/K score observer stores signed-nibble keys with one FP16 step for each of 256 selected post-RoPE coordinates. Could one step per two-coordinate RoPE plane halve that table and let query scaling commute through RoPE? The algebra works, but the tested finite-causal map loses attention quality. At layer 0 the best train-selected arm tested here raises held KL from .275403 to .307817; at layer 14 it raises .332292 to .343233. Layer 14 loses in every KV group. This rules out replacing this image's coordinate steps by a simple tied-step quantile or a tied aggregation of its paid steps.

| Layer | Independent coordinate steps | Train-selected plane steps | Difference |
| ---: | ---: | ---: | ---: |
| 0 | .275403 | .307817 | +.032414 |
| 14 | .332292 | .343233 | +.010941 |

Both heads, all eight groups and four previously inspected validation windows contribute to each teacher-to-candidate causal KL. The teacher has original Q/K on the same original-producer hidden inputs; candidate Q/K are the frozen paid binary images with the 128 selected planes, full raw K RMS denominator and the parent's train-selected raw/centered arm per group. Its centers and paid coordinate steps do not move. The plane-step choice sees eight train windows only. Each group selects the lowest finite train causal KL among four pooled paired-coordinate residual quantiles at .99, .995, .999 and 1, and four tied combinations of its two paid coordinate steps: min, max, geometric mean and arithmetic mean. The parent coordinate control uses exactly its frozen FP16 steps. The paid Q/K image, nibble key bytes and score boundary are the same in both arms. The experiment does not re-optimize centers, codes, factors or gains.

For any two-dimensional RoPE rotation `R(theta)` and diagonal step `D=diag(s0,s1)`, `D R(theta) = R(theta) D` for all positions if and only if `s0=s1`. Indeed, their upper-right entries differ by `(s1-s0) sin(theta)`; one position with nonzero sine forces equality. Tying each selected pair therefore permits moving *real* step multiplication from post-RoPE query preparation to a pre-RoPE position after query normalization. This does **not** make 512 query-step multiplies/token/layer disappear by itself. The pinned Q norm affine is shared across query heads and the fitted steps differ by group; absorbing them into normalization needs a changed head-indexed affine table and changes BF16 rounding. Moving the multiplication before normalization instead changes its denominator. No bit-identical FP32/BF16 execution or free producer fusion follows from the real commutation identity.

The plane table costs 128 FP16 steps, 256 bytes/layer, against 256 steps and 512 bytes/layer for the coordinate arm. Both cache 128 signed-nibble bytes/token/layer, quantize 256 selected keys/token/layer, prepare 512 step-scaled query coordinates/token/layer if no affine is changed, and retain all 1,024 raw K rows for normalization. The two-dot signed-nibble query consumer still needs 1,024 nibble products per cached key/layer across both heads. Thus the measured plane tie buys **only 256 static bytes per layer** in the unchanged consumer. It does not halve cache traffic, dot work, key production or weight BPW. Native latency and full-model loss were not measured.

The informative next question is a jointly learned plane-tied key quantizer and head-indexed post-norm query affine, with train/held quantized-upstream causal and gold loss. If that image recovers quality, price the changed affine addressing and native query preparation before claiming a speedup. Repeating quantile selection on the frozen image will not repair the layer-0 group-6 loss, .375735 to .528535, or the consistent layer-14 losses.

`measure.py` reconstructs the paid projection and the selected key observer on CPU. `/path/to/workspace/data/kelana-subbit/nibble-plane-step/layer{00,14}.json` retains each candidate's train KL, selected FP16 steps, group/window held KL and SHA256s of source, model, captures, paid images and parent receipts. Run a layer with:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/nibble-plane-step/measure.py --layer 0 --output /path/to/workspace/data/kelana-subbit/nibble-plane-step/layer00.json
```
