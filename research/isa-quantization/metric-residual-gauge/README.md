# A signed-gain residual gauge with a transported norm metric

**Answer.** The exact no-slice theorem for a tied Qwen residual gauge depends on keeping the RMSNorm metric Euclidean (or diagonal), not merely on the tied final gain. For a general invertible residual coordinate, a *single common transported metric* preserves every RMSNorm, all literal skips, every consumer and the tied head. It can make the final gain diagonal while aligning at least **893 of the first Q head's 1,024 input columns to zero** in ideal real arithmetic. The price is a generally dense common norm metric applied at **57 residual RMSNorm sites per token**, transformed embedding and all affected weights. This is an algebraic possibility, **not** a smaller or faster deployed Qwen image. Even a structured 128-reflection metric reader's unquantized description alone exceeds the hypothetical one-head slice saving.

This study extends [tied residual-gauge custody](../residual-gauge-custody/README.md). It does not overturn that study's *Euclidean/diagonal-norm, diagonal-final-gain, zero-boundary-cost* obstruction. The geometry is ordinary congruence and signed-form inertia, not a new theorem about neural networks.

## Whole-map custody, including the sign of final gain

Let `z=T x` for one invertible `T` shared by all residual boundaries, and `U=T⁻¹`. Define the **common** positive-definite metric `M=UᵀU`. Every residual RMSNorm becomes

```
N_M(z) = z / sqrt(zᵀ M z / d + ε) = T N(x).
```

This works with positive epsilon, with no Gaussian or producer-distribution assumption. In an attention branch with source incoming `W_Q Γ_att N(x)`, store `W'_Q=W_Q Γ_att U` (and likewise K,V); its output projection becomes `T W_O`. The MLP gate/up and down maps transform analogously. Q/K internal normalization, RoPE, GQA, softmax and nonlinear channels can stay in their original internal coordinates. A transformed branch returns `T branch(x)`, so `T(x+branch(x))=z+transformed_branch(z)`: the skip remains literal. Biases in residual outputs also transform by `T`. The final norm uses the **same M**. Distinct `T_l` across layers would reintroduce `T_{l+1}U_l` at the skip and are not a free global gauge.

The tied embedding/head cannot be ignored. If E is the original vocabulary-by-d image, its transformed **single** image must be `E'=E Tᵀ=E U⁻ᵀ`. For exact all-state logits with the same tied E' and new final matrix gain D,

```
E' D N_M(z) = E Tᵀ D T N(x) = E Γ_f N(x)
                  iff D = Uᵀ Γ_f U
```

when E has full column rank (proved for the pinned checkpoint in the predecessor). The last equation is congruence, not orthogonal similarity. For softmax-only equivalence, the predecessor's augmented-ones rank excludes an uncharged common-logit shift. Setting `D` diagonal is permitted, but an indefinite original Γ cannot become the all-positive identity: congruence preserves inertia. In particular Qwen's actual final gain has **1,021 positive, three negative and zero zero entries**. [`source_gain.py`](source_gain.py) checks the pinned safetensors SHA256 and those counts (min `−0.1142578125`, max `15.3125`).

If both the transported metric `M=UᵀU` and new gain `D=UᵀΓ_fU` must be **diagonal**, normalize the orthogonal columns of U: `U=Q diag(s)` with Q orthogonal and all `s_i>0`. Diagonal scaling does not erase an off-diagonal, so `QᵀΓ_fQ` must also be diagonal. This is exactly the earlier equal-gain eigenspace custody, up to scaling and permutation. In two dimensions the proof is explicit: for inverse columns `(a,b)` and `(c,d)`, the two off-diagonal equations are `ac+bd=0` and `g₁ac+g₂bd=0`. When `g₁≠g₂`, invertibility forces either an axis scaling or swap. [`Kelana/MetricResidualGauge.lean`](../../../Kelana/MetricResidualGauge.lean) proves this without assuming the conclusion. Thus **diagonal metric + diagonal tied gain buys no new mixing**.

## A constructive signed diagonal-gain slice, with its metric bill

All 1,024 final gains are nonzero. Let `J=diag(sign Γ_f)` and `S=diag(sqrt(|Γ_f|))`. Choose `Q=diag(Q₊,I₃)` orthogonal on the 1,021-dimensional positive-gain subspace, identity on the three negative coordinates. Define

```
U=S⁻¹ Q,    T=Qᵀ S,
D=Uᵀ Γ_f U=J,    M=UᵀU=Qᵀ |Γ_f|⁻¹ Q.
```

The first Q head's gamma-folded incoming matrix has at most 128 rows. Restricted to the 1,021 positive coordinates, `A₊ S₊⁻¹` has rank at most 128, hence kernel dimension **at least 893**. Choose the last 893 columns of Q₊ as an orthonormal basis in that kernel, extending to an orthogonal Q₊. Their transformed incoming columns vanish identically; at most **131** columns remain across positive and negative coordinates. This is an exact real linear-algebra construction, not a claim that the selected Q improves quantized error. It needs no assumption about rank in the three negative coordinates. Orthogonal changes *within the positive sign sector* keep `D=J` despite the old positive gains having many unequal magnitudes, because whitening moved their magnitudes into M. A more general indefinite congruence can also use hyperbolic mixing; it is not required for the 893-column construction.

The Lean file proves general finite rational identities `zᵀUᵀUz=||Uz||²` and `zᵀUᵀΓUz=Σ_i γ_i(Uz)_i²`, including negative γ, and exact norm/gain recovery when `Uz=x`. Its mixed-sign rational witness takes

```
Γ=diag(1,−1),  U=[[5/3,4/3],[4/3,5/3]], det U=1,
Uᵀ Γ U=Γ,   Uᵀ U=[[41/9,40/9],[40/9,41/9]].
```

The folded row `(5/3,−4/3)` becomes `(1,0)` after U. This checks directly that an unchanged diagonal **signed** final gain can coexist with a newly sparse incoming row only by paying the off-diagonal metric (or other changed boundary). The existence of real Q₊, the square roots in S, full-model transport and spectral/inertia facts are mathematical derivations, not Lean theorems. This example does not depend on a fitted model.

## Accounting before any image claim

The previous first-head fixed-group-128 Q4 hypothetical 893-column slice would remove at most `128×893/2=57,152` nibble bytes plus metadata depending on how the noncontiguous slice is packed; the predecessor's contiguous 896-column/128-coordinate scenario gave **60,928 bytes** total. Neither is an achieved image. A generic dense FP16 symmetric positive-sector metric has `1021×1022/2+3=521,734` unique entries, **1,043,468 bytes** if stored as FP16, with approximate arithmetic and no exact-real claim. A dense evaluation takes roughly `1021²+3=1,042,444` coefficient products at *each* of the 57 residual norm calls, or about **59,419,308** per token before other work. A shared description saves repeated storage, not repeated execution.

There is a more structured executable option: QR/Householder alignment of an at-most-128-dimensional row space can describe Q₊ with at most 128 reflection vectors. Storing full 1,021-wide vectors plus one factor per reflection at FP16 costs at most `2×128×(1021+1)=261,632` bytes; triangular active tails reduce that to `2×(Σ_{k=0}^{127}(1021−k)+128)=245,376` bytes. Applying each reflection to calculate `Qz`, followed by a diagonal `|Γ|⁻¹` weighted norm, still takes two passes per active tail, about `2×122,560+128=245,248` coefficient products per norm, **13,979,136** over 57 calls. These are format/work estimates, not tested ISA programs or certified FP16 reconstructions. Already the narrower structured metric description is larger than the predecessor's entire hypothetical **60,928-byte** one-head saving. Applying a single Q may save more across many live consumers; that requires a joint row-space construction, a full transformed image, metric-native implementation and matched total-byte/quality comparison. The transformed tied embedding (151,936×1,024), all incoming/outgoing layer weights and their new quantization error remain in custody, not zero-cost notation.

Run bounded checks from Kelana root:

```sh
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/metric-residual-gauge/source_gain.py
lake build Kelana.CovarianceCompletion
lake env lean Kelana/MetricResidualGauge.lean
```

The source counts are facts about the pinned BF16 tensor, not a generic all-model statement. No fitting, GPU test or measured throughput is asserted.
