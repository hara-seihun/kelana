# Cross-validated Q3 expert choice does not transfer from the short capture

The existing 32-individual-expert Q3_K allocation is a real local quality/rate point, but its training observation covers only 113 producer tokens. Can support-aware shrinkage pick a better **fixed paid bank** than greedy on this sparse capture? On the existing frozen layer-0 Q3_K/Q4_K paired gate/up images, the answer is **no**. Four-fold train-only selection rewards a policy that changes twenty of 32 chosen experts and worsens the disjoint 126-token held routed-sum RMS **.009186 → .015660** at the same 293,076,992-byte image. This is a measured selection failure, not a rejection of expert-granular allocation or a whole-model quality result.

| Q3 experts | Existing train-seen greedy held RMS | Four-fold selected held RMS | Selected cross-validation RMS | Paid gate/up bytes | Conditional complete one-read saving |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 16 | .006740 | .009555 | .008635 | 297,533,440 | .212116% |
| 32 | .009186 | .015660 | .018047 | 293,076,992 | .424232% |
| 64 | .020940 | .020940 | .028988 | 284,164,096 | .848463% |

The risk estimator has two train-selected hyperparameters: `alpha` Dirichlet pseudocounts for route frequency and `lambda` global per-observed-hit squared-error pseudocounts. It estimates each expert's frequency times squared-error-on-selection, ranks eligible experts and selects exactly k. For each of four folds, held-out rows are token indices modulo four; the other three folds alone determine counts, loss means and expert support. Squared errors are measured on the **complete sum** of the selected expert deltas, not on reconstructed matrices. All sixteen parameter pairs and the per-fold squared errors are retained. Training-only CV chooses `(alpha=8,lambda=2)` at 16 and 32 experts; at 64 it chooses the unsmoothed `(0,0)` control. The unsmoothed independent selector matches the existing joint greedy at 32 and 64 and nearly matches it at 16 (.006829 held). For 32, the chosen shrinkage's training RMS is .012202 versus .006505 for greedy, while the held RMS also gets worse; CV over its small folds favored the wrong expert coverage pattern. At 16, it replaces fifteen of greedy's choices. Picking the favorable unsmoothed policy *after viewing held* is not a valid new selector.

The observation is the frozen decoded Q4_K reference with unchanged Q5_K down, actual layer-0 producer activations and normalized router scores. Saved score-weighted expert output deltas use CPU FP32 matrix operations and FP64 routed-sum accumulation. Every image choice pays Q3_K bytes even if the held text does not route to it. Train-unseen experts are never made artificially free candidates: 169/256 appear in train; 35 of the held-seen experts are absent from train. Conditional 40-layer one-read percentages extrapolate layer-0 images to all layers and ignore mixed-format dispatch, physical traffic and any extra metadata. They are not native TPS or complete-model language loss. The failure specifically cautions against hyperparameter search on four folds of one short capture; acquire diverse producer routes and freeze a complete paid image before choosing by held language loss. Another scalar risk smoother on these 113 tokens is not the next question.

## Reproduce and custody

[The receipt](/path/to/workspace/data/qwen-moe/q3-robust-allocation/receipt.json) hashes the script, original allocation receipt, pinned model and all eight train/held delta shards and retains each fixed selection, all CV candidates, costs and outcomes. Run without a GPU:

```sh
OPENBLAS_NUM_THREADS=2 python3 research/moe/q3-robust-allocation/experiment.py
```

No runtime, image, GPU reservation or resident service changed.
