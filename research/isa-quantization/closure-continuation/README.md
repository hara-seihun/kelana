# The closed algebra is a quotient, not a polynomial degree

A low-degree Walsh expansion can approximate a complete binary response while its next nonlinear consumer immediately leaves the expansion. There is an exact alternative: choose a **small algebra of functions on the producer domain** jointly for the branches and their continuation. This does not require preserving any source gate. For binary inputs and cheap XOR translations, every translation-invariant pointwise algebra is precisely a linear-quotient Walsh algebra. Its approximation error is discarded Fourier energy; its additional error on a bilinear continuation is exactly a *conditional covariance*. This is a structural characterization and an executable finite example, not a claim about trained-model prevalence or native latency.

## Characterization and obstruction

Let `X=F₂ⁿ`, `χ_u(x)=(-1)^(u·x)` and let `A⊆R^X` be a real linear space containing constants. Assume `A` is closed under pointwise multiplication and under every translation `T_a f(x)=f(x+a)`. Then **there is a unique linear subspace `U≤F₂ⁿ` such that**

```
A = span{χ_u : u∈U} = {f : f(x+h)=f(x) for all h∈U⊥}.
```

Proof: the character projector `2⁻ⁿ Σ_a χ_u(a) T_a` sends any `f∈A` to `f̂(u)χ_u∈A`. Thus `A` is spanned by a subset of characters. It contains `χ_0`; pointwise multiplication `χ_u χ_v=χ_(u+v)` makes that subset a subgroup, hence a linear subspace. Conversely, a subgroup spans a translation- and multiplication-closed space. The second equality is Fourier orthogonality. `Kelana/ClosureContinuation.lean` checks general factor-through-code closure under sums, products, arbitrary pointwise nonlinearities and commuting state updates, and proves the fiber-disagreement obstruction. It also **formally proves the conditional-covariance identity and signed product-error decomposition** for any rational-valued conditional projection satisfying explicitly stated additivity, idempotence and left/right module laws. A concrete uniform two-point-fiber mean is proved to satisfy every law, and a pair of centered sign branches has formally checked nonzero covariance of one. This is an actual nontrivial instance, not merely assumed projection axioms. Orthogonality and the *squared-norm* decomposition, as well as the Fourier classification and arbitrary finite-fiber projection construction, remain paper proofs and exact-integer finite checks. The Lean theorem makes the exact composition obstruction explicit without pretending that all its analytic consequences have been formalized. If `rank(U)=r`, a basis `u_1,…,u_r` encodes the full live state needed by this algebra as `z=(u_1·x,…,u_r·x)`; every member is an `2^r`-entry function of `z`. XOR-changing the input by `a` changes the code only by `z↦z xor (u_1·a,…,u_r·a)`. Any pointwise SiLU, gate product, or other function of values in the algebra stays in it, although its Walsh *degree in the original coordinates* can be `n`.

In particular, a universal multiplication-closed algebra containing all `n` coordinate characters must contain all `2^n` characters. The 42-dimensional degree-≤3 space on six bits is not closed: `χ_012 χ_345=χ_012345`. No choice of coefficients repairs this general closure failure. A quotient is not asserted to preserve a teacher that distinguishes its fibers: it deliberately discards those distinctions. The characterization assumes **all** input XOR translations preserve the space; less symmetric hardware grammars can admit other algebras. An arbitrary 8-state partition also yields an 8-dimensional algebra but need not have a cheap XOR-compatible encoder or update.

For uniform inputs, let `P_U` be averaging on cosets of `U⊥`, equivalently retaining precisely Fourier coefficients in `U`. Orthogonality gives the exact one-map minimum

```
min_(a∈A) E[(f-a)²] = Σ_(u∉U) f̂(u)².
```

For multiple observed outputs, sum their *appropriately weighted* discarded energies and choose `U` jointly, not from one gate or one branch. This optimizes independent tables in the shared algebra. It is an optimistic lower bound for a constrained continuation that must compute its output from the branch tables.

## The continuation invariant

For two scalar branches `f,g` with a product consumer, write `f_0=P_U f`, `g_0=P_U g`, `r=f-f_0`, `s=g-g_0`. Because multiplying an `A` function by a residual leaves the residual orthogonal to `A`, the exact identities are

```
P_U(fg) - f_0 g_0 = P_U(rs) = Cov(f,g | z),
||fg - f_0 g_0||₂² = ||(I-P_U)(fg)||₂² + ||Cov(f,g | z)||₂².
```

Here `||·||₂²` means the uniform mean square, and `Cov(f,g | z)` is the within-code-fiber covariance. The **extra price of carrying fitted branches into the product rather than fitting an independent product table is exactly squared conditional covariance**. This is the right obstruction for a multiplication continuation, not the amount by which individual source gates fail to close. For `f=f_0+εr`, `g=g_0+εs` with fiber-centered residuals, that extra squared error is order `ε⁴`, whereas branch squared errors are order `ε²`. The identities also identify zero-cost cases beyond exact gates: residuals may be nonzero yet have zero conditional covariance. Hölder gives `||Cov(f,g|z)||₂≤||r||₄||s||₄` when a numerical bound rather than an exact truth table is needed. More general nonlinearities remain in `A` when applied to represented branches, but their mismatch to the unmodified teacher needs their own conditional moment/Jensen analysis; the covariance identity is specifically bilinear.

## Exact small experiment and controls

`check.py` uses all 64 binary inputs and exact integer Walsh coefficients. It exhausts the **1,395** rank-three subspaces, choosing both the best independent three-table algebra and the best *composed* two-table-plus-product algebra. `f,g` are independently drawn coefficient arrays, `h=fg` is their exact full convolution. In three structured cases, the eight masks of a rank-three subspace have coefficient amplitude 8 and **every one** of the other 56 masks has amplitude 1, each independently signed and scaled by a seeded choice from `{1,2,3}`. This is a deliberately quotient-biased synthetic family with full-spectrum perturbations, not a trained source or a prevalence estimate. Three unstructured controls give every mask equal amplitude 8. The product is not drawn independently. All panels are complete-domain fitting/measurement, with no holdout.

The score is the sum of three relative mean-squared errors (each divided by that output's mean square); thus it may exceed 1. `direct rank 3` independently projects all three observed maps to the chosen quotient (three tables). `composed rank 3` projects the first two maps and multiplies their carried responses (two tables). The *optimistic* best-eight-character control selects any eight unrelated Walsh characters and independently projects all three outputs; unlike a subspace, it has no guaranteed product closure. The degree-≤3 control independently projects all three outputs into 42 characters. Each control gets its own best fitting coefficients, not snapped gate weights.

| Family, seeds | Best direct rank 3 (8 terms/output) | Best composed rank 3 (8 terms/branch) | Best unconstrained 8 characters (optimistic) | Degree ≤3 (42 terms/output) |
| --- | ---: | ---: | ---: | ---: |
| Quotient-biased, 5/17/29 | .230/.328/.320 | .230/.329/.321 | .230/.328/.320 | 1.611/1.274/1.872 |
| Unstructured, 5/17/29 | 2.456/2.365/2.303 | 2.544/2.533/2.454 | 2.219/2.210/2.177 | .881/.903/1.185 |

All structured searches recover the same eight-character algebra `{0,10,23,29,33,43,54,60}`; five nonzero masks have degree four and the other two degree two. The conditional-covariance penalty in the composed score is only `.00033/.00135/.00079` (normalized product squared error), checked against the identity with **exact integer arithmetic**. With unstructured maps, this penalty and the quotient's discarded energy are large; moreover the continuation changes the optimal quotient from independent three-table fitting in all three cases and from branch-only fitting in two of three cases. The controls reject a generic advantage. The quotient wins here because the producer really supplies approximately three encoded parities; the degree control loses despite having over five times as many terms.

An ideal FP64 table reader for the two branches stores 16 doubles = 128 model-specific bytes, plus three 6-bit parity masks (3 packed bytes); an independently fitted third response table adds 64 bytes. The degree-≤3 three-output table stores 126 doubles = 1,008 bytes; an exact unrestricted three-output table stores 192 doubles = 1,536 bytes. All three target outputs are observed; the composed arm does two eight-entry reads and a multiplication to produce the third. Character coefficients are converted to truth-table entries **offline**, not evaluated as eight runtime parities each. The masks, alignment, runtime parity extraction, indexing, producer preparation, arithmetic precision, and any downstream numeric conversion must be priced on a specific ISA; these byte counts alone do not rank latency or establish BPW for a model. The independent-eight control has equal nominal *coefficient* bytes (24 doubles), but generally needs up to eight independent parity features rather than a three-bit address; its unrelated characters are not an algebra across nonlinear consumers without additional features or output repair. For unrestricted real producer states the 64-state claim does not apply.

Reproduce in under one second with standard Python:

```sh
python3 research/isa-quantization/closure-continuation/check.py
```

The script rewrites `results.json`, checks the conditional-covariance/Pythagorean equalities exactly, and reports every selected mask and score. This extends [nonlinear closure](../nonlinear-closure/README.md) by characterizing *which response families survive nonlinear continuation*, and complements [encoded continuations](../encoded-continuations/README.md) by making the shared labeling an executable XOR quotient with an explicit approximation invariant. It does not replace their stronger conventional scalar-q4 and full-table comparisons for the SwiGLU teacher: the present witnesses are function-family and algebra tests, not a quantized real-network export.
