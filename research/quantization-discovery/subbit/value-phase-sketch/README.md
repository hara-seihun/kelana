# A byte code sketch for one-nibble value phase selection

A score-only policy cannot see which value codes a fifteen-count probability row will select. The preceding policy improved the inspected layer-0 response but lost on layer 14. I put one signed byte per key and query head in the two vacant bytes of each 16-byte padded GQA value-cache group. That byte is a projection of the *packed value codes*, computed once when the key/value entry is appended. A phase selector reads the byte and probability row, not the 28-dimensional value codes or the paid output projection. On the frozen original-producer panel, it beats both the previous score-only policy and a train-fixed phase on both layers. It still does not make the frozen one-nibble consumer eligible at a complete-layer 1e-4 post-O budget.

## Map and online program

The cached code for value key `k` is `c_k in [-7,7]^28`. For a given query head, let `G` be the frozen paid-output Gram and let `v` be its largest-eigenvalue unit vector. At cache append, store

`b_k = round((c_k dot v)/step)` as signed int8, with `step = 7 ||v||_1 / 127`.

This fixed step covers *every* signed-code vector without clipping. Each GQA value group serves two query heads, so it stores two distinct bytes per key. At most 56 static projection coefficients are needed per group, and the append costs 56 real multiply-add terms plus rounding of two outputs. This is an extra producer operation; the selection scan does not get those projections for free. The nibble values remain packed and the chosen fifteen-count row is consumed by one direct nibble dot, with no int4 expansion.

For a probability row `p_0,...,p_{n-1}` summing to one, let `B_i=15 sum_{k<=i} p_k` for `i<n-1`. Phase `j/16` sets internal boundaries `floor(B_i+j/16)` and the last boundary to 15. The count vector is their adjacent difference. Put `d_i=b_i-b_{i+1}` and bin the fractional part of `B_i` into `floor(16 frac(B_i))`. Then the projected response for phase `j` is exactly

`step * [ b_{n-1} + (sum_i floor(B_i) d_i + sum_{bin(i)>=16-j} d_i)/15 ]`.

The target feature is `step * sum_k p_k b_k`. Subtract it from each projected phase response and square it. The identity is summation by parts; the sixteen bin sums let a single scan over the probability row and signed-byte sketch produce all sixteen projected residuals. The same scan makes the predecessor's eight-bin *unweighted* prefix histogram. The selector fits phase-specific affine coefficients on that ten-feature score histogram, plus two coefficients shared by all phases on the projected residual and its square. The trained selector chooses the lowest predicted normalized full-response error. Its training targets come from the actual 28-coordinate paid-output quadratic, not the one-dimensional approximation. It needs no per-key 28-dimensional projection at query time and no sixteen full response evaluations.

The logical signed-nibble cache is 14 bytes/GQA group, padded to 16. Two head-specific sketch bytes fill that padding, retaining the 128-byte padded value-cache footprint per token/layer across eight groups *if* the native layout can place them there. The selector still incurs one signed-byte load and one probability-times-byte product per key/head, one 16-bin code-difference histogram, the score histogram, sixteen two-term corrections and sixteen ten-term score dots. It either retains the probabilities and chosen counts or scans again; neither storage nor scan is free. Static FP32 coefficients for the two head projections and the small affine selector are additional weight bytes. The current Python implementation forms sixteen comparisons per key rather than using the equivalent histogram; the histogram is a proved proposed lowering, not a timed kernel. Count construction, sparse gathers, softmax, output projection and selection synchronization remain unmeasured.

## Frozen Qwen3-0.6B comparison

The paid rank-28 V/O factors, signed-nibble steps, original-producer captures and 4,095-count reference are unchanged. Heads 7/12 at layers 0/14 use sixteen positions per window, eight train windows for fitting and leave-one-train-window-out penalty selection, and four repeatedly inspected validation windows. A ridge penalty among `.1, 1, 10, 100, 1000` is selected by actual omitted-window squared response error. Only that selected fit sees the validation split. The real-valued projection is a diagnostic; the signed-byte sketch is the candidate. Figures are pooled squared post-O error divided by pooled reference energy.

| Layer | Split | Prefix | Train-fixed | Score-only | Byte sketch | Sixteen-phase full-response oracle |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 0 | train | .00050191 | .00023634 | .00022851 | .00019687 | .00016367 |
| 0 | inspected validation | .00040089 | .00035732 | .00030426 | **.00019788** | .00013646 |
| 14 | train | .00230513 | .00105167 | .00091214 | .00090936 | .00074213 |
| 14 | inspected validation | .00188470 | .00122964 | .00123814 | **.00094393** | .00073793 |

The candidate recovers 72.2%/58.1% of the fixed-phase-to-oracle gap at layers 0/14. It improves the score-only held errors by 35.0%/23.8%. Layer 0 improves three of four held windows against the fixed phase, layer 14 all four. The layer-0 real-sketch policy, trained with a different selected ridge penalty, scores .00026711 held; signed-byte quantization changed the chosen phases and happened to help on these inspected windows. That is not evidence that rounding itself improves the representation. The layer-14 real-sketch score is .00093936, close to byte's .00094393. The same cached byte and extra scalar selection work would be paid even if only a small subset of query heads used one-digit mass.

The parent score-only receipts have identical model, capture, factor and cache hashes; this experiment also checks every row's sixteen full-response errors against them. `/path/to/workspace/data/kelana-subbit/value-phase-sketch/layer{00,14}.json` retains projection vectors, cross-validation scores, fitted coefficients, every selected phase and squared error, per-window scores and source/input/parent hashes. Reproduce from Kelana with:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 $P research/quantization-discovery/subbit/value-phase-sketch/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 $P research/quantization-discovery/subbit/value-phase-sketch/measure.py --layer 14
```

This is a sampled original-producer response result, not a complete-layer head allocation, quantized-producer gold loss or native latency. The frozen signed-nibble value image still trails the same-fit E4M3 control. The useful next question is whether the one-byte code sketch can be *learned with* the narrow V/O codes and a cheap phase policy on quantized-producer complete-model text, then whether the filled-padding layout and full count/selection/nibble/O path beat the two-digit and E4M3 consumers at occupied contexts. Another score-only histogram or another frozen full-metric grid does not answer that.
