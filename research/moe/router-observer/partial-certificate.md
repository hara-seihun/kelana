# Partial-dot certificates do not spare the Qwen router's weight image

The layer-0 Qwen3.6-35B-A3B router has 256 F32 rows of width 2,048. On 126 held actual producer vectors, a certificate that reads input columns in the stored order needs a mean of **2,037.81 of 2,048 columns** before it can establish the complete top-eight set. Reading columns in descending, precomputed total router-weight energy improves this to **2,028.59**. Neither order certifies a single held route after 1,920 columns. This is a bounded negative for stopping a shared router dot prefix, not for the seven-exponential normalization shortcut or for a different sparse expert representation.

An uncharged input-dependent order by `abs(x_j) * ||W[:,j]||₂` needs 1,899.63 columns on held. It would have to sort 2,048 input coordinates and gather 256 weight rows in that changing order, and it changes the FP32 reduction order. Its 7.24% *conditional router-image* saving is a generous upper comparator, not an implementation. The selected runtime's router weights are only 2.097 MB per layer. Even granting the same fraction at all forty layers and one read per weight, that free ordering would remove at most **0.231%** of the modeled 2.626 GB whole-model weight stream per token. The static order's corresponding upper scenario is **0.030%**, before reading tail norms, checking bounds, reducing candidates or paying for changed layout. Neither is a native speedup.

## Certificate and controls

For a common column order, let `p_e(k) = Σ_{j<k} W_ej x_j`. Precompute the router-row suffix norms and compute the input suffix norm. Cauchy-Schwarz gives `r_e(k) = ||W_e[k:]||₂ ||x[k:]||₂` and `l_e ∈ [p_e-r_e,p_e+r_e]`. A complete top-eight is certified if the smallest lower bound among the true top eight is greater than the largest upper bound among the other 248. The true set is computed using all 2,048 columns offline to assess this certificate, not made available to an online algorithm. An online implementation could instead compare the eight largest lower bounds with every remaining upper bound, at additional work. The [script](partial_cert.py) scans every prefix, including zero and the full width, and keeps stable index tie breaks.

A second, deliberately free offline control uses `Σ_{j≥k}|W_ej x_j|` as its suffix radius. This reads every omitted product, so it **cannot** justify skipping those weights. It tests whether the norm envelope alone is the problem: even with that oracle, the static-order held mean is 2,018.63 columns and no held route certifies by 1,536. The input-dependent order's oracle needs 1,864.06 columns. The result is driven both by close eighth/ninth logits and by tail products, not just a loose Euclidean norm.

| Column order | Held norm mean / median | Held certified by 1,920 / 2,000 | Held absolute-tail oracle mean |
| --- | ---: | ---: | ---: |
| Stored order | 2,037.81 / 2,041 | 0 / 4 of 126 | 2,032.32 |
| Fixed weight-energy order | 2,028.59 / 2,036.5 | 0 / 15 of 126 | 2,018.63 |
| Free input-energy order | 1,899.63 / 1,915 | 66 / 114 of 126 | 1,864.06 |

The disjoint 113-token train split gives norm means 2,037.55, 2,028.19 and 1,901.12 respectively; all 239 full-real top-eight sets agree with the installed captured IDs. The hashed [receipt](/path/to/workspace/data/qwen-moe/router-observer/partial-certificate.json) retains every first certified prefix, both splits and all source, GGUF inventory and capture identities. The strict comparison uses a `1e-7` numerical gap. The worst sequential binary64 dot envelope across these inputs is `1.44e-11`; this is a mathematical real-dot certificate evaluated in double, not a proof of native FP32 logits or a native FP32 top-k. The input-dependent order does not preserve the selected model's arithmetic contract. We have not changed its runtime or resident service.

## What to do instead

The router's normalized *observation* needs only eight IDs and seven relative scores. The [seven-exponential construction](README.md) attacks 249 exponentials and a wide sum per layer without pretending that partial dots save useful whole-model traffic. Its alternative FP32 map still needs held complete-model quality and a timed native fused arm. For weight traffic, the measured Q8 nonexpert and small routed expert consumers have orders of magnitude more bytes than the router; the [native phase report](../../../../bonsai-halo/docs/qwen-moe-q8-unprofiled.md) is the right next engine control. A new prefix certificate is worth testing only with a paid, much tighter shared tail observer that avoids both the full weight scan and input-dependent reordering.

Reproduce the CPU analysis from the Kelana checkout with `OPENBLAS_NUM_THREADS=1 python3 research/moe/router-observer/partial_cert.py`. It reads the installed GGUF's router and actual `attn_post_norm` captures and writes the receipt under `/path/to/workspace/data/qwen-moe/router-observer/`. No GPU is used.
