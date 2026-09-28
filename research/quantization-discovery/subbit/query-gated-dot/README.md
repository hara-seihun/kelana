# A query-only gate cannot skip the second nibble dot on these captures

The frozen paid nibble-key observer has a tempting dynamic program: prepare each query at four-bit precision, compute one packed dot per cached key, and perform the second dot only when a cheap query-side certificate says the first is inaccurate. The certificate below accepts **no query after the first key**, out of 16,384 causal query/head/group rows per layer, at even a loose 0.1-nat KL tolerance on layers 0 and 14. It is a measured negative for this gate, not a lower bound on adaptive attention programs.

## Certificate and observation contract

The 32 selected coordinates of each cached key have signed codes `c_j` in `[-7,7]`. A prepared query has real coordinates `a_j=q_j s_j`. The one-dot code is `z_j=round(a_j/d)`, clipped to `[-7,7]`, where `d=max |a_j|/7`; its reconstructed coordinate is `d z_j`. Write `e_j=a_j-d z_j`. For every possible cached code,

`|(a-dz)·c/sqrt(128)| <= epsilon = 7 sum_j |e_j|/sqrt(128)`.

This score-radius bound is **attained on the complete product code domain** by choosing each `c_j` as `7 sign(e_j)`. Its opposite is also attainable. The exact worst-case score-error *range* is therefore `2 epsilon` if two such codewords can occur in the same causal history. Softmax ignores a common score offset. Hoeffding's lemma applied to the difference between the two log partitions gives

`KL(softmax(S_float) || softmax(S_one)) <= (2 epsilon)^2/8 = epsilon^2/2`.

The KL direction and the reference here are the floating prepared query over the **same frozen signed-nibble keys**, not original-model teacher attention. The proof uses real scores and real softmax, not bit-identical GPU FP32. It certifies arbitrary histories of admissible codes without reading them; the one-key softmax needs no score at all, so the measured gate accepts that first position automatically. Other positions take 32 absolute residuals and a sum per query/head/group beyond the one-dot query preparation. It does not certify the key producer or whole-model loss.

To locate the missing information, the replay also computes two deliberately expensive bounds. Given exact per-coordinate minima and maxima among a query's causal keys, the score-error range is at most `sum_j |e_j|(max c_j-min c_j)/sqrt(128)`; square and divide by eight for the KL certificate. An oracle that has already computed every missing score difference takes its actual causal range instead. Neither is a deployable free gate. A running prefix-extrema table would need code-dependent updates and 32 coordinate-range reads per query/group; the score-range oracle pays the omitted dot outright. Both include the first causal key, for which the softmax KL is zero.

## Replay on the frozen paid image

Four repeatedly inspected, original-producer validation windows of 256 tokens, two heads in each of eight groups, give 16,384 causal query rows per layer. The script replays paid binary Q/K, the train-selected nibble-key center and 256 coordinate steps, and the same BF16 normalization/FP32 RoPE producer as the direct-query study. It checks the KL inequality for every row. Counts below are accepted rows out of 16,384, not percentages of a complete model:

| Layer | KL limit | Query-only complete-code bound | Causal coordinate-extrema oracle | Actual score-range oracle |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .01 | 64 | 75 | 259 |
| 14 | .01 | 64 | 64 | 284 |
| 0 | .1 | 64 | 141 | 3,803 |
| 14 | .1 | 64 | 109 | 3,924 |

At .0001 and .001, the coordinate-extrema arm accepts only 64 rows per layer: the first key of each head/group/window. The query-only gate also accepts those 64 single-key rows by checking the history length, but no later row. The actual one-dot-to-floating-key attention KL averages .015475/.031762 at layers 0/14. The direct two-dot arm's **teacher** KL on these same frozen images is .275431/.332396, while the one-dot arm's is .290584/.362763; these are different reference distributions and should not be subtracted from the certificate.

The key cache is still 128 packed bytes/token/layer and the paid Q/K weight BPW and full raw K norm producer are unchanged. A one-dot pass spends 512 signed-nibble products per cached key across both heads; its second pass adds another 512. This query-only gate spends an extra 512 residual absolute values and reductions per token/layer and, at the measured tolerances, skips only the first-key second dot, 0.39% of query rows. Even an oracle that maintains each coordinate's exact causal range accepts less than 0.9% of rows at .1, before paying for its metadata and updates. The score-range oracle identifies a much wider opportunity, about 23–24% at .1, but finding that range by scoring the keys defeats this particular shortcut.

The next question is a cheap **key-aware** proxy for score-error range or a learned score coordinate that makes one dot accurate outright. Neither follows from the query's rounding residual or a coordinate box on this frozen image. A native switch on this certificate is not worth building. No GPU, Bonsai executable or resident service changed.

## Reproduce

`measure.py` writes the complete per-group quantiles, all four thresholds, KL checks, paid-image/model/capture/parent hashes and cost assumptions to `/path/to/workspace/data/kelana-subbit/query-gated-dot/layer{00,14}.json`. The script uses CPU PyTorch:

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/query-gated-dot/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/query-gated-dot/layer$(printf %02d "$layer").json"
done
```
