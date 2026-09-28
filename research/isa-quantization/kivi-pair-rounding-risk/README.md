# Fixed source-only pair coupling: complete-O expected risk

[`LAW.md`](LAW.md) records the immutable law supplied before scoring. The [corrected same-layer O pair map](../value-pair-covariance/README.md) and its exact sign certificates, not the superseded cross-layer graph, determine all 64 pairs per KV-head flush. The source-only pair map SHA256 is `2e5a182308b17a2e6b417521a7937fd9b98037bb6bfb3df3269fabb02b3e35f3`; coefficients/matching/certificates SHA256 are respectively `9a83683e04b1486fd072dbbe023d4858e75eebbf7a778d7c88824252b5757d46`, `85c19887e88bd6936c66d676eccb56e07715948838fde5a54994188c32f6176d`, and `e97403d11f8ff03d5949888888dd3f294d368d42b4a5aac3882160ac1bff10a0`. The independent analytic law and each of its 16 receipts are individually SHA-pinned in [`pins.json`](pins.json), from commit `0bed18b2`; its mean-output risk, controls, fields, events and phases are **reused**, not rescored or changed. The panel is the 8 contextual train + 4 inspected validation windows of layer 1, and 4 held layer-0 arrivals at t128/t256, with exact fixed original-K2 attention.

| Scope | Queries | Original V2 FP64 SSE | Independent expected SSE | Pair correction | Paired expected SSE | Paired / original | Paired winning queries vs original |
|---|---:|---:|---:|---:|---:|---:|---:|
| Contextual train | 2,048 | 209.016696 | 249.765157 | −1.948757 | **247.816400** | 1.18563 | 64 |
| Contextual inspected validation | 1,024 | 107.923582 | 127.760254 | −1.053644 | **126.706610** | 1.17404 | 47 |
| Held layer 0 | 8 | 0.832658 | 0.516749 | −0.005356 | **0.511393** | 0.61417 | 7 |

**Negative contextual result:** coupling improves the independent law on every aged query (strictly 1,784/2,048 train and 892/1,024 validation; pre-flush queries tie) but remains worse than original deterministic V2 and the original contextual controls. The unchanged CPU controls (delay2 / moment / feedback / K2V4) total train **206.290397 / 204.115581 / 239.739259 / 158.179727**, validation **106.487853 / 104.977831 / 120.417466 / 77.840169**, and held **0.806759 / 0.608755 / 0.580496 / 0.193585**. Held favorable ideal expectation does not overturn contextual failure or outrun K2V4. These controls use their original CPU arithmetic, while this analytic risk uses FP64 contractions and the original-K2 FP32 softmax. The original CPU V2 sums are 209.016698, 107.923584 and 0.832658; the tiny FP32/FP64 difference remains explicit in the pinned independent receipts.

## Computation and custody

[`screen.py`](screen.py) uses source BF16 values, source-built stored V fields, pinned donor event logs and their per-head hashes, layer-specific original O hashes, immutable matching and exact coefficient files. It reconstructs adjacent probabilities and **actual unequal decoded gaps**, checks equality against the independent law's means/variances, and checks every event's four joint weights, sum and both marginals. The 16 receipts cover 1,835,008 pair/event joint laws, with smallest observed joint weight at least −1e−15 and largest marginal/sum error at most 1e−15. For each event/head it collects three coefficients, then contracts them against `u²,uv,v²` at each query; it creates no query-by-output covariance arrays. All 3,080 per-query pair corrections are nonpositive within explicit `1e−11*max(1, independent risk)` tolerance. 384 bounded direct checks enumerate **all four projected 1,024-dimensional pair outcomes** and subtract independent joint weights; the largest absolute discrepancy against analytic covariance is below 1.23e−21. Exact source sign certificates prove nonincrease for all legal attention masses, not just these observed queries. Each receipt retains source, O, donor/field/event and independent-receipt hashes, layer, per-query baseline/independent/paired risk and the numerical checks. [`aggregate.py`](aggregate.py) asserts all 16 independent receipts and per-query comparisons, then creates [`summary.json`](summary.json).

Reproduce each window in less than a minute, with the original source environment:

```sh
cd research/isa-quantization/kivi-pair-rounding-risk
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python screen.py train 0
# likewise train 1..7, validation 0..3, held 0..3
python aggregate.py
```

The static map costs **1,568 B per layer / 3,136 B for both**, shared across sequences; no per-sequence map or extra K/V stored fields. Compared with deterministic rounding, each 128-D KV-head V flush needs 64 map lookups, 64 fresh uniform draws, 128 endpoint brackets/thresholds and pair probability/threshold work. The two Q heads share a sampled draw. No practical RNG, native kernel, measured latency, paid cache image, or stochastic realization has been produced: these are ideal expected-risk numbers only.
