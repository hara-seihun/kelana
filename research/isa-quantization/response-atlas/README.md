# Direct response atlas on real MLP producer states

**Comparable-size scope:** the two-chart 4,200,482-byte programme is smaller than the 4,866,096-byte Q4 control. Its selected fit is poor and the one-chart pooled floor is sound, but neither excludes useful affine/routed points at their own sizes. The target is [strong quantization at comparable effective sizes](../BRIEF.md#comparable-size-state-of-the-art-is-the-target), not a universal Q4-accuracy gate.

**Decision:** A source-derived two-chart affine atlas is a different executable family from a bank of original hidden channels: its online map is a router followed by one **direct 1,024×1,024 output matrix–vector product**, with no gate/up/SiLU/down stage. It fits under the complete scalar Q4 MLP's model payload and reduces the nominal coefficient-product count. But the source-averaged, train-built, serialized-FP16 atlas scores **.80528 relative RMS** on the separate validation states; packed group-128 Q4 gate/up/down scores **.16253**. No candidate image survives. More fundamentally, a *single affine output map*, even with unrestricted FP64 coefficients optimally chosen after seeing **both** panels, has a .33179 finite-panel RMS floor, twice the actual Q4 error .16384 on that union. This excludes the single-affine class from attaining that Q4 accuracy on the finite observed endpoint, not from all lower-size frontiers and not a general piecewise-affine program. For the chosen two-chart router, a pooled arbitrary-fit floor is nearly vacuous because one chart has fewer examples than affine coefficients; it is **not** an impossibility theorem for the two-chart family.

## Changed assumption and deciding observable

The prior [nonlinear-response bank](../nonlinear-response-bank/README.md) retained selected original hidden channels as live nonlinear features. Here source functions are used **offline to calculate an output map**, then discarded. The exact local source is Qwen3-0.6B layer-0 `F(x)=D[SiLU(Gx) ⊙ Ux]`. The input is the complete actual 1,024-dimensional BF16 selected-ternary-model producer state; all **3,072** hidden source channels participate in constructing charts, and **all 1,024 outputs** are scored. Four 256-position train windows and four disjoint 256-position validation windows are read from the owned caches in [`cache.json`](cache.json), not a designed two-coordinate grid. This validation was inspected in earlier ISA studies, so it is **separate validation, not untouched final evaluation**.

The candidate's native-level question would be a 1,024-dimensional dot to choose a chart followed by a dense 1,024×1,024 FP16 matrix reader and FP32 accumulation. Its complete description, quality and traffic must be considered together. The decisive early observable is whether the complete-output map is locally affine on those real producer states. A nonlinear hidden bank might have transfer trouble from too few traces even if the source describes it well; direct Jacobian charts test an entirely different approximation family and make source information available without fitting a million output coefficients to 1,024 responses.

For an anchor `c`, differentiating the known source gives

```
J(c) = D [diag(SiLU'(Gc) ⊙ Uc) G + diag(SiLU(Gc)) U],
b(c) = F(c) - J(c)c,
P_c(x) = J(c)x + b(c).
```

One fixed reader supplies the one-chart control. For the two-chart program, the router is the training input's first principal direction, rounded to FP16, with its training median projection rounded to FP16 as threshold. The two centroids are means of the 512 training inputs assigned to either side. This direction captures only **6.71%** of centered training input energy; it is a cheap, train-only route, not evidence that the producer lives on a line. A stronger **source-averaged** chart avoids claiming the derivative at a single centroid represents an entire half: it replaces the two diagonal coefficient vectors in `J` by the exact source's *averages on that training half*, and chooses the intercept so its affine map equals the half's mean complete output at the mean input. This uses all original gate/up/down rows offline, but no individual hidden coefficient or source weight survives in the online image. The source averaging is a fit to training input functions, not a million-parameter regression against output targets.

## Physical ledger and complete outputs

A chart is 1,048,576 FP16 Jacobian coefficients (2,097,152 bytes) plus 1,024 FP16 output-intercept coefficients (2,048 bytes). Two charts therefore cost **4,198,400 bytes**. The router pays its actual 2,048-byte FP16 direction and two-byte FP16 threshold; reserve 32 bytes for dimensions/format/framing: **4,200,482 bytes** total, 665,614 below the **4,866,096-byte** packed scalar Q4 control. The two chart payloads and router were serialized to `.bin` before scoring, independently loaded and SHA-checked. They are ignored generated artifacts because the candidate fails and no deployable single-container image is emitted; their hashes and byte counts are retained in `chart-*.json` and `score-*.json`. There are no uncharged per-chart specialized instruction constants. The generic reader and routing control flow are not counted as model bytes; actual `.text`, launch, allocation, cache and alignment costs have **not** been assembled or timed.

The scalar control is the actual stored group-128 Q4 gate, up **and down** image, including every packed code, FP16 group scale and shape descriptor, decoded for the same complete input/output boundary. It was calibrated by a multi-start alternating scalar fitter, not naive one-pass rounding. One atlas input would issue roughly 1,048,576 coefficient-input terms plus its router dot, whereas the source/Q4 three dense projections entail about 9,437,184 coefficient-input terms plus SiLU and gate/up multiplication. Packed Q4 and dense FP16 have different memory traffic and ISA work, so this arithmetic count is **not a native speedup**. No GPU admission or measurement was requested for a failed response map.

| Complete-output program | Train relative RMS | Separate validation relative RMS |
| --- | ---: | ---: |
| Original-source Jacobian at global centroid (FP64 diagnostic) | .93069 | .93167 |
| Source-averaged global chart (FP64 diagnostic) | .85673 | .86252 |
| Original-source Jacobian at routed centroids (FP64 diagnostic) | .86630 | .87019 |
| Source-averaged routed charts (FP64 diagnostic) | .79411 | .80529 |
| **Serialized FP16** source-averaged routed charts | **.79411** | **.80528** |
| Actual packed scalar Q4 gate/up/down | **.16516** | **.16253** |

The near identity of FP64 and stored FP16 charts identifies **curvature/representation**, not rounding, as the large failure. Train and validation move together; simply fitting more chart fields to the same train states is not an evidential repair.

## A sound finite-domain floor—and its boundary

[`capacity.py`](capacity.py) does independent complete-output QR projection against an intercept and all 1,024 input coordinates. On the union of 2,048 real states, the unrestricted single affine map's optimal FP64 residual is **.331788 RMS** versus the Q4 image's **.163836**. The relative residual/design orthogonality is `7.58×10⁻¹⁷`, a numerical check of the least-squares projection. This is a lower bound for *every* single affine map on **that pooled finite panel**, including non-source Jacobians and unquantized coefficients. It is not a lower bound over unseen producer states or a deployment-trained held score; the projection uses the validation targets deliberately for a favorable capacity relaxation.

For the fixed two-chart route, the analogous pooled optimistic residual is **.05609**, below Q4, but its first side has 967 states for 1,025 affine fields and can interpolate that finite side exactly; the second has 1,081 states and almost interpolates it. Such an underdetermined oracle projection does not demonstrate a transferable compressed map or vindicate these charts. The evidence instead distinguishes: one-chart class cannot reach this Q4 accuracy on the panel; this train-built two-chart source-derivative construction has large held loss; other two-chart descriptions and producer-adapted routing remain open. Charging a trained arbitrary 2×1,025×1,024 coefficient image would still fit in the same FP16 payload, but reliable estimation or source-derived construction, not finite-sample capacity alone, is indispensable.

## Custody and reproduction

The input owner `/path/to/workspace/data/kelana-subbit/vector-full/capture/isa-response/README.md` describes the ten durable response and preactivation arrays, provenance, and regeneration commands. [`cache.json`](cache.json) hashes them individually. They were copied byte-for-byte from the completed earlier writer before that writer was registered with `agent-workspace --cache-owned` and released; this study uses the **durable data path** directly and does not rebuild previous calculations for checkout cleanup. The captured source/checkpoint and scalar Q4 image hashes remain in the preceding bank's [`results.json`](../nonlinear-response-bank/results.json).

From this directory, one BLAS thread, existing CPU resources only:

```sh
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for split in train held; do OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" screen.py --split "$split"; done
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" capacity.py
for chart in 0 1; do OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" compile.py --chart "$chart"; done
for split in train held; do OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" score.py --split "$split"; done
```

Each command is under a minute. The standalone chart payloads are reproducible from the source and train captures and **not** kept as a selected model image. This is a measured numerical approximation and a finite-panel QR floor; it is not a theorem about the full producer reachable set, a whole-model behavioral measurement or a native execution benchmark.
