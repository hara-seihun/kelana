# Contracting the hidden dimension out of the FFN's quadratic part

Verdict: the tested low-rank quadratic replacements lose on arithmetic and storage.
For the output directions tested, rank 256 holds about 37% of the quadratic form's Frobenius
energy; rank 2048 holds about 93%. Spectral truncation needs roughly 1600–2000 directions for
10% relative error on the captured activations. Independent per-output forms break even near
rank 10, so that construction misses by about two orders of magnitude. A tested shared-basis
construction also loses. This measures layer 0, not all possible contractions or representations.

All numbers come from real weights and real activations:
`/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00` (PTQ1_0.gguf, D = 5120, FF = 17408,
256 captured tokens). Reproduce with `quad.py`; cached results in `results/`.

## 1. What was computed

Ideal real arithmetic up to but excluding the hidden quantiser. Since `silu(a) - silu(-a) = a`,

```
h_i(x) + h_i(-x) = (G_i . x)(U_i . x)
e_c(x) = sum_i c_i (G_i . x)(U_i . x) = x^T Q_c x,   Q_c = sym(G^T diag(c) U)
```

- `G`, `U` are the deployed operators: trits decoded from the HALO tiles times their per-(row,
  128) fp16 block scales. No PTQ scale is dropped.
- `x` is the FFN input in the basis the weights were ternarised in: RMS-normed residual times
  the signed post-norm vector, then `H_1024/32` — exactly `carrier_scan.ffn_input`.
- `c` is the output direction pulled back through the fixed hidden transform in the deployed
  order. The engine computes `h = (1/32) H diag(signs_ff) hid`, so with `Dr` the scaled ternary
  down row, `c = signs_ff * ((1/32) H_1024 Dr)`. `H` is symmetric, which is why the pullback is
  the same transform.
- Both quantisers are excluded. This is a different mathematical map, not a bound on the
  deployed map's compressibility. Quantisation may erase distinctions and make a map simpler.
- `Q_c` represents twice the even part. The even component itself is `x^T Q_c x / 2`.
- The implementation rounds the pulled-back direction through an FP32 Hadamard before forming
  `Q_c`. The algebraic identity check uses that same direction on both sides.

Identity check (`quad.py check`, row 0, 8 tokens): `x^T Q_c x` matches both the direct sum
`sum_i c_i (G_i.x)(U_i.x)` and the symmetrised full pipeline `y_r(x) + y_r(-x)` to 8e-16
relative. The object studied is the FFN's own even part, not a surrogate.

## 2. The even part is most of the layer's output

On the 256 captured tokens, splitting the whole ideal-arithmetic FFN output into
`y = even + odd` (`quad.py part`, all 5120 outputs):

| | RMS |
|---|---|
| `y` | 0.02184 |
| even component | 0.02386 |
| odd component | 0.00827 |

The quadratic part carries more energy than the output itself (even and odd partly cancel on
this token set, which is not symmetric). So this is not a marginal component — if it contracted,
it would be worth having. It does not.

## 3. Spectrum of `Q_c`

Dense floating eigendecomposition of the full 5120x5120 form, FP64 for row 0 and FP32 for the
other directions, using `quad.py spec`. Frobenius energy
retained by the best rank-k symmetric approximation, i.e. the top-k eigenvalues by magnitude:

| direction | PR | k=8 | 32 | 64 | 256 | 512 | 1024 | 2048 |
|---|---|---|---|---|---|---|---|---|
| down row 0 | 1169 | 0.024 | 0.076 | 0.133 | 0.370 | 0.561 | 0.769 | 0.934 |
| down row 137 | 1178 | 0.024 | 0.075 | 0.132 | 0.368 | 0.559 | 0.768 | 0.934 |
| down row 2048 | 1135 | 0.026 | 0.080 | 0.138 | 0.376 | 0.566 | 0.773 | 0.935 |
| random output dir | 1139 | 0.027 | 0.080 | 0.138 | 0.375 | 0.565 | 0.771 | 0.935 |
| *control:* iid Gaussian `G`,`U` | 2047 | 0.010 | 0.036 | 0.068 | 0.228 | 0.391 | 0.619 | 0.864 |
| *control:* gate columns shuffled | 1525 | 0.017 | 0.055 | 0.099 | 0.301 | 0.483 | 0.707 | 0.908 |

PR is the participation ratio `(sum l^2)^2 / sum l^4`, the effective number of eigenvalues; 5120
would be perfectly flat, 1 would be rank 1. The eigenvalues are sign-balanced (2562 positive,
2558 negative for row 0) and the largest is only 6.4% of the Frobenius norm.

The four directions have similar energy curves, though this sample does not establish a
layer-wide property. The real weights are more concentrated than the tested Gaussian control — PR 1169 against 2047 for shape-matched iid
Gaussians, and breaking the gate/up column correspondence by shuffling `G`'s columns gives back
40% of that gap (1525). So part of the concentration is the trit/scale distribution and part is
the gate-up alignment, together worth a factor of ~1.75 in effective rank. The cost model needs a
factor of ~200.

Error on the 256 real activation vectors (relative RMS of `x^T Q_k x` against `x^T Q x`, so this
is the actual function error, not a subspace fit):

| direction | k=64 | 256 | 512 | 1024 | 2048 |
|---|---|---|---|---|---|
| down row 0 | 0.876 | 0.654 | 0.458 | 0.237 | 0.096 |
| down row 137 | 0.799 | 0.577 | 0.393 | 0.223 | 0.086 |
| down row 2048 | 0.668 | 0.433 | 0.301 | 0.147 | 0.057 |
| random output dir | 0.659 | 0.445 | 0.339 | 0.195 | 0.068 |

The row-0 activation error at rank 1024 is 0.24, versus a relative Frobenius matrix error of
`sqrt(1-0.769) = 0.48`. These are different metrics. Gaussian quadratic-form error also depends
on the residual trace. Interpolated ranks: 90% Frobenius energy at k ≈ 1830, 10% activation error at k ≈ 1560-2020,
1% activation error at k ≈ 4600-4800 out of 5120.

`results/spec_*.json` also carries a covariance-whitened spectrum. **Ignore it as evidence.** The
empirical covariance of 256 tokens has rank 256, so any whitened spectrum saturates at rank 256
by construction; it measures the token count, not the map. Only 256 tokens exist in this capture.

## 4. Cost, for the whole layer rather than one output

Per token, ideal real arithmetic, all 5120 outputs, MACs only:

- deployed FFN: `3 D FF` = 267.4M (gate + up + down), amortising to `3 FF` = 52,224 per output.
- independent rank-r form per output: `r D` per output, `r D^2` for the layer. Break-even
  `r = 3 FF / D = 10.2`.
- one shared rank-m input basis for all outputs: `m D` projections plus `m(m+1)/2` per output,
  `m D + D m(m+1)/2` for the layer. Break-even `m = 321`.

| rank | independent MAC vs deployed | shared MAC vs deployed | own energy (row 0) | shared-basis energy (mean of 5 dirs) | activation error (row 0) |
|---|---|---|---|---|---|
| 8 | 0.78x | 0.0008x | 0.024 | 0.003 | 1.02 |
| 32 | 3.1x | 0.011x | 0.076 | 0.013 | 0.98 |
| 64 | 6.3x | 0.041x | 0.133 | 0.026 | 0.88 |
| 256 | 25x | 0.63x | 0.370 | 0.117 | 0.65 |
| 512 | 50x | 2.5x | 0.561 | 0.236 | 0.46 |
| 1024 | 100x | 10x | 0.769 | 0.433 | 0.24 |
| 2048 | 201x | 40x | 0.934 | — | 0.10 |

The shared basis (`quad.py shared`) is the leading eigenspace of `sum_c Q_c^2 / ||Q_c||_F^2` over
the five directions. For this fixed orthonormal basis B, `||B^T Q B||_F^2 / ||Q||_F^2` is the
energy retained by the best quadratic form restricted to B. It is not an upper bound over
other choices of shared basis. The selected basis retains little energy across the sampled
outputs. At the
arithmetic-neutral m = 321 it holds about 15% of the energy. At m = 1024, where the scheme already
costs 10x the whole FFN, it holds 43%.

Storage runs the same way. Deployed: 267.4M trits in 58.5 MB of HALO tiles including scales. A
shared-basis form at m = 321 needs `m D + D m(m+1)/2` = 266M fp32 coefficients, 1.07 GB — 18x the
weights, for 15% of one half of the map.

And the accounting above is generous, because it prices the even part as if it were the whole
layer. It is not. If the odd part is retained in its current hidden-unit representation, it still
requires gate/up projections and an output projection. Computing the even part separately
then adds work rather than replacing the whole FFN. A joint replacement of both parts remains
outside this experiment.

## 5. What this does not rule out

The negative result is about contracting the hidden dimension *first* and then compressing the
resulting `Q_c`. The even part already has a factorisation as `FF` products of linear forms. Forming dense
`Q_c` discards that known compact evaluation. Other structure was not exhaustively searched.

The route that stays open is compressing in the product form instead — approximating the 3-tensor
`T[r,j,k] = sum_i D~[r,i] G[i,j] U[i,k]` by `R < FF` terms `w_a (p_a.x)(q_a.x)`, which costs
`3 R D` and beats the deployed FFN whenever `R < FF`. For exact CP decomposition of a specified tensor, unfolding ranks lower-bound R. Those ranks
were not computed here, and the quadratic map observes only the tensor's symmetric part in
its two input indices. Approximate decomposition needs an error-dependent bound instead.
There is therefore no established `R >= 5120` bound or 3.4x speed ceiling from this study.
Product-form compression remains untested.

## 6. Assumptions, stated

1. Layer 0 only, `bench/layer00` capture. Other layers untested.
2. Four real down rows (0, 1, 137, 2048) and one random unit output direction. Row 1's spectrum
   was not computed separately; it appears only in the shared-basis study.
3. Both quantisers excluded. No compressibility ordering between the ideal and deployed maps
   is asserted.
4. For isotropic Gaussian inputs, `E[(x^T E x)^2] = 2||E||_F^2 + (tr E)^2` for symmetric E.
   Frobenius error alone omits the trace term. Activation-error columns instead evaluate the
   quadratic function on 256 real tokens.
5. Dense LAPACK eigendecompositions use fully formed `Q_c` in FP64 for row 0 and FP32 for the
   other directions. These are floating computations, not exact arithmetic or formal bounds.
   No randomised spectral estimator or activation-sample PCA is used for the main spectrum.
6. Cost is MAC counts under ideal real arithmetic. It ignores that the deployed FFN's MACs are
   ternary and int8 while every rank-r scheme's are float — which favours the rank-r schemes.
