# A probability-only candidate list for exact high-digit value attention

The [radix-128 direct value consumer](../value-mass-radix/README.md) computes a dense signed-byte low digit and a sparse signed-byte high digit for each 4,095-unit probability count. Its high list previously depended on completing every count in the prefix-rounded map. A threshold on the softmax probability can instead identify a *superset* of the high keys before the count scan. On the frozen Qwen3-0.6B layer-0/14 causal captures, it adds only 0.37%/0.27% false positives to the held high lists. This is an exact scheduling option, not a new quantizer, quality gain or timed native speedup.

## The bound and the program it permits

For a normalized nonnegative real probability row, let `S_k = M sum_{i<=k} p_i`, `M=4095`, `R` be nearest-even integer rounding and `n_k=R(S_k)-R(S_{k-1})`. Put `x_k=M p_k`. Since each rounding error lies in `[-1/2,1/2]`, `|n_k-x_k|<=1`. Therefore `n_k>=128` implies `x_k>=127`, and `x_k>129` implies `n_k>=128`. These bounds are tight as uniform threshold statements: an integer-length interval starting on a half-integer can gain an extra count from opposite tie parities. The maximum number of high keys in a row is `floor(4095/128)=31`, because counts are nonnegative and sum to 4095.

The captured implementation rounds a FP64 cumulative sum of FP32 softmax probabilities and forcibly sets the final prefix to 4095. Exact-real bounds do not automatically cover that operation. In the replay, maximum measured probability-sum deviations are at most `4.405e-7`. A conservative `x>=126` guard includes FP64 cumulative-sum error at this length and the final-prefix correction; `measure.py` checks both guards against every actual high digit. A native lowering should use the conservative guard or prove its own floating error envelope. This is not a claim of bit identity between different scan schedules.

During softmax, compare `4095*p` against the guard and compact candidate key indices with a ballot. Later count construction still produces the low digit for *every* key. For the candidate keys, use the exact prefix-derived count to calculate `floor(n/128)` and execute the high dot; candidates with zero high digit are harmless. Thus the ballot and the count scan need not be serial, while the numerical map, nibble cache and V/O projection remain unchanged. This does not remove the scan, the query-dependent threshold, or scattered candidate gathers. Padding a list to 32 lanes per row erases almost all the earlier high-support benefit; a native implementation must price a smaller cooperative list or multiple rows per wave.

## Frozen CPU panel

Eight train and four previously inspected validation windows per layer, each 256 tokens and 16 query heads, replay the existing original-producer Q/K softmax. The source, parent, model and capture hashes and both splits' counts are in `/path/to/workspace/data/kelana-subbit/value-high-prefilter/layer{00,14}.json`.

| Layer, held | Causal pairs | Actual high keys | `x>=127` candidates | `x>=126` guarded candidates | Eight-lane padded actual → candidates |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | 2,105,344 | 75,633 | 75,916 | 76,476 | 151,384 → 151,632 |
| 14 | 2,105,344 | 68,350 | 68,538 | 68,907 | 139,264 → 139,440 |

At layer 0, the threshold's extra 283 candidate pairs are 0.0134% of all causal pairs; at layer 14, 188 are 0.0089%. Even the guarded lists contain just 3.63%/3.27% of causal pairs. The eight-lane padded candidate lists add 248/176 key slots over post-scan compaction on the inspected held windows. The ceiling of 31 high keys is a semantic bound for any normalized row; the observed maxima are 18/15. The arithmetic count does not improve over post-scan compaction. The only potential win is putting list construction on the softmax/scan overlap path. It must exceed the added threshold, ballot and list-read cost on gfx1151.

The experiment did not touch a GPU or the Bonsai runtime. Next use a model-less native attention panel with occupied key contexts to compare post-scan compaction against pre-scan ballot, timing probability preparation, count scan, high and low dots, compaction, scattered nibble reads and final reduction together. Separately, the frozen half-byte V image still loses to E4M3; train its codes and O consumer on quantized-producer complete-model text before selecting a runtime map.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-high-prefilter/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-high-prefilter/measure.py --layer 14
```
