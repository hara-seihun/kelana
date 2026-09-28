# Exact common-output rank on original Qwen experts

Four original BF16 layer-0 down matrices, experts 4–7, already span the entire 2,048-dimensional output over the rationals. A shared *linear* output coordinate `C` that factors every selected expert down matrix exactly therefore needs at least 2,048 columns. This closes the lossless, unrestricted-hidden version of the common-output-factor proposal: its narrow arithmetic-winning range ends below rank 1,366.

The certificate uses the pinned official Qwen3.6-35B-A3B original-weight slice `down_proj.bf16`, not the installed mixed GGUF image. Concatenate the four `[2048,512]` matrices into one `[2048,2048]` matrix. Every finite BF16 element multiplied by `2^133` is an integer. Reduce those integers modulo 251 and eliminate rows over the field. The determinant is **32 modulo 251**, hence nonzero. A nonzero determinant after reduction proves a nonzero integer determinant before reduction; integer rescaling proves full rank of the original BF16 matrices over the reals. The executable [rank.cpp](rank.cpp) reads the raw words directly and prints the residue and rank. The [source, binary, input and result receipt](/path/to/workspace/data/qwen-moe/exact-route-rank/receipt.json) fixes this particular witness.

For any shared matrix `C` and expert factors `A_e` satisfying `W_e = C A_e` for these four experts, `rank(C) >= 2048`. More generally, exact equality of the weighted sum for independently variable 512-dimensional expert hidden vectors with nonzero coefficients forces each selectable `W_e` into the range of `C`, by varying one hidden vector at a time. This argument does **not** prove that the nonlinear Qwen producers reach independently variable hidden vectors on actual text, nor that a nonlinear or route-specific code cannot help. It also does not promise FP32 bit equality: even a full-rank real factorization changes summation order in a native kernel.

At rank 2,048 the proposed eight-expert down factor costs `8*2048*512 + 2048*2048 = 12,582,912` real MACs per token, versus `8*2048*512 = 8,388,608` direct, a 1.5-fold increase before reduction and launch work. Across 256 experts per layer, factors plus one basis store `256*512*2048 + 2048*2048` coefficients versus `256*512*2048`, or 1.015625 times as many at equal coefficient precision. These are family-specific work and storage counts, not a native speed measurement. Approximate ranks can still be useful if producer-conditioned complete-model quality and paid bytes justify them; the current actual-route rank-512 held result loses .709 relative RMS. The useful next experiment is to measure the span and covariance of *more real routed producer hiddens* with held text, then train a quantized factor against complete-model loss rather than pay for an exact common basis.

Reproduce on CPU from Kelana root:

```sh
g++ -O3 -std=c++17 research/moe/exact-route-rank/rank.cpp -o /tmp/qwen-exact-route-rank
/tmp/qwen-exact-route-rank /path/to/workspace/data/qwen-moe/experts/layer-0-0-16/down_proj.bf16 2048 4 5 6 7
# prime=251 rows=2048 columns=2048 rank=2048 experts=4,5,6,7 determinant_mod_prime=32
```

The rank witness does not use the GPU or touch Bonsai's installed model, executable or serving state.
