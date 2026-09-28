# Down codes can fit the damaged response and still lose language loss

The preceding [quantized-producer scale fit](MLP-QUANTIZED-SCALE.md) left all binary factor signs frozen. I changed the down projection's 384-bit output-row codes and its already-paid FP16 output scales, holding the fitted gate/up images, down right factor and down input scales fixed. The target is the original layer-0 endpoint minus the damaged producer's pre-MLP residual. This is a stronger equal-byte response fit on the actual binary-Q/K, narrow-rank-28 V/O layer-0 producer. It did **not** improve the six-window test continuation.

For the frozen hidden map, write the down response as `diag(p) U z`, where `z = V diag(s_pre) [SiLU(gate(x)) * up(x)]`, `U_ij` is either sign, and `p_i >= 0`. For each row `i` and coordinate `r`, with other signs and `p_i > 0` fixed, the exact binary least-squares update is

```
U_ir = sign( (Y^T Z)_ir - p_i * ((U Z^T Z)_ir - U_ir * (Z^T Z)_rr) )
```

The code takes `sign(0) = +1`. A zero scale makes the sign immaterial. A sweep keeps `U Z^T Z` current by rank-one updates and then fits each nonnegative row scale by least squares, rounding it to the same FP16 slot. This is a coordinate optimum within the frozen gate/up, down-right and squared-response family, not a global binary optimum. The response arithmetic is FP32; the continuation separately expands the paid image to BF16 weights.

The CPU fit uses 2,048 train positions, two specified sweeps, and the previously inspected 1,024-position validation capture. All three MLP projection images together retain **614,436 payload bytes** before and after; factor dimensions, signed terms, FP16 scale count and online program are unchanged. No labels or exceptions were added.

| Down image on damaged layer-0 producer | Train endpoint relative squared error | Held validation response error |
| --- | ---: | ---: |
| Paid input/output scale fit, frozen codes | .709531 | .830638 |
| One down-code sweep | .633567 | .819203 |
| Two down-code sweeps, saved image | **.610369** | **.821403** |

The second sweep lowers train error by another .02320 but raises held response error .00220. The two-sweep image changes 61,378 signs on pass one and 25,227 on pass two. Its held response gain over the scale-only image is real on this capture but small compared with its train gain.

I ran the saved two-sweep image through the same BF16-expanded model as the scale-only control. Layers 0–13 use the binary body and norms, layer-0 V/O is the same narrow image, and later layers and the tied endpoints remain original. Each window gives 255 gold predictions; all three arms have the same workload and payload policy.

| Window set | Binary MLP NLL | Scale-only NLL | Down-code NLL | Code wins against scale |
| --- | ---: | ---: | ---: | ---: |
| Six later test windows, 56–61 | 12.14876 | **11.56619** | 11.83990 | 1/6 |
| Eight later validation windows, 24–31 | 11.46525 | 11.29725 | **11.21527** | 4/8 |

The validation gain does not rescue the test loss, and both sets have been inspected repeatedly. This is a bounded negative for the *frozen hidden, endpoint-squared-error, down-U/sign-plus-scale* family on this damaged prefix. It does not reject joint gate/up codes, value-coordinate changes, a gold-loss objective, or a trained full sub-bit model. It does rule out selecting this code image by a better fixed-capture endpoint norm. The next experiment should differentiate gold or teacher continuation loss through the quantized layer-0 producer and jointly change gate/up and down signs, with larger independent train windows and a frozen held selection. An even better local response objective is not the missing proof of language quality.

`mlp_quantized_code_fit.py fit --sweeps 2` reuses `mlp-quantized-producer-capture.npz` and the three scale-fit packed images. `evaluate --split test --start 56 --count 2` and the other three panels, test 58/4 and validation 24/4 and 28/4, run through Bonsai's `tools/run-batch-compare --runtime-max 45s --exec ...`. The CPU receipt `data/kelana-subbit/full-model/mlp-quantized-down-codes.json` records source/input/output SHA-256, sign changes, both per-sweep scores and equal payload. `mlp-quantized-down-codes-image/` retains the paid three-projection image. The four `mlp-quantized-down-codes-{test,validation}-*.json` receipts retain token, image, model and source hashes plus every window's NLL. Every GPU panel restored the active Bonsai service; no native compressed inference or Bonsai runtime changed. The host was not quiet during GPU panels, which are loss evaluations, not latency comparisons.
