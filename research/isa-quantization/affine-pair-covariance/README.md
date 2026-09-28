# Weighted pairs with a free intercept still cannot reach this Q4 accuracy

**Captured-panel result.** For the same Qwen3-0.6B layer-0 `q_proj` 128-input × 128-output subprojection, every input program merging **32 disjoint freely weighted coordinate pairs**, passing 64 unmatched coordinates through, and applying an **arbitrary real affine** 128-output readout has train relative squared response error at least **0.005188092711406706**. The existing unchanged exported scalar Q4 image scores **0.005173614377259471**. Their exact rational difference is positive: approximately **0.000014478334147234897**. Thus even a free intercept and unrestricted real pair ratios/output coefficients cannot beat Q4 on the captured 2,048 train producer states. The margin is smaller than the [linear full-covariance result](../full-pair-covariance/README.md)'s ~0.000579, but the exact independent arithmetic check protects it.

This is a genuine enlargement of the linear weighted-pair family, not a re-evaluation of its existing certificate. A hypothetical FP16 output intercept adds only 256 bytes to the previously estimated 6,848-byte weighted-pair payload (7,104 < the scalar Q4 image's 8,704 bytes), but this study exports no weighted-pair image: it is an accuracy-limit certificate with an unrestricted real intercept and real readout, not a candidate fit.

**Q4 comparison alone does not exclude the 7,104-byte family from a comparable-size frontier.** Its floor exceeds the error of an 8,704-byte Q4 image, a different size point. the project lead's target is state-of-the-art quantization at comparable total effective sizes, where higher error than Q4 can be entirely appropriate. The subsequent [matched-rate study](../matched-rate-frontier/README.md) supplies that missing local comparison: a response-refitted 7,104-byte GPTQ-style scalar image has exact train error .005064387370575328, below the .005188092711406706 family floor. That now excludes beating this particular equal-byte control's captured train error. It is still not a named SOTA result, a held-error certificate or joint error/bytes/work dominance. The byte estimate remains hypothetical and does not establish ISA timing.

## Why the covariance changes but the comparator does not

Let `X` be the actual 2,048×128 input matrix and `W` the 128×128 teacher. A weighted-pair linear map realizes coefficient matrix `A`, and the affine reader adds a freely chosen output vector `b` on every row. Put `E=W−A`, `n=2048`, and `C=I−11ᵀ/n`. Orthogonal least squares in the intercept gives

```
min_b ||X Eᵀ − 1 bᵀ||² = ||C X Eᵀ||²
                         = tr(E H_c Eᵀ),
H_c = Xᵀ C X = XᵀX − (Σ_rows x)(Σ_rows x)ᵀ/n.
```

The denominator for reported relative error is still the original **uncentered** `N=||X Wᵀ||²`. The scalar Q4 comparator is still the **actual exported image**, scored on the original uncentered target, *without* granting it a newly fitted intercept. The mean component of teacher response is about 38.965% of `N`; silently replacing `N` with the centered teacher norm would change the problem. [`CenteredIntercept.lean`](CenteredIntercept.lean) proves the cleared-denominator scalar square that justifies eliminating `b`.

## Centered full-covariance dual and exact witness

The [linear full-covariance study](../full-pair-covariance/README.md) derives the shared-mode dual in detail. Apply the **same theorem** to `H_c`, not `XᵀX`: the saved certificate has `D=diag(d)>0`, `V` of size 128×48 and positive `β` such that `H_c⪰D+V diag(β)Vᵀ`. For a single common output-vector dual `m_k` for each of the 48 modes, `P=MVᵀ`, `z_i=w_i+p_i/d_i`, and any pair program:

```
tr(E H_c Eᵀ) ≥ Σ_i d_i ||z_i−A_i||²
                − Σ_i ||p_i||²/d_i − Σ_k ||m_k||²/β_k.
```

The first penalty includes all **unmatched** coordinates. Minimize each pair's two squared terms over every collinear pair of output vectors: this includes arbitrary real input ratio and output readout, and yields the smaller eigenvalue of the weighted 2×2 Gram of `z_i,z_j`. The 32-edge disjoint matching minimum is relaxed to a fractional matching LP. Saved nonpositive vertex prices and a cardinality price lie below **all 8,128** pair costs. Subtract both globally shared dual penalties and divide by original `N`; the result is the exact universal floor above. Free affine output is already eliminated by centering and cannot escape this bound.

[`spectral_dual.py`](spectral_dual.py) only **proposes** the witness numerically: it retains 90% of the predecessor dyadic diagonal, uses 48 leading spectral directions in `H_c−D`, and optimizes the shared dual with a complete matching LP in bounded steps. It reserves PSD slack, rounds every witness field to integers and records its numeric history in [`spectral-results.json`](spectral-results.json). There is no exhaustive fit or claim about the optimizer's global optimum. This proposal and the eigen/Cholesky/LP floating results have no evidentiary role in the strict conclusion.

Independent [`verify.py`](verify.py) pins the fixture and existing Q4 SHA256, checks all witness shapes and int64 dtypes, scales and guards the source dyadics, reconstructs exact centered Gram as `n(XᵀX)−(Σx)(Σx)ᵀ` over denominator `n·2^54=2^65`, and checks `H_c−D−V diag(β)Vᵀ−LLᵀ` is strictly diagonally dominant with positive diagonal **using integers**. It checks every pair inequality as an exact 2×2 rational PSD cone, the signs of matching prices, the two rational penalties and the exact unchanged Q4 error on the **uncentered** Gram. Its [receipt](verified.json) includes rational numerators/denominators of the floor, comparator and positive margin; no solver status or floating eigensolver establishes a proof. The 112 KB [`spectral-certificate.npz`](spectral-certificate.npz) is the compact dyadic witness, with no copied producer fixture.

The local Lean module proves the intercept square. General finite rational covariance/matching assembly is also proved in [`Kelana/PairCovarianceAssembly.lean`](../../../Kelana/PairCovarianceAssembly.lean), including all unmatched-coordinate penalties. Centered-metric reduction, the real PSD/cone bridge and rational-to-real transfer remain mathematical derivations; numeric PSD, all pair cones and final rational comparison are independently checked by exact Python arithmetic. No claim of full Lean formalization is made.

Fixture: `/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz` (SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`). Existing scalar Q4 image: [`affine-q4.bin`](../producer-screen/affine-q4.bin) (SHA256 `8c4b03a9696bee7f0bd80c344f2996a4d6247651ca11f671d07e0c27a86f82c6`). From Kelana root, each command completes in less than a minute on one CPU BLAS thread:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/affine-pair-covariance/verify.py
lake env lean research/isa-quantization/affine-pair-covariance/CenteredIntercept.lean
# Only to regenerate a new numerical proposal and dyadic witness:
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/affine-pair-covariance/spectral_dual.py
```

This excludes reaching the stated Q4 error within the **32-disjoint freely weighted pair + arbitrary real affine readout grammar on captured train states**. It does not exclude a competitive lower-size error/work point. It does not settle held/unseen producer states, overlapping pairs, recurrent/deeper sparse programs, nonlinear readers, all attention outputs, model quality or native ISA work. The Q4 image and fixture remain with their existing owners.
