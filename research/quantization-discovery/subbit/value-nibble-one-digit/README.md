# One probability nibble is too coarse for the frozen narrow V/O image

A conserved 15-unit probability row fits one unsigned nibble per key. The existing 28-coordinate signed-nibble V cache can consume it with one `v_dot8_i32_iu4` per eight coordinates, with no float or byte expansion of the cached code. This halves the digit passes of the 255-unit arm and removes two of the three passes of the 4,095-unit arm. On the frozen Qwen3-0.6B layer-0/14 V/O images, however, **no head can switch from the train-selected 255/4,095 mix to 15 units under its existing 1e-4 train post-O rounding-error budget**. That is an exact subset result inside this fixed-image, prefix-rounded grammar, not a claim about learned value codes or value-aware mass assignment.

For a normalized causal probability row, let `N_t(M)=round(M sum_{i<=t} p_i)-round(M sum_{i<t} p_i)`, with the final prefix fixed to `M`. With `M=15`, every `N_t` is an unsigned nibble, sums to 15, and at most fifteen keys can have nonzero mass, at *any* context length. For each cached signed-nibble code coordinate `c_t` in `[-8,7]`, the integer numerator `sum_t N_t c_t` lies in `[-120,105]`. One signed-first/unsigned-second packed nibble dot per eight coordinates computes it exactly; the FP32 scale, denominator and O projection remain separate operations and have no bit-identity claim. The real-probability prefix-rounding error satisfies `|step|/(30) sum_t |c_t-c_{t+1}|` per coordinate, before FP rounding. Unlike 255 units, fifteen units give this bound little room when adjacent codes vary.

The same Q/K probabilities, paid rank-28 V/O image and signed-nibble cache steps as the [255-unit experiment](../value-nibble-255/README.md) were replayed. Eight 256-token original-producer train windows fix the head subset. Four repeatedly inspected validation windows are held only relative to that fit. The train objective is the complete summed post-O response against all-4,095 mass; it includes cross-head cancellations. For each subset of heads that the parent assigned 255 units, replace those heads with 15 units. The difference vectors give the exact quadratic `E(S)=E(0)+2 sum_{i in S}<r,d_i>+sum_{i,j in S}<d_i,d_j>` in real arithmetic. All `2^15` or `2^4` masks were evaluated, with the minimum recorded at each cardinality. The winning masks were replayed through the actual FP32 output path on held windows.

| Layer | Parent 255 heads | Best one-15-head train error | Parent train / held error | All-15 held error | All-15 four-lane dot8 slots |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 15 | .00010643 | .00008613 / .00008794 | .01099438 | 597,968 |
| 14 | 4 | .00102862 | .00006598 / .00006063 | .19206680 | 527,632 |

The best layer-0 single switch is head 7; it misses the 1e-4 budget by .00000643 on train and scores .00011527 held. The layer-14 best single switch is head 12 and scores .00087920 held. All-15 would cut modeled four-lane dot slots from 5,831,456 to 597,968 at layer 0 and 6,842,432 to 527,632 at layer 14, but destroys the fixed-map rounding quality. At the declared budget, the actual selected program has **zero** slot reduction. Those slot totals include four-lane padding for the nonzero mass list; they omit probability preparation, scan, compaction, cache gathers, O work, divergence and native time. The V/O factor bytes and 112-byte logical V cache are unchanged.

This closes the cheap one-digit extension of the **frozen 255-head allocation**, not all three-way allocations, different rounding rules, codebooks or quantized-producer loss. A new one-digit attempt needs a jointly learned code/consumer or a value-aware assignment of its fifteen units, with the extra per-query selection work charged. The current quality-credible direct route remains two or three probability nibbles. It is more useful to repair the V/O basis and codes on quantized-producer complete-model text than to time this poor-quality one-digit map.

`measure.py` reproduces the CPU panel using the pinned model and captures. `/path/to/workspace/data/kelana-subbit/value-nibble-one-digit/layer{00,14}.json` retains every train-best cardinality and held replay, the parent mask, per-window errors, support/slot counts, and source/model/capture/factor/cache/parent hashes. From a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-nibble-one-digit/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-nibble-one-digit/measure.py --layer 14
```
