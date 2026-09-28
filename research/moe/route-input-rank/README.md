# Three actual co-routed experts fill the original input dimension

The original BF16 gate/up preactivations of **three experts on one held Qwen3.6-35B-A3B layer-0 route** have exact rational rank **2,048/2,048**. This closes the five-coordinate opening left by the exact rank-2,043 original-BF16 pair certificate: a common *linear input factor that exposes the selected preactivations* cannot narrow the 2,048-dimensional input, even if the factor is specialized to this one route and only three of its eight experts must be served.

The selected installed-GGUF held-text route is token 113, IDs `10,3,239,129,1,225,109,190` in captured top-k order. Experts 10, 3 and 1 are in the locally retained original BF16 slice. Their stacked original gate/up map has shape `[3072,2048]` and rank 2,048 modulo 251: row elimination picks respectively 923, 898 and 227 independent source rows from the three experts, and the product of nonzero pivots is 189 modulo 251. The elimination only needs these three original experts; the other five IDs identify the actual route, not an assumed random selection. The original BF16 and selected GGUF define different numerical maps, so the route is an observation of routing, **not** a claim that original BF16 would select the same eight IDs if run end to end.

## Scope and cost consequence

Let `A_e` be each original BF16 `[1024,2048]` gate/up map. On unrestricted real inputs, if three co-routed preactivation vectors factor as `A_e x = B_e C x` through a common linear `C: R^2048 -> R^k`, then their stacked rank is at most `k`. The witnessed nonzero modular minor implies rational and real rank 2,048, hence `k >= 2048`. This does **not** require reconstructing individual weights, but it **does** require exposing all three gate/up preactivation vectors. It does not bound a nonlinear map that observes only the final weighted expert sum, a finite producer-reachable input domain, approximate coding, or direct packed labels. Real-factor equality does not imply FP32 bit equality after reassociation.

If the factor is used to feed all eight selected gate/up maps as dense coefficient products, its online scalar-product count is at least `2048*2048 + 8192*2048 = 20,971,520`, versus `8192*2048 = 16,777,216` for the eight direct maps: **1.25× direct** before route dispatch, nonlinearity, down maps, or intermediate traffic. In the same dense equal-precision full-bank grammar, one 2048×2048 common factor plus 256 expert coefficient maps stores **1.0078125×** the direct gate/up coefficients. Neither scalar products nor coefficient count is a measured gfx1151 runtime cost. Structured, sparse, route-dependent or packed factors may have different costs and observations. The stronger downstream [routed-sum Jacobian result](../routed-jacobian/README.md) already establishes full local dimension for one installed GGUF weighted-sum neighborhood, but uses a floating inverse-residual certificate and a different map; this result supplies an exact finite-field original-weight witness at the preactivation boundary.

## Reproduce and evidence

`witness.cpp` checks route length/IDs and the original slice size, converts every finite BF16 value to its exact integer times `2^133`, reduces modulo 251, then performs forward elimination on the complete stacked selected rows. For normal BF16, the scaled integer is `(128+fraction)*2^(exponent-1)`; for subnormal BF16 it is `fraction`. A nonzero 2,048-row minor in this field cannot vanish over the rationals or reals. The field, order and resulting counts are printed for replay. The prime is not a claim about numerical behavior of native BF16 products.

```sh
cd /path/to/workspace/projects/kelana
g++ -O3 -std=c++17 research/moe/route-input-rank/witness.cpp -o /tmp/route-input-rank
/tmp/route-input-rank /path/to/workspace/data/qwen-moe/experts/layer-0-0-16/gate_up_proj.bf16 \
  /path/to/workspace/data/qwen-moe/route-capture/held.0.ffn_moe_topk-0.bin
# token=113 route=10,3,239,129,1,225,109,190 available=10:923,3:898,1:227 rank_mod_251=2048 pivot_product_mod_251=189
```

[The receipt](/path/to/workspace/data/qwen-moe/route-input-rank/receipt.json) ties the pinned original slice, route input, source and compiled witness to this output. CPU only: no GPU reservation, installed native map, service, quality image or throughput changed. The next representation experiment should keep all necessary input distinctions, jointly encode the **actual quantized producer** and packed expert consumer, and judge any lossy image on disjoint complete-model language loss at its paid rate. Another narrow exact dense preactivation factor cannot help this route.
