# Two routed experts already saturate Qwen's gate/up input in 37 layers

The selected Qwen3.6-35B-A3B GGUF has 40 independently quantized 256-expert layers. On the **actual held token-1 route at every layer**, stack the installed decoded `[512,2048]` Q4_K gate and up rows of only the *first two* selected experts. The resulting 2,048-square preactivation map has **rank 2,048 in 37/40 layers**. The three exceptions have exact ranks **1,022 (layer 0), 1,996 (layer 1), and 1,808 (layer 3)**. Every missing rank is accounted for by an exactly zero installed row: respectively 1,026, 52 and 240 zero rows. Across all forty images, **all 80,602 nonzero rows are independent within their layer's two-expert map**. The layer-20 route's pivot product, for example, is 118 modulo 251. The earlier [layer-0 installed witness](../installed-input-rank/README.md) needed five selected experts to reach full rank; this forty-layer census shows that two—the minimum possible with 1,024 gate/up rows per expert—already suffice in 37 layers. Together with that earlier layer-0 route, there is a full-rank actual-route witness in every layer. The previous layer-0 witness uses a **different held token**; this census alone does not certify the eight-expert rank at layer-0 token 1.

For every one of the forty maps, finite decoded FP32 coefficients are exactly rational. Multiply their bit patterns by `2^149` and reduce the resulting integers modulo 251; Gaussian elimination gives a nonzero pivot product for **each nonzero row**. A nonzero modular minor is a nonzero integer minor, hence a real-rank lower bound. Counting all-zero decoded rows gives a matching real-rank upper bound for the three exceptions. This is not a floating-rank threshold. Each route and its eight positive scores are checked against the installed-runtime actual-producer capture; scores do not enter this preactivation map.

**Cost contract.** An exact *common linear input carrier* `E: R^2048 -> R^r` feeding all selected gate/up **preactivations** through linear consumers must have `r >= 2048` on the 37 full-rank two-expert routes, and also on the separately witnessed layer-0 held-token-113 route. For 37 layers this conclusion already follows from just two routed experts. In the dense equal-precision eight-expert scalar-product grammar, adding an explicit full-width common projection to the 8 × 2 × 512 gate/up output rows costs at least `2048² + 8192×2048 = 20,971,520` products against `16,777,216` direct, **1.25×**, before storing a factor, routing or down projections. It cannot buy a cheaper exact preactivation map by narrowing. This does **not** bound a composed SwiGLU/down observation, an input-reachable manifold, a nonlinear or discrete packed carrier, an ISA-specific transform, or finite native FP32 bit identity. The separate [routed-sum Jacobian certificate](../routed-jacobian/README.md) handles the real composed FFN locally on a layer-0 producer neighborhood. No image, executable or service changed here.

## CPU evidence and reproduction

[The forty-layer receipt](/path/to/workspace/data/qwen-moe/installed-gateup-rank/receipt.json) contains the source, decoder, acquisition, inventory and witness executable hashes; every layer's actual route, positive-score capture hash, decoded 16-MiB row image hash, rank, zero count and pivot product. The data directory retains all forty images, per-layer extraction receipts and witness stdout, including nonfull layer-0/1/3 results. `extract.py` uses the selected runtime's Q4_K dequantizer, not a synthetic matrix or official BF16 values; `summarize.py` checks the complete forty-layer image and rank/zero equality. Reuse the already maintained [`installed-down-rank/witness.cpp`](../installed-down-rank/witness.cpp) for elimination:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=/path/to/workspace/data/qwen-moe/installed-gateup-rank
g++ -O3 -std=c++17 research/moe/installed-down-rank/witness.cpp -o "$D/witness"
for i in $(seq 0 39); do
  "$P" research/moe/installed-gateup-rank/extract.py --layer "$i" --output "$D/held-$i.f32"
  "$D/witness" "$D/held-$i.f32" > "$D/held-$i.witness" || test "$i" = 0 || test "$i" = 1 || test "$i" = 3
 done
"$P" research/moe/installed-gateup-rank/summarize.py "$D"
# full_rank_layers=37, nonfull_layers={0:1022,1:1996,3:1808}
```

**Next:** do not fit a narrower exact dense shared *gate/up input* factor on the installed bank. The Q8_1 activation preparation is already shared across selected experts; new MoE representation work should change the paid packed coordinates/consumer against broader actual routed producers and prove held complete-model quality and online cost. For exact runtime work, investigate the ordinary Q8/Q4 device execution regime rather than multiplying the same full-width input by an additional dense basis.
