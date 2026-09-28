# Choose K norm rows for the causal score, not raw energy

The 128-plane paid Q/K observer already caches one 64-byte BF16 line per KV group. Its sparse K denominator computes sixteen additional raw rows per group, sampled by train energy strata, and fits five positive coefficients. On the layer-14 original-producer capture it left .01745 held causal KL above the full K denominator. I kept the score, binary Q/K factors, row count and four energy strata fixed, and changed which four rows in each stratum the K producer would emit.

Up to two train-only row exchanges per group, followed by a refit of the five FP16 denominator coefficients, bring the four-window mean held two-head causal KL from **.253286 to .246907** at layer 0 and **.325664 to .308927** at layer 14. All eight aggregate held windows improve. The full raw-K denominator at the same 128-plane score mask gives .252318/.308216. The layer-0 learned sparse norm actually beats that full denominator on this inspected text because it is allowed to compensate for errors in the paid score numerator. Layer 14 comes within .000711 KL of full norm at 384 rather than 1,024 raw K rows. This is a useful construction for a joint producer/consumer fit, not a claim that the denominator is an accurate estimate of true RMSNorm.

| Layer | Energy-sampled parent | Exchanged rows, original coefficients | Exchanged rows, refitted FP16 coefficients | Full raw K |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .253286 | .249795 | .246907 | .252318 |
| 14 | .325664 | .312491 | .308927 | .308216 |

The layer-0 group-3, group-6 and group-7 held KL values worsen after refit despite lower smooth train CE. The aggregate gain comes from the other groups, not from a per-group held-window selector. Layer 14 improves in all eight groups. These four validation windows have already been inspected repeatedly; no fresh-text generalization claim follows.

## Search and online bill

For a fixed group, let `b[w,h,t,k]` be the paid two-head score numerator, `d[w,k] = sum_j a_j f_j[w,k]` the positive sparse denominator and `z = b / sqrt(d)`. The training objective is finite masked teacher-to-candidate causal cross-entropy over the parent's sixteen strided queries in each of eight train windows. Its exact smooth derivative for one key is `sum_(h,t) (teacher-probability minus candidate-probability) * z / (2*d)`. Every candidate swaps one sampled row with an unsampled row in the **same train-energy quartile**. Its feature change is `weight * (raw_new^2 - raw_old^2) / 128` in that quartile. Contracting with this derivative ranks the possible exchanges without another softmax per candidate. The sixteen best predicted swaps get exact smooth train evaluation; the best strictly improving one is taken, at most twice. The final five positive coefficients get the parent's bounded L-BFGS-B fit, then FP16 rounding. No validation data enters selection. The gradient shortlist is a search heuristic, not a global support optimum or a BF16-execution derivative.

The exchanged image keeps 256 score-selected raw K coordinates and sixteen extra norm rows per group. It would emit 384 of 1,024 K raw rows per layer and perform 360,448 common-input-plus-output binary-factor signed terms/token, versus 524,288 for the full K factor. It keeps the same 512-byte line-padded key cache/token/layer, 512 score products per causal key across both heads, 512 BF16 selected-affine bytes/layer and 208 norm index/coefficient bytes/layer as the sparse parent. Replacing indices and coefficient values costs no extra online operations or stored bytes. Layer 0's separately [pruned support](../norm-sensitivity/README.md) emits only 364 rows at .253040 held KL, so the comparison to that cheaper point must charge these twenty rows. The binary image was not physically pruned here; these are proposed native counts, not measured native speed.

This CPU replay uses BF16-expanded paid Q/K and original-producer hidden states, the original model's two-head causal teacher, BF16 key normalization, and FP32 RoPE/score/softmax on all held causal positions. It does not establish quantized-upstream gold loss or full-model quality. The next useful experiment is to fit the selected-row K output signs together with this support and Q/K score on quantized-upstream train text. Freeze that image for disjoint post-O/gold loss against an equally charged binary control before spending GPU time on a native producer.

## Receipts

`measure.py` owns the bounded train exchange and BF16 held replay. `summarize.py` checks eight group identities per layer. `/path/to/workspace/data/kelana-subbit/norm-row-exchange/` holds all sixteen group receipts and two summaries. Each group receipt retains exact parent/exchanged row indices, coefficients, train CE, four held KL values, per-exchange decisions and source/model/capture/paid-image/parent hashes. The summaries record group hashes, per-window and per-group comparisons and online counts. From the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/norm-row-exchange
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 14 --group 4 --output /path/to/workspace/data/kelana-subbit/norm-row-exchange/layer14-group4.json
python3 "$D/summarize.py"
```

The GPU, Bonsai executable and resident service did not change.
