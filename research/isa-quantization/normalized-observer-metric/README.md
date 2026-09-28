# The Q RMSNorm response is a joint input/output metric

**Result.** One input covariance, even paired with a freely chosen *fixed* output metric, cannot in general price every small Q-weight edit after RMSNorm. The local response is a fourth-order, source-dependent input/output tensor. On the four already frozen, paid Qwen3-0.6B head images, that joint Jacobian diagnostic predicts the observed held ranking reversal between raw and normalized Q without any refit. It does **not** establish a new deployable quantizer or explain the entire causal attention observer, which also depends on K, RoPE, softmax, V and O.

## Characterization and exact obstruction

For real arithmetic, head dimension `d`, learned diagonal gamma `Γ`, and positive epsilon, define `F(z)=Γz/sqrt(s)`, `s=||z||²/d+ε`. At teacher `z=Wx`,

`J(z)=Γ/sqrt(s) · (I−zzᵀ/(d s))`.

For a small complete weight perturbation `Δ`, its local normalized-output squared response under any specified finite source law `P` is

`L_P(Δ)=E_P ||J(Wx)Δx||² = E_P [xᵀΔᵀ A_x Δx]`, `A_x=J(Wx)ᵀJ(Wx)`.

Its coefficients `T_(ab,ij)=E_P[(A_x)_(ab)x_i x_j]` jointly couple **two output and two input indices**. A source covariance `C` alone, with output Euclidean norm, prices all perturbations exactly only if `T_(ab,ij)=δ_ab C_ij`. Even allowing an arbitrary constant output quadratic `Q`, the response `tr(QΔCΔᵀ)` agrees on *every* `Δ` exactly when the symmetric-pair tensor factors `T_(ab,ij)=Q_ab C_ij` (equivalently a rank-one matricization in output-pair versus input-pair indices, with PSD factors). This follows by equality of quadratic forms and polarization. On rank-one edits `Δ=uvᵀ`, a necessary condition is `E[(v·x)²uᵀA_xu]=(uᵀQu)(vᵀCv)`: every two-output/two-input probe matrix must have zero determinant. It is a **universal** characterization, not a claim that any particular finite candidate pair cannot happen to be ranked correctly by an input covariance.

A rational two-token witness disproves universal factorization even at **ε>0 and nontrivial learned gamma**. Let `d=2`, `W=I`, equiprobable source `x=e₁,e₂`, `ε=1`, `Γ=diag(2,3)`. At either input `s=3/2`; radial derivative squared before gamma is `a=ε²/s³=8/27`, tangential derivative squared `b=1/s=2/3`. For output probes `u=e₁,e₂` and input probes `v=e₁,e₂`, omitting the common positive probability `1/2`, the response matrix is

```
[ 4a  4b ]
[ 9b  9a ]
```

Its determinant `36(a²−b²)<0`, contradicting every `Q⊗C` factor. [`NoInputCovariance.lean`](NoInputCovariance.lean) checks the exact rational nonzero minor and the no-separable-factor implication. This is a differential (second-order) response theorem, not a numerical finite-edit assertion.

Positive epsilon also makes the tempting *exact radial gauge* false. If every gamma coordinate is nonzero, `F` is injective: for `y=Γ⁻¹F(z)`, `z=y sqrt(ε/(1−||y||²/d))` on its image. More narrowly, for `z≠0,c>0`, `F(cz)=F(z)` implies `(c²−1)ε=0`, hence `c=1` at positive epsilon. Radial sensitivity can nevertheless be tiny when `||z||²/d ≫ ε`; the norm's derivative along `z` is scaled by `ε/s`. At epsilon zero the positive radial gauge becomes exact, but that limit is not the Qwen norm.

## Fixed actual-source probes and four frozen programs

The [canonical complete-head observer](../quip-complete-head-observer/README.md) supplies the unchanged 128×1024 Qwen3 layer-0 Q head and its four independently priced/frozen images: `root_H` 50,322 B, `scalar_H` 50,320 B, `root_M` 50,322 B, `scalar_M` 50,320 B. [`measure.py`](measure.py) uses the pinned producer fixture (SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`), original source Q, and original checkpoint Q norm gamma (`γ₀=4.53125`, `γ₁=1.2421875`; no zero coordinate). There are 2,048 train and 1,024 *inspected held* source positions. These positions are correlated source-window states, not independent draws from a declared language distribution.

For a transparent, bounded probe, choose output coordinates 0,1 and input directions parallel to teacher Q rows 0,1, normalized to length one (their cosine is .25842). The two-by-two rank-one **Jacobian** response matrix has train determinant `−.1783723` and singular-value ratio `.00018187`; held determinant `−.2154486` and ratio `.00021928`. The **finite** edit `Δ=(1/64)e_p v_jᵀ` yields train determinant `−1.1448e−8` and held `−1.3647e−8`. See [`results.json`](results.json) for all entries. The minor establishes nonseparability of the observed probe values up to numerical measurement precision, but the small singular ratio says **this chosen two-by-two witness is nearly separable**. Its magnitude does not explain the full root/scalar reversal. Held is inspected solely to diagnose the already observed result, never to select directions, images or a fit.

[`frozen.py`](frozen.py) decodes the **same four pinned images**, without changing a byte or fitting a parameter. It computes ideal-real FP64 raw-Q squared response, local joint-Jacobian normalized-Q response, and *exact finite* ideal-real RMSNorm response on the original 128-dimensional Q norm with learned gamma and `ε=1e−6`. Each is divided by its corresponding teacher raw/normalized sum of squares. The output joint/finite normalization denominator is shared across all four candidates in each panel.

| Panel | Frozen image | Raw Q | Joint local normalized Q | Exact ideal normalized Q |
| --- | --- | ---: | ---: | ---: |
| train | root_H | .00384223 | .00646444 | .00649114 |
| train | scalar_H | .01234679 | .01481211 | .01510073 |
| train | root_M | .00504183 | .00849023 | .00853783 |
| train | scalar_M | .01303163 | .01607467 | .01640014 |
| inspected held | root_H | **.01310979** | .02138060 | .02141149 |
| inspected held | scalar_H | .01462780 | **.01776714** | **.01811911** |
| inspected held | root_M | **.01261749** | .02086577 | .02095074 |
| inspected held | scalar_M | .01468089 | **.01860879** | **.01905574** |

On held source states, both root images win **raw Q** against their corresponding scalar, yet lose **normalized Q**; the joint Jacobian has the correct reversed order. Its local/finite ratio is .99856 for root_H, .98057 for scalar_H, .99594 for root_M, and .97654 for scalar_M. The original BF16-rounded CPU observer independently reported held normalized Q `.02141683` versus `.01812619` for root_H/scalar_H and `.02097905` versus `.01908079` for root_M/scalar_M. Those are close but not identical to these ideal-real numbers: BF16 rounding creates a staircase, so an ideal-real derivative is **not** a derivative of the emitted rounded kernel. No attention KL ranking follows formally from the norm-only tensor; the canonical observer directly measured that separate causal consumer.

**Program-selection implication:** for an actual norm consumer, assess a candidate's joint response `E||J(Wx)Δx||²` or its direct finite consumer effect rather than assuming an input-only H/G/M metric is sufficient. A program can stream each `δz=Δx`, apply `J(Wx)δz`, and accumulate squared norms; it need not store the fourth-order tensor. Source-law coverage, output norm geometry, finite-edit curvature, BF16 execution and downstream attention remain distinct obligations. A train-fitted joint tensor is not guaranteed to generalize to held source states, and none of these diagnostics authorizes a held-selected quantizer.

## Reproduction and ownership

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$PY research/isa-quantization/normalized-observer-metric/measure.py
$PY research/isa-quantization/normalized-observer-metric/frozen.py train
$PY research/isa-quantization/normalized-observer-metric/frozen.py held
lake env lean research/isa-quantization/normalized-observer-metric/NoInputCovariance.lean
```

Each CPU invocation is bounded under one minute; no new capture, GPU, fit, mode choice or damping sweep. The image loader checks frozen image hashes in the canonical observer; the fixture bytes and model checkpoint belong to their existing data owners. [`frozen-train.json`](frozen-train.json), [`frozen-held.json`](frozen-held.json) and [`results.json`](results.json) retain the full numeric receipts. This study owns only analysis scripts, theorem and receipts; shared catalogue and synthesis are parent-owned.
