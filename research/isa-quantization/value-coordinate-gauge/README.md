# Value-coordinate gauges: move the groups, not the live vectors

A channel permutation can change which value coordinates share a quantization grid without adding an online permutation or a new model-specific lookup. Physically permute the shared V projection's output rows and the corresponding columns of **every** consuming O head block. The exact unquantized attention map is unchanged. Grouped cache quantization need not commute with that permutation, so its complete output can change at the same model/cache bytes.

This is ordinary channel reordering and a familiar representation symmetry, not a new quantization algorithm; [SKVQ](https://arxiv.org/abs/2405.06219) is prior KV channel-rearrangement work. The useful obligations are physical source-field custody, all shared-head consumers, actual grouped quantization, and the live output rather than coordinate MSE. The [separately owned real-source study](../kivi-v-channel-fold/README.md) supplies those measurements: one fixed train-RMS grouping improves held complete-O error7.75% at unchanged52,400B peak cache and unchanged source-weight bytes. It rewrites786,432B of existing V/O fields, rather than adding a permutation lookup. This local rule is not SKVQ's complete method; the algebra here does not predict a gain from any particular sorting heuristic.

## Exact transport, including shared values

Use column values `v_i = W_V x_i` and head output blocks `O_h`. For a permutation matrix P,

```
W'_V = P W_V,       v'_i = P v_i,       O'_h = O_h P^T.
```

With the same causal probabilities `a_{h,t,i}`,

```
sum_h O'_h sum_i a_{h,t,i} v'_i
  = sum_h O_h sum_i a_{h,t,i} v_i.                       (1)
```

All query heads sharing this V cache must transport their O columns. Q/K, normalization, RoPE and softmax need not change. A projection bias, if present, must also be permuted; the current source has none. Any additional consumer of V would need the same treatment. This is an exact real/rational identity on every input, not a low-rank approximation or a query distribution assumption.

A permutation copies existing BF16 fields exactly. It can be folded into ordinary stored matrix layouts offline; inference then emits and consumes the chosen order directly. Keeping the old weights and gathering live vectors instead would be a different, more expensive program. The permutation used to prepare rewritten fields is provenance, not an inference asset **only when the actual rewritten weights are present and no runtime decoder consults it**. No uncharged specialized reader is assumed.

Finite arithmetic remains a separate boundary: each permuted V row keeps its original reduction order, but permuting O's input coordinates can change its floating reduction order. Exact representability of fields does not prove bitwise O equality. The real-source acceptance must price and check this boundary before interpreting a quantized-cache result.

## Group quantization makes partitions the variable

Let Q_G quantize each contiguous group of g value coordinates using its own source min/max, rounded stored affine fields and scalar code rule. The effective quantized value in the original coordinates is

```
vhat_P = P^T Q_G(P v).
```

Generally this differs from `Q_G(v)`: P changes the source coordinates sharing each grid. If a second permutation only reorders coordinates **within** groups or permutes whole groups, their min/max and stored fields move unchanged, and the scalar codes move with their coordinates. Thus, in ideal arithmetic and for a coordinate-independent deterministic tie rule, the effective map depends on the unordered partition into g-element groups, not the internal order or group labels. For D coordinates and g dividing D there are

```
D! / [(g!)^(D/g) (D/g)!]
```

such equal-size partitions. This is a structural quotient, not a suggestion to enumerate it. Physical packing, O reduction order, bank placement and alignment can distinguish realizations that are equivalent at this mathematical level.

Grouping channels by a source scale statistic is one inexpensive heuristic, not an optimizer for the downstream observer. Neither smaller ranges nor smaller value MSE by themselves prove lower output error. The exact toy below keeps value MSE unchanged while changing complete response error from nonzero to zero.

## The fixed-probability V objective is exactly quadratic

Unlike a key perturbation through softmax, a value perturbation is linear when probabilities and O are fixed. This remains true if those probabilities already come from a quantized K cache. Let `e_{i,d}` be the value error in original coordinates and define

```
A[(t,o),(i,d)] = sum_h a_{h,t,i} O_h[o,d],
G[(i,d),(j,c)] = sum_{t,o} A[(t,o),(i,d)] A[(t,o),(j,c)].
```

Set unavailable/future probabilities to zero to encode causality. For a fixed value error already applied to every available token, this gives

```
E_V = A e,                ||E_V||² = e^T G e >= 0.       (2)
```

This is the actual complete multihead Gram, including cross-head, cross-token and cross-coordinate terms, not a diagonal source variance or a small-edit Hessian approximation. Positive observation weights can be included by weighting the output rows. A separate sum of head squared errors generally gives a different Gram.

If the target is the original teacher while K is already quantized, let b be the existing K-only output error. The complete objective under a candidate value error is instead

```
||b + A e||² = ||b||² + 2 (A^T b)^T e + e^T G e.         (3)
```

The affine cross term matters. Equation(2) by itself prices value-only error against the same K-probability reader, not the full teacher discrepancy. The [joint K/V study](../joint-cache-error/README.md) derives the equivalent decomposition relative to teacher probabilities and measures its terms on the frozen source. All of these identities are conditional on the stated source/probabilities; a quantized full model whose future queries change needs its own closed-loop acceptance.

### A causal recent buffer needs a flush mask, not just a causal triangle

A recent value is still full precision until its quantization event. Let `m[t,i]=1` precisely when token i has already flushed before query t, and0 otherwise. The stored token error e_i is fixed once produced, but the live error is `m[t,i] e_i`. For these caches the correct coefficient is therefore

```
A_m[(t,o),(i,d)] = m[t,i] sum_h a[h,t,i] O_h[o,d].
```

Equations(2–3) hold with A_m and its Gram. Zeroing future probabilities alone would incorrectly charge quantization error to recent BF16 values. The finite proof includes `masked_value_difference` and `masked_actual_error_eq_gramEnergy` for arbitrary rational masks; the zero/one causal schedule is the concrete application. No probability normalization is required for the masked coefficients.

This places three completed programs in one exact conditional objective:

- [Query-metric key codes](../kivi-response-metric/README.md) change a and the K-only offset b while holding the V error map/schedule fixed.
- [Longer recent-V retention](../kivi-v45-control/README.md) changes m, retaining exactly the same token grids and errors e, with a and b unchanged.
- [Folded V grouping](../kivi-v-channel-fold/README.md) changes the value-error map e after undoing the coordinate permutation, with a, b and the schedule unchanged in ideal arithmetic.

Their gains need not add: both the affine term and Gram cross terms change in a composition. The [frozen two-arm composition](../kivi-folded-near-rate/README.md) is evaluated from actual causal bytes, not predicted by adding the individual percentage gains. With folded V/O common, metric K+V32 gives held pair error.000122323 versus.000127814 for original K+V45 (4.30% lower), but aggregate train and half the held windows prefer V45. Metric data is shared per model group while recent-V storage is per sequence; the report keeps that concurrency distinction separate from encoding work. These equations do not require building a giant token-coordinate Gram to evaluate a candidate; the complete reader or a factored response suffices.

`Kelana/ValueCoordinateGauge.lean` proves finite rational permutation transport, actual output linearity, the squared-response/Gram identity and nonnegativity, plus the masked causal version. Source grouping, min/max implementation, real-source floating behavior, actual storage and execution remain separate obligations.

## A query-independent O metric is a surrogate, not the complete Gram

The [original KIVI2 attribution](../kivi-two-bit-error-directions/README.md) motivates changing V digits without changing source coordinates or cache size. For KV group g shared by two query heads, one available encoder metric is

```
B_g = stack(O_(2g), O_(2g+1)),
G_g = B_g^T B_g,
Q_g(e_i) = e_i^T G_g e_i.
```

It uses common source O and the currently arriving value, so it does not require an unavailable future query. But it discards the attention weights, cross-token terms, cross-head sum before squaring, and the fixed K-error affine term in(3). It is therefore not a block extracted from the complete masked Gram without additional assumptions about those observations. Lowering every Q_g does not assert that the actual complete teacher error falls. The V/interaction effect direction measured at eight queries is evidence for testing this rule, not a license to treat it as their exact objective.

For exact rational arithmetic, the existing `Kelana/LowRankCodeUpdate.lean` applies directly with zero diagonal and `U[d,(h,o)]=O_h[o,d]`. Its `energy_update`, `finite_grid_update` and `sweep_stepwise` prove that selecting a minimum among grid codes including the current code gives nonincrease of this **local** squared response along the actual visited sweep. Those statements need neither an eigendecomposition nor a low numerical rank. They do not establish FP32 equality between a separately rounded prepared Gram and the original stacked-O contraction, nor complete attention/O monotonicity.

Preparing all eight128×128 FP32 Grams costs **524,288 B** beyond the unchanged cache/source fields. It converts source-dependent column contractions into matrix lookups but does not make them free: one-sequence KIVI2 peak plus these Grams is **829,056 B**, before sweep scratch/code. Sharing the Grams across sequences gives `524288 + N*304768`, not the original `N*304768`. A direct source-column realization could avoid that particular stored matrix only by paying its different online work and temporary projected errors. Neither representation is automatically a size or speed win. Original KIVI2 is the same-cache control; original KIVI4 at419,200B is a stronger smaller-state control for this prepared realization. Actual code decisions, fields and complete output remain separate acceptance obligations.

## Additive coordinates have a different constant consumer

The [additive translation foundation](TRANSLATION.md) proves that subtracting a fixed per-channel V center can be corrected once after normalized attention/O, rather than once per token. It derives the exact finite-source worst-range problem as difference constraints and certifies global optimality using a feasible potential and a matching balanced flow/cycle. Source-only range, stored-center rounding, eventual quantized output and paid online work are distinct; this is not another bit-width or O-Gram sweep.

## Exact paid six-coordinate example

The source emits `v=x*(0,10,1,11,2,12)` for token values x in `{1,2}`. One output reads coordinates2 minus3, so the source response is `-10*x`. Two contiguous groups of three coordinates use binary min/max grids and nearest-even ties.

- Original grouping decodes source x=1 to `(0,10,0,12,2,12)`, yielding `-12` instead of `-10`.
- Permutation `(0,2,4,1,3,5)` groups `(0,1,2)` and `(10,11,12)`. With physically permuted V and O fields, its decoded response is exactly `-10`; x=2 similarly gives exactly `-20`.
- Both caches have the same total squared **value-coordinate** error10 over these two tokens. With attention probabilities `(1/4,3/4)`, original complete squared error is **49/4**, while the grouped image's error is **0**.

Each actual image is **30 bytes**: six signed-byte V weights, six signed-byte O weights, and two cache records each containing six packed code bits in one byte plus four FP16 affine fields. No permutation field is stored or read. `witness.py` independently decodes both images, reconstructs the min/max grids and exact rational codes, checks physical V/O transport and the complete response. The grouped response is exact separately for each possible source token, hence for every later attention mixture of that declared finite producer, not just the displayed probability row. A second two-head Gram check gives combined squared response169/36, whereas the incorrect sum of separate head squares is505/36.

The stronger direct reader `-10*x`, or one-bit token labels followed by that map, is exact and cheaper. The example is therefore a witness for transport/grouping/observer distinctions, not a new compression win. Native code, quantizer/flush work and floating accumulation are not measured by this tiny image.

```sh
python3 research/isa-quantization/value-coordinate-gauge/witness.py
lake env lean Kelana/ValueCoordinateGauge.lean
```
