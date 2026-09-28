# Paying for only one Q3_K gate/up bank

**Static Q3_K recoding of either gate or up alone loses roughly 6% of the complete layer-0 routed expert response on held actual producer tokens, for only half the two-bank byte saving.** At equal paid rate, gate-only is slightly less damaging than up-only, but neither is a serving proposal. The errors are nearly orthogonal rather than compensating; quantizing both gives .084997 relative RMS. This closes the cheap idea that one of the two projections might carry almost all the recoding error and the other could be shrunk nearly for free. The next useful quantizer must fit the nonlinear weighted sum on substantially broader producers and pass complete-model held language loss.

| Decoded installed layer-0 gate/up image | Bank bytes across 256 experts | Conditional forty-layer one-read saving | Routed-sum relative RMS, train / held |
| --- | ---: | ---: | ---: |
| Q4_K gate + Q4_K up | 301,989,888 | 0 | 0 / 0 |
| Q3_K gate + Q4_K up | 266,338,304 | 44,564,480 bytes (1.697% of complete modeled one-read) | .060875 / .058834 |
| Q4_K gate + Q3_K up | 266,338,304 | 44,564,480 bytes (1.697%) | .065259 / .061111 |
| Q3_K gate + Q3_K up | 230,686,720 | 89,128,960 bytes (3.394%) | .089569 / .084997 |

The two one-bank error vectors have cosine .00849 train / .00441 held in the flattened complete score-weighted output, and the nonlinear interaction `y_both - y_gate - y_up + y_reference` is .00840 / .00791 relative RMS. Their errors add approximately in quadrature, not by cancellation. A free hindsight *per-token* choice of which entire bank to recode, with the same one-bank rate and knowledge of the resulting error, would lower held RMS only to .056765; gate-only wins 78 of 126 held tokens and up-only wins 48. This oracle is not a realizable encoder with no selection cost, but bounds the benefit of merely switching these two static images after seeing a token. It does not bound newly trained weight codes, expert-specific allocations or a direct packed computation.

The observation is the complete eight-selected-expert weighted down-output sum for each actual layer-0 producer input, selected expert IDs and normalized scores on 113 train and 126 held tokens. Each Q3_K bank is the **already paid native GGML image** obtained by `quantize_q3_K` from the decoded installed Q4_K image in [the two-bank study](../gateup-q3-recode/README.md), not an idealized entropy rate. Q4_K down and the other gate/up bank remain unchanged. CPU FP32 BLAS and sigmoid/SwiGLU feed FP32 down projections; the routed sum accumulates in FP64. RMS divides total squared error by total squared decoded-Q4 reference response. Running both Q3 banks reproduces the original .089569/.084997 response RMS, providing a direct cross-study control. The modeled byte budget is 2,626,187,904 bytes per generated token; its savings grant eight separate image reads per layer across all forty layers, not measured DRAM transactions, GPU instruction costs, prompt grouping or model TPS.

[Raw receipt](/path/to/workspace/data/qwen-moe/gateup-asymmetry/receipt.json) SHA-256 `715d89f0ba1004c754b021c3b3bd1be89e4f7b803d2ddaeb10e6c24f4713feb6` binds source, each of eight Q3 image shards, installed library/model inventory, both capture splits and eight raw response shards. It records each token's squared error, the denominator, the interaction and error cosine. No GPU, installed image, serving binary or service state changed. Local response loss is **not** complete-model held loss or native FP32 bit identity. The ternary 0.6B and sub-bit pilots demonstrate why a local error should not select an approximate serving image.

From a registered Kelana writer, with the preceding Q3 image shards retained:

```sh
for i in 0 1 2 3 4 5 6 7; do
  OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 python3 research/moe/gateup-asymmetry/measure.py --part "$i"
done
OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 python3 research/moe/gateup-asymmetry/measure.py --combine
```

**Next:** either fit producer-aware codes jointly against gate/up → SwiGLU → routed sum with sufficiently broad expert coverage, or evaluate a paid expert-specific Q3/Q4 allocation as a frozen forty-layer complete-model image. The slight gate preference does not justify two native format dispatches by itself. The separate ordinary Q8/expert phase diagnosis is a more direct engine question.
