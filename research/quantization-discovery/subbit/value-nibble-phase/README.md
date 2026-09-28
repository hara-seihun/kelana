# Shifting the one-nibble mass grid does not rescue a head

A single unsigned probability nibble would halve the dot passes of the 255-unit narrow-value consumer. Before changing the value codes, I tested the cheapest extra degree of freedom in its count map: a constant phase for the prefix rounding grid. The phase is fixed per head on train text. It changes no paid V/O bytes, cache bytes, integer-dot grammar or per-query preparation beyond adding one scalar to each prefix. On the frozen Qwen3-0.6B layer-0 and layer-14 images, even the best of sixteen phases for every parent-selected head leaves **zero** heads that can switch to one digit under the existing 1e-4 train post-O error budget.

For a normalized causal probability row, let `C_t = sum_{i<=t} p_i` and `P_t(u) = floor(15 C_t + u)`, with `u` in `{0, 1/16, ..., 15/16}`. Set `P_0=0` before the first key and force the final prefix to 15. Counts `P_t-P_{t-1}` are nonnegative, sum to 15 and lie in `[0,15]`. Thus the same signed/unsigned nibble dot computes `sum_t (P_t-P_{t-1}) c_t` directly against each packed signed-nibble V coordinate. At most fifteen keys can have nonzero mass. In exact real arithmetic, each interior prefix discrepancy is less than one unit, yielding `|step|/15 * sum_t |c_t-c_{t+1}|` as a coordinate error bound. Phase one-half normally gives the tighter nearest-prefix half-unit bound; the other phases trade that uniform bound for a different placement of the count units. Floating prefix accumulation and final FP32 O accumulation are replayed, not covered by the real bound.

The replay holds the paid rank-28 V/O factors, Q/K probabilities and signed-nibble codes fixed. Eight 256-token original-producer train windows select one head in the parent's 255-unit mask and one of sixteen phases; four previously inspected validation windows replay that selection. Every eligible `(head, phase)` pair is scored against the **complete summed post-O response** of the all-4095 map, not merely its head in isolation. The parent 255/4095 mix is the baseline. This is an exhaustive 240-candidate search at layer 0 and 64-candidate search at layer 14, within the one-switch, fixed-head-phase grammar. It is not an optimum over continuous phase, multiple switched heads, per-query offsets or changed value codes.

| Layer | Parent train error | Best train head/phase/error | Held parent / selected error | Held four-lane dot8 slots on switched head, 255 -> 15 |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .00008613 | 7 / .375 / .00010574 | .00008794 / .00011435 | 40,672 -> 18,288 |
| 14 | .00006598 | 12 / .5625 / .00089142 | .00006063 / .00093140 | 71,392 -> 16,736 |

The previous fixed nearest-prefix one-head minima were .00010643/.00102862 on train, so phase placement helps a little at layer 0 and substantially at layer 14, but neither crosses the threshold. The modeled head slots assume four-lane padded nonzero-key lists and four dot8 instructions for 32 padded coordinates per active digit/key. The selected program keeps the 255-unit parent heads because no switch qualifies; its realized slot saving is zero. A hypothetical switch also needs the count scan, list construction and scattered cache accesses, none of which these dot slots price. The half-byte V cache itself still trails the E4M3 quality control on this frozen image. No GPU, native consumer, quantized-producer loss or Bonsai service changed.

The next question should change the **value representation and mass assignment together** on quantized-producer complete-model text. A value-aware fifteen-unit map might place mass where the two O consumers are sensitive, but calculating that placement is online work and must beat the saved dot pass. Another fixed phase sweep on these codes does not address the missing capacity.

`measure.py` replays both layers using the pinned model and captures. The per-candidate train and held errors, slot counts and source/model/capture/factor/cache/parent hashes are in `/path/to/workspace/data/kelana-subbit/value-nibble-phase/layer{00,14}.json`. From a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-nibble-phase/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-nibble-phase/measure.py --layer 14
```
