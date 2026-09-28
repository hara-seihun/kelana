# Exact output rank of installed Qwen routes

## A middle-layer route has full output rank

The previous layer-0 quantization collapse is **not** a generic route-level output coordinate. On the actual held layer-20 token-1 route `172,128,232,255,191,222,178,6`, the installed Q5_K down maps of the **first four selected experts alone** supply 2,048 linearly independent decoded FP32 columns. The existing finite-field witness, applied to the newly saved `[2048,2048]` column image, gives rank 2,048 and pivot product **141 modulo 251**. The eight routed scores are positive. Thus the eight-expert concatenated down map on this route also has exact real rank 2,048. The first four experts' output span already exhausts the output space; layer 0's 42 missing directions cannot be assumed elsewhere.

For the explicit grammar `sum_e a_e D_e h_e = C sum_e a_e B_e h_e` on independently variable 512-coordinate expert hiddens, `C` must have rank 2,048. Its dense scalar-product count is at least `2048*(2048+8*512) = 12,582,912`, against `8*512*2048 = 8,388,608` direct products: **1.5×**, before the boundary and reduction. This is a semantic rank and restricted arithmetic lower bound, **not** a native FP32 bit-identity theorem, total model lower bound or measured speed. Actual routed SwiGLU hiddens are coupled through the common producer, so this independent-hidden premise does not bound an arbitrary nonlinear or producer-domain observer. A quantization-aware packed alternative must pay its representation and native consumer cost. The earlier layer-0 route below is a contrasting installed-image control, not a rank claim for other layers.

This result reuses the original [modular witness](witness.cpp) without a second rank implementation. [`middle_extract.py`](middle_extract.py) checks held IDs and all eight positive scores, decodes exactly four selected expert slices with the installed Q5_K library, and writes their columns in route order. CPU-only reproduction:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=/path/to/workspace/data/qwen-moe/installed-down-rank
$P research/moe/installed-down-rank/middle_extract.py --output "$D/middle-four-route.f32"
g++ -O3 -std=c++17 research/moe/installed-down-rank/witness.cpp -o "$D/middle-witness"
"$D/middle-witness" "$D/middle-four-route.f32"
# prime=251 distinct_columns=2048 output_width=2048 rank_mod_251=2048 pivot_product_mod_251=141
```

[The middle-route receipt](/path/to/workspace/data/qwen-moe/installed-down-rank/middle-receipt.json) hashes extraction source, installed decoder, inventory, route/score arrays, model acquisition, matrix, witness source and executable. Matrix SHA-256 `000d6d0adbbd464db165f7f8a7eb2cd054a755577377dbbdc5d44e00b9fbc161`. No model, GPU, runtime or service changed. **Next:** exact dense common down factors on this representative middle-layer route are a 50% arithmetic loss. A cheaper whole-map result must exploit the *coupled producer* or changed packed labels and then pass a paid complete-image held-language comparison; independently profile the selected native Q8 and routed expert time instead of extrapolating this scalar count to TPS.

The *installed* Qwen3.6-35B-A3B Q5_K down maps on held layer-0 token 113 route to `10,3,239,129,1,225,109,190`. Decoding all eight selected `[2048,512]` matrices with the installed GGML library reveals **2,006 distinct FP32 column vectors among 4,096 columns**. The per-expert counts are `244,210,265,264,231,252,362,178`. A modulo-251 witness finds **rank 2,006** for their concatenation. This is an exact real-arithmetic rank for the *decoded installed image*, not the original BF16 model. Its co-routed four-expert prefix has only **983** independent columns, contradicting the tempting inference from four *different* original-BF16 experts' full rank. That failed first attempt and its decoded matrix are retained in the receipt.

The rank has both an upper and a lower certificate. Within each expert, byte-identical decoded FP32 column vectors are collapsed (the class assignments and counts are hashed). The 2,006 representatives are independent after scaling every finite IEEE754 value by `2^149` and eliminating modulo 251; the pivot product is `61` modulo 251. An integer minor nonzero modulo 251 remains nonzero over the rationals and reals. Hence the eight independently variable 512-coordinate expert hiddens have a **2,006-dimensional** output span, with **42 exact missing output directions**. All eight captured normalized scores for that token are positive, so multiplying expert blocks by their nonzero score does not change this span.

This quantization-induced collapse does **not** make the proposed dense common-output factor cheaper. In the grammar `sum_e a_e D_e h_e = C sum_e a_e B_e h_e` for all independently variable hiddens, varying one hidden at a time forces `rank(C) >= 2006`. Direct down work is `8*2048*512 = 8,388,608` scalar MACs; the factor needs at least `(8*512+2048)*2006 = 12,324,864`, **1.46923828125× direct** before preparation, reduction, scatter or the common basis's storage. Arithmetic savings require integer rank at most 1,365. This is a restricted exact *dense linear factor* lower bound, not an ISA-independent lower bound. A different FP32 reduction order would not reproduce installed finite logit bits just because the real maps agree.

The duplicates identify a different producer-aware opportunity. On this very held token, all repeated-column coordinates of every selected expert have **zero captured post-SwiGLU activation**; the nonzero counts per expert are `228,194,249,248,215,236,346,162`, each on a singleton column. No summing of repeated hidden values is needed to discard them on this observed token. This is consistent with [the installed layer-0 dormant-coordinate audit](../../../../bonsai-halo/docs/qwen-moe-zero-mask-mechanism.md), and the [forty-layer audit](../../../../bonsai-halo/docs/qwen-moe-all-layer-dormancy.md) already shows layer 0's sparsity does not generalize. The rank witness itself assumes unrestricted independent hidden inputs; the one-token zero observation is **not** a proof of reachable-domain invariance, an exact packed Q5_K reader, or an additional forty-layer byte saving. The original BF16 co-route triple has rank at least 1,530, but its coefficients belong to a different map and cannot certify this installed one.

## Reproduce and next experiment

No GPU or engine process is involved. From the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=/path/to/workspace/data/qwen-moe/installed-down-rank
$P research/moe/installed-down-rank/extract.py --output "$D/distinct-down-columns.f32"
g++ -O3 -std=c++17 research/moe/installed-down-rank/witness.cpp -o "$D/witness"
"$D/witness" "$D/distinct-down-columns.f32"
# prime=251 distinct_columns=2006 output_width=2048 rank_mod_251=2006 pivot_product_mod_251=61
```

[The source, library, route, score, inventory, representative image and executable hashes](/path/to/workspace/data/qwen-moe/installed-down-rank/receipt.json) preserve the proof. The original GGUF is pinned by its acquisition receipt; the generated representative image and initial four-bank failed-hypothesis image remain outside Git. This is a CPU proof and structural cost comparison, with no paid replacement image, full-model quality result, native TPS or service change.

**Next:** reject route-conditioned exact dense output factors on this installed route too. For a representation that can win, train packed approximate coordinates against broad quantized producer activations and scores on *many layers*, charge a complete frozen image, and compare disjoint held language loss and native traffic/time. A separate exact selective reader would require a rearranged Q5 image, the per-expert producer zero predicate across all layers, unchanged native accumulation bits or an explicit alternative quality contract, and a measured gain beyond the already small forty-layer dormancy ceiling. Do not treat these duplicated columns as independently available traffic savings on the current densely packed image.
