# A finite paid-grid charge on the unmatched coordinates

**Result on the same captured 128×128 train panel, without a new fit:** a b=4 output reader adds a strictly positive **0.0000009378994042970606** relative squared error to the saved linear full-covariance m=32 pair certificate. The combined universal floor is **0.005753941442747534**, still below the actual equal-6,848-byte local response-refitted mixed Q3/Q4 scalar control **0.005975855413743526** by **0.00022191397099599174**. This finite-grid relaxation therefore does **not** exclude the 6,848-byte pair family from even this local captured-train frontier. It is not an SOTA, held-state, native-execution or complete-model claim. See [the receipt](verified.json) and [the original exact covariance witness](../full-pair-covariance/README.md).

## Additive theorem and the separation boundary

Let `H ⪰ D + V diag(β) Vᵀ` be the saved common covariance minorant, `d_i>0`, and `z_i=w_i+p_i/d_i` the saved shifted teacher columns. For *any* disjoint matching `M` of `m` input pairs, let `U` be its `n−2m` untouched input columns. The already proved shared-mode square gives, for the realized output matrix `A`,

```
error(A) ≥ Σ_{(i,j)∈M} [d_i ||z_i−A_i||²+d_j ||z_j−A_j||²]
           + Σ_{i∈U} d_i ||z_i−A_i||² − P,
P = Σ_i ||p_i||²/d_i + Σ_k ||dual_k||²/β_k.
```

The pair sum is bounded by the saved pair cones and matching prices, which for `m=32` yield `N * original_floor + P`; **do not subtract P a second time**. Suppose each output row's coefficients on U belong to at most `K` values (not necessarily the same values in different rows). Define

```
T_o(q,K) = min_{S⊂{1,…,n}, |S|=q; c_1,…,c_K∈ℝ; assignment S→{1,…,K}}
             Σ_{i∈S} (z_{oi}−c_{assignment(i)})².
```

With `d_* = min_i d_i`, every legal matrix has

```
error(A)/N ≥ original_floor(m) + (d_*/N) Σ_o T_o(n−2m,K).
```

Indeed `U` is one common set across rows, while minimization in `T_o` permits a *different* set per row. Each untouched column is charged exactly once, in its row; paired columns remain in the pair cost, not in `T_o`. The general additive interface is stated in [`GridAssembly.lean`](GridAssembly.lean); the numerical/contiguity bridges below are mathematical arguments and independently replayed integer programs, not fully Lean formalized. An affine per-row grid of `2^b` real levels satisfies this premise with `K=2^b`; its actual equal-spaced FP16-constrained centers are a **subset** of this relaxation. No quantization constraint on paired coefficients or pair ratios is used here.

### Why trimmed one-dimensional clusters can be contiguous

For a fixed set of K centers and equal per-point weights, the best cardinality-q assignment chooses the q smallest squared distances to the *nearest* center. Order the centers and break equidistant ties consistently. Each center owns a Voronoi interval, and within that interval distance grows monotonically outward from its center. A sublevel set of nearest-center squared distance is thus a union of at most K intervals. At the selection threshold, tied boundary points can be selected inward-first to reach exactly q without making a hole in any interval; duplicate-valued points may be reordered. Reoptimizing each selected interval's center to its arithmetic mean only reduces error. Therefore the minimum `T_o` is attained by at most K contiguous intervals among the **sorted original values**, with all other points omitted. This argument relies on equal weights: arbitrary `d_i` can break contiguity, which is why we first replace every positive `d_i` by the valid uniform lower weight `d_*`.

## Integer lower certificate, independently checked

For each exact rational shifted `z_{oi}`, form the signed integer `y_{oi}=floor(2^16 z_{oi})`. Then `|z_{oi}−y_{oi}/2^16|<2^-16`, even for negatives. Sort each row of y exactly. For interval `[l,r)` of `s=r−l` integers, its optimized within-cluster squared cost in **integer-grid units** is

```
C(l,r) = Σ y_i² − (Σ y_i)²/s;
C_lower(l,r) = floor((s Σ y_i² − (Σ y_i)²)/s).
```

`C_lower` is an integer ≤C. Dynamic programming skips individual positions or selects a contiguous interval, with exactly 64 selected points and at most 16 intervals. Each row's DP value is a lower bound on its optimum rounded-grid cost; interval flooring can lose <1 per selected interval, but this loss is already built into the DP value and must **not** be subtracted again. The backward Bellman implementation [`trimmed.c`](trimmed.c) and a separate forward state-graph relaxation [`check.c`](check.c) recompute **all 128 row optima independently** and agree exactly; their sum is **4,085,722**. Neither reads a fitter or a selected matching.

For any selected row vector and its optimally fitted centers, triangle inequality gives `sqrt(SSE_z) ≥ sqrt(SSE_y)/2^16 − sqrt(64)/2^16`. Applying `64(a−b)²−63a²+4032b²=(a−64b)²≥0` yields the conservative row cost

```
SSE_z ≥ [63/64 * DP_value − 63*64] / 2^32.
```

Its aggregate lower energy is

```
d_* / (2^32 * 64 * 2^32) * [63 * 4,085,722 − 63 * 64 * 128 * 64].
```

The first `2^32` above converts the saved integer `d_*` to real, the second is the grid's square scale. This exact positive rational is divided by the exact original uncentered response norm `N`. [`verify.py`](verify.py) checks the pinned BF16/FP32 fixture and certificate hashes, forms shifted coefficients from integer witness fields, builds the original response norm exactly, runs and compares both integer DPs, and binds the original rational dual floor from the separately accepted receipt. The resulting [receipt](verified.json) keeps the compact additional rational and both source hashes. No optimizer eigenvector or fitted grid error supplies a lower bound. Run, from the Kelana root, on one CPU thread (~1.6 seconds):

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/paid-grid-floor/verify.py
lake env lean research/isa-quantization/paid-grid-floor/GridAssembly.lean
```

## Paid reader scope and why this remains weak

At fixed `m=32,b=4`, a 128-output by 96-carrier linear output reader stores 6,144 packed coefficient-code bytes, 256 FP16 scale bytes and 256 FP16 origin bytes, 128 uint8 indices (64 pair endpoints and 64 singleton sources), and 64 FP16-ratio bytes: **6,848 bytes**. Its 16 equally spaced output levels per row are paid for by those codes and grid fields. The 6,848-byte scalar comparison has 6,320 packed mixed Q3/Q4 code bytes, 512 FP16 grid bytes and a 16-byte row-mode mask; both are fixed 128×128/m=32 format images with common executable/framing excluded. The variable-cardinality self-describing grammar in [RATE.md](../full-pair-covariance/RATE.md) charges two extra descriptor bytes and is a *different* 6,850-byte image; this certificate does not quietly attach those bytes to the existing 6,848-byte matched control. Neither path's generic code, layout residency or runtime is measured here. The actual pair reader also performs 32 ratio multiplications and 32 input additions before its 12,288 output coefficient contributions, versus 16,384 scalar contributions; these are not a native speed claim.

The decisive loss of information is independent per-row trimming of **64 of 128** columns, arbitrary 16 real (rather than affine FP16) centers, and uniformization to the smallest covariance diagonal. Paired readout values remain entirely real and unconstrained. There is no contradiction between this small positive charge and the substantially larger quantization loss in one selected paid pair image: that image is an *upper witness*, not a universal lower bound. A tighter future bound must couple the common untouched-column set or the affine grid geometry (or both) with the pair selection while preserving the single global dual penalty.
