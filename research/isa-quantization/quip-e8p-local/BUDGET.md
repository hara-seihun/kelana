# An achieved structured image and an all-cardinality pair bound

The [named local QuIP# RVQ3 image](README.md) changes the control, not the covariance theorem. The parent's [all-cardinality rate identity](../full-pair-covariance/RATE.md) turns the already accepted PSD/cone/matching witnesses into a simultaneous bound on every disjoint-pair count. Combining that identity with the actual 6,178-byte image gives a captured-train error exclusion for two declared Q4-readout families, without another fit or a cardinality sweep.

## Exact achieved map

[`budget_compare.py`](budget_compare.py) independently reconstructs the primary stored image with integer Hadamards. Main and residual lattice entries are quarter-integers; the ideal residual divisor 2.04 is exactly `51/25`; the two normalized 128-point Hadamards contribute `1/128`; the stored FP16 global scale is `1037/32768`. Consequently the entire ideal decoded weight matrix is rational. The source weights and captured producer states are dyadic, so the complete response error can be evaluated as an exact rational using the existing guarded integer Gram builder.

The achieved ideal train relative squared error is **0.005977048186103444**, recorded as a full rational in [`budget.json`](budget.json). Integer reconstruction agrees with the float64 independent image replay within `1e-12`. This exact arithmetic models the ideal serialized map with rational `51/25`, not the bitwise result of an FP32 native kernel. The [native study](../quip-native-endpoint/README.md) separately checks its emitted arithmetic and measures execution.

## Payable family and strict comparison

The variable-cardinality reader from RATE.md has 128 original inputs/outputs, m disjoint freely weighted pairs, `128-m` carriers, b-bit per-output affine coefficient codes, FP16 ratios, all source indices, optional FP16 output intercept a, and two descriptor bytes. Its model-specific description is

```
B(m,b,a) = 16*b*(128-m) + 640 + 2*m + 256*a + 2.
```

The saved linear and centered-affine covariance witnesses have positive cardinality slopes. The smallest m fitting a budget therefore also has the smallest certified error among all feasible m in a fixed b/a family. At **6,178 model-specific bytes**:

| Output code / intercept | Least feasible m | Bytes at that m | Universal train error floor | Can this bound exclude matching the achieved RVQ error? |
| --- | ---: | ---: | ---: | --- |
| Q4 / none | 43 | 6,168 | **.008005100749** | **Yes** |
| Q4 / affine intercept | 47 | 6,176 | **.007951817445** | **Yes** |
| Q3 / none | 14 | 6,142 | .002067753570 | No |
| Q3 / affine intercept | 19 | 6,168 | .002792864609 | No |
| Q1 or Q2 / either | 0 | Below budget | 0 | No |

Both strict Q4-readout comparisons use exact rational inequalities. They grant even arbitrary real output coefficients and arbitrary real pair ratios, larger families than the paid fields realize. Lowering output precision changes the byte implication enough that this free-readout relaxation no longer settles the comparison. No observed fitted error is substituted for a universal floor.

The separate [paid-grid floor](../paid-grid-floor/README.md) retains a small part of this missing constraint: on the fixed m=32/Q4 family it charges untouched columns to independently trimmed 16-center readouts. Its extra .0000009378994 is valid but too weak to close the different 6,848-byte comparison. It is not added to this table at other cardinalities.

## Asset and observer boundary

This comparison assumes **the same 5,120 bytes of generic QuIP reader tables are already shared by the deployment**. If the isolated tile must buy them itself, its total static data is **11,298 bytes**, not 6,178, and this budget argument does not establish standalone size dominance. The [full-row slab](../quip-full-row-slab/README.md) charges those tables once to an actual 128-by-1024 region rather than hypothetical future consumers; its held comparison reverses.

The statement is about ideal captured-train response error under the declared model-specific byte budget. It does not assert held-state error, native work dominance, complete attention behavior, every sparse circuit, or state-of-the-art quantization optimality. It is a concrete use of a named structured achieved control at its own paid boundary, rather than requiring a cheaper format to match a larger Q4 image.

Reproduction (CPU, seconds):

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/quip-e8p-local/budget_compare.py
```

The command rechecks both source covariance certificates before combining them, pins the actual image/reader assets, recomputes the exact source response, and emits every precision/intercept comparison in the compact receipt. The general finite rational matching assembly is proved in `Kelana/PairCovarianceAssembly.lean`; real covariance/cone bridges retain the proof scope declared in the primary reports.
