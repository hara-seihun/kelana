# Per-query phase grid against the exact one-nibble oracle

The response-optimal systematic phase search sorts up to 255 events and prepares a separate 28-by-28 metric difference for each key and query. A finite uniform phase grid avoids both. I compared 2, 4, 8, 16 and 32 phases per query with the exact event optimum on the same frozen signed-nibble value codes. This is a per-query response selector, not the earlier train-fixed phase study.

For each grid phase `u=k/m`, prefix boundaries are `floor(15*cumulative_probability+u)` and the terminal boundary is fixed at 15. The counts are nonnegative and conserve fifteen units on the normalized real simplex. Evaluate each candidate's 28-coordinate numerator and its quadratic post-O error against the floating code response; select the smallest error. This finds the exact minimum within the `m`-phase grid. It cannot guarantee the continuous-phase optimum: a winning interval between adjacent events can contain no grid phase. Neither search attempts unrestricted fifteen-unit allocation.

The Qwen3-0.6B replay uses the same original-producer captures, paid rank-28 image, cache-code steps and sampled heads 7/12 as [the event search](../value-adaptive-phase/README.md). Eight train and four repeatedly inspected validation windows each contribute causal positions 63, 127, 191 and 255. Errors use the paid head's post-O metric and the 4,095-unit response as reference, divided by that reference's squared energy. The selector itself minimizes error against the floating-probability code response.

| Layer, split | Prefix 15 | Exact event | Grid 2 | Grid 4 | Grid 8 | Grid 16 | Grid 32 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 train | .00060829 | .00024321 | .00024509 | .00024509 | .00024321 | .00024321 | .00024321 |
| 0 inspected validation | .00006709 | .00006096 | .00006709 | .00006709 | .00006709 | .00006709 | .00006096 |
| 14 train | .00136620 | .00083914 | .00106233 | .00094945 | .00091150 | .00090861 | .00089282 |
| 14 inspected validation | .00046388 | .00028060 | .00036711 | .00034818 | .00031845 | .00029828 | .00029828 |

At layer 14 the sixteen-phase grid captures 90.3% of the inspected-held prefix-to-event improvement, measured as `(prefix-grid16)/(prefix-exact)`. Doubling to 32 does not improve held error. Layer 0 has too little held improvement for a grid to recover until 32 phases. This narrows the *selection* question: a cheap policy should predict a useful phase or shortlist, rather than prepare 255 dense metric differences. The result does not qualify a head for the complete-layer 1e-4 budget and does not fix the frozen cache's gap to E4M3.

The grid still loses the online-cost argument. With `n=256`, width `d=28` and `m=16`, a direct implementation has about `m*n=4,096` prefix boundary operations, at most `m*15*d=6,720` count/code accumulation products, `m*d²=12,544` Gram-evaluation multiply-adds, and `n*d=7,168` products for the floating target, plus count extraction, phase choice and the final packed nibble dot. This replaces the event search's roughly `255*28²=199,920` dense metric-preparation products and sort but remains tens of thousands of scalar operations to save one probability digit on one head. The fixed 28-by-28 Gram is image metadata; no free transformed per-key cache is assumed. Computing `m` dense 28-coordinate responses instead of sparse fifteen-key gathers only increases this cost. No native time, quantized-producer complete-model loss or serving path changed.

The exact next experiment is to train value codes and a small phase predictor together against quantized-producer composed loss, with the event search supplying a target and a measured selector budget below the removed dot work. A larger brute-force grid on these same frozen rows is not that experiment.

`measure.py` reproduces the CPU panel. Rowwise phases, event counts, energy and errors, plus source/model/capture/factor/cache/parent hashes, are in `/path/to/workspace/data/kelana-subbit/value-phase-grid/layer{00,14}.json`.

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-phase-grid/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-phase-grid/measure.py --layer 14
```
