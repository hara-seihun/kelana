# Complete expert-axis rank in the installed Qwen image

The first sixteen original BF16 experts already made a shared gate/up map look expensive. The installed 256-expert Q4_K layer-0 bank gives a sharper answer for exact *linear* sharing: all 256 gate matrices are independent as vectors of coefficients. In particular, a common bank of fewer than 256 full-width gate maps cannot reproduce every expert's gate preactivation for arbitrary input vectors. This closes the frozen full-bank linear expert-index basis, not the possibility of a route-conditioned nonlinear computation or an approximation on real producer activations.

## Finite witness

For each expert, `witness.py` decodes the first 256 gate output rows with the selected runtime's `dequantize_row_q4_K`. It takes each row's coefficient of input coordinate zero, forming a 256 by 256 matrix whose rows are experts. Every decoded coefficient is a finite binary32 rational. Multiplication by `2^149` converts it exactly to an integer; reduction modulo the prime 65521 yields determinant **42514**. Thus the integer matrix has nonzero determinant, so the sampled rational matrix has rank 256 over the reals. A 256-column restriction cannot have greater row rank than the complete 512 by 2048 gate matrix per expert, proving the complete expert-index rank is exactly 256. The witness uses neither floating-point SVD tolerances nor a claim that image cardinality establishes a fiber relation.

The initial attempt sampled 256 input coordinates of gate output row zero. It had rank 150: 106 experts' first Q4_K blocks decode to zero, and all eight blocks of that row have the same active-expert count. This was a bad witness, not an upper bound on the full bank. Sampling across output rows produces full rank. Both observations are reproducible from the script and pinned model.

[Receipt](/path/to/workspace/data/qwen-moe/full-axis-rank/receipt.json) retains all 256 modular pivots, the determinant, sample hashes, model SHA-256, tensor offset and stride, inventory hash, selected dequantizer binary hash and script hash. The script works from the packed image, without downloading the full BF16 bank or reserving the GPU:

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/moe/full-axis-rank/witness.py
```

## What the bound costs

Suppose `G_e` is the installed decoded expert gate matrix and the proposed representation stores `k` common full gate matrices `B_j` and scalar coefficients `a_ej`, then forms `G_e x = sum_j a_ej (B_j x)` for every expert and every real input `x`. This requires `G_e = sum_j a_ej B_j` and hence `k >= 256` by the witness. At one token with eight routed experts, evaluating those common full-width maps takes at least 256 times one gate map's scalar products, against eight direct maps, before mixing: a **32-fold product-count disadvantage** in this restricted grammar. The full basis also stores at least as many full matrices as the original 256-expert gate bank at equal coefficient precision, plus its mixing coefficients. For a bank reused across many prompt tokens one could amortize its loads, but not its per-token products. This is an arithmetic/storage comparison to an ideal direct gate map, not a native timing bound on the mixed Q4_K consumer.

The contract explicitly demands each gate preactivation, even for experts not selected by one particular router input. It says nothing about route-specific bases, the nonlinear SwiGLU/down weighted sum as a direct observation, restricted reachable producer inputs, lossy codes, learned matrices or FP32 bit identity under reassociation. In particular, a route-conditioned construction need not compute 256 basis responses. The next useful construction should couple real routes and nonlinear downstream consumers, paying for any basis selection and learned image and selecting with complete-model quality. Another global frozen linear expert basis is ruled out for exact arithmetic on this image.
