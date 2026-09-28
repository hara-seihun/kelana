# A residual gauge must pay its tied observation boundary

**Finding.** A shared orthogonal residual coordinate can make *several* nonlinear-block matrices sparse without an online rotation: an exact tied-embedding toy has 45→27 bytes in one declared sparse grammar. But on the pinned Qwen3-0.6B checkpoint, an exact whole-model orthogonal gauge that **keeps one tied embedding/head image and a diagonal final RMSNorm gain, with no additional output operator**, cannot make **even the first layer's first 128-row query head** omit a single residual input coordinate. The obstruction is exact rational rank, not a failed rotation fit. The final gain has 125 distinct BF16 values; for every equal-gain coordinate class, the first query head's corresponding column submatrix has full column rank. Their ranks sum to 1,024. This excludes coordinate-slice savings in that tightly specified *zero-boundary-cost gauge family*, not rotated quantization quality or a paid non-diagonal final reader.

The familiar residual rotation invariance and quantization motivation already appear in [QuaRot](https://arxiv.org/abs/2404.00456), [SpinQuant](https://arxiv.org/abs/2405.16406), Kelana's [shared signed-Hadamard image](../../ternary/shared-rotation/README.md) and [nonlinear gauge toy](../../ternary-toys/nonlinear-gauges/README.md). Our decision here is the **simultaneous row-space/last-consumer/tied-storage custody test**, not a claim to have discovered orthogonal rotation or a new real-model quantizer.

## Exact whole-map transport and the necessary endpoint

Use column residual vectors `x∈R^d`, orthogonal `Q`, and `z=Qx`. RMS normalization `N(x)=x/sqrt(||x||²/d+ε)` satisfies `N(Qx)=Q N(x)` for positive ε. In every layer, the pre-attention and pre-MLP diagonal gains `Γ_l` may be **folded into each subsequent incoming projection**: for example `W'_Q=W_Q Γ_att Qᵀ`, `W'_K=W_K Γ_att Qᵀ`, `W'_V=W_V Γ_att Qᵀ`, `W'_gate/up=W_gate/up Γ_mlp Qᵀ`; attention-output and MLP-down weights become `W'_O=Q W_O`, `W'_down=Q W_down`. These are equations for ideal real computation, not permission to omit their stored quantized coefficients or model-specific metadata. Q/K head coordinates, RoPE, per-head Q/K norms, scores, V channels and nonlinear MLP channels remain in their original internal coordinates; no separate RoPE-commutation assertion is needed. The two residual branches produce **z-coordinate outputs**, so the skip is still literal addition. Output biases, if present, must transform by Q too. A single common Q can persist across layers without a conversion around each block.

If layer boundaries instead use Q_l and Q_{l+1}, the skip is `Q_{l+1}Q_lᵀ z_l`, not `z_l`. Unless those gauges agree on all reachable residual states, a conversion or an equivalent paid linear correction must enter the next program. Exact preservation on all `R^d` with a literal skip forces `Q_{l+1}=Q_l`. Lean's [`transported_residual`](ResidualGauge.lean) records the abstract nonlinear-branch/additive identity; finite-dimensional orthogonal norm/attention transport remains the algebra above.

Let E be the vocabulary-by-d shared embedding/head and `Γ_f` the final diagonal norm gain. Input tokens require `E'=E Qᵀ`, since the new embedding column must equal Q times the original. A tied head using the **same E'** and only a new diagonal final gain `Γ'_f` has logits `E Qᵀ Γ'_f Q N(x)`; the source has `E Γ_f N(x)`. If E has full column rank and the equality is required on all residual states, these agree exactly iff

```
Γ'_f = Q Γ_f Qᵀ  is diagonal.                         (1)
```

This conclusion also holds for equality of *softmax laws* if the all-ones vocabulary vector is not in `image E`: an input-dependent logit difference in that image cannot be a common-logit shift. Both rank premises hold for the pinned source by the modular checks below. A restricted reachable final-state subspace could weaken (1), but requires its own proved enclosure; it is not supplied by a finite calibration sample.

For scalar Γ_f every Q meets (1); for generic pairwise-distinct gains, only signed coordinate permutations meet it. Equal gain values permit orthogonal mixing *inside their eigenspaces*, with an optional permutation of whole output coordinate labels. In a two-coordinate plane with gains a≠b, the conjugated off-diagonal is `(a−b)c s`, so any rotation with `c s≠0` breaks diagonal custody. [`ResidualGauge.lean`](ResidualGauge.lean) checks the zero-product consequence, not a formal spectral theorem.

### Joint row-space criterion, conditional on diagonal custody

Partition original input coordinates into the equal-value eigenspaces `I_g` of Γ_f. For a concatenation A of any chosen gamma-folded incoming rows (for example one Q head, a GQA group, Q/K/V, or gate/up), the **minimum number of input coordinate columns that remain nonzero after a Q satisfying (1)** is exactly

```
s_min(A;Γ_f) = Σ_g rank(A[:, I_g]).                    (2)
```

Proof: Q maps each gain eigenspace orthogonally onto a coordinate eigenspace of Γ'_f, so invertibility within that class preserves the rank of its projected row space. At least that many columns are required per class. Conversely choose, in each class, an orthonormal coordinate basis whose first `rank(A[:,I_g])` axes span that projected row space; all other transformed columns are zero. This proves attainability in ideal real arithmetic. A single **joint** Q works for the concatenation; separately minimizing each consumer and summing the claimed savings is invalid. If several layers share the gauge, concatenate their desired row families too. If gamma folding changes a matrix's rank within a class, use the actually folded A; for the tested head its layer-0 attention gain has no zeros, so column scaling leaves each rank unchanged.

## Exact pinned-Qwen obstruction in seconds

[`check.py`](check.py) verifies SHA256 `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b` of the existing BF16 safetensors checkpoint, reads only the needed tensors, proves each used BF16 coefficient lies exactly on a `2^-32` dyadic grid, and computes integer matrix ranks modulo the prime 65,521. A full-column-rank modular submatrix has full column rank over rational/reals; floating SVD tolerance does not establish the verdict. The [receipt](verified.json) contains:

* Final `model.norm.weight`: 125 exact gain values among 1,024 positions; largest equal-value class 70, 52 singleton classes. The layer-0 input RMSNorm gain has no zeros.
* Layer-0 `q_proj.weight[0:128,:]`: **every** `128×|I_g|` gain-class submatrix has modular rank `|I_g|`. Hence (2) is `Σ_g |I_g|=1,024`. For this head there is no missing input coordinate under any diagonal-compatible orthogonal gauge, even though an unrestricted Q could align its ≤128-dimensional row space with a 128-coordinate slice.
* The first 1,152 rows of the 151,936×1,024 tied embedding already have modular rank 1,024. Appending an all-ones column raises rank to 1,025. Thus both the exact-logit and softmax-only endpoint implications above hold for **all-state** equality.

No quantized weights were fitted, no held states were scored and no GPU was used. A modular-rank result is a rigorous **lower** bound on rational rank; failure to find a pivot would not prove a rank deficiency. This positive-pivot certificate closes the needed directions. The query head is the first of 16 query heads in one of 28 layers, not a surrogate for the entire model; nevertheless one head alone is already a discriminating negative for a universal "make each head a 128-column slice for free" prescription.

## What the fields and operations would cost

Qwen3-0.6B has d=1,024, 128-dimensional query heads, 28 layers, 151,936 vocabulary rows and one tied embedding/head image. A fixed group-128 affine Q4 image of **one** 128-row query head has eight 128-column groups per row. An ideal 128-coordinate contiguous slice would delete `128×896/2=57,344` packed code bytes and `128×7×(2+2)=3,584` FP16 scale/origin bytes: **60,928 bytes**, plus it would avoid 114,688 coefficient-input contributions per token in a sparse reader. These are a *hypothetical* fixed-grammar difference, not measured savings: (2) shows **zero** such deleted columns for the zero-boundary-cost gauge on this real head. General rotated weight fit could still improve error at unchanged bytes. Code packing, descriptors, row alignment and native traffic must be reassessed for another grammar; a dense reader that executes zeros saves no operations.

One can abandon the diagonal tied endpoint, but the bill moves rather than vanishes:

* Keep one tied `E'=EQᵀ` image and apply the exact symmetric `A_f=QΓ_f Qᵀ` after the final norm. A fully materialized FP16 symmetric 1,024×1,024 operator occupies **1,049,600 bytes** (upper triangle) and a dense application entails up to 1,048,576 coefficient products per token. FP16 is only an approximate image; a structured/factorized A_f may be smaller and faster, and must be charged by its actual description and reader. No universal lower bound of 1,049,600 bytes is claimed.
* Instead keep a diagonal/no final gain and an **untied** transformed output head `E_head'=E Γ_f Qᵀ`, separate from input `E_embed'=EQᵀ`. An additional full 151,936×1,024 fixed group-128 affine Q4 image costs `151,936×(512 packed bytes+32 FP16 metadata bytes)=82,653,184` model bytes, plus its shape descriptor; its new fit and native work would also need evaluation. One may reclaim the original 2,048-byte final gamma if genuinely absorbed, not a second full image. Compared to a hypothetical 60,928-byte one-head slice this is a large negative ledger, **not** a lower bound excluding compact joint/low-rank heads.
* Store a generic dense Q (FP16 description: 2,097,152 bytes, approximate) and evaluate Qᵀ, Γ_f and Q at the final boundary: two dense 1,024×1,024 transforms plus gamma, unless Q has an explicitly cheaper structure. A signed Hadamard uses two 1,024-wide transforms: each has 5,120 butterflies/10,240 adds-or-subtracts before signs/scaling, so its *pair* adds 20,480 adds-or-subtracts plus signs/scales and 1,024 gain multiplies. Its sign description is 128 bytes if not already shared. A structured Q can cost much less than dense Q; the comparison must use its actual program.

No model needs to store Q solely to *explain* an already transformed set of weights when (1) holds: E', all folded incoming rows and conjugated output rows are the executable image. Conversely a non-diagonal final operator or per-layer skip conversion is not made free by calling Q a change of notation. Changed generic code, prepared state, metadata and quantization distortion belong to the same ledger.

## Exact paid toy showing the route is not vacuous

[`toy.py`](toy.py) uses a four-wide **rational orthogonal** Q whose first block is `[[3/5,4/5],[-4/5,3/5]]`, with identity on the other coordinates; scalar final gamma; tied source embedding/head `E=Q`; two nonlinear square units with incoming rows `Q[0:2,:]` and output columns `Qᵀ[:,0:2]`. The source block is `x ↦ x+W_out φ(W_in N(x))`, and its rotated block has **identity embedding/head, two coordinate-picking incoming rows and two coordinate-writing output columns**. `N(x)=x/(1+||x||²)` is a rational isotropic normalizer for exact replay; the same symbolic proof works for ideal real RMSNorm because it is orthogonally equivariant. All 97 reported token/stack and small-grid input checks use exact `Fraction`, including nonlinear composition and tied final logits.

One explicit fixed-shape sparse reader stores each nonzero as one byte each for row, column and a code into the **same generic** exact rational dictionary `{−4/5,3/5,4/5,1}`, plus one entry-count byte for each of the three matrices. It charges 14 nonzeros/45 bytes in the source versus 8 nonzeros/27 bytes after transport, **18 bytes saved**. Q is not needed by this deployed reader: the rotated embedding initializes the rotated state, all branch outputs stay there and the tied head observes it. The matrix sizes and dictionary are unchanged, no hidden decoder/table is fitted. This deliberately planted example establishes a nontrivial complete-map possibility, **not** prevalence, Qwen quantization accuracy or native speed; sparse dispatch overhead and generic code are not timed.

Run both bounded certificates from the Kelana root (the source read/check is about four seconds on CPU1):

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/residual-gauge-custody/check.py
python3 research/isa-quantization/residual-gauge-custody/toy.py
lake env lean research/isa-quantization/residual-gauge-custody/ResidualGauge.lean
```

The actionable search question is therefore **which complete set of live consumers can share a compressed Q while carrying its label through residual additions, and what paid final observer realizes the tied logits?** Under strictly diagonal tied custody the class-rank formula gives an immediate exact no-slice test. Under a paid output operator the Qwen result does not close the route; a candidate must export the transformed tied image, affected matrices, output operator and any skip conversions before comparing complete-model behavior and native cost at a matched total effective size.
