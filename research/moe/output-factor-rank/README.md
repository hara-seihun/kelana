# A real routed triple already defeats a narrow exact down-output basis

The installed Qwen3.6-35B-A3B GGUF's **held layer-0 token 113** routes to experts `10,3,239,129,1,225,109,190`. Three of those experts (10, 3 and 1) occur in the retained **original BF16** bank. Their concatenated down projections `[2048,1536]` have rank **at least 1530 over the rationals/reals**, certified by elimination modulo 251. This is the first exact down-output certificate *on a co-routed triple* in this image: the [previous full-rank four-expert certificate](../exact-route-rank/README.md) uses experts 4–7, which this token does not select. It is a restricted negative for exact route-conditioned linear factoring, not a new native speed result.

For independently variable hidden vectors and nonzero route scores, let `D_e: R^512 -> R^2048`. If a shared route-specific linear output coordinate `C: R^r -> R^2048` and factors `B_e` exactly implement `sum_e a_e D_e h_e = C sum_e a_e B_e h_e`, vary one hidden vector at a time: each selected `D_e` must factor through `C`. This triple forces `r >= 1530`, even if the remaining five selected experts contribute no additional rank. An arithmetic-winning dense eight-expert factor needs `8*512*r + 2048*r < 8*512*2048`, or integer `r <= 1365`. At `r=1530`, the factor takes **at least 9,400,320 scalar MACs versus 8,388,608 direct (1.12060546875×)**. Route-specific basis selection, rank-slot traffic and the shared projection can only add work to that dense count. This does not claim a universal ISA bound: packed direct labels, structured/sparse factors, correlated reachable hidden vectors, nonlinear whole-sum observers and lossy approximations remain outside the grammar. A real-arithmetic factor is not a bit-identical FP32 schedule. The observed route comes from the installed quantized GGUF; the coefficient rank is for separately pinned original BF16, **not** the installed Q5_K map or the original checkpoint's own unmeasured routing decision.

This narrows the next representation question. Do not materialize a different exact basis for every observed route hoping that co-selection alone drops the required rank below the dense arithmetic break-even. Capture broad actual quantized producer activations and scores, train a paid approximate shared or packed code against the weighted sum, and require disjoint complete-model language loss and native traffic/time before selection. The existing short-capture [actual-route basis](../real-sum-rank/README.md) loses .709 held relative RMS at rank 512; this exact unrestricted-hidden result neither explains nor rescues that approximation.

## Reproduce and custody

The C++ witness checks the fixed route IDs and the source slice size. Every finite BF16 value is an integer after multiplication by `2^133`; modular elimination gives 1530 nonzero pivots, product 208 modulo 251. A nonzero minor in the field is nonzero over the rationals. Rank **1530 is a lower bound**, not an assertion that the remaining six columns are rationally dependent: modular reduction can lose rank. The first 1366 pivots suffice to cross the cost threshold; preserving all 1530 makes the useful gap explicit.

```sh
g++ -O3 -std=c++17 research/moe/output-factor-rank/witness.cpp -o /tmp/qwen-output-factor-rank
/tmp/qwen-output-factor-rank \
  /path/to/workspace/data/qwen-moe/experts/layer-0-0-16/down_proj.bf16 \
  /path/to/workspace/data/qwen-moe/route-capture/held.0.ffn_moe_topk-0.bin
# held_token=113 experts=10,3,1 stacked_down_shape=2048x1536 rank_mod_251=1530 pivot_product_mod_251=208
```

[The source/binary/input-hashed receipt](/path/to/workspace/data/qwen-moe/output-factor-rank/receipt.json) retains the rank, route and arithmetic count. CPU only; no GPU, packed image, installed runtime or resident service changed.
