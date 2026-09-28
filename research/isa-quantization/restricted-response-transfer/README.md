# Transfer response control only through the executable error family

A rank-deficient calibration panel does **not** by itself prevent a uniform response-transfer certificate. What matters is which coefficient-error directions the executable representation can realize. This study gives an exact finite-dimensional criterion, a constructive rational certificate, and a small exact family with an ambient blind direction that the legal reader cannot reach. It does not fit or re-diagnose the 128×1,024 Qwen `q_proj` panel; that panel's calibration rank 896 and held activity in its 128-dimensional calibration kernel motivate the question, not any numeric assertion here.

## Linear and affine families: exact criterion

Vectorize the complete output-coefficient error `E` into a finite-dimensional real space `V`; flatten all producer/output responses into two linear maps `C:V→Y_cal`, `H:V→Y_held`. Thus the two absolute squared response losses are `||Ce||²` and `||He||²`. The producer and observation boundaries, row coupling, bias/intercept choices, and any other live error terms must be represented in these maps and in the **actual legal set** of errors. A finite certificate `||He||²≤λ||Ce||²` for *every* error in a linear subspace `L` exists **if and only if**

```
ker(C|L) ⊆ ker(H|L).                                      (1)
```

Necessity follows by evaluating a calibration-null vector. For sufficiency, `T(Ce)=He` is a well-defined linear map on `C(L)` precisely because of (1); extend `T` by zero on its orthogonal complement in `Y_cal`. Its finite operator norm gives `λ=||T||op²`. An executable family `F⊂L` inherits the bound, but (1) need not be necessary for a genuinely nonlinear subset of L.

**Full affine class.** If `F=e₀+L` contains *every* point of that affine space, the same criterion on `S=span({e₀}∪L)` is also necessary, not merely sufficient. Any `s=αe₀+u∈S` with `α≠0` is a multiple of a member of F, so homogeneous quadratic inequalities on F apply to s. For `s∈L`, apply the inequality to `e₀+t s`, divide by `t²`, and let `|t|→∞`. Consequently the best constant over the entire affine family is the best constant on S. This argument does **not** apply to bounded parameter ranges, a discrete codebook, routed unions or curved image families.

A calibration-panel error **lower** bound alone is not a transfer bound: (1) must hold on the same error class and complete observation boundary. If both teacher response denominators are positive, an absolute certificate translates to

```
relative_held_error ≤ λ (||teacher_cal||² / ||teacher_held||²)
                         * relative_cal_error.
```

The factor of teacher norms cannot be silently dropped. This is deterministic finite-panel transfer, not a claim about unseen reachable producer states. To certify all reachable states, H must be the corresponding complete reachable-domain response operator or a proved enclosing norm, not a finite held sample promoted by name.

## Polynomial-time rational construction and witness of failure

For rational `C,H` and a rational independent-column basis `B` for L or S, form `C_B=CB`, `H_B=HB`. Choose independent columns J spanning `image(C_B)`, and put `C_J=(C_B)_J`, `H_J=(H_B)_J`, `G=C_JᵀC_J`. `G` is rational symmetric positive definite. For each remaining column j compute `α_j=G⁻¹ C_Jᵀ(C_B)_j` and check **exactly**

```
C_J α_j = (C_B)_j,               H_J α_j = (H_B)_j.      (2)
```

If the held identity fails, `B(e_j−Σ_i α_{j,i} e_{J_i})` is an explicit legal-subspace calibration-null/held-active direction. If all pass, the rational matrix

```
T = H_J G⁻¹ C_Jᵀ
```

satisfies `T C_B = H_B` exactly. Cauchy–Schwarz and the Frobenius norm supply the immediately verifiable rational bound

```
λ_F = Σ_{a,b} T_ab² = tr(G⁻¹ H_Jᵀ H_J),
||He||² ≤ λ_F ||Ce||² for e∈L.
```

This is an explicit conservative constant, not a fitted regression. A smaller proposed rational λ is accepted by checking positive semidefiniteness of `λ C_BᵀC_B−H_BᵀH_B` with exact arithmetic (e.g. rational Gram/LDL factorization with null-pivot handling). On the quotient of the common kernel, the *best* constant is the largest generalized eigenvalue of `(H_BᵀH_B,C_BᵀC_B)`. The Frobenius trace may be loose by up to the rank of `C_B`; it avoids floating eigenvalue acceptance entirely. `check.py` implements the rational kernel test, failure witness, decoder identity and trace charge; the tiny example's sharper PSD matrix is separately checked by all principal minors. A real-panel application would require a **proved source-level enclosure of all executable errors** before declaring B legal, and a rationalized/exact panel or outward-rounded interval certificate for the matrices. Merely taking the span of observed fit residuals is not such an enclosure.

## A discriminating exact family

Let `V=Q³`, `C(x,y,z)=(x,z)` and `H(x,y,z)=(x+y,2z)`. The ambient blind vector `(0,1,0)` has `C=0` but `||H||²=1`: no finite ambient transfer constant exists. Restrict the *legal* reader error to `L={(a,a,b):a,b∈Q}`. Then

```
C(a,a,b)=(a,b),      H(a,a,b)=(2a,2b),
||H(a,a,b)||² = 4 ||C(a,a,b)||².
```

The certificate's exact restricted Grams are `G_C=I₂`, `G_H=4I₂`; the constructive trace constant is 8, while the exact PSD check certifies the **sharp** constant 4. A legal reader enforcing its first two coefficient errors equal thus removes the ambient blind direction without increasing calibration rank. This is a schematic representation constraint, not a measured q_proj candidate or a claim that such equality is a good quantizer.

## What a nonlinear-family kernel test misses

Consider instead the compact polynomial image

```
F_bad={(t²,t,0): 0≤t≤1}.
```

It intersects `ker C` only at `(0,0,0)`, which is held-null too, yet for `t>0` its held/calibration energy ratio is `(1+1/t)²→∞`. Thus "every legal calibration-null point is held-null," **even for a compact closed legal image**, is insufficient. The limiting *directions* matter. The companion family `F_good={(t,t²,0):0≤t≤1}` has the **same linear span containing the ambient blind vector**, but its ratio `(1+t)²≤4`. A span certificate is sufficient but not necessary for this curved family; the exact polynomial witness is `4t²−(t+t²)²=t²(1−t)(3+t)≥0` on `[0,1]`.

For a general family F, put `D={e/||He||:e∈F, He≠0}`. A finite bound exists exactly when `inf_{d∈D}||Cd||>0`, equivalently zero lies outside the closure of `C(D)`; the best λ is that infimum's inverse square. This normalized-image criterion includes the dangerous approach to a blind direction, but is not automatically an efficient decision algorithm. Useful executable-family certificates may instead exploit a sound linear/affine enclosure, a finite code enumeration with all bytes charged, or a polynomial/SOS inequality in the actual program parameters. For F_good the factorization above supplies the latter directly.

[`RestrictedTransfer.lean`](RestrictedTransfer.lean) proves the general legal-null necessity, inheritance under family restriction, and the exact two-parameter legal/ambient witness using integer algebra. It does not formalize finite-dimensional real factorization, affine limiting continuity, rational Gaussian elimination or semialgebraic optimization; those proofs are given here and the finite rational arithmetic is replayed independently. [`check.py`](check.py) emits [`verified.json`](verified.json) without any fixture, GPU or fitting and exercises full-rank, shared-null, ambient-blind and zero-calibration cases. From the Kelana root:

```sh
python3 research/isa-quantization/restricted-response-transfer/check.py
lake env lean research/isa-quantization/restricted-response-transfer/RestrictedTransfer.lean
```
