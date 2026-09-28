# Query-dependent residuals in the direct nibble-key score

The frozen paid Q/K observer's second nibble dot is not uniformly valuable across queries. Selecting its correction coordinates from the query rather than a fixed training order improves held causal attention KL at the same *logical* product count. The catch is physical: arbitrary selected coordinates do not form fewer `v_dot8_i32_iu4` operands without a query-dependent key gather and packing. Restricting the choice to whole contiguous eight-coordinate tiles makes that lowering plausible but loses most of the quality gain. This is a useful split between a better finite score map and a still-unpaid machine program.

Qwen3-0.6B layers 0 and 14 use the same frozen binary Q/K factors, 128 selected RoPE planes, train-chosen signed-nibble key steps and 128-byte K cache as [the fixed-coordinate study](../nibble-query-sparse/README.md). Eight 256-token train windows supply key-code variance and the fixed-coordinate order. Four repeatedly inspected validation windows measure teacher-to-candidate causal KL over both heads and all eight GQA groups, using original-producer inputs. Each query chooses its coordinates before reading any keys and without seeing teacher scores or labels.

| Layer | One dot | Fixed 16 | Adaptive 16 | Fixed 24 | Adaptive 24 | Full second dot |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .290584 | .281867 | .277047 | .277886 | .275533 | .275381 |
| 14 | .362763 | .346036 | .336828 | .338124 | .332957 | .332397 |

The adaptive 16-coordinate map beats the fixed 24-coordinate map on all four aggregate held windows at both layers. Its 768 signed-nibble products per cached key/layer across the two heads are 128 fewer than the fixed 24 map's 896, and 256 fewer than the full two-dot map's 1,024. The 24-coordinate adaptive arm comes within .000152/.000560 KL of the full correction at layers 0/14. These are product counts, **not issued dot instructions or native time**. Query preparation, variable key gathers, packing and softmax remain in the online path. The 128-byte cache and full raw K RMSNorm producer are unchanged. The two-dot control remains the practical candidate until a cheaper layout is found.

## Why this selector is optimal for one explicit surrogate

Let `c_j(t)` be a stored signed-nibble key code and let the prepared query coordinate be `a_j=q_j*s_j`. With `d=max |a_j|/7`, the first dot uses `z_j=round(a_j/d)` clamped to `[-7,7]`, and the residual digit is `r_j=round(16(a_j/d-z_j))` clamped to `[-8,7]`. For a subset `S` the real-valued score map is

```
(d / sqrt(128)) * (sum_j z_j*c_j(t) + sum_{j in S} r_j*c_j(t)/16).
```

The inner sums are exact signed integers in int32. A common key-code mean contributes the same score shift to every causal key and disappears under exact real softmax. For a fixed query, assume the centered cached key coordinates have diagonal covariance with train variances `v_j`. The variance of the *omitted* full-second-dot correction is then `d²/(128*256) * sum_{j not in S} r_j²*v_j`. Selecting the `m` largest `r_j²*v_j` is exactly optimal for that conditional quadratic and fixed cardinality. This is not an optimality statement for causal KL, correlated key codes, BF16 arithmetic, or a different producer. The measured KL above tests whether the cheap diagonal choice transfers.

An arbitrary coordinate mask must be gathered from each packed key or applied to four complete eight-lane dot operands, in which case it saves no dot instructions. For a realizable two-of-four-tile choice, I also evaluated the same selector with eight-coordinate physical tiles and with an offline train-rank round-robin permutation of the key/query coordinates. At 16 selected coordinates, held KL for original tiles / balanced tiles is .281337/.281424 at layer 0 and .345242/.345459 at layer 14. The fixed 16 map is .281867/.346036. Thus tile selection gives only .000530/.000577 over fixed, versus .004819/.009209 for arbitrary coordinates; balance-by-train-rank does not rescue it. Two tile dots still need four tile-energy reductions, a choice and dynamic tile addresses per head/group/query. There is no native or complete-model benefit claim.

The next worthwhile experiment learns a *key-coordinate transform and packed tile layout* with the query rounding rule, so that cheap tile choices capture the adaptive residual energy. Train against finite causal loss on quantized-producer text and compare full-model quality to the unchanged two-dot map before timing a native path. More fixed coordinate-mask sweeps on this same image will not close the gap.

`measure.py` replays the held captures on CPU, including the fixed-order controls from their prior receipts. `/path/to/workspace/data/kelana-subbit/nibble-query-adaptive/layer{00,14}.json` holds per-group/window train and validation KL, the learned variance and balanced tile map, program counts, and SHA-256 hashes of source, model, capture, paid Q/K images and parent receipts. The cached keys and all candidates share the same causal workload; no GPU, Bonsai executable or resident service changed.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/nibble-query-adaptive/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/nibble-query-adaptive/layer$(printf '%02d' "$layer").json"
done
```
