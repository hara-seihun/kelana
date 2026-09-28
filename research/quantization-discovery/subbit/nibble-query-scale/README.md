# Key-code covariance is the wrong single-dot query scale at layer 14

Can the paid signed-nibble key cache use one query nibble dot instead of two by choosing a better scale for each query? I tested a key-aware dynamic scale, with the same frozen paid Q/K factors, selected key coordinates and codes as the [two-dot construction](../nibble-query-lowering/README.md). The answer is no for this family. A covariance-optimal one-dot scale improves average score error at layer 14 but damages causal attention on every held window. This is a useful warning against selecting the cheaper dot on uniform key-score error.

| Layer | Float prepared query | One dot, max scale | One dot, diagonal key moment | One dot, full key covariance | Two dots |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 causal KL | .275403 | .290584 | .289530 | .287105 | .275431 |
| 14 causal KL | .332292 | .362763 | .495513 | .476919 | .332396 |
| 0 mean absolute score error vs float | 0 | .280006 | .295859 | .285561 | .016511 |
| 14 mean absolute score error vs float | 0 | .319723 | .304372 | .293359 | .019076 |

Each KL is the mean teacher-to-candidate causal softmax KL over four previously inspected 256-token validation windows, both query heads and eight KV groups. At layer 14 the covariance arm's four window KLs are `.48428, .46848, .45896, .49595`, against `.34805, .37277, .34168, .38854` for the max-scale one-dot control. Layer-0 covariance improves all four held windows over max-scale but still loses to the two-dot result. The score-error column averages all query/key pairs, including causally masked ones. These windows are not fresh independent acceptance data.

For each head/group/query let `a_j=q_j s_j` be the float prepared query and `c_t` the signed-nibble key code. The baseline chooses `d=max |a_j|/7` and `z_j=clip(round(a_j/d),-7,7)`. All new arms search the **same frozen eight scale ratios** `r=(.5,.625,.75,.875,1,1.125,1.25,1.5)` against `d*r`, then perform one dot `sum z_j c_t` for every key. There is no held-loss-guided candidate choice. The 32-coordinate key-code mean and covariance come from eight train capture windows, before held queries are scored. The diagonal arm minimizes `sum_j C_jj (d*r*z_j-a_j)^2` per query. The full-covariance arm minimizes `e^T C e`. Because `C` is the covariance of centered train key codes, the latter is exactly the **uniform train-key mean squared error of the score after removing a constant score shift** for that query, within the eight candidate ratios. It is not a finite causal-KL optimum. Neither arm changes the key cache or expands it into int4/BF16.

The scale optimizer learns to clip. At layer 14, group 3 chooses ratios below one on 2,000 of 2,048 head/window/position queries with the diagonal objective and 1,891 with covariance. Its held group KL changes `.258324` max-scale to `.691066` diagonal or `.645032` covariance. At layer 0, the corresponding selection stays mostly at ratio one. This exposes the failure mode: a rare large prepared coordinate controls some attention scores, while a covariance average over uniformly sampled keys can prefer clipping it. Even full cross-coordinate covariance is the wrong metric for a causal softmax over a query's prefix. Layer 14 actually **reduces** all-key average score error with covariance, `.319723` to `.293359`, while worsening KL `.362763` to `.476919`. A score-MSE gain is not a causal-quality certificate.

The diagonal route keeps the 128-byte/token/layer key cache and 512 signed-nibble score products per cached key across both heads instead of 1,024 for two dots. It adds 512 FP16 diagonal-moment bytes/layer and, at each token, 4,096 candidate query rounds/clips plus 4,096 weighted-error terms for eight ratios, across sixteen head/groups. The baseline two-dot route rounds only 512 prepared coordinates; all routes still prepare 512 coordinate-step query products and produce all 1,024 raw K rows for normalization. The full-covariance diagnostic needs another 131,072 scalar multiply terms per query token/layer and a dense moment table; it is not a cheap native candidate. Native nibble packing, query-selection time, full-model loss and quantized-upstream transfer are unmeasured.

The next useful single-dot question is a **causal-observer-trained scale policy**, fitted on train attention distributions and checked on fresh quantized-upstream text, rather than more uniformly weighted second-moment tuning. It must pay for scale selection and beat the existing two-dot consumer at matched quality. For now the two-dot arm retains its quality advantage; this negative does not rule out learned per-coordinate query companding, a sparse high-precision correction, or a different key/query code pair.

`measure.py` writes source/model/capture/paid-image/parent hashes, each group's ratio histogram, per-window KL and score error to `/path/to/workspace/data/kelana-subbit/nibble-query-scale/layer{00,14}.json`. Run from the Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/nibble-query-scale/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/nibble-query-scale/layer$(printf '%02d' "$layer").json"
done
```

No GPU, Bonsai executable or resident service changed.
