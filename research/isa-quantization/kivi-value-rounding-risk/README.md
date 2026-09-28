# Fixed-law adjacent-grid KIVI2 value rounding: analytic complete-O risk

The source law and arithmetic clarification were frozen in [LAW.md](LAW.md) before scoring. This is an ideal independent stochastic rounding **expectation**, not a sampled run, implemented encoder, or hardware claim. Original K2 bytes, per-V33 stored FP16 fields, flush chronology, recent BF16 bytes, complete original O and teacher are unchanged. The FP32 CPU attention probabilities from the original K2 pre-query state are held fixed. The four decoded V levels use separate FP32 multiplication/addition. The BF16 source value determines FP64 adjacent probabilities; clipped endpoints are deterministic. Each KV-coordinate draw is shared by its two Q heads, and distinct KV-coordinate draws are independent. The complete-O FP64 mean-bias term includes K/source mismatch and endpoint clipping. The covariance trace uses the per-KV two-Q-head O-column Gram, with the cross-head term retained.

## Result

| Scope | Queries | Original V2 deterministic FP64 SSE | Mean-output SSE | Variance trace | Expected SSE | Expected / original | Winning queries |
|---|---:|---:|---:|---:|---:|---:|---:|
| Layer1 contextual train, 8 windows | 2048 | 209.016696 | 156.152406 | 93.612750 | **249.765157** | 1.1950 | 57 |
| Layer1 contextual inspected validation, 4 windows | 1024 | 107.923582 | 76.951085 | 50.809169 | **127.760254** | 1.1838 | 43 |
| Layer0 held, 4 arrivals × t128/t256 | 8 | 0.832658 | 0.179568 | 0.337181 | **0.516749** | 0.6206 | 7 |

**Negative contextual transfer:** the fixed law loses on both contextual panels despite a better mean. Its variance penalty exceeds its reduction in mean-output SSE. The held layer0 result is favorable in expectation only, and does not reverse the larger, distinct contextual source-panel negative. The contextual original CPU receipts total 209.016698 / 107.923584 (FP64 minus CPU −0.00000174 / −0.00000137); held original CPU receipt totals 0.832658 (difference −0.00000024). Thus the original FP32/FP64 rounding boundary is explicitly distinguished. Teacher-squared totals are 13465.224624, 6793.961378 and 271.317983 respectively; relative expected squared errors are 0.01854890, 0.01880497 and 0.00190459. Original relative squared errors are 0.01552270, 0.01588522 and 0.00306894.

The corresponding unchanged CPU controls in `../kivi-value-error-moment/summary.json` are, respectively for train / validation / held: delay2 **206.290397 / 106.487853 / 0.806759**, moment **204.115581 / 104.977831 / 0.608755**, feedback **239.739259 / 120.417466 / 0.580496**, K2V4 **158.179727 / 77.840169 / 0.193585**. They are different mechanisms and CPU arithmetic; not FP64 stochastic-law variants. The ideal encoder adds bracket comparisons, probability arithmetic and one random draw per flushed V coordinate compared with original deterministic rounding, with unchanged 2-bit codes/fields and cache timing. No measured encoder/runtime/storage gain or paid image is claimed.

## Custody and reproduction

`screen.py` reads `../contextual-value-feedback/{train,validation}-*-source.npz`, original event logs/manifest/teacher/O, or the same four held BF16 arrivals and two retained Q/teacher states in `../kivi-value-intern`, `../kivi-two-bit-causal` and `../kivi-two-bit-dot-native`. It verifies source hashes, donor event hashes, source-built V fields, original V33/K32 chronology and O bytes. `panel-window-result.json` holds every query's original FP64 baseline, FP32 CPU receipt, rounding difference, mean risk, variance, expected risk and aged count, plus source/field/event hashes, counts of interior/exact/clipped/duplicate levels and nonnegative-variance/probability checks. `summary.json` aggregates without hiding per-query outcomes. On t128/t256, an independent direct summed-head O-coefficient contraction matches the Gram contraction to absolute differences at most 2.78e−17 across the panels. Source records have 19,218 / 9,454 / 9,931 clipped coordinates (train / validation / held); clipping bias is retained in mean risk. No stochastic seeds are used.

Run each bounded window separately (venv documented by the source owners):

```sh
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python screen.py train 0
# likewise train 1..7, validation 0..3, held 0..3
python aggregate.py
```

The [finite risk-floor theorem](../value-rounding-risk/README.md) and `Kelana/ValueRoundingRisk.lean` derive adjacent variance optimality and the complete biased-observer contraction. The contextual numerical floor therefore excludes a gain for every independent law with these same clipped coordinate means and decoded grids at this fixed ideal linear readout, not just one sampled seed. The statement is conditional on those means and independence, not a comparison against correlated, feedback, K, or larger-grid designs. In particular this contextual negative is not a universal impossibility result for value rounding.
