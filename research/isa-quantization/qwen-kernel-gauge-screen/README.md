# Train-only score-row-gauge geometry at the real Qwen GQA source

The [frozen uncentered rank-64 positive-feature reader](../qwen-positive-kernel/README.md) had huge random-feature variance geometry and poor actual attention/output response. **Most of its uncentered exponent is a removable mean, but substantial residual geometry remains.** Without changing its table, rank, code, values, inference image or output evaluation, this study constructs **one source/train-only shared key shift** and measures only `||u_i+v_j−c||²` on every original causal pair of all eight train and four inspected-held layer-0 GQA windows. On train, the two-head average pair exponent falls **3,357.770 → 395.244**, exactly **2,962.526** by the centroid identity. On inspected held it falls **3,525.875 → 429.194**. The minimum centered causal exponent over all train pairs is still **22.542** (head0) / **26.600** (head1), with per-window medians commonly `164–276`; thus centering alone does not make the *iid Gaussian variance expression* small at rank64. This is **not** an output-quality result for any centered feature reader, and does not exclude another positive kernel or paid co-design.

## Declared pair law, exact source and gauge

The source is the same pinned Qwen3-0.6B BF16 checkpoint SHA256 `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b` and producer fixture SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`. The actual first two layer-0 Q heads and their shared K use the original BF16 projection, Q/K learned-gamma RMSNorm and original position-dependent RoPE from [`attention-consumer/measure.py`](../attention-consumer/measure.py), then divide their 128 coordinates by `128^(1/4)` so the original score is `u_i·v_j`. All eight train windows and four held windows have 256 causal positions. The first 128 fixture Q weight rows are checked exactly against the checkpoint. No synthetic Gaussian producer or newly captured data is used.

The declared **training pair measure** is uniform across all two heads, all eight windows, and all **32,896 lower-triangular `(query i,key j≤i)` pairs** within each window. It is *not* uniform-query followed by a uniformly sampled prior: longer query prefixes receive more mass. A single common shift `c` is used for the **shared K** across both Q heads and all windows, rather than separate per-head/window fitted shifts. In [`screen.py`](screen.py), the train centroid is evaluated without constructing a giant pair array:

`c = [Σ_windows Σ_heads (Σ_i (i+1)u_hi + Σ_j (256−j)v_j)] / (8×2×32896)`.

The resulting FP64 vector [`train-causal-pair-center-f64.npy`](train-causal-pair-center-f64.npy) is 1,152 bytes in its NumPy container (1,024 raw payload bytes), SHA256 `0f73d862603b687cc41ef4f37574cf7d87f13dd98bec4443386bed773fdb3023`, with squared norm **2,962.5258529593457**. The data file is a **diagnostic preparation artifact, not inference metadata**. If an inference reader chose this exact FP64 center it would have to pay the 1,024 raw value bytes plus a format/ownership decision; a separately rounded FP16 center would need 256 B but would be a different, untested program. Per-token subtracting a paid center and loading it also count as preparation/live work. This study does not claim either paid candidate runs or improves output.

Replacing every K coordinate `v_j` by `v_j−c` changes a score by the same query-row bias `−u_i·c` at every visible prior position, so **exact softmax probabilities, V mixing and O output are unchanged** in ideal arithmetic if such a gauge is actually applied consistently. For the *specific ideal continuous iid Gaussian positive-product estimator*, its per-score relative variance at rank `r` becomes `(exp(||u_i+v_j−c||²)−1)/r`; this expression is **not gauge invariant** even though exact softmax is. The centroid uniquely minimizes the declared finite-pair *mean exponent* `E||u+v−c||²`, and the train mean drops by exactly `||c||²`. It does **not** necessarily minimize mean variance, normalized attention error, final O error or finite-FP16-table behavior. The parent's general gauge theorem and toy own the abstract result; this directory owns only its pinned producer arithmetic and receipts.

## All causal-pair geometry, no second candidate

[`aggregate.py`](aggregate.py) requires all twelve per-window receipts, verifies the train-center hash, combines equal-count means and extrema, and checks the centroid reduction identity on train. Window median ranges below are ranges of individual **window medians**, not pooled global quantiles. Score-row-gauge identity is checked on actual source matrices in every window; no attention output from shifted keys is measured.

| Panel, two-head mean | Uncentered exponent mean | Centered exponent mean | Reduction | Original key norm² mean | Shifted key norm² mean |
| --- | ---: | ---: | ---: | ---: | ---: |
| train | 3,357.7703 | 395.2444 | 2,962.5259 | 3,311.9282 | 398.8147 |
| inspected held | 3,525.8752 | 429.1943 | 3,096.6809 | 3,487.3460 | 434.8601 |

| Panel/head | Uncentered exponent minimum | Centered exponent minimum | Centered mean | Centered window-median range | Centered maximum |
| --- | ---: | ---: | ---: | ---: | ---: |
| train head0 | 740.580 | 22.542 | 388.412 | 164.354–260.806 | 5,024.127 |
| train head1 | 762.329 | 26.600 | 402.077 | 178.736–275.558 | 5,069.966 |
| held head0 | 736.196 | 20.114 | 422.120 | 221.110–272.169 | 6,836.733 |
| held head1 | 747.564 | 25.015 | 436.268 | 240.223–283.464 | 6,877.525 |

The minimum train head0 exponent alone would give the ideal iid rank64 *per-score* relative-variance factor `≈exp(22.542)/64` (well above one), but a large per-score variance does **not** prove the normalized kernel output must be bad: numerator and denominator can covary, and deterministic source-aware features need not be iid Gaussian. Conversely the huge removable uncentered mean invalidates any claim that the frozen reader's variance obstruction is invariant under score-preserving recoding. Held values diagnose the same train-derived `c`; no held-derived choice is made. The actual frozen uncentered reader and conventional paid controls remain in their [separate primary study](../qwen-positive-kernel/README.md).

## Reproduction

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$PY research/isa-quantization/qwen-kernel-gauge-screen/screen.py center
for i in 0 1 2 3 4 5 6 7; do $PY research/isa-quantization/qwen-kernel-gauge-screen/screen.py train "$i"; done
for i in 0 1 2 3; do $PY research/isa-quantization/qwen-kernel-gauge-screen/screen.py held "$i"; done
$PY research/isa-quantization/qwen-kernel-gauge-screen/aggregate.py
```

Each CPU command finishes within a minute; no GPU, new feature table, K/V code fit, native reader or extra source capture is involved. [`center.json`](center.json) pins the centroid and law, twelve per-window JSON receipts include causal exponent distributions, and [`results.json`](results.json) combines them. It is source/consumer geometry, not a proposed replacement state or a held-quality estimate.
