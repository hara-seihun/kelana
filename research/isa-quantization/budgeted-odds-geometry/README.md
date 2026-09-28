# Budgeted odds geometry: a global weighted KL/rank certificate

This study strengthens the [causal-odds-rank](../causal-odds-rank/README.md) floor for the **same** reachable two-position histories and the same separable candidate contract. For current label `x`, prior label `y`, and actual history `[y,x]`, let `L_xy=logit(p_xy)` be the teacher's prior-versus-self odds. A legal candidate has `Lhat_xy=psi(x)·phi(y)+b(x)`, where neither query nor key accesses the other's token. The arbitrary current-only offset includes its self score and all common row-logit shifts. A history-dependent query or nonseparable table is outside this factor class. An `r`-dimensional carrier is not an `r`-bit limit.

## Global theorem (no exogenous candidate-logit cap)

Let a finite rectangular panel have positive occurrence masses `mu_xy`, strictly interior probabilities `p_xy`, and objective `D=sum_xy mu_xy KL(Bern(p_xy)||Bern(sigmoid(Lhat_xy)))`. Suppose an **actual feasible candidate** has loss at most `U>0`. Choose a positive rational/real radius `M_xy` such that

```
B_xy = U / mu_xy,
s_xy = +1 if L_xy >= 0 else -1,
kappa_xy(t) = KL(Bern(p_xy) || Bern(sigmoid(L_xy+s_xy*t))),
kappa_xy(M_xy) >= B_xy.
```

Define `w_xy = mu_xy*kappa_xy(M_xy)/M_xy²`. For **any positive factorable minorant** `a_x c_y <= w_xy`, put `u_y=sqrt(c_y)`, `D_a=diag(sqrt(a_x))`, `D_c=diag(sqrt(c_y))`, and `P_u=I-uuᵀ/(uᵀu)`. For any separable candidate of dimension at most `r`,

```
D >= min { U, sum_{j>r} sigma_j(D_a L D_c P_u)² }.       (A)
```

There is no fit enumeration or a candidate logit bound. `U` is a **certified achievable control**, not a hypothesis on candidates. If `D>=U`, (A) is immediate. Otherwise each cell pays `KL_xy < U/mu_xy`. At fixed edit magnitude `t`, the outward direction `s_xy*t` has **the least** binary KL: the binary log-partition curvature `sigmoid'(L+v)` decreases with `|L+v|`, while `|L+v|<=|L|+|v|`. Moreover

```
kappa_xy(t)/t² = integral_0^1 (1-z) sigmoid'(L_xy+s_xy*z*t) dz
```

is decreasing in `t>0`. Thus `|Lhat_xy-L_xy|<=M_xy` and the **exact finite-edit** lower envelope is `KL_xy >= [kappa_xy(M_xy)/M_xy²]*(Lhat_xy-L_xy)²`. No tangent/Fisher quadratic is used globally. Multiplication by `mu` and the factorable minorant yields `D>=||D_a(Lhat-L)D_c||_F²`. Projection right by `P_u` contracts this norm; the row bias vanishes because `1ᵀD_c=uᵀ` and `uᵀP_u=0`. The remaining projected candidate has rank at most `r`, so Eckart–Young supplies (A). A nonuniform law is handled without pretending its masses are uniform. For an unweighted `m×n` panel, `mu=1/(mn)`, so `B=mn U` and a constant coefficient `c<=kappa(M)/M²` gives `D>=min(U,c R_r²/(mn))` with `R_r` the ordinary row-centered tail.

The exact teacher masses matter twice: in the budget-derived radii and in the weighted geometry. Strongly heterogeneous weights need not admit a good single factorable minorant; multiple disjoint rectangles or a sharper certified weighted low-rank solver may improve (A). The feasible control is particularly valuable when it keeps **every** edit within an informative finite range. Without such a control no positive global quadratic coefficient exists: KL grows only linearly in a saturating logit direction. As a separate simple route, the parent study's fractional rectangle-cover bound avoids an exceptionally rare background cell; (A) is different because it uses the feasible loss to tighten KL *inside each rectangle* and can exploit a factorable weighting rather than its minimum mass/variance.

## Discriminating exact panel and executable controls

The parent's actual two-current/three-prior panel has `L=log(2)*[[1,0,-1],[0,1,-1]]`, `p=[[2/3,1/2,1/3],[1/2,2/3,1/3]]`, and rank-one centered tail `R_1²=log(2)²`. Its one-byte shared-key image (plus the eight-byte generic probability table) returns `(7/12,7/12,1/3)` for both queries and has mean KL `U=.00957506104276...`; the two-byte direct image (plus the same table) returns the exact teacher law and has zero loss but is **not** rank-one separable. The paid readers, probability table and exact bytes are owned by [causal-odds-rank/witness.py](../causal-odds-rank/witness.py). Those are feasible/direct controls, not evidence of an optimized rank-one fit or a full-model/native frontier.

Here `B=6U=.0574503662565...`. Choose outward rational endpoints `q(1/3)=2/11`, `q(1/2)=2/3`, `q(2/3)=9/11`. For each teacher cell, exact rational-log interval arithmetic certifies both `KL(p||q)>B` and `KL(p||q)/|logit(q)-logit(p)|² > 99/1000`. Taking `a_x=99/6000` and `c_y=1` in (A), including the occurrence mass `mu=1/6`, gives

```
mean KL >= (99/1000)*log(2)²/6 = .00792747472965...
```

This is **10.82% above** the previous no-control bound `(log(2)-1/2)/27=.00715359927999...` and below the feasible shared-key `.00957506...`; it is not the exact rank-one optimum. The direct table's zero loss does not contradict it because its distinct query×prior lookup lies outside the rank-one family. A program whose features depend on past y on the query side need not have centered rank one either. The stronger floor is a reusable *error* certificate, not a claim of size-matched state-of-the-art domination: complete paid bytes and native cost remain separate axes.

## Reproduction and proof boundary

```sh
python3 research/isa-quantization/budgeted-odds-geometry/certificate.py
lake env lean Kelana/BudgetedOddsGeometry.lean
```

[`certificate.py`](certificate.py) independently evaluates the fixed teacher/control laws and rational outward endpoints, checks interval inequalities with the existing 24-term rational atanh logarithm and geometric tail, and writes [`results.json`](results.json). All computations take less than a second. Its rank tail is exact from the rational coefficient Gram eigenvalues `3,1`; the log and loss comparisons are rational intervals, not floating-point assertions. No parameter fit is attempted.

The outward-curvature lemma and real weighted projection/Eckart–Young theorem in (A) are **analytic proofs in this note**, not Lean-checked. [`Kelana/BudgetedOddsGeometry.lean`](../../../Kelana/BudgetedOddsGeometry.lean) checks the finite rational aggregation once a cellwise quadratic minorant and residual floor are provided; it does not silently replace real logs, real singular values, or the analytic statements. The parent's rational bias-centering foundation is in `Kelana/CausalOddsRank.lean`. A stronger subsequent formal result must first give an exact elaborating statement of (A) over real numbers with the actual `mu`, candidate factorization and reachable-history contract; the repository currently depends on Lean Std, not Mathlib's real analysis.
