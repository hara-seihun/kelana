# A paid low-rank correction to the tied Qwen head

Can a shared factor recover the rare head and embedding errors of the 0.6252-bit K256 codebook more efficiently than storing frequent rows exactly? This experiment spends almost the same sub-bit budget on a rank-16 FP16 residual. It fails on the observations that matter, even though it reduces the aggregate logit RMS. The result rules out **unweighted global residual SVD as a substitute for frequent exact rows** on this fixed pilot. It does not rule out factors fitted to token frequency, softmax sensitivity or the quantized model's hidden inputs.

The pinned Qwen3-0.6B tied matrix has 151,936 rows of width 1,024. The [base codebook](../tied-head/README.md) stores 12,158,980 bytes. I decoded that exact image, subtracted it from the BF16 source weights in FP32, and took a randomized rank-16 SVD of the residual, with 32 sketch columns and one power iteration. Two FP16 factors add 4,894,720 bytes. The online head program adds a 16-by-1,024 input projection and a 151,936-by-16 output projection to the codebook table response. Input embedding decoding adds one rank-16 row reconstruction. This is not dense int4 expansion, but neither native timing nor a complete model has been measured.

I also truncated the same factors to rank eight and spent the freed bytes on the 1,280 most frequent exact train tokens. The direct control retains 2,560 frequent exact rows and no residual. All rates below include the redundant codebook bytes for exact rows, four-byte row IDs, FP16 factor bytes and eight bytes for a head-only scalar calibration.

| Image | Paid BPW | Held validation head NLL | KL to original | Top-1 / 64 | Frequency-weighted embedding RMS |
| --- | ---: | ---: | ---: | ---: | ---: |
| K256 alone | 0.625211 | 5.7951 | 2.2209 | 19 | 0.8390 |
| K256 + rank 16 | 0.876896 | 5.9454 | 2.3331 | 14 | 0.8100 |
| K256 + rank 8 + 1,280 exact | 0.886111 | 4.7627 | 1.1495 | 45 | 0.4603 |
| K256 + 2,560 exact | 0.895325 | **4.6287** | **1.0649** | **52** | **0.4164** |

These head numbers use the original model's fixed 64 final hidden inputs and BF16 logits. The original NLL on them is 3.6103. Each candidate independently fits the *same two scalar head correction parameters* to 32 train next-token positions from four train windows, never to validation logits. The 2,560-row control's 32-position fit is not the earlier 128-position result of 4.429 NLL; comparing the two as if they shared a training budget would be misleading. Exact rows come from the full train-corpus frequency order. Embedding error uses held validation token counts. Input embedding changes were not propagated through the model.

The failure is sharper than a reconstruction-norm comparison suggests. The rank-16 correction reduces raw head-logit RMS from 2.0812 to 1.8561 on the same 64 positions, but drops top-1 agreement from 19 to 14 and worsens held NLL after the matched scalar fit. In the mixed construction, reallocating half the factor bytes to exact frequent rows greatly improves both consumers, but still loses to spending that budget on 2,560 frequent rows. A global SVD spends its rank on large residual energy rather than the token-specific head margin or occurrence-weighted embedding errors.

A next candidate should fit the rare-row factor to train softmax response and embedding frequency jointly, with the exact frequent subset present during fitting. It should then propagate the resulting input embeddings through the model. An additional unweighted rank or a faster implementation of this image is not the useful next experiment.

`study.py fit` creates the rank-16 FP16 factor image; `study.py assess` reproduces the table. Both run on CPU with the installed research Python environment. Raw `rank16.npz` and `result.json` live in [`/path/to/workspace/data/kelana-subbit/tied-rare/`](/path/to/workspace/data/kelana-subbit/tied-rare/). The JSON pins the base image, capture, factor and source hashes, rate accounting, fit seed and the four complete quality records. No GPU lock or service state changed.

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/tied-rare/study.py fit
OPENBLAS_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/tied-rare/study.py assess
```
