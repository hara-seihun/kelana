# Why the full-row QuIP# win on train reverses on held inputs

This is a **post-result diagnosis** of the two frozen 128×1,024 decoded images from [the full-row slab](../quip-full-row-slab/README.md). Neither image, code, sign, scale, calibration policy nor held sample was selected or fitted here. The already-observed held panel diagnoses transfer; it is not a new validation set. [`analyze.py`](analyze.py) reads the standalone image hashes, original fixture and independent decoders, and computes the exact empirical second-moment response identity `E_X(Δ)=tr(H_X ΔᵀΔ)` with `H_X=XᵀX/|X|` and `Δ=Ŵ−W`.

## Decisive source/covariance geometry

The 2,048 calibration rows contain **896 unique input vectors**, and the 1,024 held rows contain 472 unique vectors, of which 121 occur in training. Exactly **438 held positions** use an input vector not seen during calibration (351 distinct new vectors). The training covariance has rank **896** in 1,024 dimensions: its nullity is **128**. Its first positive eigenvalue is `2.6170e−5`, versus the largest `8.64359`, leaving a clean gap from numerically zero eigenvalues (~`1e−16`). The held inputs have **1.185558** mean squared energy projected into that train-null space; train energy there is `1.69e−25`. Thus a deterministic audit of input uniqueness/rank already exposes an unseen-direction risk, and the separate held covariance shows it actually occurs. The full-row producer is layer-0 Q-projection input on disjoint text windows, not an iid Gaussian or an unrestricted continuous calibration domain.

A **uniform unrestricted** guarantee `tr(H_held ΔᵀΔ) ≤ C tr(H_train ΔᵀΔ)` has **no finite C** for these observed covariances: choose a one-row error map whose row lies in the train kernel with positive held variance. [`NoUniformTransfer.lean`](NoUniformTransfer.lean) proves the abstract kernel-witness implication; the float64 eigendecomposition/projection measures the magnitude here. The subsequent [token-producer study](../quip-token-producer/README.md) supplies an exact noncontainment certificate: 896 unique train vectors imply rank at most 896, while those vectors plus the first novel held input have a nonzero 897-column minor modulo 65521 (determinant 18187). Thus the absence of a finite unrestricted transfer constant does not depend on an eigenvalue cutoff. Restricting *all* error rows to the training support yields a finite generalized-covariance worst-case factor **474.409**, but that is an extremely loose bound on the two actual decoded maps and cannot cover their nonzero null components. This is a precise failure of a proposed transfer certificate, not proof that any future calibration necessarily fails.

## Fixed-map attribution (per source state)

| Quantity | QuIP# RVQ3 54,418 B | scalar group128 54,416 B |
| --- | ---: | ---: |
| coefficient error `||Δ||²_F` | **9.604317** | 4.963882 |
| coefficient error fraction in train-null directions | **38.301%** | 14.451% |
| train response error numerator | **.03014638** | .06905550 |
| held response error numerator | **.10147204** | .08067737 |
| held error of train-null projection alone | **.03406913** | .00669691 |
| held error of supported projection alone | .06790563 | .07426852 |
| held null/support interference | −.00050271 | −.00028805 |
| held error at novel-input positions | **92.169%** | 70.676% |

The numerator decomposition is exact: write `Δ=ΔP_null+ΔP_support`; each positive projected held term is `||X_held (ΔP)^T||²/1024`, with their interference included once. QuIP# has **5.09×** the scalar's held null-projection error. Its null excess `.02737222` is **larger than the entire held numerator deficit `.02079467`**; on the training-supported component it still improves by `.00636289`. The small negative cross-term difference is also in [`results.json`](results.json). This identifies the reversal mechanism for these **two particular images**: train covariance is blind to code distortion in 128 directions that the held source exercises. QuIP# places almost twice the total coefficient error in the matrix and a much larger fraction of it into that blind subspace. It is not merely a larger denominator or a conclusion about E8 quantization universally.

The teacher output energy per train/held state is **7.846066 / 7.740173**, a held/train factor of **.986504**, common to both arms. QuIP# raw response-error numerator grows **3.36598×** from train to held versus scalar **1.16830×**. The published relative errors `.00384223→.01310979` versus `.00880129→.01042320` reverse because the numerators change, not because their common normalization denominator shifts. Among the 896 training-supported generalized covariance modes, the top 100 account for **57.86%** of QuIP#'s supported held error while carrying **3.05%** of its train error; scalar has **34.18% / .95%**. These amplification modes are a secondary warning, not the main explanation: the QuIP# supported held error remains below scalar.

## Reproduce and interpretation

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/isa-quantization/quip-covariance-transfer/analyze.py
lake env lean research/isa-quantization/quip-covariance-transfer/NoUniformTransfer.lean
```

The computation and Lean check are individually sub-minute. `results.json` pins the images by SHA256, all covariance/energy components and source row counts. The rank/uniqueness check is cheap enough to run before fitting another full-row method: a 128-dimensional calibration-null space is a reason to seek more diverse **training** source states or a source prior, not to let held outputs tune the already evaluated images. It does not itself identify which quantizer will transfer; no train-only statistic can certify arbitrary future covariance without a constraint relating future source support to training support.
