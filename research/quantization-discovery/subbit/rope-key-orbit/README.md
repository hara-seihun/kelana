# RoPE key-cache rank depends on the observation boundary

A narrow shared value cache works because attention scales values without changing their coordinates. A narrow key cache faces a different map: RoPE moves a key's coordinates by position before each query observes it. This note settles the exact rank of a fixed linear **post-rotation** key-cache decoder, and measures its best isotropic-score approximation on pinned Qwen3-0.6B key weights. It does not reject pre-rotation codes with position-aware consumers.

## Exact finite-context result

Let `R_t` be the 128-dimensional Qwen3 RoPE rotation at integer position `t`. For a key `v`, suppose the cache stores `E R_t v` in `r` real numbers and a fixed linear decoder `D` supplies the key to every possible query `q`, so `qᵀ D E R_t v = qᵀ R_t v` for all `q` and `t=0,...,127`. Then `r >= dim span{R_t v : 0 <= t < 128}`. Equality is achievable by choosing a basis of that span. This counts cache elements, not the cost of computing `E`, decoding or the query dot.

Here the rotation has 64 independent real two-planes. Write `z_j=v_j+i v_{j+64}`. Its complex eigenvalues are `exp(±i ω_j)`, with `ω_j=1000000^(-j/64)` for `j=0,...,63`. All 128 eigenvalues are distinct: `0<ω_j<=1<π`, and the positive frequencies are strictly distinct. If every `z_j` is nonzero, the matrix with columns `R_t v`, `t=0,...,127`, is a real form of a full-rank Vandermonde matrix on these eigenvalues. Its determinant is nonzero. **Even a one-dimensional unrotated key producer `k=a v` then needs all 128 post-rotation coordinates** in this fixed-decoder grammar when 128 positions and all query directions matter. For fewer positions the orbit dimension is their count, up to 128, under the same hypothesis. This is a rank proof over real arithmetic, not a BF16 bit-identity claim.

The pinned layer-0 and layer-14 K matrices have eight full-row-rank 128×1024 groups. Even their *first column* has a nonzero component in every RoPE plane. The smallest such plane magnitude among these 16 groups is 0.000947, and the smallest singular value of a group K matrix is 0.061994, after casting the pinned BF16 weights to FP64. Thus the rank-one example applies to an actual weight column on this algebraic input domain. The original projection already has full row rank, but the rank-one example isolates the **position orbit** as the obstruction rather than confusing it with weight rank.

There are two important escapes. A position-aware decoder can store the scalar `a` in the rank-one example and compute `qᵀ R_t v` for each queried position. That changes the online work and consumes positions in the query/key interaction. Also, a restricted reachable query set may fail to observe some directions. Neither escape contradicts the fixed-decoder theorem. Pairwise frequencies can be pruned or Q/K jointly trained under a declared error contract; this proof does not forbid useful lossy keys.

## Optimal isotropic-score rank curve on real weights

For a finite uniform position range `0,...,L-1`, let `x` be isotropic with `E xxᵀ=I`, `k_t=R_t K_g x`, and let the observing query be independent and isotropic in 128 dimensions. For any position-independent linear `r`-element encoder of the **rotated** key and linear decoder, the minimum expected squared score error divided by the original expected squared score is

`1 - (λ₁+...+λᵣ)/tr(C_L)`, where `C_L=(1/L) Σ_t R_t K_g K_gᵀ R_tᵀ` and the eigenvalues descend.

Indeed isotropy of the query turns score error into key reconstruction error. Eckart-Young/Ky Fan on `C_L` gives this minimum and an orthogonal top-eigenspace projection attains it. No code rounding or activation sample enters this calculation. `orbit.py` evaluates the finite trigonometric sums in FP64 without expanding 4,096 rotated matrices. The one-position covariance is checked against `K_g K_gᵀ`.

| Layer | Mean rank-28 energy, unrotated K | 256-position rotated K | 4,096-position rotated K | Rank-28 rotated range at 4,096 |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .452691 | .403353 | .379899 | .335125–.494166 |
| 14 | .558273 | .455782 | .444175 | .340584–.683503 |

Each mean covers the eight KV groups. For example, layer 0 loses at least `1-.379899=.620101` of isotropic score variance **on average across groups** at 28 post-RoPE cache coordinates and a 4,096-position uniform horizon, even with a free continuous optimal decoder. This is a family bound for this artificial input/query distribution, not a held-text attention KL or model NLL. Query anisotropy, headwise normalization, quantized producers, softmax and causal position frequencies can change the best subspace and the quality ranking. The numbers do not price native latency, which includes preparation, code lookup, rotations, cache traffic, synchronization and occupancy.

## What to build next

Do not copy the rank-28 V/O code into K and expect the same coordinate freedom. On real Qwen train captures, fit a **joint Q/K score observer** under causal positions and quantized producers, with both query heads observing each shared key. One native candidate stores a pre-rotation key code and evaluates its position-dependent query response directly from that code; another retains selected RoPE two-planes so the standard rotation remains cheap. Compare score/softmax and complete-model held loss at equal paid rate, then price query-dependent preparation per occupied key. The isotropic curve is the no-query-training control and a warning against spending kernel effort on post-rotation rank 28 before that fit.

`/path/to/workspace/data/kelana-subbit/rope-key-orbit/receipt.json` contains every group/rank at 28, 64 and 96, the model/config/source SHA256 hashes, and the exact horizons. Reproduce with:

```sh
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/rope-key-orbit/orbit.py --output /path/to/workspace/data/kelana-subbit/rope-key-orbit/receipt.json
```

This CPU panel did not reserve the GPU or alter Bonsai's serving map.
