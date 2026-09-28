# Does joint routed-sum allocation beat independent expert ranking?

The [paid Q4_K/Q5_K down-bank experiment](../down-rate-allocation/README.md) ranks experts by their individual score-weighted recoding error. That ignores cancellation between the eight expert outputs on each token. Here the **allocated object is the complete routed down sum**: does using its cross-expert terms produce a better paid mixed bank on actual producers?

**Result: no on this capture.** Optimizing the train sum chooses a different 32-Q5 bank, but held relative RMS rises from .026884 to .027242. At 64 retained Q5 experts both choices coincide (.022914 held); at 128 the joint choice moves .008868 to .008877. A train-objective improving one-for-one swap search cannot improve any of the greedy budgets. This is a useful bounded negative: the local output errors of distinct routed experts are close to orthogonal *in aggregate* even though routing makes their membership dependent. Changing how this small capture ranks the same Q4 recodes is unlikely to unlock a high-quality mixed image. Broader calibration and complete-model loss, and especially gate/up image changes with larger rate leverage, take precedence over another sum-aware selector.

| Retained Q5 experts | Layer-0 down-bank bytes | Independent train / held RMS | Joint greedy train / held RMS | Train swap improvements |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 150,994,944 | .032927 / .046106 | .032927 / .046106 | 0 |
| 32 | 155,189,248 | .015961 / .026884 | .015959 / .027242 | 0 |
| 64 | 159,383,552 | .008370 / .022914 | .008370 / .022914 | 0 |
| 128 | 167,772,160 | .001717 / .008868 | .001717 / .008877 | 0 |
| 192 | 176,160,768 | 0 / .007435 | 0 / .007435 | 0 |
| 224 | 180,355,072 | 0 / .005464 | 0 / .005464 | 0 |

The 256-Q5 endpoint is the installed bank (184,549,376 layer down bytes, zero error). Each Q4 choice saves exactly 131,072 bytes relative to that bank. If the half-Q4 layer-0 result transferred to all forty layers, its modeled complete one-read weight-byte saving is only .7985%; no transfer or physical traffic saving is measured. All eight products still execute, with the same existing Q4_K or Q5_K native readers; no runtime was changed.

## Exact finite-capture certificate

For each expert `e`, form a vector `v_e` over all captured tokens and all 2,048 output coordinates; on a token where it is not selected it is zero, otherwise it is its actual normalized-router-score-weighted **decoded Q4_K minus installed decoded Q5_K** down response. With `x_e=1` for a Q4 expert, the observed squared sum error is `||sum_e x_e v_e||² = xᵀGx`, where `G_ef=<v_e,v_f>`. Its diagonal `D` is the independent-ranking objective. The train and held Grams are separate; only train chooses the image. We compute them from the existing complete 256-expert difference shards, so no new model approximation is introduced by the analysis.

On the nonzero-diagonal subspace, define `C=D^{-1/2}(G-D)D^{-1/2}`. The measured eigenvalue intervals are **[-.091123, .089609] on 113 train tokens** (169 active experts) and **[-.077118, .072862] on 126 held tokens** (188 active experts); maximum absolute normalized pair correlations are .053761 and .044660. Consequently, for **every real coefficient vector supported on these captured experts**, not just the tested binary bank choices, `(1+λ_min)xᵀDx ≤ xᵀGx ≤ (1+λ_max)xᵀDx`. On train, the diagonal top-k choice's full-sum squared error is at most `(1+.089609)/(1-.091123)=1.1989` times the globally best fixed-cardinality binary choice (RMS ratio at most 1.095), even granting an exact combinatorial optimizer. This bound covers cancellation within the stated fixed Q4 recodes and producer/score capture, not other representations or text. A zero-train-energy expert contributes no train vector; the bound includes it with a zero coordinate. The held spectrum is descriptive, not an allocation oracle.

The greedy procedure removes one Q4 expert at a time by its exact marginal improvement `2(Gx)_e-G_ee`, and at each reported cardinality the swap search tests all remaining Q4-to-Q5 exchanges against the quadratic objective until none improves it. This is a one-exchange local optimum, not a global combinatorial optimum. The spectral certificate is independent of that search. At 192 Q5 experts every train-observed expert is retained, so train error is exactly zero; 35 held-only experts remain unranked by train and account for the observed residual. No more elaborate optimizer on these same train contributions can learn their held effects.

## Evidence and scope

[The reproducible receipt](/path/to/workspace/data/qwen-moe/down-joint-allocation/receipt.json) (SHA-256 `201a4add5443c7b41b3480e12b25fb02c4d308b26939d1b7861bca701a6c6089`) retains every expert selection, full train/held errors, input shard hashes, capture and model acquisition hashes, eigenspectra and source hash. The [plain panel](/path/to/workspace/data/qwen-moe/down-joint-allocation/panel.txt) is a compact view. Run from Kelana root:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 research/moe/down-joint-allocation/experiment.py
```

The underlying differences used CPU FP32 BLAS and the sum uses FP64; this does not reproduce the selected native FP32 fold bitwise. It is a **local layer-0 routed-output** quality/rate comparison, not held language loss, a converted whole image, or native speed. The selected Qwen GGUF and Bonsai service remain unchanged. The next useful representation experiment needs substantially more disjoint routed producer text, then a paid full-image allocation judged by complete-model held loss; rather than optimize selection on 113 tokens, target joint gate/up/down recoding with a larger possible weight-byte prize.
