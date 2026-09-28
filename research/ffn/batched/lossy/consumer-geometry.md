# Quantize what the consumer observes

Our A4 experiment minimizes error in individual activation coordinates. That is not the optimization problem we actually want. If the next operation is a fixed linear map `A`, the relevant error is `A(q-h)`, not `q-h`.

This distinction gives both an opportunity and a practical obstruction in Bonsai.

## Exact error geometry

For a linear consumer and error `e`,

```
output squared error = ||A e||² = eᵀ Aᵀ A e.
```

For a random error with mean `mu` and covariance `Sigma`,

```
E ||A e||² = ||A mu||² + trace(A Sigma Aᵀ).
```

These are exact identities, not Taylor approximations. The mixed covariance terms can cancel output error. Independent coordinate noise discards that opportunity. Zero mean controls the first term only.

For the consumer `F(a,b,c) = (a+c,b+c)`, every error `(e,e,-e)` is invisible. Its coordinate error can be arbitrarily large while output error stays zero. A small finite example is stronger than an appeal to average cancellation:

- Input `(0.49,0.49,0.49)`.
- Coordinate-nearest integer encoding `(0,0,0)` has input squared error `0.7203` and output squared error `1.9208`.
- Encoding `(0,0,1)` has slightly worse input error `0.7403`, but output error `0.0008`.

That is a factor of 2401 in output squared error, with the same code alphabet and number of coefficients. [`ConsumerGeometry.lean`](../../../../Kelana/ConsumerGeometry.lean) proves these integer-scaled identities, the invisible direction and a bounded step to the edge of a representation box.

This does not say any arbitrary nonlinear consumer preserves cancellation. Apply the linear identity after dequantization at the down-projection input. Moving the same perturbation backward across Hadamard, amax quantization or SiLU requires a separate argument.

## General existence theorem: most coefficients can reach endpoints

Let `A` be a real `n × m` matrix of rank `r`, let `b_i >= 0`, and let `h` lie in the box `[-b_i,b_i]`. There exists another vector `z` in the same box such that:

1. `A z = A h`;
2. at most `r` coordinates of `z` lie strictly between their two endpoints.

**Proof.** The nonempty compact polytope

```
P = {z : A z = A h and -b_i <= z_i <= b_i}
```

has an extreme point. If that point had more than `r` interior coordinates, the corresponding columns of `A` would be linearly dependent. Choose a nonzero dependence vector `v` supported on those coordinates. Both `z + epsilon*v` and `z - epsilon*v` remain in the box for sufficiently small positive epsilon, and both have the same image under `A`. Their midpoint is `z`, contradicting extremality. Therefore at most `r` coordinates are interior. QED.

This is a standard polytope argument, not a new theorem. The general real-matrix theorem is proved here in prose; the Lean file formalizes the three-coordinate constructive instance, not arbitrary finite-dimensional linear algebra.

For Bonsai's down projection, `m=17408` and `n=5120`. Therefore at least **12288 hidden coefficients can be at endpoints without changing the real-valued linear result**, if we are free to change the other coefficients within their bounds. Per-block activation scales can define those bounds and remain unchanged.

This is not yet a binary activation kernel:

- The remaining coordinates are real, not necessarily A4, A8 or representable at a cheap finite precision.
- Which coordinates saturate depends on the current input.
- Finding the representation is online work. Free weight preprocessing does not make a per-token linear solve free.
- Changing reduction order can change the native FP32 result even when the real linear map is identical.
- The theorem starts after the hidden producer. It does not eliminate the cost of SiLU or Hadamard by itself.

It proves that preserving every intermediate coordinate is unnecessarily restrictive. It does not prove that exploiting this freedom is cheap.

## Real weights: global freedom, little cheap local freedom

[`consumer_geometry.py`](consumer_geometry.py) reads the actual down-projection weights. Results are in [layer 0](consumer-geometry-layer00.json) and [layer 10](consumer-geometry-layer10.json).

Both have at least 12288 null directions by dimension. But all eight sampled 128-column scale groups in each layer have full column rank. This claim has an exact finite certificate: the first 128 output rows of the ternary submatrix have nonzero determinant modulo 65521. Each selected row scale is nonzero and shared by all 128 columns, so scaling the rows does not change rank. The JSON retains elimination pivots, determinants and source-submatrix hashes. These certificates are computed by integer elimination, not checked by Lean.

Thus no nonzero perturbation confined to any of those sampled groups is exactly invisible to the full down projection.

The numerical spectra tell a related approximate story. Normalize each column to unit length. The smallest eigenvalue of the resulting Gram matrix is:

| Support | Layer 0 | Layer 10 |
|---|---:|---:|
| sampled contiguous 128 groups | 0.675 to 0.692 | 0.679 to 0.694 |
| one sampled cross-group set, 128 columns | 0.697 | 0.682 |
| one sampled cross-group set, 512 columns | 0.447 | 0.444 |
| one sampled cross-group set, 1024 columns | 0.288 | 0.279 |

For these sampled supports, even the least visible local error direction still carries appreciable output energy. These spectra do not bound every sparse support, and they are floating-point estimates. They explain why local pair cancellation or small-block balancing is not an obvious way to exploit the large global nullspace.

The research question is now sharper: **can a cheap, mostly local circuit steer errors into sufficiently invisible global directions, without paying for another dense projection?** A generic dense pseudoinverse can find a direction; its cost is not a solution to our inference problem.

## A concrete use: fit scales in the consumer metric

The grouped-scale kernel approximates eight scales `lambda` by `L*m`, where each multiplier is an integer from 1 through 7. It originally minimized relative scale error. If `z` is the vector of eight actual block dot products, the consumer instead observes

```
error = zᵀ(L*m-lambda)
mean squared error = (L*m-lambda)ᵀ C (L*m-lambda)
C = mean(z zᵀ).
```

`C` is an uncentered second moment, so it includes mean contributions. For fixed `m`, write `d=mᵀCm`, `n=mᵀC lambda`, `c=lambdaᵀC lambda`. When `d>0`, the unconstrained best scalar is `L=n/d`; a positive-scale constraint replaces a negative optimum by the boundary. Completing the square gives

```
d * loss(L) = d*c - n² + (d*L-n)².
```

The Lean file proves this denominator-cleared identity and its lower bound over integers. The fitting script uses floating-point estimates, rounds stored scales to FP16 and searches multiplier coordinates heuristically; it does not claim a global optimum.

[`consumer_scale_fit.py`](consumer_scale_fit.py) fits on 256 contextual rows from the calibration document and evaluates on 256 rows from a different document. It uses the first 512 output rows of each layer-0 gate/up matrix, with the same grouped-A4 input representation for every fit. [Results](consumer-scale-fit.json):

| Projection | Relative-scale fit, test error | Consumer-metric fit, test error |
|---|---:|---:|
| gate | 2.9848% | 2.9168% |
| up | 3.0849% | 3.0219% |

These are projection RMS errors caused by weight-scale approximation only. The consumer-metric column uses 10% shrinkage toward a diagonal second moment. It reduces this error by about 2% relative while slightly worsening the scale-reconstruction metric. The code alphabet, stored scale width and runtime operations are unchanged.

Jointly optimizing across all five scale groups improves calibration error much more, but most of that gain disappears on the other document. This is evidence against treating an input-specific cancellation as a generally useful representation. No new native candidate or full-model quality claim follows from this CPU experiment.

## Prior work worth borrowing

- Lyubarskii and Vershynin, [Uncertainty principles and vector quantization](https://www.math.uci.edu/~rvershyn/papers/quantization.pdf): redundant frames and Kashin representations spread information across bounded coefficients. Their frame hypotheses matter; the dimension count above does not establish them for Bonsai's learned down matrix.
- Merkulov et al., [Quantization of Large Language Models with an Overdetermined Basis](https://proceedings.mlr.press/v244/merkulov24a.html), 2024: uses Kashin-style representations for model quantization. [Retrieved paper](kashin-retrieval.json). It provides representation algorithms and compression evidence, not a demonstrated fast native Bonsai activation map.
- [Frame Quantization of Neural Networks](https://link.springer.com/article/10.1007/s00041-025-10182-7), 2025: Sigma-Delta quantization uses correlated errors and frame redundancy. This is the right family of ideas for structured cancellation, rather than hoping independent rounding noise disappears.

The immediate lesson is to optimize an error's image under its consumer. The hard part is arranging that cancellation with cheaper instructions than the computation it replaces.
