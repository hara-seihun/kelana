# Weighted pairs: an exact ceiling on the entire diagonal certificate class

The preceding [input-program certificate](../input-programs/README.md) proves that **every** program merging 32 disjoint input-coordinate pairs as `x_i ± x_j`, passing through the other 64 coordinates, and applying *any real linear 128-output readout* loses to an exported scalar Q4 image on one real Qwen3-0.6B layer-0 `q_proj` 128×128 subprojection. This study changes the executable input map, not the number of carriers: each pair may instead emit `x_i + t_ij*x_j`. Its coefficient ratio may be a model-specific FP16 or a small immediate alphabet. The complete 128 outputs and the same 2,048 train / 1,024 held actual producer states remain the observation boundary. This is still a subprojection, not the complete attention or language-model consumer.

**Current accuracy-target decision:** the [full-covariance certificate](../full-pair-covariance/README.md) proves all 32-disjoint freely weighted pairs with arbitrary real output readout have train error at least .005753003543343237, above Q4 .005173614377259471. This excludes matching that Q4 accuracy, not the 6,848-byte pair family from a comparable-size frontier against an 8,704-byte Q4 point. The diagonal-class ceiling proved here remains valid and explains why that different covariance machinery was necessary.

## Geometry of a weighted pair

Let `H=XᵀX`, `W` have output columns `w_i`, and `H ⪰ diag(d)` for positive `d`. A pair with ratio `t` supplies one carrier, so a free readout vector `a` gives columns `(a,t a)`. Its diagonal-metric discrepancy is

```
min_a [d_i ||w_i-a||²+d_j ||w_j-t a||²]
 = d_i||w_i||²+d_j||w_j||²
   - ||d_i w_i+t d_j w_j||²/(d_i+t² d_j).
```

[`WeightedPairIdentity.lean`](WeightedPairIdentity.lean) proves the cleared-denominator scalar completion-of-square identity; output coordinates add. If `t` can be any real number, the minimum is the **smaller eigenvalue** of the weighted 2×2 Gram

```
[[d_i ||w_i||², sqrt(d_i d_j) <w_i,w_j>],
 [sqrt(d_i d_j) <w_i,w_j>, d_j ||w_j||²]].
```

Equivalently, that pair costs at least `τ` iff both weighted squared norms are ≥`τ` and their shifted product is at least `d_i*d_j*<w_i,w_j>²`. This is a two-dimensional PSD/cone condition, avoiding eigenvalue square roots in a certificate. Pair costs add for disjoint pairs under the diagonal minorant. A fractional 32-edge matching dual then lowers **every** choice of 32 pairs and ratios. This is the same response-space relaxation that decided the signed family, now with a genuinely larger map grammar.

## Real-model screen and paid work

[`study.py`](study.py) starts from the predecessor's **exactly certified dyadic diagonal minorant**. Its free-ratio 32-edge matching relaxation is .0049289, below the **exact exported scalar Q4 control's .005173614**. After a bounded, numerically proposed diagonal-ray improvement, the relaxation reaches .00505138, still below Q4. That improved floating diagonal is **not a numerical certificate** and must not be used as a universal theorem. Its role is to test whether this low-dimensional PSD-minorant route obviously resolves the larger family. The best of two finite ratio alphabets is still under the threshold:

| 96-carrier family, 32 disjoint pairs | Numerical diagonal/matching floor | Fitted complete-response program |
| --- | ---: | ---: |
| Previous signed `t∈{-1,+1}` | **.005176814 exact certified** with previous diagonal | selected signed pairing .014038 train, .017577 held |
| `t∈{-2,-1,+1,+2}` | .00511695 after bounded diagonal improvement | not fitted |
| `t∈{-2,-1,-.5,+.5,+1,+2}` | .00509523 after bounded improvement | not fitted |
| Free real `t` | .00505138 after bounded improvement | selected free-ratio pairing **.014856 train, .018477 held** |
| Exported direct scalar Q4 | — | **.005174 train, .005174 held** |

The free-ratio heuristic takes the 32 lowest-cost disjoint edges for the chosen diagonal and chooses each pair's locally optimal weighted-Gram principal direction. It then fits an **arbitrary real complete 128-output readout** on train and scores held. It loses to Q4 even before output packing; no replacement image is claimed. This is not a global optimum over pairings or coupled response fitting. On the chosen diagonal, 8,126 of 8,128 individual edges have strictly lower free-ratio cost than their best signed variant; the signed obstruction cannot be transferred by relabeling the coefficients.

A hypothetical direct reader with FP16 `t` per pair would pay 64 ratio bytes, 128 bytes for explicit indices of all pair/singleton sources, 6,144 signed four-bit output-code bytes and 512 FP16 output scale/origin bytes: **6,848 static bytes** (versus scalar Q4's 8,704). A fixed six-value ratio alphabet instead needs 3 bits per pair (12 packed bytes) plus fixed shared alphabet code, and simple `±1,±2,±1/2` operations; `±1/2` still requires scaling and does not automatically preserve exact integer producer codes. The free-ratio FP16 path needs 32 extra input multiplications plus 32 additions, then 12,288 output coefficient products versus direct Q4's 16,384. Byte counts exclude common code, layout, padding and native scheduling; there is **no packed weighted-pair export, nor a native-work speedup**. If a future fit survives, all of these fields must be serialized and the actual program measured.

## Exact lower certificate and a matching exact *upper* certificate

[`weighted-dual.npz`](weighted-dual.npz) stores 128 dyadic nonpositive vertex prices and one cardinality price for the *original* exactly certified diagonal. [`verify_weighted.py`](verify_weighted.py) checks that original signed PSD factor with exact integers, reconstructs exact dyadic `W` and `H`, and checks every free-ratio edge inequality as a **rational 2×2 PSD cone** without floating eigenvalues, optimizing or trusting LP status. It also checks the fixture, source certificate and exported Q4 hashes against the predecessor receipt. The resulting certified universal lower bound is **.004925653567585009**; the exported Q4 exact response is **.005173614377259471**. This diagonal certificate alone leaves **.000247960809674462** of relative squared error below Q4; the selected real-readout witness at .014856 does not close that gap. The subsequent full-covariance certificate excludes this Q4-accuracy interval for the entire family. It does not settle the family's frontier at its lower effective size. The numeric .00505138 improvement is not substituted for the exact .00492565 floor.

### What the best diagonal certificate can ever establish

A follow-up asks whether optimizing the diagonal minorant and matching dual *jointly* could push the free-ratio floor past Q4. Define the certificate value

```
C* = sup_{d≥0, H⪰diag(d)} min_{fractional 32-edge matchings q}
       Σ_edges q_e λmin(diag(sqrt(d_i),sqrt(d_j)) G_ij
                      diag(sqrt(d_i),sqrt(d_j))) / ||XWᵀ||².
```

The expression is a concave maximization in `d`: each edge cost is an infimum of quantities linear in `d`; the minimum over matchings remains concave. Numerically, [`outer_bound.py`](outer_bound.py) separates violated PSD directions and pair tangents in an outer LP. A finite outer LP objective of about .005142 is *not* treated as proof. Instead, [`build_outer_certificate.py`](build_outer_certificate.py) rounds **144 fractional matching edge weights** to exact dyadics summing to 32, retains **10** PSD direction multipliers, and adds conservative identity diagonal bounds. For each active edge, a saved dyadic ratio and dyadic diagonal anchor determine a valid linear *upper* tangent to its free-ratio concave cost, by fixing that ratio and its optimal readout at the anchor. All of these inequalities are checked algebraically and arithmetically by independent [`verify_outer.py`](verify_outer.py), with the source/target matrices reconstructed as exact dyadics. Its final integer/rational comparison is

| Exact statement on captured producer panel | Value |
| --- | ---: |
| Existing feasible diagonal + matching dual: `C* ≥` | **.004925653567585009** |
| New finite outer certificate: `C* ≤` | **.005142118673001042** |
| Exported scalar Q4 response error | **.005173614377259471** |

The entire diagonal-minorant/fractional-matching method is therefore **provably too weak** to reject free weighted pairs against this Q4 control: even its best possible floor is at least .0000314957 *below* the threshold. Its maximum remains within a .0002164651 interval. This is an upper bound on a **certificate class**, not a feasible weighted-pair image and not a lower bound on any actual input program's performance. A multi-coordinate PSD minorant with a shared output-vector dual now excludes reaching the Q4 accuracy target in [full-pair-covariance](../full-pair-covariance/README.md). A no-larger strong quantization control is still required to reject the family from a comparable-size frontier. The exact signed-pair rejection remains valid, since signed ratios form a strict subfamily.

The upper proof is short: any feasible fractional matching `q` gives `min_match Σ cost_e(d) ≤ Σ q_e cost_e(d)`. For every saved edge, `cost_e(d)` is ≤ the fixed-ratio quadratic cost and hence ≤ its tangent `α_ei d_i+α_ej d_j` at the saved positive anchor. The dyadic `q` has cardinality 32 and vertex degrees ≤1. The weighted tangent sum is coordinatewise bounded by nonnegative combinations of saved PSD-direction inequalities `vᵀdiag(d)v ≤ vᵀHv` and identity bounds `d_i≤H_ii`. Their constant right side is **.005142118673001042**, below exact Q4. The checker verifies all signs, degree constraints, rational gradients, coordinatewise domination, exact Gram, and final strict inequality without using the outer optimizer or trusting solver status. The pair-completion identity is Lean checked; convexity, tangent validity and the generic PSD argument are stated here as mathematical derivations rather than claiming Lean proof of every step.

This study neither certifies an unseen-language producer domain nor evaluates the rest of attention. The cone/matching floor and the new certificate-class ceiling are exact integer/rational replays for this captured panel, not native ISA timing. The ratio/floating optimization is separate evidence.

## Reproduce and provenance

The input fixture stays with `/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz` (SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`). The predecessor-owned [`diagonal-certificate.npz`](../input-programs/diagonal-certificate.npz) has SHA256 `ad0316685162659df6bddb908d6c471054ff9c4cf3b258d830bc81ad77069c93`; its exact verifier and receipt remain in that owner. The [`scalar image`](../producer-screen/affine-q4.bin) stays with producer screen. No large fixture or predecessor certificate is copied into this directory.

From Kelana root after the predecessor commits are integrated, CPU only and one BLAS thread:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/weighted-input-pairs/study.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/weighted-input-pairs/verify_weighted.py
lake env lean research/isa-quantization/weighted-input-pairs/WeightedPairIdentity.lean
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/weighted-input-pairs/verify_outer.py
```

The optimizer may propose different numerically equivalent diagonals on another BLAS; the saved dyadic dual's verifier is independent of that proposal. `study.py` accepts `--certificate PATH` for running before canonical predecessor integration; normal operation uses the sibling owner path. The compact [`results.json`](results.json) records selected ratios and numeric comparisons; [`verified-weighted.json`](verified-weighted.json) records the exact lower receipt. To regenerate the **upper** witness rather than merely replay it, run `outer_bound.py` then `build_outer_certificate.py`; each finishes in seconds, and the latter accepts `--gram-source PATH` before predecessor integration. [`outer-certificate.npz`](outer-certificate.npz) is the saved proposal-independent witness; [`verified-outer.json`](verified-outer.json) records its exact verification. Only the predecessor-owned model/activation/image assets remain outside this scope.
