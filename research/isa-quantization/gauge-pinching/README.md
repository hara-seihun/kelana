# Approximate tied-gain custody is a subspace pinching problem

The [exact residual-gauge certificate](../residual-gauge-custody/README.md) rules out deleting even one input column of Qwen's first Q head while preserving a tied embedding/head and an **exactly** diagonal final gain. Exact gain preservation is not the quantization objective. Here we solve a different question: **what is the smallest final-gain change that permits a chosen incoming row space to occupy a coordinate slice, with a diagonal final gain still used by the executable reader?**

For a fixed row space, the optimal Frobenius boundary approximation has a closed form. No rotation search or regularization sweep is required. This is the familiar orthogonal block projection (pinching) applied to the joint approximation/consumer-custody problem, not a claim to invent pinching. A source-only Qwen screen realizes the formula. Its coefficient-space result is not a whole-model quality result; the all-state logit bound below is much too loose to establish usefulness.

## The complete-map question

Use a column residual state x, tied vocabulary matrix E, final symmetric gain F (diagonal in the source), and an orthogonal common residual gauge Q. As established in the preceding report, embeddings become EQᵀ, incoming rows become WΓQᵀ, outgoing rows become QW, and literal residual additions remain in the new coordinates. Ideal real internal computation is unchanged when all live consumers are transported together. The final tied observer with diagonal gain Λ instead computes

```
E Qᵀ Λ Q N(x),       N(x) = x / sqrt(||x||²/d + epsilon).
```

The source computes EFN(x). If X=QᵀΛQ, the only changed ideal output operator is **F→X**. This does not assert that independently rounding the transformed matrices preserves the ideal equivalence; their actual quantized images, preparation and native reader remain additional obligations.

Let A concatenate the gamma-folded incoming rows we want to reduce to one coordinate slice. Let S=range(Aᵀ), rank r, and P the orthogonal projector onto S. A gauge puts A in its first r columns exactly when its first r inverse-coordinate axes span S. Such a gauge can realize a diagonal Λ **if and only if** X is symmetric and commutes with P:

* Necessity: in the gauge coordinates, both the projector onto the first r axes and Λ are diagonal.
* Sufficiency: if XP=PX, both S and S-perp are invariant under symmetric X. Choose an orthonormal eigenbasis inside each block. Together these give the required Q and Λ, without losing the coordinate slice.

Thus optimizing over the gauge and its final diagonal fields, at fixed desired S, is equivalent to optimizing over **all symmetric matrices commuting with P**. Preserving F exactly gives the previous gain-class obstruction. Allowing X to change gives a new approximation family.

## Exact solution and general theorem

Define

```
B = P F P + (I-P) F (I-P),
Delta = F-B = P F (I-P) + (I-P) F P.
```

For every symmetric X commuting with P,

```
||F-X||_F² = ||F-B||_F² + ||B-X||_F²,
min_X ||F-X||_F² = 2 ||P F (I-P)||_F² = ||[P,F]||_F².
```

B is symmetric, commutes with P, and uniquely attains the minimum. In an orthonormal S/S-perp basis, a feasible X has zero off-diagonal blocks. The two fixed off-diagonal blocks of F contribute equal squared norms; all other squared differences are nonnegative. This proves the identity and uniqueness, not merely a stationary condition. Frobenius invariance transports it back to the original coordinates. Diagonalizing B separately in its two blocks realizes the optimum using a diagonal final gain and a coordinate-sliced incoming reader.

The same minimum holds over nonsymmetric commuting X, although only the symmetric class supplies an orthogonal diagonal reader. This is an error optimum, not a storage, operator-norm, logit-KL or quantized-image optimum. For positive F the pinching is positive; positivity is unnecessary for the theorem, and the actual source final gain includes a negative entry.

### A low-rank boundary discrepancy

If U has orthonormal columns spanning S, set

```
C = (I-UUᵀ) F U,       Uᵀ C = 0,
Delta = C Uᵀ + U Cᵀ.
```

Then `rank(Delta) <= 2r`, `||Delta||_F²=2||C||_F²`, and `||Delta||_op=||C||_op`. The nonzero eigenvalues of Delta are the signed singular values of C. Consequently a source-only calculation needs neither a search for Q nor a full transformed model. This low-rank identity does **not** make a correction free: explicitly repairing Delta would reintroduce final-boundary fields and work. In the approximate-gauge construction Delta is deliberately omitted, and its effect on the complete observer must be measured.

## Formal foundation and exact witness

[`Kelana/GaugePinching.lean`](../../../Kelana/GaugePinching.lean) proves actual finite rational block-matrix sums. `four_blocks` derives the four-rectangle Frobenius decomposition; symmetry and a proved transpose/Fubini identity identify the two cross-block costs. `pinching_pythagorean`, `within_nonneg`, `pinched_attains` and `pinched_minimizes` establish the exact floor and attainment without assuming the desired inequality. The Lean scope is a rational orthogonal coordinate presentation. Real orthogonal conjugation, spectral diagonalization, uniqueness after basis transport, low-rank singular-value claims and the logit inequality below are analytic arguments here, not claims about that module.

[`witness.py`](witness.py) uses exact Fraction arithmetic. For `F=diag(1,2)` and `S=span((3,4))`, the basis rows of Q are `(3/5,4/5)` and `(-4/5,3/5)`. The source incoming row `(3,4)` becomes `(5,0)`. In the new basis F has diagonal `(41/25,34/25)` and cross term `12/25`. Pinching gives

```
B = [[913/625, 84/625], [84/625, 962/625]],
||F-B||_F² = 288/625.
```

This is smaller than the best scalar-gain error `1/2`; preserving F exactly is impossible for this S. A scalar source gain has zero floor. The witness verifies the decomposition for arbitrary rational block diagonal choices by exact symbolic coefficient accounting and concrete declared controls. It is an algebra witness, not a paid full-model improvement; the preceding report's complete nonlinear toy separately establishes nonvacuous storage savings under scalar final gain.

## Source-only first-head screen

[`screen.py`](screen.py) pins the same original BF16 checkpoint SHA256 `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b`. A is the first 128 rows of layer-0 q_proj after multiplying the original input RMSNorm gamma. U spans its full 128-dimensional row space; its smallest singular value is .02150156. F is the original final `model.norm.weight`, not the attention-head gamma. Nothing is fitted to held states.

The [receipt](results.json) gives:

* `||Delta||_F² = 213.1940985`, **.01359138 of the source gain's squared Frobenius norm**.
* Spectral error **5.5341332**. Small relative coefficient energy is not uniformly small output error.
* Rank discrepancy at most 256. Source F's minimum diagonal is -.1142578; the pinched matrix's measured minimum eigenvalue is .3742789.
* Source-head residual outside S is `4.35e-30` relative squared; U orthonormality error `3.11e-15`; pinching commutator error `5.33e-15` in FP64.
* Every one of 151,936 original embedding rows e is evaluated using the low-rank formula. `max ||e Delta||² = 1.23807017`, mean .37380830. No vocabulary-by-1024 changed-logit image is saved.

These are floating numerical realization results, not interval-certified universal constants. The exact theorem is independent of those numbers. No final hidden-state law, transformed quantized model, candidate language score or native timing was inferred from this screen.

### Why the resulting all-state KL bound does not settle quality

For any source residual x, the learned-gain-free RMS normalization obeys `||N(x)|| <= sqrt(d)` with epsilon>0. Source and approximate logits differ by `-E Delta N(x)`. If R is the largest norm of an embedding-boundary row `e Delta`, the logit-edit oscillation is at most `2 sqrt(d) R`. The standard finite-edit softmax Hoeffding bound therefore gives

```
KL(softmax(E F N(x)) || softmax(E B N(x))) <= d R² / 2.
```

This is a bound for the **complete tied vocabulary observer**, not a head's raw response. The measured row radius gives about **633.89 nats**, far too loose to establish acceptable error. Frobenius gain optimality alone must not be used to declare a behavioral win. Existing [finite-edit observation bounds](../observation-loss/README.md) can score actual source final states more sharply; a separate fixed-gain observer is the next discriminator, without changing B to match its result.

## The observer changes the approximation optimum

Even an isotropic input law followed by a fixed embedding E changes the problem from gain Frobenius error to `||E(F-X)||_F²`. Write `M=EᵀE` in the S/S-perp basis as `[[M11,M12],[M21,M22]]`, write `D=F12`, and write the free residual blocks `Y=F11-X11`, `Z=F22-X22`. When M is positive definite, the unique symmetric block-diagonal optimum solves two Sylvester equations:

```
M11 Y + Y M11 = -(M12 Dᵀ + D M21),
M22 Z + Z M22 = -(M21 D + Dᵀ M12).
```

Expand `tr((F-X)ᵀ M (F-X))`: its variable terms are `tr(Y M11 Y)+2tr(Y M12 Dᵀ)` and `tr(Z M22 Z)+2tr(Z M21 D)`. Differentiation within symmetric blocks gives the equations; positive-definite block Hessians give unique global minima. In general Y and Z are **not zero**, so unweighted pinching is not the optimum even for this simple complete linear observer. This analytic observation does not propose using an isotropic residual law in place of the actual source law or categorical loss.

The exact witness adds `E=[[1,0],[0,1],[1,1]]` in the rotated coordinates, so `M=[[2,1],[1,2]]`. The embedding-weighted optimum changes the two gains to `(47/25,40/25)` and has error `432/625` instead of unweighted pinching's `576/625`. The polynomial identity is checked for **all** two diagonal parameters, not selected samples. General Sylvester and KL optimization are not Lean-formalized here.

The [fixed pinched-gain observer](../pinched-gain-observer/README.md) now supplies the actual discriminator on an existing final-head capture, without any fit: its stated BF16 hook correction yields validation teacher KL **1.58050** and gold NLL **4.03973→5.26716**, on 510 next-token positions across two source windows. The saved hook is after BF16 gain multiplication; dividing by gamma reconstructs, rather than directly captures, the pre-gamma normalized residual. A separate saved-GPU-logit comparison and FP32-head sensitivity preserve the large loss. This rejects further recoding around this fixed Frobenius-optimal proposal, not all approximate gains or metric-carrying residual programs. The entire gain family is not rejected by one surrogate optimum's failure.

## What is and is not paid

In ideal real arithmetic, diagonalizing B within the two blocks retains an r=128 coordinate slice for this head without storing an additional final dense operator. As in the preceding report, deleting seven group128 Q4 groups per output row would hypothetically save **60,928 data bytes** and 114,688 direct contributions per token for this one head. That number is not a candidate result: transformed tied embeddings, all other incoming/outgoing maps and diagonal final gain must be quantized and paid together. Their distortion and decode/program costs can erase the local saving. Q is an offline construction witness, not necessarily a stored matrix, provided every consumer is actually transformed and no undeclared boundary uses the old coordinates.

An explicit low-rank correction restoring exact F would require its own U/C description or an equivalent program and all online products. Likewise, larger desired joint row families change S, r and the pinching floor. This study fixes the original first-head family before seeing any output score; it does not grow a rank ladder or optimize a coefficient criterion and call it language quality.

```sh
python3 research/isa-quantization/gauge-pinching/witness.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/gauge-pinching/screen.py
lake env lean Kelana/GaugePinching.lean
```

Each command completes in under a minute. Source data remain in their original owner; results and mathematics belong here.
