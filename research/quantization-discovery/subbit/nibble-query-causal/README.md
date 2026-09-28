# A causal scale fit does not rescue the one-dot nibble query

The [key-covariance scale fit](../nibble-query-scale/README.md) minimized average score error and failed badly at layer 14. I replaced that objective with the finite causal teacher-to-candidate softmax KL, fitting one fixed scale ratio for each of the sixteen query heads and KV groups on eight train windows. This is a cheap one-dot policy: unlike per-query searches, it needs only sixteen stored FP16 ratios and one extra scale multiply per query token. It does not recover the two-dot map.

| Layer | One dot, max scale | One dot, train causal ratio | Held-only per-window ratio oracle | Two dots |
| ---: | ---: | ---: | ---: | ---: |
| 0 held causal KL | .290584 | .287134 | .282574 | .275431 |
| 14 held causal KL | .362763 | .362798 | .356552 | .332396 |

All scores average two heads, eight groups and four 256-token validation windows. Layer 0 improves in each window, by .00304, .00266, .00236 and .00574 KL. Layer 14 changes by +.00053, -.00124, +.00198 and -.00114. The held-only oracle chooses the best ratio separately for each head/group/window using held labels; it is a generous diagnostic lower bound on the measured KL for any one static ratio per head/group, not an admissible image. Even it is .00714/.02416 KL behind two dots at layers 0/14. Layer 14's train fit chooses ratio 1 for fifteen heads and .875 for the last; the static policy correctly declines the widespread clipping selected by key-covariance optimization. That also means the cheap static scale has practically no room at this layer.

The frozen producer uses Qwen3-0.6B binary Q/K factors, the 128-plane score observer and the coordinate-scaled signed-nibble key cache. For each query/head/group the floating preparation is `a_j=q_j*s_j` over 32 coordinates. The baseline step is `d=max_j |a_j|/7`; a candidate uses `r*d`, rounds and clips to `[-7,7]`, then scores each cached signed-nibble key with one integer dot and a final floating scale. The candidate set is `r ∈ {.5,.625,.75,.875,1,1.125,1.25,1.5}`. We select the ratio that minimizes mean exact finite causal KL on the train windows, independently for each head/group, and freeze it before the four held windows. There is no per-query held selection. The teacher uses original Q/K on the same original-producer hidden capture; the candidate uses paid factors. Real softmax and float64 replay of integer sums establish these CPU KLs, not bit-identical FP32 execution.

The candidate still stores 128 packed key bytes/token/layer, 512 FP16 key-step bytes/layer and 32 FP16 ratio bytes/layer. It prepares 512 step-scaled query coordinates per token/layer, rounds and clips them, and spends 512 signed-nibble products/key for both heads rather than the two-dot arm's 1,024. It still produces all 1,024 raw K rows for the RMS denominator. The extra sixteen ratio multiplies/token/layer are not a meaningful substitute for the second score dot if the layer-14 causal behavior must match it. No native time, fresh quantized-upstream loss or full-model behavior was measured. The four validation windows were previously inspected; they are exploratory and cannot select another arm.

This negative closes *static head/group scale selection inside this frozen one-dot grammar*, not per-query causal selection or new query/key codes. A next experiment should change the coordinates, for example train a query code with a reserved high-precision correction on rare influential coordinates and price that correction against the second full nibble dot. Repeating fixed-ratio fitting on these captures will not close the layer-14 gap.

`measure.py` writes every train and held ratio's per-window/head KL, selected ratios and the held ratio grid used for the oracle, source/model/capture/paid-image hashes and cost counts to `/path/to/workspace/data/kelana-subbit/nibble-query-causal/layer{00,14}.json`. Run each layer from the Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/nibble-query-causal/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/nibble-query-causal/layer$(printf '%02d' "$layer").json"
done
```

The CPU runs did not use the GPU or change Bonsai's executable or resident service.
