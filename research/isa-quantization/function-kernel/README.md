# Function-space kernel for a complete nonlinear MLP

**Result:** A known source model makes a complete-output bank readout calculable from an input-law inner product without fitting the 1,024 output rows against captured response traces. Gaussian integration by parts and a one-dimensional Hermite expansion reduce each SiLU×up feature-pair moment to six scalar series; only selected-feature-to-all cross moments are needed, not a 3,072² kernel. That mathematical route is viable. Its **single Gaussian producer law is not**: on the real Qwen layer-0 captured producer states, the predicted feature cross moments differ from observed validation moments by ~86–95%, and its 128-feature complete-output prediction has .87072 held relative RMS versus .16253 for packed all-three-matrix Q4. We reject fitting/deploying a larger Gaussian-law bank on this fixture. The same analytic construction could be revisited with a source-derived law that preserves persistent higher joint moments.

## Boundary and explicit law

Use the same complete 1,024→3,072→1,024 BF16 Qwen3-0.6B layer-0 gate/SiLU/up/down MLP and actual selected-ternary-producer inputs as [the preceding bank study](../nonlinear-response-bank/README.md): 1,024 train and 1,024 different validation full-width states, each assembled from four disjoint 256-position text windows. That earlier capacity screen inspected the validation targets to select promising bank sizes, so this study **does not call these targets a fresh final test**. This study instead asks whether a different, source-informed calculation of a readout improves transfer. Its chosen K=128 feature identifiers use only training hidden variation and known source down-column norms. There is no validation-target-selected parameter or rank inside this study.

The declared producer law is the possibly singular multivariate Gaussian `X ~ N(μ,Σ)` whose mean and **full** covariance equal the 1,024 training input states' empirical mean and covariance. This is much more generous to a Gaussian model than independent-coordinate variance. The target map is `Y_o=∑_{j=0}^{3071} D[o,j] f_j(X)`, where `f_j(X)=SiLU(g_j·X) (u_j·X)` uses known BF16 source rows. Neither a feature nor a gate/up intermediate is a requirement on a general representation; this is one candidate program family. The Gaussian law is a hypothesis about the producer, not an exact property of the selected ternary model.

## Exact algebra: only a cross kernel

Write `G_i=g_i·X`, `U_i=u_i·X`, `φ=SiLU`, means `m_i=E U_i`, covariances `c_{ij}=Cov(U_i,U_j)`, and `a_{ij}=Cov(U_i,G_j)`. Let `⟨p_i,q_j⟩=E[p(G_i)q(G_j)]` under the bivariate Gaussian gate marginal. Gaussian integration by parts twice gives **raw** feature moments:

```
E[f_i f_j] = (m_i*m_j+c_ij) ⟨φ_i,φ_j⟩
 + m_i [a_ji ⟨φ'_i,φ_j⟩ + a_jj ⟨φ_i,φ'_j⟩]
 + m_j [a_ii ⟨φ'_i,φ_j⟩ + a_ij ⟨φ_i,φ'_j⟩]
 + a_ii*a_ji ⟨φ''_i,φ_j⟩
 + (a_ii*a_jj+a_ij*a_ji) ⟨φ'_i,φ'_j⟩
 + a_ij*a_jj ⟨φ_i,φ''_j⟩.
```

The one-point mean is `E f_i = m_i Eφ(G_i) + a_ii Eφ'(G_i)`. Subtract its outer product for the centered kernel `K`. For each gate `G_i=μ_i+σ_i Z`, let `c_n(p_i)=E[p(μ_i+σ_i Z) He_n(Z)/√n!]`. The bivariate Gaussian identity gives `⟨p_i,q_j⟩=∑_{n≥0} c_n(p_i)c_n(q_j)ρ_ij^n`, `ρ_ij=Cov(G_i,G_j)/(σ_iσ_j)`. **Every coefficient is a one-dimensional Gaussian integral**, including derivatives `φ'=s+z s(1-s)` and `φ''=s(1-s)(2+z(1-2s))`, `s=sigmoid(z)`. For exact coefficients, Cauchy–Schwarz bounds a truncated pair-series tail by `√(tail_L(p_i) tail_L(q_j))` for `|ρ|≤1`; the program's quadrature-based tails are diagnostics, not interval-certified numerical bounds.

For selected bank `B`, the population-optimal affine readout under this law is `R=(K_BB+λI)^−1 K_B,all Dᵀ`, with bias `D E[f] − (E[f_B])ᵀ R`; `λ=0.01 trace(K_BB)/|B|` is fixed in source, not tuned on validation. Crucially `K_B,all Dᵀ` is only `|B|×1,024`, so no `3,072²` feature Gram or 1,024-output response fit is necessary. [`FunctionKernel.lean`](FunctionKernel.lean) proves the finite-state/discrete-law cross-kernel contraction for any linear readout. It does **not** prove Gaussian integration by parts, quadrature accuracy or emitted ISA execution. The derivation above uses standard Gaussian Stein integration and smooth finite-moment functions; [`validate_formula.py`](validate_formula.py) independently conditions both up variables on their two gates and integrates in two dimensions for 21 off-diagonal pairs.

The implementation computes the training preactivations once, obtains the four selected-vs-all covariance blocks by matrix multiplication, and processes 256 target channels per bounded call. Work is `O(N*input*hidden + N*|B|*hidden + L*|B|*hidden + |B|²*outputs)` with blockwise `O(|B|*256)` additional workspace, rather than an `O(L*hidden²)` pair kernel. `N=1024`, `L=16`, `|B|=128` here. Precomputation and bank fitting are offline; the *online* candidate still has two 1,024-input projections per feature, SiLU/up, and one dense 1,024-output readout. Its charged model fields would be 128 original BF16 gate/up row pairs, 128×1,024 FP16 readout, FP16 bias, uint16 feature IDs and a 7-byte header, **788,743 bytes**; no fitted image is exported after the loss result. Compiled reader bytes, input preparation, GPU cache effects and native time are unmeasured. The independently exported scalar Q4 gate/up/down control costs **4,866,096 bytes**; it is the same baseline as the preceding study.

## The producer-law obstruction is measured, not quadrature error

At Hermite order 16 and 64-point one-dimensional Gauss–Hermite quadrature, raising to order 24 and 96 points changes the 128×256 kernel block by **5.15×10⁻⁸ relative Frobenius**. The independent conditional two-dimensional quadrature differs from order-24 Hermite moments by **9.46×10⁻¹³ relative RMS** across 21 nonidentical pairs. These are numerical agreement checks, not a formal floating-point certificate. The single Gaussian law nevertheless misses the *observed* 128×256 raw Gram by .81421 on train and .81464 on validation, and the centered Gram by .86641/.85876. Across all twelve 256-channel blocks, the centered relative errors range .83396–.93803 on train and .84037–.95399 on validation; individual block receipts are saved as `witness-128-*.json`.

The mismatch is explainable in concrete producer moments. For standardized gate/up forms `Z_g,Z_u`, any centered joint Gaussian has `E[Z_g² Z_u]=0`. The 3,072 actual source channels instead have third-moment RMS **.19215 train / .19342 validation**; the per-channel train/validation third moments correlate **.85053**, with matching sign for 73.5%. Median absolute gate skew is .26948/.24985 and median gate excess kurtosis .20837/.18578. These values come from the actual source linear forms on the full captured inputs, not a random synthetic teacher. Finite sample fluctuations are present, but the high train/validation correlation shows a persistent direction of non-Gaussianity. [`producer-law.json`](producer-law.json) records the fuller moments and standard-error diagnostics. The missing structure is a tractable **joint gate/up producer law beyond mean and covariance**; merely taking more Hermite terms under the same Gaussian cannot supply these cumulants.

[`readout.py`](readout.py) forms the Gaussian-law K=128 bank's complete 1,024-output readout without response fitting, rounds its coefficients and bias to FP16, then evaluates all train and separate validation targets. The analytic predicted feature/output cross covariance differs by .88916/.90745 from actual train/validation. The actual full-response RMS is **.84959 train / .87072 validation**; scalar Q4's validation RMS is **.16253**. Even a free FP64 readout chosen *after seeing the validation targets* for these same selected K=128 features has a .67413 validation floor (preceding screen), so a repaired law alone cannot make this particular small bank beat Q4. At K=784 that floor crosses Q4, but paying for a 12× larger Gaussian kernel under a law already contradicted by this direct comparison would not produce useful evidence. This rejects one explicit Gaussian producer-law bank, not function-space quantization or non-Gaussian source-derived kernels in general.

## Reproduce

Run the preceding bank study's `prepare.py --split train/held --chunk 0..3` first to make the ignored full-state caches. Then, with one BLAS thread and CPU only, from this directory:

```sh
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" preactivation.py --split train
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" preactivation.py --split held
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" producer_law.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" validate_formula.py
for block in $(seq 0 11); do
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" kernel.py --rank 128 --block "$block"
done
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" readout.py
lake env lean FunctionKernel.lean
```

Each computation is individually under one minute. `.npz` and `.npy` caches are excluded from Git; compact readout, producer-law, formula and per-block receipts are committed. Source/capture/image hashes are in the linked preceding bank's [`results.json`](../nonlinear-response-bank/results.json). This is numerical BF16-source/FP32-response evidence on real states and a formal **finite algebraic** contraction lemma, not a proof of numerical Gaussian integration, unseen-model behavior or a native speed claim.
