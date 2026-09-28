# A local rank bound for the complete Qwen expert sum

## Shared expert included: full 2,048-dimensional local observation

The earlier routed-only witness did not include Qwen's ninth, shared expert. It was possible in principle for the shared branch to cancel the routed Jacobian and make a narrower exact observer of the *actual combined FFN output*. The [extended CPU certificate](/path/to/workspace/data/qwen-moe/routed-jacobian/shared-receipt.json) closes that possibility at the same held layer-0 producer input. It decodes the installed Q8_0 shared gate/up/down matrices and F32 shared scalar gate, and evaluates the real map

```text
F(x) = sum_e softmax(W_e x) D_e [silu(G_e x) * (U_e x)]
     + sigmoid(w*x) D_* [silu(G_* x) * (U_* x)].
```

Here the eight IDs remain fixed on an open neighborhood: the selected-router eighth-to-ninth logit margin is 0.08195394. The shared derivative is `sigmoid(w*x) J_* + sigmoid(w*x)(1-sigmoid(w*x)) y_* w^T`, with `y_*` the ungated shared output. The route, weight decoders, source, input and model hashes are recorded in the receipt. The midpoint's least singular value is 3.61512337e-7, but the certificate uses an inverse `B` and encloses the mathematical Jacobian: `||I-B J||_inf <= 0.400211475 < 1`. Its maximum entry uncertainty is 1.619e-11, including Q8_0 dequantized weights interpreted as exact FP32 reals, dot/product rounding, sigmoid midpoint cross-checks and a doubled evaluation envelope. The Neumann argument therefore certifies rank 2,048 of the *combined* real-arithmetic FFN observation. A differentiable common encoder `E:R^2048 -> R^r` and differentiable decoder computing this exact output on that neighborhood require `r >= 2048` by the chain rule. This improves the routed-only conclusion's scope, rather than claiming a faster program or a quantization-code lower bound.

The shared gate on this input is 0.07036914, not zero; dropping the shared term merely because it is small would be an approximation. This result is for the decoded GGUF real map, not native FP32 evaluation order, discrete packed labels, other layers, or complete-model language quality. A useful native/representation successor is a paid full-width packed coordinate and direct consumer evaluated on broad quantized producers and disjoint complete-model loss; another narrow smooth exact input factor cannot recover the ninth branch by cancellation.

Replay with `OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 python3 research/moe/routed-jacobian/witness.py --include-shared` from Kelana. No GPU or installed runtime was changed.

The installed Qwen3.6-35B-A3B layer-0 expert bank gives a sharp obstruction to one tempting representation: compress the common 2,048-dimensional expert input into a *narrow differentiable coordinate*, then reconstruct the exact routed weighted sum. On an actual held producer input, the complete variable-score routed sum has a full-rank 2,048 by 2,048 Jacobian, with the installed F32 router included. A differentiable shared input encoder of dimension below **2,048** cannot compute this real-arithmetic routed sum exactly on an open neighborhood of that input. The earlier fixed-score witness and its rank-2,041 bound for arbitrary score derivatives are retained below as the route-independent control.

This says nothing against a packed 2,048-coordinate input, a discontinuous code over finite machine inputs, approximation, or a cheaper program that never forms a shared low-dimensional input. The capture-derived map is the decoded GGUF expert branch, not bit-identical native FP32 execution; the [real-input study](../real-gate-input/README.md) reports 2.01% RMS between its offline reconstruction and native captured routed sum. There is no whole-model quality, inference-rate or kernel-speed claim here.

## Observation and certificate

For one top-eight set, fix the scores `s_e` at their observed values and consider the complete weighted expert branch

```text
F_s(x) = sum_e s_e D_e [silu(G_e x) * (U_e x)].
```

`G_e`, `U_e` and `D_e` are the installed layer-0 GGUF Q4_K/Q5_K matrices decoded to finite FP32 values and interpreted as exact real numbers. The input is the first held layer-0 `attn_post_norm` producer capture. The observed route is `[112,238,120,56,254,153,200,43]`; scores and capture hashes are in the [receipt](/path/to/workspace/data/qwen-moe/routed-jacobian/receipt.json). This observes the entire weighted expert sum after SwiGLU and down projection, not gate channels or an isolated matrix. The full-rank certificate below uses the real softmax of the eight selected logits from the installed F32 router, not the rounded native captured scores.

Writing `g=G_e x`, `u=U_e x` and `t=sigmoid(g)`, its Jacobian is

```text
J_s = sum_e s_e D_e diag(u * (t + g*t*(1-t))) G_e
    + sum_e s_e D_e diag(g*t) U_e.
```

The first version of `witness.py` evaluated this 2,048-square fixed-score matrix, enclosed dot-product and product rounding and compared the floating sigmoid with 50-digit correctly rounded Decimal exponentials at the dot midpoints. It computed an approximate inverse `B`. For the exact real Jacobian `J_s`, its certificate bounded `||I - B J_s||_inf` by **0.0729763144**, including a doubled bound for matrix evaluation and inverse-residual multiplication. Since that number is below one, the Neumann series makes `B J_s` invertible, hence `J_s` has rank 2,048. The midpoint's smallest singular value is `1.52988966e-7`, its largest elementwise Jacobian error envelope is `2.05030615e-12`, and its computed inverse residual infinity norm is `7.85419053e-9`. The script regenerates the inverse; matrix coordinates, source and input hashes are in the receipt. A singular-value threshold alone is not the certificate. The arithmetic envelope assumes correctly rounded IEEE binary64 basic operations, ordinary dot/GEMM error bounds and Decimal's correctly rounded exponential; it is not a formal proof of the native GPU FP32 graph.

Now let the selected expert scores be differentiable functions of `x`, normalized so `sum_e s_e(x)=1`, on a neighborhood where the top-eight IDs stay fixed. Their contribution to the Jacobian is `Y Ds`, where `Y` has eight expert-output columns. Differentiating the normalization shows `rank(Ds) <= 7`. Rank subadditivity gives the original router-independent `rank(J_full) >= 2041` bound. The actual router permits a stronger result.

For the installed F32 router rows `W_e`, the ideal-real selected scores are `a=softmax(W_e x)` and `Ds=(diag(a)-a a^T) W`. The complete derivative is `J = J_a + Y Ds`. The current CPU witness reads all 256 router rows, confirms the same top-eight set with a positive eighth-to-ninth logit margin of **0.08195394**, and encloses both the expert derivative and the score/output rank-seven product. For its computed inverse `B`, the bound on `||I-BJ||_inf` is **0.781664775**, including doubled evaluation and inverse-product errors. That is below one, so `J` is invertible. The midpoint's smallest singular value is `5.82282e-8`; this singular value alone is not the proof. The real selected scores differ by at most `4.712e-7` from the captured native scores, whose FP32 dispatch is a separate map. The source, model, capture, library and midpoint hashes, numerical error envelope and route margin are in the [full-router receipt](/path/to/workspace/data/qwen-moe/routed-jacobian/full-receipt.json). The [fixed-score receipt](/path/to/workspace/data/qwen-moe/routed-jacobian/receipt.json) remains intact.

Consequently, if `F=R(E(x))` on this fixed-route neighborhood with differentiable `E:R^2048 -> R^r` and `R`, the chain rule requires `r>=2048`. This is a local exact-real bound for the routed expert-sum observation. It does not extend through the separate shared expert, residual, subsequent layers or a quantized/discontinuous encoding without another argument. The witness uses IEEE binary64 dot/GEMM error bounds and correctly rounded Decimal exponential comparisons; it is not a formal FP32 GPU execution proof.

This closes every narrow *smooth* exact shared-input bottleneck on this real-input neighborhood, not the cheaper-coordinate search. It does not price a representation or establish a speed bound. A useful next construction keeps the 2,048 local dimensions in lower-paid labels, jointly changes the packed expert consumer and measures complete-model loss at paid image rate. The positive route margin also permits a separate bounded numerical experiment with router derivatives without conflating top-k changes with the weighted-sum approximation.

## Replay

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 python3 research/moe/routed-jacobian/witness.py
```

The CPU script reads the pinned GGUF and its selected runtime decoder, the held producer input, IDs and scores under `/path/to/workspace/data/qwen-moe/`, and writes `routed-jacobian/receipt.json` there. It needs NumPy and no GPU lock. No installed runtime, serving state or model image changed.
