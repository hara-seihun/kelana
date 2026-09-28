# Cross-pair covariance: the global soft mode cannot be charged per edge

The [weighted-pair study](../weighted-input-pairs/README.md) establishes an exact **ceiling** on every heterogeneous *diagonal* covariance-minorant / fractional-matching certificate: `.005142118673...`, below exported scalar Q4's `.005173614377...` train relative squared response error. This study asks what that diagonal choice discards, and tests a genuinely non-diagonal dual before asking for another matching fit. The target remains **every** 32-disjoint freely weighted pair input program with arbitrary real 128-output readout on the same real Qwen3-0.6B layer-0 128×128 subprojection. No new producer capture, training, GPU or candidate image is involved.

## Exact family obstruction to diagonal covariance certificates

For any `m≥2`, let `n=2m`, `W=I_n`, `u=(1,…,1)/sqrt(n)`, and consider the positive definite producer Gram

```
H = I_n - (1-ε) u uᵀ,                 0 < ε < 1.
```

The mode `u` costs ε, while its `n−1` perpendicular modes cost one. A legal `m`-carrier program computes the differences within the fixed pairs `(0,1),(2,3),…`; its complete real output readout projects onto those pair differences. Its residual subspace is the span of the `m` pair sums: it contains `u` and `m−1` perpendicular vectors. Thus its squared complete-response loss is **`ε+m−1`**. No rank-`m` linear response can do better, by the spectral tail of `H` (one eigenvalue ε and `n−1` eigenvalues one). This proves the *optimum over all pairings and arbitrary real pair ratios* is exactly `ε+m−1` for this family, not merely the score of one selected pairing.

Any diagonal minorant `H⪰diag(d)` has `Σ_i d_i/n ≤ uᵀHu=ε`. With `W=I`, a freely weighted two-coordinate carrier costs `min(d_i,d_j)` after unconstrained readout fitting. Among all matchings, the minimum is the sum of the `m` smallest `d_i`, at most `(Σ_i d_i)/2 ≤ mε`. Uniform `d_i=ε` is PSD-feasible, attaining this certificate ceiling. So the **best possible diagonal-minorant/matching certificate is `mε`**, while the true whole-response family optimum is `m−1+ε`: the missing gap is `(m−1)(1−ε)`. The diagonal relaxation spends the one global low-variance direction **once per pair**, although only one independent lost direction can use it. This is precisely the cross-pair covariance it forgets.

The off-diagonal entries of `H` are all the same negative number. A PSD correction `R=H-diag(d)` with those off-diagonal entries has rank at least `n−1`: if `R` is a Gram of vectors `v_i` with `v_i·v_j=-c` for every `i≠j`, then a linear dependence `Σ a_i v_i=0` forces `(||v_j||²+c)a_j=cΣ a_i` for every `j`; the nullspace has dimension at most one. The uniform choice `d=εI` attains rank `n−1`. A one-rank positive correction cannot exactly restore this all-to-all negative correlation. This is about exact representation of this Gram, **not** a claim that all rank-`<n−1` minorants give no partial improvement.

[`toy.py`](toy.py) independently computes a four-coordinate rational witness with `m=2, ε=1/4`: `H_ii=13/16`, `H_ij=-3/16` for distinct coordinates. The legal pair-difference program has exact error **5/4**, every diagonal matching certificate is ≤**1/2**, and `d=1/4` attains the bound. [`DiagonalGap.lean`](DiagonalGap.lean) kernel-checks the sorted-price combinatorial step for this four-coordinate ceiling. The general spectral and Gram-rank arguments above are mathematical derivations; the rational witness calculation is executable, not a Lean proof of the full family theorem.

## New non-diagonal dual, and the real-panel gap

A rank-one **positive** cross-input correction produces a valid non-diagonal minorant `B=diag(d)+βvvᵀ⪯H`. For weight error `E=W−W'`, completing the square through an arbitrary output-vector dual `p` gives

```
tr(EHEᵀ) ≥ Σ_i d_i ||E_i||² + β||Ev||²
          ≥ Σ_i [d_i||E_i||²+2v_i<p,E_i>] − ||p||²/β.
```

Put `w̃_i=w_i+(v_i/d_i)p`. For **each fixed `p`**, minimize independently over all real pair ratios and readout vectors, then over fractional disjoint matchings. This yields a sound whole-family lower bound

```
LPmatching( λmin(weighted 2×2 Gram of w̃_i,w̃_j) )
       − ||p||² ( Σ_i v_i²/d_i + 1/β ),
```

all divided by `||XWᵀ||²`. The subtracted `Σ_i v_i²/d_i` also pays for *unmatched* coordinates, which are free to choose their replacement weights. Dropping it would make the bound unsound. The dual variable `p` couples every edge through one shared output direction, rather than assigning the producer's same soft mode independently to all of them. This is the new covariance-aware certificate family; the algebra does not depend on how `p` is proposed.

[`rankone_screen.py`](rankone_screen.py) uses the **actual** Qwen fixture's 2,048 train producer states and original BF16 weights, scaled versions of the prior exact `d`, and a spectral positive rank-one direction in the residual `H−diag(d)`. Each `β` is chosen inside the numerically feasible PSD range. It optimizes one common `p` only by a bounded first-order proposal and recomputes the complete 8,128-edge matching LP; no pair programme or readout is fitted. Outcomes, relative squared response error:

| Diagonal retained | Proposed rank-one/dual bound | Prior exact diagonal lower | Q4 control |
| ---: | ---: | ---: | ---: |
| 70% | .003460 | | |
| 85% | .004201 | | |
| 95% | .004696 | **.004926** | **.005174** |

These are **numerical proposals**, not certified real-panel lower bounds. Even the most promising tested rank-one correction does not recover the loss from making the diagonal safely interior; it cannot reject the freely weighted family here. An orthogonal-output variant in [`split_screen.py`](split_screen.py) lets two disjoint 64-output groups use separately optimized diagonal minorants. Summing their separately free-ratio matching minima is valid as a lower relaxation for any *shared* pair ratio, but it reaches only .004173 (contiguous groups) or .004194 (interleaved) numerically. This too is not an exact rejection, and its separately minimized ratios deliberately give each group *more* freedom than the real reader has. Results and selected diagonals are retained, not promoted into numerical certificates.

**Reaching the stated Q4 accuracy is now excluded**, not the lower-byte family from a rate-distortion frontier, by the subsequent [full-covariance study](../full-pair-covariance/README.md): a 48-mode shared dual has an independently integer-checked floor .005753003543343237, above Q4 .005173614377259471 for every 32-disjoint freely weighted pair map and arbitrary real readout. The rank-one and split-output attempts recorded here did not cross the threshold; the exact constructed family explains the covariance they were trying to retain. Its unbounded diagonal gap is a general theorem, not an estimate of the Qwen margin. Held producer states do not enter the train-panel universal certificate; no held-language result follows.

## Provenance and reproduction

The real source fixture is `/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz`, SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`. The signed predecessor's dyadic diagonal certificate and the exported scalar Q4 image remain with [input programs](../input-programs/README.md) and [producer screen](../producer-screen/README.md); no copy is made here. Its exact Q4 train result is `.005173614377259471`, held result `.005173614986353243`. The pinned checkpoint and fixture split are documented with the [binary-factor comparison](../../quantization-discovery/subbit/binary-factors/README.md).

From Kelana root after predecessor integration, one CPU BLAS thread and each run under a minute:

```sh
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/pair-covariance/toy.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/pair-covariance/rankone_screen.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/pair-covariance/split_screen.py
lake env lean research/isa-quantization/pair-covariance/DiagonalGap.lean
```

`rankone_screen.py` and `split_screen.py` accept `--signed-certificate PATH` for pre-integration work. The rational witness and its theorem do not require the real fixture or solver. Source and compact receipts stay under this study; there is no packed candidate image because none survived the actual Q4 comparator.
