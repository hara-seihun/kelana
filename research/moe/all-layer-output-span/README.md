# Forty-layer actual-route output-span obstruction

On the pinned Qwen3.6-35B-A3B GGUF's two disjoint 64-token real-text captures, even a **free optimal orthogonal projection into the entire 512-vector training-slot span at each layer** loses **0.704919 pooled held relative RMS** of the score-weighted eight-expert down sum. Every layer loses at least **0.55855** (median **0.79948**); excluding the unusually large-norm final layer raises pooled error to **0.77031**. All forty observed train-slot matrices have numerical rank 512. This extends the [layer-0 113/126-token basis study](../real-sum-rank/README.md) to every routed layer on a separate 64/64 capture, rather than projecting one layer's deficit onto the entire model. It rejects a *fixed per-layer output coordinate constrained to these sampled directions*, not a learned full-bank coordinate or direct packed computation.

## Observation and exact family bound

For each layer and token, eight captured native FP32 down vectors `d_i` and normalized route scores `a_i` define the study's ideal-real FP64 local sum `y = sum_i a_i d_i`. Fit one shared per-layer output subspace from the 64 train tokens' **512 weighted slot vectors** `a_i d_i`, then project all 64 held sums into it. The best rank-r train-slot PCA basis minimizes the summed **slot** training error. For a fixed basis `C` with orthonormal columns, even a free omniscient decoder cannot achieve smaller squared response error than `||y - CCᵀy||²`. At r=512 the basis spans *all* observed train slots, so the reported held error is a lower bound on every subspace constrained to that span, irrespective of its online coefficient computation. It is not a lower bound on a subspace chosen from all 256 installed experts' weights or more independent producers. Full train-sum error vanishes here by construction and does not imply held quality.

| Fixed per-layer train-slot coordinate | Train pooled RMS | Held pooled RMS | Held layer median | Held layer range |
| --- | ---: | ---: | ---: | ---: |
| rank 64 | .475823 | .848212 | .954871 | .690460–.972282 |
| rank 128 | .332474 | .819324 | .927233 | .657049–.948399 |
| rank 256 | .178678 | .774955 | .881241 | .612268–.905898 |
| entire rank-512 train span | ~0 | **.704919** | **.799481** | **.558547–.828176** |

Pooled RMS is `sqrt(sum_layer,t ||error||² / sum_layer,t ||y||²)`; the final layer supplies **34.28%** of the held denominator and has the lowest held relative error. The median prevents its large norm from concealing the other layers. These are disjoint prompt-producer observations of the selected mixed-quantized image, not generated decode trajectories. FP64 recombination does not reproduce the native FP32 reduction order, and local output error is not held language NLL. No approximate representation is selected: there is **no paid changed complete image** at a defensible quality point. The earlier conditional equal-effective-byte rank-512 factoring could save at most **6.55% of the complete one-read model stream**, before basis traffic and boundary work; this loss is too large to warrant its native port. The result measures no GPU latency, model quality, or serving rate.

## Reproduction and next experiment

`measure.py` reads every layer's actual score/down arrays, checks their SHA-256 against the capture receipt, eigendecomposes the 512×512 train-slot Gram and evaluates an independently formed projected residual on held sums. To keep each CPU job bounded:

```sh
cd /path/to/workspace/projects/kelana
for start in 0 5 10 15 20 25 30 35; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 python3 research/moe/all-layer-output-span/measure.py \
    --start "$start" --stop "$((start+5))" \
    --out "/path/to/workspace/data/qwen-moe/all-layer-output-span/layers-$start-$((start+4)).json"
done
OPENBLAS_NUM_THREADS=4 python3 research/moe/all-layer-output-span/summarize.py
```

[The forty-layer aggregate receipt](/path/to/workspace/data/qwen-moe/all-layer-output-span/receipt.json) binds both sources, all eight shard hashes, the pinned model and capture receipt, all **160 actual score/down input hashes**, 2,560 layer-token cases and 20,480 routed slots per split. The shards retain every layer/rank's squared numerator and denominator, numerical train rank and eigenvalue ratio; recomputation requires no GPU. The independent next question is whether a **weight-informed or newly trained paid coordinate** from substantially more diverse real routed producers reduces disjoint complete-model loss. A short-capture slot span is not that coordinate. If no changed image wins, investigate native ordinary Q8/expert physical execution instead.
