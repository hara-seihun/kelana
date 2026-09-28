# Installed co-routed gate/up input rank despite layer-0 dormancy

The **actual installed Qwen3.6-35B-A3B Q4_K gate/up** maps of five experts on one held layer-0 route already have **full 2,048-dimensional exact real input rank**. This resolves the numerical-image mismatch in the earlier original-BF16 co-route witness: the same conclusion holds for decoded coefficients from the serving image, even though most layer-0 gate/up rows quantize to zero. It closes only an exact *common linear input factor that exposes gate/up preactivations on unrestricted real inputs*, not the nonlinear weighted-sum observer or direct packed computation.

The held installed-GGUF token 113 route is `10,3,239,129,1,225,109,190`, with eight positive captured scores. Decode the two `[512,2048]` Q4_K maps for each selected expert using the installed GGML `dequantize_row_q4_K` and remove **entirely zero** rows. Gate and up have the same zero-row masks for every selected expert; per-expert live counts, each repeated twice, are `228,194,249,248,215,236,346,162`. Thus 3,756 of the original 8,192 gate/up rows remain. The first four experts contribute 1,838 live rows. The first **210** nonzero gate rows of the fifth expert supply the remaining pivots: the first 2,048 decoded nonzero rows produce 2,048 nonzero pivots with product **190 modulo 251** after multiplying each finite IEEE754 binary32 coefficient by `2^149` to make it an exact integer. The incremental echelon witness reports rank 2,048 (each successive row introduces a new pivot), so the 2,048-square minor is nonzero over the rationals and reals. No float-rank tolerance is used.

Let `A_e` be these decoded gate/up linear maps on the fixed route. If `A_e x=B_e Cx` for the five selected experts on **all** real `x`, with common linear `C: R^2048 -> R^r`, stacking their rows forces `r >= rank([A_e])=2048`. Adding the other three experts cannot reduce rank. Under dense scalar-product accounting for eight experts, the common factor adds `2048²` to the original `8192*2048` direct products: **1.25×** the direct arithmetic, before routing, producer preparation, materialization and memory. If one first compacts exact zero rows, direct live work is `3756*2048=7,692,288` MACs, while a dense full-width common factor plus these live maps costs `11,886,592`, **1.54526×** that stronger control. This is not a measured hardware time: quantized native block readers and scale layout do not automatically support zero-row skipping, and the [all-layer census](../../../../bonsai-halo/docs/qwen-moe-all-layer-dormancy.md) rejects extrapolating layer-0 sparsity to forty layers. Real factor equality also does not imply native FP32 bit identity.

The full rank applies to exposing those **preactivations** for arbitrary inputs. The actual post-attention producer may occupy a smaller reachable subset; SwiGLU/down/score composition might identify inputs that the separate gate/up vectors distinguish. An exact shared *nonlinear* observer or a lossy, producer-trained packed representation remains open. The independent full-rank [routed-sum Jacobian witness](../routed-jacobian/README.md) gives a stronger local real differentiable whole-sum obstruction at another installed-map boundary; this modular witness specifically isolates how the installed Q4_K preactivation image behaves despite its zero rows.

## Reproduce and custody

From the Kelana root, CPU only:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=/path/to/workspace/data/qwen-moe/installed-input-rank
$P research/moe/installed-input-rank/extract.py --output "$D/nonzero-gate-up-rows.f32"
g++ -O3 -std=c++17 research/moe/installed-input-rank/witness.cpp -o "$D/witness"
"$D/witness" "$D/nonzero-gate-up-rows.f32"
# prime=251 input_width=2048 available_nonzero_rows=3756 rows_read=2048 rank_mod_251=2048 pivot_product_mod_251=190
```

[The hashed receipt](/path/to/workspace/data/qwen-moe/installed-input-rank/receipt.json) binds extraction source, native library, model inventory and route, complete decoded nonzero-row image, proof source and executable. It preserves the full extracted matrix beyond the witness prefix for other exact-domain questions. This CPU construction changes neither model image nor runtime or service; no GPU, complete-model language quality or speed was measured.

**Next:** stop narrowing exact dense common preactivation factors on this installed route. A meaningful MoE representation needs broader actual quantized-producer routes across layers, a paid complete image and held language loss before native cost/timing. An exact packed sparse consumer instead needs a paid rearranged image and an all-layer selective-work/traffic study; this proof alone does not buy a skip.
