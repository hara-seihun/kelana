# Shared gate/up input projection on Qwen3.6 MoE

A single narrow input transform reused by the eight routed experts sounds attractive: compute `z=Px` once, then let expert `e` consume `A_e z` for both gate and up. On the first sixteen original Qwen3.6-35B-A3B layer-0 experts, this fixed common linear coordinate has a sharp rate/response limit. At rank 512, the *optimal* common basis retains only 53.48% of their aggregate squared response under isotropic unit-covariance inputs. Rank 1,397 is needed for 90%. That basis costs 12.28 BF16 bits per original gate/up weight before quantization and still leaves the eight-expert down projections untouched. This is a useful stop rule for a weight-only shared-input factor, not a rejection of a learned, route-conditioned or nonlinear code.

## Map and bound

Let `W_e` be each `[1024,2048]` original BF16 gate/up matrix, interpreted as real coefficients, for experts 0 through 15. For a shared rank-`r` input map `P` and arbitrary expert consumers `A_e`, minimize `sum_e E_x ||W_e x - A_e P x||²` where `E xxᵀ=I`. Put the sixteen matrices in one vertical stack `W`. Eckart-Young gives the minimum squared error `sum_{i>r} sigma_i(W)^2`, attained by the top right singular subspace and `A_e=W_e Pᵀ` for orthonormal rows of `P`. This is an exact optimum in this *linear, shared-input, isotropic, unweighted* family. It prices both gate and up preactivations, not post-SiLU products or the weighted routed output. Router choices, activation covariance, expert importance and quantized factors can change the answer.

All rates below are BF16 factor payload, without scales, indexing, tensor padding or down-projection weights. A common rank `r` stores `2048r + 16·1024r` BF16 coefficients against `16·1024·2048` originals. For eight active experts, logical products per token are `2048r` shared input products plus `8·1024r` output products, versus `8·1024·2048` originals. The first term must execute for each *different token*, even when its expert route is reused. Neither those counts nor weight bytes predict a HIP runtime. The common transform alone reads `4096r` BF16 bytes per cold token unless it stays cached. Gate/up nonlinearities, route selection, down projections, temporary `z`, launches, numerical reductions and memory residency still count.

| Shared rank | Retained isotropic squared response | BF16 factor bytes for 16 experts | Eight-expert products / original |
| ---: | ---: | ---: | ---: |
| 128 | 21.22% | 4.72 MB / 67.11 MB | 7.81% |
| 256 | 34.12% | 9.44 MB / 67.11 MB | 15.63% |
| 512 | 53.48% | 18.87 MB / 67.11 MB | 31.25% |
| 1024 | 78.74% | 37.75 MB / 67.11 MB | 62.50% |
| 1536 | 93.09% | 56.62 MB / 67.11 MB | 93.75% |

The product ratio uses both stages, `(2048+8192)r/(8192·2048)`. The 50%, 90%, 95% and 99% energy thresholds occur at ranks 460, 1397, 1638 and 1926. At 95%, this basis costs 14.40 BF16 bits per original weight and **as many logical products as the unfactored gate/up** (rank 1638 is the integer product break-even). At a uniform four-bit *gate/up-only* payload, the BF16 factor rank cap is 455 and thus retains less than 50%; at one bit it is 113 and retains less than the rank-128 row's 21.22%. The actual UD-Q4_K_M image is mixed-rate; these are uniform-rate comparisons, not its exact bytes or quality. Lower-precision factors could move the storage bound but introduce code error and a native consumer that must be priced. The best original-axis shared 512-coordinate selection retains 28.05%, while expert-specific selections retain 29.41% at 512 coordinates each. The unrestricted common basis is substantially better than merely retaining channels, yet still loses almost half the gate/up response energy at that rank.

## Consequence

Do not start a native shared gate/up *weight-only* rank-512 reader on the assumption that one projection amortized across eight experts preserves ordinary activations. Instead, the next informative experiment should use real router assignments and producer activations: compare the same factor family against matched-rate independent expert factors and directly score the weighted expert sum after SiLU and down, with the real mixed-rate Q4 image as control. Fit the shared subspace to that composed observation if the route-weighted covariance concentrates. Alternatively learn a common *activation quantizer* with expert-specific residuals, so one shared preparation is cheap without forcing all sixteen matrices through the same narrow real subspace. This bound does not constrain the common **down-output** coordinate studied separately in Kelana.

[Receipt](/path/to/workspace/data/qwen-moe/shared-gate-input/README.md) contains image/source hashes and all ranks. Run from a Kelana writer checkout with `/path/to/workspace/data/fish-s2-pro/venv/bin/python` and `OPENBLAS_NUM_THREADS=8`:

```sh
python research/moe/shared-gate-input/measure.py --output /path/to/workspace/data/qwen-moe/shared-gate-input/layer0-16.json
```

The script converts the pinned raw BF16 payload to FP32 and diagonalizes `WᵀW`. Its spectral trace is the exact finite-image real-coefficient isotropic objective up to floating arithmetic; no GPU, full-model loss, serving executable or service changes are involved.
