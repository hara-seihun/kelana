# The key denominator is still a producer

The [selected group key affine](../rope-selected-affine/README.md) stores only 224 coordinates of a 1,024-coordinate key per layer. Its score consumer still needs each group's full raw RMSNorm denominator. I tried two ways to remove that producer bill on the existing paid binary K image. One is an exact real-arithmetic factor-coordinate identity with a bad cost at the image's rank; the other measures a cheap learned selected-row denominator on held causal attention. The cheap map fails badly at layer 14. This is a useful stop on the frozen image, not a reason to abandon jointly trained narrow keys.

## Factor-coordinate identity and its bill

Write the paid key producer as `z = V diag(pre) x`, `u = diag(post) U z`, with `U` an `1024 × 256` signed matrix. Partition its rows into eight groups of 128. For each group, the unrounded squared RMS denominator is exactly

`d_g² = (zᵀ G_g z)/128 + ε`, where `G_g = U_gᵀ diag(post_g²) U_g`.

Thus a factor-coordinate consumer need not materialize all 128 raw key rows to compute the *real-arithmetic* norm. It can compute the selected `U` rows and a quadratic in `z`. But an ordinary symmetric Gram evaluation has `256 × 257 / 2 = 32,896` products per group, or 263,168 per token across eight groups. The omitted output rows cost only `(1024 − 224) × 256 = 204,800` signed terms. In this grammar the quadratic already exceeds the omitted work before its FP32 arithmetic, reduction, register traffic and storage. Eight dense FP16 symmetric Grams would occupy 526,336 bytes per layer, rather than the original binary U plane's 32,768 bytes. The common input stage, 262,144 signed terms, is paid by both paths. A symmetric-Gram route first becomes cheaper in *product count* than omitted signed rows only below rank 200, since `8 R(R+1)/2 < 800R`. That is a family-specific break-even, not a hardware time bound or a lower bound on other structured quadratic programs.

More importantly, this identity does **not** reproduce the deployed BF16-normalized map. The quality evaluator rounds every raw coordinate to BF16 *before* squaring and summing. Generally `sum BF16(u_i)²` differs from `zᵀGz`; even a better-ranked Gram must measure the resulting lossy attention map or compute the omitted rounded rows. No FP32 reassociation is asserted bit-identical.

## Paid-image selected-denominator experiment

The script expands the actual refined .6245-BPW complete image's layer-0/14 binary K matrices to BF16, as the common quality evaluator does. It computes BF16 raw K on the existing original-producer train capture, fits one nonnegative scalar per group from selected raw energy to full raw energy, and separately fits a slope plus nonnegative intercept. The four previously inspected validation windows get **no fitting**. All arms use the same paid K numerators, frozen 112-plane masks, BF16 selected group affine, original Q, FP32 RoPE/score and all causal keys. Teacher attention uses original Q/K. Thus comparisons between full and selected denominators isolate this changed observation. They are not complete-model gold loss or a quantized-upstream result.

| Layer | Full paid-K denominator | Selected raw RMS, no fit | Train-fitted scalar | Train-fitted affine |
| --- | ---: | ---: | ---: | ---: |
| 0 held teacher-to-candidate causal KL | .263253 | .384417 | .277170 | **.257272** |
| 14 held teacher-to-candidate causal KL | **.477637** | .997543 | .799615 | 1.097958 |
| 0 held denominator relative RMS error, group mean | 0 | 1.4173 | .1488 | .1284 |
| 14 held denominator relative RMS error, group mean | 0 | 1.2005 | .5055 | .5908 |

At layer 0 the fitted affine improves all four held windows against the full paid-K denominator. At layer 14 it worsens all four, from full `[.48138, .48261, .47194, .47462]` to `[1.12189, 1.07970, 1.10770, 1.08254]`; the scalar also loses on all four. The affine's layer-0 gain is an *approximate-map* quality observation, not evidence that a selected norm preserves the original key map. Only 4.80%/2.96% of layer-0/14 selected BF16 normalized coordinates match the full-denominator arm with that affine. This comparison uses the already inspected original-producer windows; it cannot select a native or model-level image.

Computing only the 224 selected K rows reduces the output factor from 262,144 to 57,344 signed terms per token/layer, leaving the same 262,144-term input factor. The total falls from 524,288 to 319,488 signed terms, a 39.1% reduction, while retaining the existing binary U/V and scale payload. The eight train-fitted slopes and intercepts would add 32 FP16 bytes if stored separately, or potentially merge with group affine under a jointly defined normalization. They also need group-wise selected squared reductions and rsqrt, whose latency and register cost are not in these term counts. The selected affine table's 448 bytes and masks are paid equally. The experiment evaluated fitted coefficients in FP32; it did **not** round those coefficients to FP16 or measure a native consumer.

The frozen original-producer training distribution does not supply a safe selected-denominator replacement on this paid image. Next fit a selected-row Q/K image and its normalization *together* on quantized-producer text, with the two observing heads' causal or post-O/gold objective. Compare full norm, selected norm and an equal-rate binary Q/K control on disjoint windows. If layer 14's denominator tail persists, try a small learned norm sketch of additional raw rows and charge those rows and indices. Repeating an affine fit on the same original-producer capture will not settle it.

The CPU receipts at `/path/to/workspace/data/kelana-subbit/key-rms-factor/layer{00,14}.json` retain all group and window scores, fit coefficients, source/model/capture/paid-image/prior hashes and work counts. No GPU reservation, Bonsai executable or resident service changed. Reproduce each layer in a separate bounded command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/key-rms-factor
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 0 --output /path/to/workspace/data/kelana-subbit/key-rms-factor/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 14 --output /path/to/workspace/data/kelana-subbit/key-rms-factor/layer14.json
```
