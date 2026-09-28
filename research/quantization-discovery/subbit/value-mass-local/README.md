# Local mass rounding for the direct narrow-value consumer

The [integer narrow-value consumer](../value-integer-consumer/README.md) conserves a 4,095-unit probability mass by rounding a cumulative sum at every causal key. That puts a prefix scan between softmax and the signed-byte dots. An independent key rounding plus one conservation repair is a different approximate map with a simpler candidate schedule: one reduction for the integer count sum, one for the largest probability, then one correction at that key. On the frozen Qwen3-0.6B layer-0/14 captures it preserves nonnegative counts and the total mass on **all 98,304 inspected query/head rows at each mass**. At 4,095 units its held post-O error barely moves. The result warrants a native scan-versus-reduction experiment, not an inference speed claim or a replacement for the pinned nibble V/O image.

For a causal probability row `p` with sum one, mass `M`, and a deterministic maximum-probability key `j`, form `r_k = round_even(M p_k)`, `D = M - sum_k r_k`, then set `n_j = r_j + D` and `n_k = r_k` elsewhere. Every count remains nonnegative exactly when `D >= -r_j`. Otherwise this one-owner program is invalid. The final sum is `M`; zero-probability keys are untouched because the owner has positive probability. For nibble codes `c_k` in `[-7,7]`, the integer attention coordinate `sum_k n_k c_k` has magnitude at most `7M` and fits int32. With `M=4095`, the [radix-128 sparse high-digit dot](../value-mass-radix/README.md) consumes these counts without expanding values, and at most 31 keys/head need high digits by mass conservation. Its exact integer observation changes when this quantizer replaces prefix rounding, even though both have the same mass and code alphabet.

The feasibility condition is real, not a theorem about all softmax rows. A 256-key probability row with 200 unnormalized masses of 15.51 and 56 of `(4095 - 200*15.51)/56` sums to 4,095; independent rounding sums to 4,208. The deficit is -113 but the largest rounded key has only 18 units. This row would produce a negative count. A production implementation needs an always-valid distributed repair or a priced fallback. The checked adversary lives in [`measure.py`](measure.py).

## Captured behavior

The source replays original-producer Q/K softmax on eight 256-token train windows and four repeatedly inspected validation windows per layer, 16 query heads each. It uses the same FP64 mass multiplication and nearest-even rounding as the prefix control. Validation post-O compares the same paid rank-28 V/O image, the previously train-fitted per-coordinate signed-nibble cache, and the original V/O teacher. Only the mass quantizer changes. Model, capture, factor, cache-fit and source hashes accompany per-window errors in `/path/to/workspace/data/kelana-subbit/value-mass-local/layer{00,14}.json`.

| Layer | Mass | Train feasible / rows | Held feasible / rows | Held mean `L1(n_local-n_prefix)/M` | Held post-O relative squared error, prefix → local | Held high-key support, prefix → local |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 127 | 32,768 / 32,768 | 16,384 / 16,384 | .116740 | .387033 → .390945 | not applicable |
| 14 | 127 | 32,768 / 32,768 | 16,384 / 16,384 | .136427 | .378737 → .364808 | not applicable |
| 0 | 4,095 | 32,768 / 32,768 | 16,384 / 16,384 | .005361 | .386705 → .386787 | 75,633 → 75,634 |
| 14 | 4,095 | 32,768 / 32,768 | 16,384 / 16,384 | .007774 | .365405 → .365548 | 68,350 → 68,355 |

At 4,095 units, the four held windows per layer all move slightly upward in teacher error. Local-versus-prefix squared output difference relative to the prefix output is 2.40e-6 at layer 0 and 4.52e-5 at layer 14. The maximum held correction deficit is 26/28 units and the maximum per-row count-vector L1 change is 90/98 units at layers 0/14. The `L1/M` entries are exact total-variation surrogates before the shared code dot, not a post-O quality guarantee. The general code-coordinate difference is bounded by `7 * ||n_local-n_prefix||_1` units, which is loose and says nothing about the learned O projection. The surprising 127-unit layer-14 improvement is a changed approximation that happens to compensate frozen cache error, not evidence that one-dot arithmetic is globally more accurate.

## What to try next

The useful native question is whether eliminating a cross-key prefix scan beats two reductions, one indexed correction and a validity check when all count construction stays inside the timed kernel. A model-less panel should compare *equal* nibble caches, softmax inputs, full low/high dots and occupied contexts, including longer rows where the fast-path feasibility rate may change. For a complete program, develop an always-valid repair or time a fallback on its actual frequency. The 4,095-unit map is the credible quality arm on these captures. The 127-unit arm's quality is layer-dependent and should not be selected on this repeatedly inspected text. Neither arm fixes the nibble cache's deficit against E4M3; refitting the V basis and O codes on quantized-producer complete-model text remains independent work.

From a Kelana checkout, each panel runs within a bounded CPU command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-local/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-local/measure.py --layer 14
```
