# Softmax curvature alone is the wrong tied-head factor objective

The [paid tied-head residual](../tied-rare/README.md) lost to exact frequent rows. I kept its rank-eight plus 1,280 exact-row rate fixed and asked whether directing its residual factor toward the head's train softmax curvature would recover the held loss. It did not. It improved held teacher KL and top-token agreement against the equal-rate unweighted SVD, but raised held next-token NLL. Both factors lose to 2,560 exact rows on NLL and embedding error. The next fitting target has to include **gold-token loss and embedding frequency**, not merely the teacher distribution's diagonal curvature.

The base is the pinned Qwen3-0.6B K256 tied image. Exact rows are the 1,280 highest-count tokens in the entire train corpus. On 64 final-hidden train inputs, sampled at offsets 4,20,...,244 in four windows, I computed the original head softmax and weighted each *nonexact* residual row by `0.1 + 100000 mean_t[p_t(row)(1-p_t(row))]`. A randomized 16-column sketch with one power iteration finds the leading rank-eight SVD of the weighted 151,936-by-1,024 residual. Dividing its row factor by the square-root weight returns a head/embedding factor in the original coordinate; both factors are stored FP16. This is a diagonal-curvature proxy, not an exact head KL optimizer. Its effect is strongest on rows which still have teacher probability after the frequent exact rows claim 70.23% of the train fit probability mass.

Both arms use the same K256 codebook, exact-row IDs and BF16 values, FP16 rank-eight factor sizes, and eight bytes for a separately trained two-scalar rare-logit correction. The unweighted arm truncates the prior rank-16 residual image to rank eight. Scalar calibration uses 32 *different* train positions at offsets 0,32,...,224 from the same four windows. The final assessment uses 64 held validation head inputs and logits, plus held validation corpus frequencies for embedding error. Its original-model NLL is 3.6103. Original hidden inputs stay fixed: no quantized embedding propagation and no full-model inference claim.

| Shared tied image | Paid BPW | Held NLL | Teacher KL | Top-1 / 64 | Frequency-weighted embedding RMS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Unweighted rank 8 + 1,280 exact | 0.886111 | **4.76268** | 1.14949 | 45 | **0.46029** |
| Curvature-weighted rank 8 + 1,280 exact | 0.886111 | 4.93195 | **1.13500** | **49** | 0.46176 |
| 2,560 frequent exact, no factor | 0.895325 | **4.6287** | **1.0649** | **52** | **0.4164** |

The last row comes from the [matched 32-position calibration panel](../tied-rare/README.md), not the earlier 128-position head fit. Before the scalar correction, curvature weighting moves KL from 1.54102 to 1.36585 and top agreement from 49 to 51, but NLL goes from 5.02909 to 5.11367. The separately fitted scalar correction helps NLL in both arms and changes top agreement, so the uncalibrated and calibrated comparisons must not be mixed. Training calibration NLL also worsens, 6.31166 to 6.42957. A teacher-curvature objective selects rows that preserve the teacher distribution, while the rare validation gold tokens need not be among those rows. The exact-row control still spends just 0.00921 extra BPW and wins on both consumers.

For a head query, the factor adds 8-by-1,024 and 151,936-by-8 products on top of 64 response-table lookups per row and 1,280 exact-row dots. An embedding query needs one 8-by-1,024 factor row reconstruction plus codebook decode unless its row is exact. Nothing expands the complete matrix to int4 online, but this is only a program count, not a native timing. Next train the factor against actual gold-token cross-entropy jointly with occurrence-weighted embedding reconstruction, retaining the exact subset. Use held text beyond these 64 positions and then propagate the embedding through the model before considering a native consumer.

[`study.py`](study.py) regenerates the weighted image and the paired comparison. Raw `rank8.npz`, `fit.json` and `result.json` live under [`/path/to/workspace/data/kelana-subbit/tied-softmax/`](/path/to/workspace/data/kelana-subbit/tied-softmax/). The receipts identify source, base, head capture and factor hashes. The image's paid payload is 17,232,908 bytes; the NPZ container size is not the runtime rate. This is a CPU experiment, so the GPU lock and resident service were untouched.

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/tied-softmax/study.py fit
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/tied-softmax/study.py assess
```
