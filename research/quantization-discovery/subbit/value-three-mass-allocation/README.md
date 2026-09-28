# Three probability masses, one frozen narrow-value image

Can headwise cancellation make a fifteen-count, one-nibble attention mass viable when every single-head switch fails? This experiment gives each of sixteen Q heads one of three conserved masses, 15, 255 or 4095, and minimizes the *complete four-lane padded dot-slot count* subject to a train post-O rounding-error budget. It enumerates the entire `3^16 = 43,046,721`-assignment family, rather than extending only heads selected by a prior two-mass mask.

At the existing `1e-4` train budget, **neither layer selects a 15-count head**, even though the search permits cross-head cancellation and arbitrary changes to the 255/4095 assignments. The three-mass optimum equals the exact two-mass optimum. On this frozen Qwen3-0.6B image, no head-mask search recovers a one-digit saving at the quality threshold. The first one-digit choice appears at `2e-4` on layer 0 and `2e-3` on layer 14. This is a useful stop rule for this image and prefix-rounding rule, not a limit on codes learned for fifteen counts.

| Layer | Train budget | Mass-15 heads | Held four-lane slots, three/two masses | Held relative rounding error, three/two masses |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 1e-4 | 0 | 2,797,248 / 2,797,248 | .00009920 / .00009920 |
| 14 | 1e-4 | 0 | 5,683,536 / 5,683,536 | .00009599 / .00009599 |
| 0 | 2e-4 | 1 | 2,498,144 / 2,520,560 | .00013857 / .00010979 |
| 14 | 1e-3 | 0 | 2,472,304 / 2,472,304 | .00055714 / .00055714 |
| 0 | 5e-4 | 3 | 2,345,056 / 2,520,560 | .00052791 / .00010979 |
| 14 | 2e-3 | 1 | 2,360,736 / 2,472,304 | .00207535 / .00055714 |

The all-4095 held work controls are 5,831,456 and 6,842,432 slots for layers 0 and 14. The `1e-4` masks use fifteen and five 255-count heads respectively. A further `5e-4` train budget buys a 6.96% slot reduction at layer 0 but none at layer 14. The selected layer-0 held error at that larger budget is .000528, slightly above train .000488. Counts, selected masks, every budget and held-window scores are in the receipts.

## Finite-family certificate

For each head `h` and mass `m`, use nonnegative prefix-rounded counts

```
n_t(m) = round(m * sum_{i<=t} p_i) - round(m * sum_{i<t} p_i),
```

with the last prefix fixed to `m`. These sum to `m`. A signed-nibble value code times a 15-count integer needs one unsigned/signed nibble dot pass; 255 and 4095 need two and three passes. No floating key value is expanded per key. The head output is the paid 28-coordinate O response of that mass-normalized integer accumulation. For each nonbaseline choice let `d_{h,m}` be its recorded output minus the 4095 output, flattened over eight training windows. For any assignment `a`, real-arithmetic squared error against the all-4095 map is exactly

```
E(a) = sum_{h,k} <d_{h,a_h}, d_{k,a_k}>,  d_{h,4095}=0.
```

The 32-by-32 Gram and all per-head slot costs are stored in each receipt. `search.cpp` visits every assignment except branches whose accrued nonnegative work is already no better than a feasible incumbent. It does **not** prune on error, where future heads could cancel it. Thus it finds minimum train four-lane dot slots under each specified budget; ties in work need not minimize error. The two-mass control runs the same search with 15 disallowed. Each winner is replayed from its actual held head outputs rather than trusting the quadratic for FP32 summation. The Gram concerns the recorded FP32 per-head outputs interpreted in real arithmetic, not a proof of bit-identical FP32 mixed-head reduction.

The panel uses eight 256-token train and four repeatedly inspected validation windows, recorded original-producer probabilities and BF16-prepared rank-28 coordinates. It uses the refitted two-bit O matrix and signed-nibble steps/endpoints in the [prepared mixed-cache panel](../value-cache-mixed-rate/README.md). This is a **different frozen V/O image** from the original [two-digit study](../value-nibble-255/README.md); all comparisons here use the same prepared factors and cache. The per-head work is four issued dot8 slots per nonzero digit/key, rounded to four-key subgroups. It includes the sparse-list lane padding but not probability scans, list construction, gathers, O projection, divergence, native latency or full-model language quality. The frozen nibble cache still needs a quality win over E4M3.

The next one-digit experiment should alter the value basis, code labels or mass assignment on quantized-producer complete-model text, then price the whole consumer. Another head-mask enumeration of this frozen prefix-rounded image cannot improve the `1e-4` result.

`measure.py` consumes the pinned prepared train/validation arrays at `data/kelana-subbit/value-cache-mixed-rate/layer{00,14}-{train,validation}.npz`. Run `g++ -O3 -std=c++17 -o research/quantization-discovery/subbit/value-three-mass-allocation/search research/quantization-discovery/subbit/value-three-mass-allocation/search.cpp`, then `OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-three-mass-allocation/measure.py --layer 0` or `--layer 14`. Receipts at `/path/to/workspace/data/kelana-subbit/value-three-mass-allocation/layer{00,14}.json` include source, prepared-input and cache-fit SHA-256 hashes, per-head work, Gram, assignments and per-window held errors. No GPU, Bonsai executable or resident service changed.
