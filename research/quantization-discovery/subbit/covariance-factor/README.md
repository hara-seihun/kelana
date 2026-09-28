# Head covariance in the tied rank-eight factor

The tied Qwen3-0.6B head and embedding ask different things of one sub-bit image. The existing rank-eight factor weights each residual row by head softmax curvature and token occurrence, but treats every input coordinate alike. I kept its K256 codebook, 1,280 frequent exact rows, row weights, seed, 16-column randomized sketch, FP16 factor budget and train positions fixed. Then I changed only the input-coordinate metric to favor directions actually used by the 128 captured train head inputs.

This lowered uncalibrated held NLL from 4.98743 to 4.86483 at the stronger covariance setting. After each image received the same independent 32-position train calibration, held NLL went the other way, 4.74903 to 4.81208. Embedding RMS also worsened, .45853 to .46017. The better raw head fit does not survive this calibration and tied-embedding boundary. It would be a mistake to build a GPU kernel for it now.

## Construction and proof

Write `R` for the source tied matrix minus the decoded codebook rows, with exact rows omitted, `d_i` for the already established joint curvature/occurrence weight, and `H` for the same 128 captured train head inputs. The top 32 right singular directions `V` of `H` capture 88.80% of its squared energy. If `lambda_j = 1024 sigma_j(H)^2 / ||H||_F^2`, define

```
C_alpha = I + alpha V diag(lambda) V^T
J_alpha(L,B) = sum_i d_i (R_i - (LB)_i) C_alpha (R_i - (LB)_i)^T
```

`alpha=0` is precisely the old diagonal-row metric. At positive alpha the head-input directions receive more weight without discarding other coordinates or changing the embedding program. Let `T=C_alpha^(1/2)` and `A=diag(sqrt(d)) R T`. Because `T` is invertible, all rank-at-most-eight matrices `LB` correspond bijectively to rank-at-most-eight matrices `diag(sqrt(d)) LB T` on the positive-weight rows. Eckart-Young therefore gives the exact real-valued optimum by truncating `A`'s SVD and transforming its right factor by `T^(-1)`; the minimum is the squared singular tail. Zero-weight exact rows can be set to zero. This proof does not say that the 16-column randomized sketch followed by FP16 storage is optimal, nor that covariance-weighted squared error minimizes softmax or gold-token loss.

The code uses this square-root and inverse directly in the 32-dimensional eigenspace. It never stores a dense 1,024-square covariance. All three new fits have the same **17,232,908 paid bytes, .886111 bits per tied weight**, and the same online codebook, eight-factor head response and one-row embedding decoder as the old image. The covariance belongs entirely to offline fitting; it adds no online operation. Its head rows are scored on fixed original-model hidden states, not hidden states propagated from quantized embeddings.

## Paired observations

The 128 fitting head positions are `4,12,...,252` in each of four train windows. Thirty-two disjoint train positions fit the two rare-logit scalars separately for each arm. The 64 held head positions come from two validation windows. Occurrence weights use the whole train corpus; embedding RMS uses held validation token counts. The `alpha=0` factor is byte-identical to the previous `joint-spectrum/rank8.npz` image, a useful control for the sketch and data plumbing.

| Head-coordinate metric | Paid BPW | Raw held NLL | Calibrated held NLL | Teacher KL | Teacher top-1 / 64 | Held weighted embedding RMS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `alpha=0`, diagonal control | .886111 | 4.98743 | **4.74903** | **1.10344** | 45 | **.45853** |
| `alpha=.1` | .886111 | 4.97733 | 4.81324 | 1.12210 | 45 | .45859 |
| `alpha=1` | .886111 | **4.86483** | 4.81208 | 1.14179 | **48** | .46017 |
| 2,560 frequent exact rows, separate prior control | .895325 | not measured here | 4.62868 | 1.06488 | 52 | .41641 |

At `alpha=1`, head logit RMS against the original decreases from 2.73654 to 2.64586 **after** calibration, yet KL and NLL worsen. The calibrated NLL change against diagonal is +.06305 nats/token, with 29/64 positions improving. Its two validation windows change by +.16676 and -.04065 nats/token. The independent calibration train NLL falls from 6.25356 to 6.06252, so the discrepancy is not a failed optimizer step. The 32 calibration positions are too few to tell whether a better-fitted head geometry helps after a stable calibration. This negative is restricted to this rank-eight family, covariance weight, fitting sample and calibration budget. It is not a bound against other covariance-aware factors or against sub-bit quantization.

The next useful experiment should fit calibration on substantially more *disjoint train* head positions and score fresh held windows before deciding whether the covariance fit itself or its two-scalar correction loses. More pressing for a tied model is to feed decoded input embeddings through the network and fit gold-token loss on that propagated distribution; a fixed-head RMS surrogate cannot value those changes. Neither this study nor the exact-row control has a native GPU or full-model timing result.

`study.py fit 0`, `fit 0.1`, `fit 1` and `assess` are separate bounded CPU commands from the Kelana root. Use `/path/to/workspace/data/fish-s2-pro/venv/bin/python` with `OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4`. The FP16 images, fit receipts and full per-arm/per-window assessment with source, captured-input and factor SHA256s live under `/path/to/workspace/data/kelana-subbit/covariance-factor/`. This experiment did not reserve the GPU or touch serving.
