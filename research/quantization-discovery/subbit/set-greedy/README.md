# Joint-set exact-row selection does not repair tied-head overfit

The gold-row study selected 1,280 replacement rows by their individual gain after fixing 1,280 frequent anchors. I asked whether its failure came from ignoring the other selected rows in the log partition. Replacing the independent ranking with a greedy evaluation of the **current complete set** changes 117 of the 1,280 additions. It lowers fit NLL by only 0.000085 nats and raises held NLL by 0.00247. Both gold-directed sets lose to 2,560 frequent exact rows. The interaction is real, but it is not the missing capacity in this pilot.

| 2,560 exact rows on the same K256 image | Fit NLL, uncalibrated | Held NLL, separately calibrated | Held teacher KL | Top-1 / 64 | Validation-frequency-weighted embedding RMS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Frequent | 4.507977 | **4.628683** | 1.064876 | **52** | **.416411** |
| Best 1,280 individual gains after frequent anchors | 3.664226 | 4.692458 | **1.059544** | 48 | .460789 |
| Greedy exact selected-set gain | **3.664141** | 4.694923 | 1.061818 | 48 | .460947 |

The gold-directed fit gains 0.844 nats on 128 train positions and loses 0.064 to 0.066 nats on 64 validation positions against frequency. Exact selected-set optimization does not close that generalization gap. The last greedy addition still has positive fit gain, `5.97e-7` nats, so the fixed row count did not force a negative-gain tail.

## What is optimized

For each train position, write the current log-partition as `Z_t(S)`, and let replacing row `i` change the unnormalized partition by `D_ti = exp(exact_ti) - exp(base_ti)`. The exact gain of adding `i` to `S` is

```
gain(i | S) = mean_t [1[y_t=i] (exact_ti - base_ti)
                      - log1p(D_ti / Z_t(S))].
```

The implementation rescales `Z` and every `D` by the same position-dependent exponential factor. The ratio, selected row and complete-set loss are unchanged. After choosing a row, it adds that row's `D` to `Z`; the next gain therefore sees every previous change. This is an exact one-step greedy objective on the captured float32 score arrays, not an optimum over all size-1,280 subsets. Mixed-sign `D` offers no general submodular guarantee. The static control ranks the same candidate pool by the gain at the anchored set. Its selected IDs and reported metrics reproduce the earlier gold-row result.

The candidate pool is the union of the 2,560 most frequent train-token IDs and the 2,560 highest single-row head-gain IDs, minus the 1,280 fixed frequent anchors: 3,796 candidates. Both algorithms choose 1,280 additions from this same pool, with deterministic ties. The 117 exchanged rows explain the small but nonzero fit difference. The limit is this pool, these 128 original-model head inputs and forward greedy, not every possible row allocation or a learned response family.

All three images pay **17,412,108 bytes, .895325 bits per unique tied weight**. Each uses the same 64-by-256 response-table preparation, 64 code entries per vocabulary row, 2,560 exact BF16 row dots, exact-row ID lookup for embeddings and two train-fitted rare-logit calibration scalars. Row selection is offline and has no online speed implication. The complete head and embedding are still very lossy; this is not a comparison with a quality-matched int4 model.

The train scores are 128 final-hidden positions from four WikiText train windows. Another 32 train positions fit the rare-head calibration separately for each image. The 64 held head positions come from two validation windows, while validation token occurrences weight embedding reconstruction error. Hidden inputs are original-model states. Approximate embeddings were not propagated through the model. CPU-only evaluation touched neither the GPU lock nor the resident service.

`study.py prepare`, eight calls of `study.py step`, then `study.py assess` reproduce the selection from the prior gold-row score matrices. Run each with `OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4` and the existing `/path/to/workspace/data/fish-s2-pro/venv/bin/python`. `/path/to/workspace/data/kelana-subbit/set-greedy/` retains the candidate pool, selection trajectory, all three paid images, input and source SHA256s, calibration and observations in `result.json`. The original pinned model and score captures remain identified in [gold-row](../gold-row/README.md).

The next tied-image experiment should buy independent train head inputs and propagate the approximate embedding into the transformer, then fit a richer rare response against the resulting consumer. Another optimization pass over these 128 final-hidden observations is unlikely to reverse the frequent-row control.
