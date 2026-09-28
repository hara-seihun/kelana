# Cheap input programs: an exact signed-pair Q4-accuracy limit

**Comparable-size scope:** the signed-pair programme is estimated near 6,788 bytes, while the Q4 control uses 8,704. The universal floor below excludes matching that Q4 error on the captured panel, not a useful lower-size rate/distortion point. the project lead's target is strong quantization at comparable effective size; see [the benchmark contract](../BRIEF.md#comparable-size-state-of-the-art-is-the-target).

The preceding [producer screen](../producer-screen/README.md) found a rank-96 four-bit output description with **.003504** train relative squared response error when its input factors were arbitrary real numbers. Its actual signed-carrier image lost badly. Here the question is whether a *different*, genuinely cheap input computation can exploit the available 96 output carriers at no more than the exported scalar Q4 image's **8,704 bytes**, while doing less recurring work than 128×128 direct coefficient consumption.

The fixed real boundary is the same Qwen3-0.6B layer-0 `q_proj` **128 input by all 128 selected output** subprojection, evaluated on its 2,048 existing train and 1,024 held producer states. We preserve all outputs of this local boundary, not the rest of the attention projection. The reference is the actual [`affine-q4.bin`](../producer-screen/affine-q4.bin): 8,704 packed bytes, replayed in this study, .005173614 train and .005173615 held relative squared error. The global calibrated-Q4 and selected ternary model-level baselines remain documented in [producer screen](../producer-screen/README.md); these local scores are not model NLL.

## An explicit input-program family

Choose 32 disjoint coordinate pairs. Each pair makes **one** signed sum `x_i ± x_j` (one add/subtraction); 64 unmatched coordinates pass through. A 96-carrier output projection consumes these values. An eventual signed-four-bit output matrix with one FP16 scale for each of 128 outputs would cost 6,144 code bytes + 256 scale bytes. Conservatively pay 128 bytes for 64 pair indices and 64 singleton indices, plus 4 bytes of pair signs, and pay **another 256 bytes** for possible affine output origins: **6,788 total bytes**. This is a budget estimate, *not an exported candidate*. (With only signed symmetric scales the actual count would be 6,532 bytes.) The output reads 12,288 coefficients and the input uses 32 additions/subtractions, compared to the direct scalar control's 16,384 coefficient reads/accumulations. Thus it offers a concrete 25% reduction in recurring coefficient operations and storage under the same input/output contract; ISA timing, nibble decode and register pressure remain unmeasured. No extra training or model downloads are involved.

For a fixed input program `T` (128×96), the best possible train response over **all real output matrices**, not merely four-bit images, is the orthogonal projection of `Y=XWᵀ` onto the column span of `XT`. Its exact algebraic squared-error floor is

```
min_A ||XWᵀ - XT A||² = ||(I-P_XT) XWᵀ||².
```

The code computes this projection with FP64 least squares. This is a *sound family floor for the fixed `T` on the captured states*, even if scales/origins were free; no FP16 rounding or response fit can improve it. The input-program choice is **heuristic**, however: for each pair, rank a sign by the squared residual of its own two-coordinate contribution after projecting onto `x_i ± x_j`; greedily take 32 low-cost disjoint pairs and then refit the **complete** 128-output response. The pairwise ranking is not the complete objective, since other carriers can compensate across pairs.

| Input program, 96 carriers | Best real-readout train floor | Held error of train-selected real readout |
| --- | ---: | ---: |
| 32 selected signed pairs, 64 pass-through | **.014038** | .017577 |
| 32 selected sums only, 64 pass-through | .014590 | .018902 |
| 96 selected original coordinates (pivoted-QR heuristic) | .017783 | .022437 |
| 96 selected normalized Hadamard coordinates (pivoted-QR heuristic) | .021304 | .027202 |
| 96 arbitrary real input factors, selected Q4 output basis (prior relaxation) | .003504 | not an executable input program |
| Exported direct scalar Q4 | **.005174** | **.005174** |

The selected pair programs cannot match this Q4 accuracy even before fitting output codes: their response-space floors exceed the scalar image's error by 2.71× and 2.82×. The diagonal certificate below extends that **accuracy-threshold** conclusion to all 32-disjoint signed-pair programmes, not just these selections. Merely selecting 96 wires or a fixed fast Hadamard basis is worse in these bounded selections. The full 128-point Hadamard costs up to 896 additions/subtractions before the 12,288 output coefficient operations, so it is less compelling as a recurring-work reduction than sparse pair merges. These are selection outcomes at the same 96-carrier input-program budget, not global subset lower bounds. No candidate survives here, hence there is no hypothetical packed image presented as a win.

## General obstruction: from weak spectral bound to decisive diagonal certificate

A **dense two-stage** linear map through `r` carriers uses `128r` first-stage and `128r` second-stage coefficient contributions. The scalar direct consumer uses `128²`. The real-response rank screen proves `r≥67` is necessary to beat the actual Q4 response on this panel, so `256r≥17,152>16,384`: a conventional dense two-stage coefficient path cannot simultaneously meet the Q4 response threshold and reduce this simple operation count. This is a count of contributions, not a latency theorem: native signed/int4 dots have different instruction throughput, and an input transform may have sparse/structured implementation. Sparse pair merges explicitly escape the dense premise, but fail in response geometry for the selected programmes.

One lower bound does hold **over every choice** of 32 disjoint signed pairs, albeit too weak to reject the family. Let `H=XᵀX`, `λ` its smallest eigenvalue, and `w_i` the full 128-output weight column for coordinate `i`. Any real readout following signed pair `(i,j,s)` must give its two weight columns coefficients `(a, s a)`. By `H≽λ I` and optimizing `a`, its residual weight Frobenius energy is at least `||w_i-s w_j||²/2`. The 32 selected edges are distinct, so summing the 32 cheapest edges **without enforcing disjointness** gives a universal floor

```
λ * sum_32_smallest_edges min_s ||w_i-s w_j||²/2 / ||XWᵀ||².
```

This initial bound returns **.001190**, below Q4's .005174. It does not resolve the family. The heterogeneous diagonal minorant below does. An arbitrary nonlinear decoder still lies outside this linear-output projection theorem and must pay its own work/storage.

### Why single-edge covariance alone did not settle the matching

For a specified disjoint signed matching let `D` be the 128×32 matrix whose edge columns are `e_i-s e_j`. The constraint on a candidate weight map `W'` is `W'D=0`. Since `H=XᵀX` is positive definite, constrained least squares gives the **exact** fixed-program response floor

```
C(D) = tr[(WD)(DᵀH⁻¹D)⁻¹(WD)ᵀ] / ||XWᵀ||².
```

Proof: with `E=W-W'`, the minimum of `tr(EHEᵀ)` subject to `ED=WD` has `E=WD(DᵀH⁻¹D)⁻¹DᵀH⁻¹`; substitution gives the expression. Disjoint edge columns are independent. This identity captures all producer covariance, but its inverse couples the 32 pair choices. The single-edge costs `a_e=min_s ||W(e_i-s e_j)||²/((e_i-s e_j)ᵀH⁻¹(e_i-s e_j))` sum to **.010452** over the cheapest 32 edges. Enforcing disjointness with a fractional matching LP raises the sum to **.011683**. *Neither sum is a valid bound by itself*: off-diagonal entries of `DᵀH⁻¹D` allow joint penalties to share error.

A replayable simultaneous bound uses the normalized precision Gram `R`: its diagonal is one. Over **both signs** for all 8,128 possible edges, [`certificate.py`](certificate.py) finds the largest sum of the 31 largest absolute correlations against disjoint edges, **13.749278**. For every 32-edge matching, the row-sum bound gives `R ≼ (1+13.749278)I`. Hence `C(D) ≥ Σ_edges a_e/(1+13.749278)`. Feeding the fractional matching relaxation yields a universal floor **.000792**, weaker than the simpler `.001190` bound. The exact covariance identity strengthens individual edge scores, but a global worst-row correlation bound erases that gain. The successful route is a **diagonal minorant of the full covariance**, which makes disjoint pairs additive without throwing away every coordinate's scale.

### Decisive certificate for all disjoint signed pairs

Choose positive numbers `d_i` such that `H ⪰ diag(d)`. For any candidate weight error `E=W-W'`, `tr(EHEᵀ) ≥ Σ_i d_i ||E_i||²`. On signed pair `(i,j,s)`, the readout constraint requires the candidate columns `(a,s a)` for one arbitrary real output vector `a`. Completing the square independently in every output gives the **exact diagonal-metric pair cost**

```
min_a [d_i ||w_i-a||² + d_j ||w_j-s a||²]
    = d_i*d_j/(d_i+d_j) * ||w_i-s*w_j||².
```

Disjoint pair costs now add, while unmatched input coordinates may be fitted for free. A fractional matching LP over all 8,128 edges, with 32 selected edges and each vertex used at most once, is a lower bound on every legal integer matching. Its dual has a nonpositive price `u_i` for each vertex, and an unrestricted cardinality price `c`. The easily checked condition

```
u_i + u_j + c ≤ min_s [d_i*d_j/(d_i+d_j) * ||w_i-s*w_j||²] / ||XWᵀ||²
```

for **every edge** proves that every matching costs at least `Σ_i u_i + 32c`. This combination preserves heterogeneous coordinate covariance and the disjointness obligation without enumerating matchings or fitting readout codes.

[`diagonal_minorant.py`](diagonal_minorant.py) proposes a diagonal using safe rays `d=t*r`, where `t⁻¹=λmax(diag(sqrt r)H⁻¹diag(sqrt r))`, then improves the ray with a bounded dual-guided search. This search is only a proposal: the certificate exports **dyadic integers** for `d`, one triangular factor and all 129 dual fields. Independent [`verify_diagonal.py`](verify_diagonal.py) does not run the optimizer or LP. It recovers the exact dyadic input Gram, teacher weights and decoded exported Q4 image from their existing owners and checks, with Python **integer arithmetic**:

1. The matrix `H-diag(d)-LLᵀ` is symmetric and strictly diagonally dominant with positive diagonal, so `H ⪰ diag(d)`; no floating eigensolver status is accepted as evidence.
2. Every one of the 8,128 rational edge-dual inequalities holds by cross multiplication, with the vertex prices nonpositive.
3. The dual lower bound exceeds the **exact rational Q4 relative squared error** after a final integer cross multiplication.

| Exact captured-panel quantity | Value |
| --- | ---: |
| Universal signed-pair error floor, dual certificate | **.005176814521502315** |
| Exported Q4 image error | **.005173614377259471** |
| Strict certified margin | **+.000003200144242844** |
| Heuristic best signed-pair real-readout floor | .014037775631571447 |

This resolves the **specified Q4-accuracy question**: no 32-disjoint signed-pair input program with arbitrary real linear output readout beats this exported Q4 response on the 2,048 captured train states. The family would do 32 pair operations plus 12,288 readout coefficient operations and could fit in the Q4 byte budget, but fails on response geometry even with its output codes/scales free. The strict margin is small; it is protected by the exact integer certificate rather than inferred from a solver tolerance. This does not exclude overlapping pairs, deeper sparse circuits, nonlinear input encodings, other input producers, or full Qwen attention replacements.

[`DiagonalPairCertificate.lean`](DiagonalPairCertificate.lean) proves the cleared-denominator harmonic identity underlying the pair cost; [`PairConstraints.lean`](PairConstraints.lean) proves signed-pair coefficient laws. The PSD/matching-dual inequalities and all numeric comparisons are replayed exactly by the independent Python verifier, **not** formalized in Lean. The fixed-program covariance-projection identity remains a paper derivation. Proof boundaries are intentionally distinct.

The 128-dimensional captured train Gram is positive definite (smallest eigenvalue 9.17055 in FP64). This sample covariance is **not** a producer invariant or worst-case enclosure; held error diagnoses transfer to separate states and is not an unseen-domain bound. The preceding study has a modular-rank certificate on the exact captured matrices, but it does not certify future Qwen histories.

## Reproduce and custody

Fixture remains with `/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz` (SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`), as described in [binary-factor comparison](../../quantization-discovery/subbit/binary-factors/README.md). Results contain all 32 selected pairs and signs; no large fixture is copied. Run from Kelana root with one BLAS thread; each command is sub-minute:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/input-programs/pairs.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/input-programs/pilot.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/input-programs/certificate.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/input-programs/verify_diagonal.py
lake env lean research/isa-quantization/input-programs/PairConstraints.lean
lake env lean research/isa-quantization/input-programs/DiagonalPairCertificate.lean
```

`pairs.py` replays the existing exported Q4 bytes and selected-pair floors. `pilot.py` screens two 96-feature coordinate systems. `certificate.py` records the weaker precision-edge route. `diagonal_minorant.py` proposes the separately committed certificate image [`diagonal-certificate.npz`](diagonal-certificate.npz), and `verify_diagonal.py` checks it **without optimizing** into [`verified-diagonal.json`](verified-diagonal.json). The model checkpoint and activation fixture retain their established owners.
