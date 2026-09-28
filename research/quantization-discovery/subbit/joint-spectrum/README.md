# A joint tied-head and embedding rank-eight fit

The tied Qwen3-0.6B matrix must serve two different callers. A final hidden state asks it for vocabulary scores; an input token asks it for one embedding row. The earlier rank-eight factor fit against head softmax curvature improved teacher KL but hurt next-token loss and embedding error. I added train-corpus token occurrence to the factor objective, keeping the K256 codebook, 1,280 exact frequent rows, rank, FP16 factor storage and online program unchanged. On the same 64 held final-hidden positions, the joint factor improves calibrated NLL from 4.93195 to 4.74903, teacher KL from 1.13500 to 1.10344, and validation-frequency-weighted embedding RMS from .46176 to .45853. Top-token agreement falls from 49 to 45 of 64. The 2,560-exact-row control at .895325 BPW still wins on NLL, 4.62868, and embedding RMS, .41641. This is a better equal-rate factor than curvature alone on three observations, not a quality-matched victory or a complete quantized model.

## The rank-constrained problem

Let `R` be the source tied matrix minus the decoded codebook image, restricted to rows not stored exactly. Let `d_i >= 0` represent each row's joint consumer importance. For the surrogate

```
J(L,B) = sum_i d_i ||R_i - (LB)_i||_2^2,    rank(LB) <= k,
```

put `D = diag(d_i)` and `A = D^(1/2) R`. The Eckart-Young theorem gives a global optimum over **real** rank-k corrections: truncate the SVD of `A`, then multiply its left factor by `D^(-1/2)` on positive-weight rows. The minimum is `sum_{j>k} sigma_j(A)^2`. Zero-weight rows contribute nothing, and their correction may be set to zero. For a fixed full-row-rank right factor `B`, the optimal left row is `R_i B^T (BB^T)^(-1)` whenever `d_i > 0`: the row weight changes *which right subspace is selected*, not the best per-row coefficient inside it. This tells us exactly what a diagonal importance fit can and cannot repair. It cannot model different head-input covariance directions or the selected-set log-partition interaction. FP16 rounding and a randomized 16-column sketch are outside the optimum guarantee; no exact singular-tail value is claimed for the stored image.

This run uses `d_i = 0.1 + 100000 mean_train[p_i(1-p_i)] + 4 train_count_i / mean_rare_train_count`, zeroing the 1,280 exact rows. Teacher probabilities come from the 128 train positions `4,12,...,252` in each of four windows, using the existing gold-row response capture. Counts use the entire 2,518,423-token train corpus. The occurrence term is an input-embedding risk surrogate, not a validation-selected coefficient. The new weighted matrix gets one power iteration and a 16-column randomized sketch, then rank-eight FP16 factors. The prior curvature-only factor used 64 train head positions, so the experiment changes both the objective and the head sample size. It does not isolate the coefficient's causal effect. The held split and the two-scalar rare-head calibration procedure are shared.

| 1,280 exact + rank eight | Paid tied BPW | Held NLL | Teacher KL | Top-1 / 64 | Held embedding RMS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Curvature-only prior | .886111 | 4.93195 | 1.13500 | 49 | .46176 |
| Joint occurrence and curvature | .886111 | 4.74903 | 1.10344 | 45 | .45853 |
| 2,560 frequent exact, no factor | .895325 | 4.62868 | 1.06488 | 52 | .41641 |

The two factor arms have the same 17,232,908-byte paid payload. A head query still builds the K256 codebook response table, reads 64 labels per vocabulary row, computes eight 1,024-coordinate input-factor dots and 151,936 eight-coordinate output-factor dots, then replaces the 1,280 exact rows with BF16 dots. An embedding query decodes one row plus eight factor contributions unless its row is exact. The factor is never expanded to int4 for either consumer. These are operation counts, **not native timing**. The head metric is on fixed original-model final hidden inputs; neither the changed input embedding nor any other quantized layer was propagated. Both arms fit separate rare-logit temperature and offset on 32 disjoint train positions.

The next experiment is no longer another row-diagonal SVD. Fix the same 128-position head sample and compare coefficients before assigning a gain to occurrence. Then fit a low-dimensional head-input covariance jointly with embedding frequency, or optimize held-out gold loss through a quantized-embedding continuation. Measure the resulting full-model loss before building a native consumer. The top-1 loss here matters even though NLL improves.

`study.py fit` and `study.py assess` are bounded CPU steps using the existing read-only Python environment. The image, base/capture/frequency/source hashes, FP16 factors and both result receipts are under `/path/to/workspace/data/kelana-subbit/joint-spectrum/`. The comparator is the retained `tied-softmax/rank8.npz`; source weights and codebook are the pinned tied-head images. The resident GPU service was untouched.

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/joint-spectrum/study.py fit
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/joint-spectrum/study.py assess
```
