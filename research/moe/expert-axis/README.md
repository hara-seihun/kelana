# Expert-index sharing before Qwen3.6's MoE nonlinearity

A tempting reuse point is the gate/up map *across experts*. One could prepare a few full-width linear responses to the current token once, mix those responses for its eight selected experts, then run the ordinary SwiGLU and down projections. This differs from the [shared input subspace](../shared-gate-input/README.md), which narrows the token, and the [shared down-output subspace](../README.md), which mixes after the expert nonlinearities.

On all sixteen available official BF16 layer-0 experts, this particular sharing coordinate has almost no redundancy. The largest absolute pairwise cosine between flattened 1024-by-2048 gate/up matrices is **0.01362**. The best seven-dimensional expert-index span retains **56.50%** of their isotropic squared preactivation response; 90% needs rank **14**. Seven basis maps cost **87.84%** of eight original gate/up maps' logical products per token, before mixing, launch and nonlinear work. Fourteen maps cost **175.68%**. In a separate composed control using 32 shared Gaussian token inputs, uniform eight-of-sixteen routes and independent softmax weights, rank seven gives **0.616** relative RMS error at the routed post-SwiGLU/down sum. This is not an attractive frozen weight-only reader. It does not constrain learned expert codebooks, activation-conditioned routes or the remaining 240 experts.

## Family and exact bound

Flatten each expert's gate/up matrix into a row of `W` with shape `[E, 1024*2048]`. A shared rank-`k` representation is `W_hat = A B`, where `B` holds `k` full `[1024,2048]` basis matrices and `A` contains `E*k` scalar coefficients. For a token `x`, compute `t_j=B_j x` once, then form each routed expert's `[1024]` preactivation `z_e=sum_j A[e,j] t_j`. The gate and up halves enter that expert's SwiGLU separately. Exact real preactivations for all possible tokens require `W_hat=W`; equivalently `k >= rank(W)`. The measured sixteen-row Gram has sixteen positive eigenvalues, so no nontrivial exact linear expert-index compression exists for this slice.

For the declared isotropic linear-response objective `sum_e E_x ||(W_e-W_hat_e)x||²` with `E[xxᵀ]=I`, the squared loss is `||W-W_hat||_F²`. Eckart-Young makes the top-`k` singular subspace globally optimal *in this factor family*; the minimum loss is the sum of the discarded Gram eigenvalues. Since the sixteen available experts have different norms, this optimum may spend a dimension almost entirely on a high-norm expert rather than a genuinely shared direction. The tiny pairwise cosines make that failure mode visible. This bound is not a post-SwiGLU/down error bound, where cancellations, routing and the input distribution change the objective.

## Measured slice and cost

The fixture is `model.language_model.layers.0.mlp.experts.gate_up_proj` and `down_proj`, experts 0 through 15, official revision `995ad96eacd98c81ed38be0c5b274b04031597b0`. The [receipt](/path/to/workspace/data/qwen-moe/expert-axis/README.md) records source and exact payload hashes, all sixteen eigenvalues and the synthetic route panel. The BF16 values are interpreted as real numbers in the bound. The composed control uses the exact original BF16 down matrices, one shared seeded Gaussian `x` per sample, uniformly selected eight-expert subsets and independently seeded normalized scores. Its RMS is against the corresponding original routed output, not language quality or the existing Q4 image.

| Expert-axis rank | Isotropic preactivation energy | All-sixteen preactivation RMS | Weighted post-SwiGLU/down RMS | Gate/up product ratio |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 10.59% | .946 | .919 | .1255 |
| 2 | 19.74% | .896 | .861 | .2510 |
| 4 | 35.41% | .804 | .727 | .5020 |
| 7 | 56.50% | .660 | .616 | .8784 |
| 8 | 62.15% | .616 | .594 | 1.0039 |
| 12 | 82.78% | .417 | .414 | 1.5059 |
| 14 | at least 90% | not sampled | not sampled | 1.7568 |

The original eight-expert gate/up map takes `8*1024*2048 = 16,777,216` scalar products per token. The proposed map takes `k*1024*2048 + 8*k*1024`, so the strict arithmetic break-even is `k < 8*2048/(2048+8)`, or `k <= 7`. At equal BF16 coefficient width its read traffic for a cold basis plus routed coefficients is `2*k*1024*2048 + 2*8*k` bytes, against `2*8*1024*2048` for the direct matrices. For rank seven the basis alone is 29.36 MB against 33.55 MB of eight direct BF16 gate/up matrices. Its full sixteen-expert *stored* image is `2*k*1024*2048 + 2*16*k` bytes, against 67.11 MB direct. Scaling that storage ratio to 256 experts assumes the *unmeasured* 240 experts admit the same small basis, which these sixteen almost-orthogonal matrices give no reason to expect.

The mixing operations, `k*1024` temporary values, 8*1024 routed preactivations, gate/up nonlinearities, unchanged down experts, output scatter/reduction and any quantization of `A` and `B` are extra. A shared basis could remain warm between tokens, but a serving result would have to establish that. BF16 MAC ratios are not comparisons to the mixed-rate UD-Q4_K_M runtime, nor are they measured latency. Even an exact real factorization would change FP32 reduction order.

## Next question

Stop fitting frozen expert-index spans to weight energy. Collect real layer-0 route assignments and gate/up producer activations, then fit a low-cost **shared activation preparation plus expert-specific coded residuals** against the weighted post-SwiGLU/down sum. Such a code need not have an expert-axis rank at all. Compare its paid bits and complete native activation/gather/matmul/scatter path to the current grouped mixed-Q4 reader. The measured rank-seven span has too little response fidelity to justify a native prototype on its own.

From a Kelana writer checkout, with the existing NumPy environment:

```sh
OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/moe/expert-axis/measure.py \
  --output /path/to/workspace/data/qwen-moe/expert-axis/layer0-16.json --samples 32
```

This is a CPU finite-image and synthetic-input result. No GPU reservation, model quality measurement, engine executable or service setting changed.
