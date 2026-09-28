# Full-covariance Q4-accuracy limit for freely weighted 32-pair programs

**Result.** On the captured Qwen3-0.6B layer-0 `q_proj` 128-input × 128-output subprojection, no input map made of **32 disjoint freely weighted coordinate pairs** and 64 pass-through coordinates, followed by an arbitrary real linear output readout, reaches the exported scalar Q4 image's train response error. An independently replayed exact integer certificate gives a universal relative squared error floor **0.005753003543343237**, versus scalar Q4 **0.005173614377259471**, a strict margin **0.0005793891660837662**. All 2,048 actual train producer states and all 128 selected outputs enter the certificate. The unrestricted-real family contains the byte-limited four-bit-readout family, so the same Q4-accuracy limit applies to it without fitting or output quantization.

**This is not a comparable-size frontier rejection.** The estimated weighted-pair payload is 6,848 bytes versus the actual Q4 image's 8,704 bytes. Higher error at lower size is expected and may be useful. The theorem excludes matching that Q4 accuracy, not competing with state-of-the-art quantization near 6,848 bytes. The [matched-rate study](../matched-rate-frontier/README.md) now supplies a 6,848-byte local GPTQ-style control, but its train error .005975855 remains above this universal .005753004 floor. Thus this certificate does not exclude the family at that size. A strong structured-method comparison is still underway. See the [evaluation contract](../BRIEF.md#comparable-size-state-of-the-art-is-the-target).

The predecessor [weighted-input-pairs](../weighted-input-pairs/README.md) proves an exact **0.005142118673001042 upper bound on every diagonal-minorant/matching certificate**. Its ceiling is not an upper bound on the true weighted-pair error. [Pair covariance](../pair-covariance/README.md) explains why a shared producer soft mode cannot be spent separately on every pair; a single rank-one/output-split screen did not settle the real panel. Here a 48-dimensional *shared* covariance dual crosses Q4 with substantial independently checked slack.

The [all-cardinality rate interpretation](RATE.md) reuses the same accepted witness for every number of disjoint pairs. It gives one exact affine error lower-bound function and connects it to an explicitly framed reader's byte formula, without a larger search. It also explains why free-real readout relaxation loses the very bit-width constraint needed for a joint quantization frontier.

## Universal theorem and the shared dual

Let `H=XᵀX` be the actual full 128×128 train Gram, `W` the exact captured teacher weights (128 outputs × 128 inputs), and `N=tr(WHWᵀ)>0`. For a particular legal input map and unrestricted real readout `A`, write `E=W-A`. A pair `(i,j)` forces `(A_i,A_j)=(a,t a)` for an arbitrary output vector `a` and arbitrary real ratio `t`; unmatched columns of `A` are unrestricted. The certificate gives strictly positive diagonal `D=diag(d)`, a 128×48 matrix `V`, and positive mode weights `β` with

```
                     H ⪰ D + V diag(β) Vᵀ.
```

For one **common** 128-output-vector dual `m_k` per covariance mode, put `P=M Vᵀ` (thus `p_i=Σ_k V_ik m_k`). Completing the mode squares *once for the whole map*, then completing each diagonal-coordinate square, gives for every `A`:

```
tr(E H Eᵀ) ≥ Σ_i d_i ||E_i||² + 2 Σ_i <p_i,E_i> − Σ_k ||m_k||²/β_k
           = Σ_i d_i ||(w_i+p_i/d_i)-A_i||² − Σ_i ||p_i||²/d_i − Σ_k ||m_k||²/β_k.
```

In particular the first penalty includes **unmatched** coordinates; omitting it would invalidate the result. Define the shifted columns `z_i=w_i+p_i/d_i`. For a pair, minimizing its two squares over *all collinear output-column pairs*, including the limit with first column zero, gives the smaller eigenvalue `c_ij` of

```
[ d_i ||z_i||²                  sqrt(d_i d_j) <z_i,z_j> ]
[ sqrt(d_i d_j) <z_i,z_j>       d_j ||z_j||²           ].
```

All finite weighted ratios and all real readouts are contained in that minimization. Unmatched coordinates contribute zero before the global penalties. For the 32 disjoint pairs, a fractional cardinality-32 matching LP (nonnegative edge multiplicities, vertex degrees at most one) relaxes the integer matching. The saved nonpositive vertex prices `u_i` and cardinality price `c` satisfy **every** edge inequality `u_i+u_j+c ≤ c_ij/N`. Hence every legal map has relative squared error at least

```
Σ_i u_i + 32c − [Σ_i ||p_i||²/d_i + Σ_k ||m_k||²/β_k]/N.
```

The independently checked value of this expression is **0.005753003543343237**. The pair inequality is checked without a floating eigensolver: put `q=(u_i+u_j+c)N`, `s_i=d_i w_i+p_i`; then both `||s_i||²−q d_i` and `||s_j||²−q d_j` are nonnegative, and their product is at least `<s_i,s_j>²`. These are exactly the rational 2×2 PSD conditions for `c_ij≥q`. All 8,128 edges, not merely the proposed LP support, are checked.

## Exact evidence and proposal boundaries

[`spectral_dual.py`](spectral_dual.py) is a bounded numerical *proposal*: use the predecessor's positive dyadic diagonal; choose 48 leading eigenmodes of `H−D`, reserve 10% of their eigenvalues for PSD slack, and maximize a concave covariance dual by finite preconditioned steps with a complete fractional matching LP at each step. Round the resulting vectors, multipliers, matching prices and a Cholesky factor to dyadic integers. Its numerical objective after 24 steps was ~0.005758. Neither spectral decomposition, optimization, Cholesky, nor solver success is accepted as a proof.

[`verify.py`](verify.py) instead reconstructs the BF16/FP32 source inputs and weights as exact dyadics, computes the exact full Gram with overflow-guarded integer limbs, checks the saved factor leaves `H−D−V diag(β)Vᵀ−LLᵀ` strictly diagonally dominant with positive diagonal, checks every rational edge cone, sums both penalties with exact `Fraction`, decodes the existing Q4 image, and compares exact rational response errors. Its [receipt](verified.json) retains source/certificate/diagonal/image SHA256, exact rational floor/baseline/margin, minimum PSD and cone slack numerators and the strict result. The accepted arrays must have the declared integer dtypes and exact shapes; source casts and Gram limbs have explicit overflow guards. The shared-mode square inequality requires no rank assumption on V. The 112 KB [dyadic witness](spectral-certificate.npz) has no copied producer fixture or checkpoint.

[`FullCovarianceDual.lean`](FullCovarianceDual.lean) proves the two cleared-denominator square identities at the heart of the shared-mode and shifted-coordinate derivations. [`Kelana/PairCovarianceAssembly.lean`](../../../Kelana/PairCovarianceAssembly.lean) now proves general finite rational assembly: shared-mode completion, coordinate shifting, all-output Fubini, unmatched-coordinate penalties and disjoint matching/cardinality/vertex-price charging. Its final theorem derives the response floor from quadratic-minorant and pair-energy hypotheses, rather than assuming the final summed inequality. The real PSD bridge, free-ratio pair-cone implication and rational-to-real transfer remain mathematical arguments, not a fully Lean-formalized theorem. The PSD, all cones, exact numeric penalties and final strict comparison are independently integer-replayed Python evidence, not Lean theorems. The optimizer's value and eigenvectors alone carry no certificate.

Fixture: `/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz`, SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`; exported scalar Q4 image in [producer screen](../producer-screen/affine-q4.bin), SHA256 `8c4b03a9696bee7f0bd80c344f2996a4d6247651ca11f671d07e0c27a86f82c6`. The baseline diagonal source remains [input programs](../input-programs/diagonal-certificate.npz); the verifier rechecks the stronger PSD inequality itself, without trusting that source's earlier certificate.

From Kelana root, one CPU BLAS thread, each computation under a minute:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/full-pair-covariance/verify.py
lake env lean research/isa-quantization/full-pair-covariance/FullCovarianceDual.lean
# Only when regenerating the proposal:
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/full-pair-covariance/spectral_dual.py
```

This is a captured-train-panel universal **accuracy lower bound** for this specific 32-disjoint-weighted-pair, linear-readout grammar, not exclusion from a size/error/work frontier. It does not claim a bound over held histories or unseen language, overlapping or multistage sparse programs, nonlinear decoders, all attention outputs, the whole Qwen model, or native ISA timing. There is no weighted-pair candidate image.
