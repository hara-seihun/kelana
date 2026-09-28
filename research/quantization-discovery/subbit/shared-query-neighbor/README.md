# Certify the shared query by walking its nearest nibble neighbors

The [joint three-dot query](../shared-query-joint-round/README.md) has a conditional fifteen-label least-squares fit. The [interval certificate](../shared-query-pruning/README.md) reduced the number of scored labels, but computing its endpoints needs a square root and divisions. A nearest-neighbor walk gets exactly the same conditional optimum using only quadratic lower-bound comparisons. It is a cheaper query-preparation construction, not a native speed measurement.

For base query `a0`, other query `a1`, positive base/difference scales `d,e`, and positive head weight `lambda`, let `delta=a1-a0`. Candidate base integer `u` lies in `[-119,119]`, difference nibble `v` in `[-7,7]`, and

```
L(u,v) = (a0-d*u)^2 + lambda*(a1-d*u-e*v)^2.
B(v) = lambda/(1+lambda)*(delta-e*v)^2 <= min_u L(u,v).
```

First score `v0=clip(round(delta/e),-7,7)` using its clipped nearest conditional `u`. This supplies a feasible cost `U`. Inspect `v0-1` and `v0+1` if they are in range. On either side, stop as soon as `B(v)>U`; if not, score its conditional `u`, update `U`, and inspect the next integer on that side. Keep a side open at equality to preserve all ties. This needs no square root, endpoint rounding or fifteen-way bound vector. The sequence `B(v0-1),B(v0-2),...` and its right-hand counterpart are nondecreasing because `v0` is the nearest clipped integer to `delta/e`. Once a bound exceeds the feasible best, every later label on that side is excluded. If `U` falls after another score, a stopped side stays stopped. Hence the final cost is the global minimum of the fixed-scale, diagonal, real-arithmetic lattice problem, including clipped `u` endpoints. The proof applies to every finite query, not just these captures. The `1e-12` inclusive FP64 guard in the replay is a measurement detail; a native implementation promising the same finite-precision choice needs conservative bound evaluation.

## Frozen paid Q/K replay

The replay loads the same Qwen3-0.6B binary Q/K images, selected K coordinate/step, two-head train-selected weights and original-producer 256-token windows as the interval report. Each scored coordinate is checked against full fifteen-way enumeration. Adjacent 32 coordinates are grouped into a hypothetical SIMD32 wave, so `slow_waves` counts waves containing at least one coordinate that needs another scored nibble. This is a scheduling diagnostic, not issued instruction time.

| Layer / split | Coordinates | Scored candidates | Bound tests | Waves scoring another label | Mean maximum bound tests/wave |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 / train | 524,288 | 528,265 | 1,032,215 | 3,152 / 16,384 | 2.187 |
| 0 / inspected validation | 262,144 | 263,976 | 515,896 | 1,450 / 8,192 | 2.172 |
| 14 / train | 524,288 | 536,161 | 1,039,149 | 6,404 / 16,384 | 2.384 |
| 14 / inspected validation | 262,144 | 268,235 | 519,766 | 3,208 / 8,192 | 2.385 |

The exact scored-label histograms equal the preceding interval's histograms: held layer 0 scores one/two labels on 260,312/1,832 coordinates; layer 14 scores one/two/three on 256,054/6,089/1. The new walk usually evaluates two scalar lower bounds, and the worst measured coordinate evaluates four. Most coordinates stop after the incumbent, yet 17.70%/39.16% of held layer-0/14 waves need a second score. A warp-level implementation cannot price itself from the mean 1.007/1.023 candidate count alone. In the stated 32-coordinate arrangement, about 82%/61% of waves can skip every extra score. The three key-cache dot passes, 128 key bytes/token/layer, and frozen .278049/.333448 held attention KL are unchanged. There is no quantized-producer language loss or native timing here.

`measure.py` replays both layers in the installed CPU environment, writing source/model/capture/paid-image/parent hashes and group histograms to `/path/to/workspace/data/kelana-subbit/shared-query-neighbor/layer{00,14}.json`:

```sh
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/quantization-discovery/subbit/shared-query-neighbor/measure.py \
  --layer 14 --output /path/to/workspace/data/kelana-subbit/shared-query-neighbor/layer14.json
```

The next native question is a single bounded panel of the full query-preparation and fused three-dot two-head score against independent three-dot and four-dot scores at occupied context. Use the wave slow-path fraction above to choose a layout, and check fresh quantized-producer quality before selecting a serving path. If this conditional quality gain vanishes, training the paid Q/K producer and score consumer together is more useful than polishing its rounding.
