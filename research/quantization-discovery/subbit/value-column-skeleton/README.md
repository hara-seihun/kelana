# Keep the paid output columns, code only the transfer

The [shared two-head output-rank study](../value-cohead-output-rank/README.md) found a cheap real rank-256 approximation but a severe failure when it independently rounded both new factors to two bits. Its basis had thrown away the paid decoder's already-fitted two-bit columns. Here one factor keeps whole 28-coordinate head groups of that decoder, including the original codes and FP16 row scales. Only the map from missing head coordinates into retained coordinates is fitted and quantized. This is a direct consumer of the paid narrow-V cache. No 128-wide value or int4 weight is reconstructed.

Write the frozen output map as `A = [C D]`, with `C` containing selected whole paid groups. For attended coordinates `z = [z_C z_D]`, compute `h = z_C + z_D T` and `y = h Cᵀ`. The real least-squares transfer for reproducing the paid response is `Tᵀ = C⁺D`. Thus `C Tᵀ` is the orthogonal projection of the missing paid columns onto the span of the retained ones. This is exact on every real input if `D` lies in that span; otherwise the residual is `z_D (D - C Tᵀ)ᵀ`. Neither this projection nor the two-bit transfer has an FP32 bit-identity claim. The group choice is greedy on the **train** paid-response output subspace. If `Y = Z Aᵀ`, the score for candidate columns `C` is `tr((CᵀC)⁻¹ CᵀYᵀYC)`. The 448-coordinate Grams make every group choice exact *conditional on the previously selected groups*; greedy is not a global optimum.

On the same original-producer Qwen3-0.6B captures and frozen paid rank-28 V/O image as that rank study, there are eight train and four distinct previously inspected 256-token validation windows per layer. The comparison observes the complete two-head post-O response against original V/O. A ten-group image retains 280 of 448 output coordinates, with 168 transferred into them. It costs 107,426 output-image bytes with two-bit transfer, against 147,584 for the paid output image and 117,792 for the independently two-bit rank-256 SVD image. The count includes 10 × 1024 × (7 packed-code + 2 FP16-scale) bytes, 168 transfer rows of 280 packed two-bit codes and ten FP16 scales each, 128 bytes of existing group descriptors, a 16-byte transfer descriptor and a two-byte head-group mask. The paid V producer's 61,056 bytes are common to all arms. Across the unchanged 3,145,728 V/O weights this is .428472 BPW, against .530599 paid and .454834 for the SVD arm. Logical output factor terms are 333,760 rather than 458,752 paid or 376,832 for SVD rank 256. The transfer adds one 280-coordinate reduction boundary; selector routing, native scheduling and physical traffic have not been timed.

| Layer | Paid output bytes / held teacher error | Independently two-bit SVD rank-256 bytes / error | Preserved 10-group two-bit bytes / error | Preserved 10-group four-bit bytes / error |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 147,584 / .378887 | 117,792 / .590752 | 107,426 / .413157 | 119,186 / .409548 |
| 14 | 147,584 / .326195 | 117,792 / .631886 | 107,426 / .375237 | 119,186 / .358668 |

The preserved-column construction **strictly improves the tested SVD-plus-independent-quantization arm in stored output bytes, logical factor terms and held teacher error**, with the same frozen V producer and observations. This is not a claim against a jointly learned rank-256 image, against the original paid quality, or about elapsed inference time. At fourteen retained groups and four-bit transfer, 141,714 output bytes leave little rate margin and still score .383937/.333727 against .378887/.326195 paid. At eight groups, two-bit transfer costs 90,002 bytes but scores .438055/.388559. A two-bit transfer is a weaker approximation than four bits yet keeps much of the gain over double-quantized SVD, because the expensive 1024-row output factor is copied exactly from its already-paid two-bit image.

As a fitting control, the script solves for the transfer against complete train **teacher** output instead of the paid response while freezing `C`. This train-targeted transfer loses on validation at all four group counts and both layers. For ten groups, two-bit teacher-fit error is .430778/.397682 versus .413157/.375237 for the paid-response fit. The failure is specific to fitting the transfer on these 2,048 original-producer rows; it does not reject jointly learned columns, changed V codes or a composed language-loss fit.

This result changes the next construction. Keep expensive decoder columns that are already good, then learn a cheap transfer and the V coordinate together against fresh quantized-upstream composed loss. First price the two-stage native consumer and its group routing against the original paid reader. The current evidence does not select a serving map: the paid image still wins held quality, and no full-model NLL, GPU latency or engine executable changed.

[`measure.py`](measure.py) regenerates the code/scale hashes, both target fits, per-window errors and charged rates in [`data/kelana-subbit/value-column-skeleton/`](/path/to/workspace/data/kelana-subbit/value-column-skeleton/README.md):

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-column-skeleton/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
