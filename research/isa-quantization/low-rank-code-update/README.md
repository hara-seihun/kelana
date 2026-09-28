# A compact query metric for causal key-code assignment

A quantized cache can retain KIVI's packed layout and query reader while changing **which existing codes are assigned when a source chunk arrives**. This study supplies the algebra for a compact diagonal-plus-low-rank query-response metric. It is standard finite-grid coordinate descent, not a new optimization algorithm; the question is whether the paid metric/preparation improves a complete causal cache at its own memory rate.

## What the metric prices

For a fixed distribution of scaled queries `q/sqrt(head_width)`, let its uncentered second moment be C. For a key error vector e,

```
E_q (q dot e)² = e^T C e.
```

This is **raw score error**, not attention KL or output loss. Learned Q/K gains, normalization, rotation and the actual query law determine C; an isotropic key MSE need not predict it. The [stopped fixed-Hadamard study](../kivi-hadamard-cache/README.md) illustrates that distinction on the actual source. Full softmax removes globally common row shifts, and live V/O defines another weighting; the [joint-cache error study](../joint-cache-error/README.md) states that observer explicitly. Code assignment under C is a surrogate, not a complete-quality guarantee.

Store a positive diagonal D and factor U with r columns, defining the exact represented metric

```
M = diag(D) + U U^T,
F(e) = sum_d D_d e_d² + ||U^T e||².
```

FP16 fields define **M itself** after decoding; a proof about an unrounded proposal is insufficient. Positivity of decoded D ensures a strictly convex coordinate cost. Choosing U from leading query-covariance modes and D from the residual diagonal is one concrete approximation, not generally a PSD upper/lower bound on C. The rank and source law must be fixed before candidate evaluation; no guarantee transfers from M to C merely because their diagonals approximately agree.

For128-dimensional keys and r=8, actual FP16 U and D use **2,304B**. They are additional model-specific preparation fields, not a free use of the original Q weights. If resident with the52,400B KIVI peak state, the sum is54,704B before code/scratch/common model state. Pool sharing or unloading must be demonstrated rather than assumed.

## Exact coordinate update

Carry `s=U^T e`. Changing coordinate d by delta gives

```
s' = s + delta U_d,
F(e+delta unit_d)-F(e) = 2 delta g_d + delta² h_d,
g_d = D_d e_d + U_d dot s,
h_d = D_d + ||U_d||².                                      (1)
```

The finite rational implementation is the scope of `Kelana/LowRankCodeUpdate.lean`: actual finite sums, a coordinate update, the quadratic identity, and descent when the selected finite-grid candidate costs no more than the present one. For a finite affine code grid with current code c, stored origin o and positive stored step b, changing to code j uses `delta=b(j-c)`. The real minimizing code is

```
c - g_d/(h_d b).
```

Nearest integer clipped to the valid interval minimizes the one-dimensional quadratic. At zero step all codes represent the same value; keep the original code. In exact arithmetic, a chosen minimum cannot increase F because the current code is among the candidates. A finite forward sweep therefore cannot increase **this represented metric**. Floating implementation must check actual decoded errors and updates, not treat the rational proof as a rounding theorem.

For a32-token arrived K chunk, its code objective is the sum of32 such energies. Source K is already available at its causal flush; no future key or held target enters assignment. The existing origin/step fields can remain unchanged, as can V, recent buffers and query code. Each coordinate update costs O(r) products and updates; the initial factor response costs O(128r) per token. The32×r running factor values, source/error chunk, code buffers and setup are transient preparation. The query still uses the ordinary KIVI packed reader—no per-query low-rank multiplication is introduced.

## Exact two-coordinate witness

With D=(1,1), U=(1,1)^T, source key `(1/2,1/2)` and coordinate grid `{0,1}`, ordinary nearest-even scalar assignment gives `(0,0)`. Its represented energy is3/2. One forward sweep gives `(1,0)` with energy1/2; Euclidean key error remains1/2 in both. Correlated score sensitivity distinguishes equally good independent scalar errors. `witness.py` reads an actual8-byte FP16 metric and one-byte packed old/new code images, and checks each finite candidate and update with rational arithmetic. The tiny metric is not free; the toy supplies no size/work superiority over an exact direct key.

The [real-source response-metric study](../kivi-response-metric/README.md) now applies this rule to all twelve original causal windows. Its actual2,304B FP16 metric and one forward sweep reduce held complete pair-O squared error **.000155355→.000135159** (13.0%) while peak cache+metric grows **52,400→54,704B** (4.4%). V bytes, K fields, recent buffers, flush timing and query reader remain unchanged. Three of four held windows improve; the other worsens despite the represented metric's decrease. This is a nearby-size quality/encoding-work tradeoff, not strict domination. The [fixed V45 control](../kivi-v45-control/README.md) now spends2,288B extra and achieves.000136901 held error at54,688B: just1.27% above the metric's error, with no metric fit or key-code sweep. This is why represented-metric descent must not be confused with a strong complete rate/work advantage. No extra iterations or rank choices are earned merely by a favorable train surrogate.
