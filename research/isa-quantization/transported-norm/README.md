# Transporting the complete GQA attention coordinate

**Further result:** [sign-embedded Q4 coordinates](SIGN-EMBEDDED.md) retain this five-angle quality at **8,704 static bytes**, the same as scalar Q4, by changing the Q4 grammar and charging sign extraction, restoration and transported norms. The 8,768-byte image below remains the original experiment's provenance. The subsequent [full Q/K GQA group Q4 study](GROUP.md) finds that this quality advantage does not survive quantizing both complete query heads and their shared key under its matched same-byte reader; [whole-group train selection](WHOLE-SELECTION.md) resolves the earlier local-angle mismatch within two finite coordinate families.

**Finding.** An exact pre-RoPE pair rotation need not commute with Qwen's diagonal RMSNorm gamma. Transporting the *norm metric* through the encoded coordinates removes that restriction. A five-angle-per-pair Q4 construction improves held causal **two-head GQA mean attention KL** from the actual exported scalar Q4's **0.00090243** to **0.00067834**, and its combined V/O relative squared response error from **0.00021990** to **0.00013528**. Against a freshly fitted zero-angle Q4 using the *same* 512 train tokens, KL improves **0.00087277 → 0.00067834**, while V/O error improves **0.00022173 → 0.00013528**. This is an accuracy improvement **at higher bytes and additional online norm work**, not a compression/throughput Pareto victory. Its value is an executable counterexample to treating diagonal-gamma compatibility as a necessary constraint on complete-attention coordinates.

## Exact law, including GQA and epsilon

For each RoPE pair `p=(i,i+64)`, write the nonzero diagonal norm gamma as `Γ_Q,p`, `Γ_K,p`. Pick any invertible complex-linear real pair map `S_p=[[a,-b],[b,a]]` (`a²+b²>0`), shared by **both Q heads served by K head 0**, and set the K-side map to `S_p^{-T}`. On the pre-norm projection coordinates use

```
T_Q,p = Γ_Q,p⁻¹ S_p Γ_Q,p
T_K,p = Γ_K,p⁻¹ S_p⁻ᵀ Γ_K,p.
encoded norm metric M_h,p = T_h,p⁻ᵀ T_h,p⁻¹  (h = Q,K)
N_h(u) = Γ_h u / sqrt((Σ_p u_pᵀ M_h,p u_p)/128 + epsilon).
```

Then `N_Q(T_Q z)=S N_Q(original z)` and `N_K(T_K z)=S⁻ᵀ N_K(original z)` **for every input and positive epsilon**, since the denominators reconstruct the original Euclidean squared norm exactly. Pair maps commute with every position's RoPE rotation, and the dual maps preserve every Q/K dot product, including all causal keys and both GQA query heads. Therefore all logits, softmax distributions and V/O outputs are identical in ideal real arithmetic for *unquantized* weights. No arbitrary gain is discarded by RMSNorm; the metric transports its exact scale. For this experiment `S=R(theta)` is orthogonal, so both normalized Q and K use the same rotation but their **pre-norm** maps differ because `Γ_Q` and `Γ_K` differ. In general `S⁻ᵀ` must be used on K, not `S`.

For rotation `c=cos(theta),s=sin(theta)` and `r=gamma_y/gamma_x`, `T=[[c,-sr],[s/r,c]]`. Its inverse maps encoded pair `(u,v)` to `(cu+srv,-s*u/r+cv)`, hence the metric contribution is `(cu+srv)²+(-s*u/r+cv)²`. It has a cross term unless gamma coordinates agree or the rotation is a special discrete symmetry. Nonzero gamma entries, a shared static position-independent program, all changed live heads, and consistent K-cache representation are required. The epsilon is retained *inside* the transported norm. This is an algebraic statement, not an assertion that BF16 rounding or GPU kernels preserve it. [`Kelana/TransportedPair.lean`](../../../Kelana/TransportedPair.lean) checks rotation commutation and a polynomial score identity; [`Kelana/TransportedNorm.lean`](../../../Kelana/TransportedNorm.lean) checks the norm-pullback and complete shared-key score laws conditional on the concrete encode/rotation/dual identities. Neither module formalizes Qwen's floating arithmetic or an analytic softmax identity.

## Bounded image and replay

[`replay.py`](replay.py) selects one of `0, ±π/8, ±π/4` per pair using only the first two 256-token train windows of the pinned layer-0 Qwen3-0.6B fixture. For each trial it transforms head-0 submatrix rows 0:128 × columns 0:128, fits each row to the *same* five-round FP16-origin/FP16-step affine Q4 grid search as the existing producer, and minimizes the recovered original-coordinate input-covariance response loss. It does not select angles by held attention KL or O response. The 64 choices (44 nonzero) and Q4 rows occupy [`q4-coordinate.bin`](q4-coordinate.bin), **8,768 bytes = 8,704 Q4 + 64 angle indices**; no auxiliary per-history table. A matched zero-angle fit of the identical procedure is also scored. The source BF16 image of **all** other coefficients of both Q heads and their shared K head is transformed, not dropped: these unchanged-size but changed-value BF16 model fields account for `2×128×1024×2 + 128×1024×2 − 128×128×2 + 8,768 = 762,432` bytes for the affected Q/K group versus scalar Q4's **762,368**. The gamma fields already exist in both paths. The actual replay retains 64 decoded angle bytes and recomputes float64 pair inverses/FP32 metric arithmetic per normalization call, rather than retaining a metric table. A prepared FP32 symmetric metric table costs `2 norm types × 64 pairs × 3 coefficients × 4 bytes = 1,536` additional live bytes, plus 64 angle bytes; persisting it would increase static bytes too. A 768-byte FP16 table is only an untested lower-precision alternative. [The whole-group ledger](WHOLE-SELECTION.md#static-bytes-prepared-state-and-actual-reader-work) details its sign restoration, transient norm accumulator and shared-K recomputation. No original and transformed full weights can coexist for free in a deployment.

The replay rounds the transformed full Q and K *stored weights* to BF16 before their projections and rounds the resulting full projections to BF16, computes an FP32 transported quadratic norm with `1e-6` epsilon, BF16-rounds normalized vectors, multiplies the original BF16 gamma, applies BF16 trigonometric RoPE and FP32 score/softmax/value/O. Both Q heads share transformed K and V; it compares their mean teacher-to-candidate causal attention KL and the *sum* of their V/O outputs against the sum of their original contributions. `coordinate_no_q4` isolates the BF16 gauge leakage after transforming all original weights without modifying the Q block. The same first two held validation windows are used by every reader. The unquantized coordinate has held mean KL **0.00001906** and V/O error **0.00000471**: BF16 arithmetic makes the exact real gauge only approximate.

| Reader | Train GQA mean KL | Held GQA mean KL | Held combined V/O relative sq. |
| --- | ---: | ---: | ---: |
| Exported affine Q4, 8,704 B | .00067775 | .00090243 | .00021990 |
| Matched zero-angle Q4, 8,704 B | .00061299 | .00087277 | .00022173 |
| Rotated Q4 + paid index, 8,768 B | **.00057596** | **.00067834** | **.00013528** |
| Unquantized rotated coordinates | .00002172 | .00001906 | .00000471 |

The selected image and complete numeric result are [`results.json`](results.json); the fixture and original model stay with their documented owner. The local image's SHA256 is in that result. The online cost is materially greater than plain Q4: for each token, both query heads and the shared key head evaluate **64 quadratic pair metrics** rather than the ordinary 128-square sum, including a pair cross-product and three coefficient multiplications per pair (and metric-coefficient loads), plus the same RMS reciprocal root and Q/K matmuls. The replay's Python metric assembly is not a native instruction schedule. Rotated source BF16 rows keep the same matrix multiply shape, but changed model weights and all angle/metric generation and storage count. No native latency, whole-model KL or asymptotic win is established. A cheaper fused metric/norm or a different complete representation is needed to make the improved local behavioral response a paid frontier gain. The earlier [attention-consumer study](../attention-consumer/README.md) established a free paired-sign symmetry and found that its signed carrier loses badly to scalar Q4; the present result does **not** overturn that signed-carrier rejection. The [attention-metric study](../../quantization-discovery/subbit/attention-metric/README.md) already established that raw Q error is not the attention objective.

Run on the existing host with one BLAS thread (each call under a minute):

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/transported-norm/replay.py
lake env lean Kelana/TransportedPair.lean
lake env lean Kelana/TransportedNorm.lean
```
