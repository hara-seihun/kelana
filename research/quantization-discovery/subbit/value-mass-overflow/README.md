# One byte dot plus sparse overflow for narrow values

The [paid rank-28 V/O image](../value-observer/README.md) and [4,095-count signed-byte cache reader](../value-int8-consumer/README.md) already remove the 128-wide value and int4 expansion. That reader splits every attention count into signed low and high bytes, then makes two full byte-dot passes. A different decomposition keeps the count below 256 on the dense path and handles only large counts as exceptions. It produces **exactly the same integer response**, not merely a similar attention approximation.

For nonnegative conserved counts `n_t` with `sum_t n_t = 4095`, set `b_t = min(n_t,255)` and `e_t = max(n_t-255,0)`. For every one of the paid cache's 28 int8 coordinates,

```
sum_t n_t q[t,j] = dot_u8_i8(b, q[:,j]) + sum_{t:e_t>0} e_t q[t,j].
```

All products and sums fit signed int32: `|sum n_t q[t,j]| <= 4095*127 = 520065`. Since every exception has `n_t >= 256`, at most `floor(4095/256) = 15` keys can need a scalar correction for any head/query, at any context length. This bound does not assume sparse softmax or a particular model. The output scale `s[g,j]/4095` remains after the integer response, followed by the same paid two-head O consumer. The identity is over integers and hence over the real-valued scaled count map. It does not assert bit identity with the original floating attention or a different FP32 O fold.

On four previously inspected 256-token original-producer Qwen3-0.6B validation windows at each layer, the executable gathers only nonzero exceptions and scatters their 28-coordinate corrections. It checks all integer responses against a full-count dot using the paid frozen image and the parent FP16-rounded int8 code image. The integer response hashes and model, source, capture, factor image and parent-receipt hashes are in the [data receipts](/path/to/workspace/data/kelana-subbit/value-mass-overflow/README.md).

| Layer | Head/query rows | Overflow keys | Mean per row | Rows with overflow | Maximum seen | Correction products / second causal dot |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 16,384 | 38,246 | 2.334 | 15,745 | 10 | 1,070,888 / 58,949,632 = 1.817% |
| 14 | 16,384 | 40,770 | 2.488 | 16,382 | 9 | 1,141,560 / 58,949,632 = 1.936% |

A causal dense pass over keys `0..s` spends 58,949,632 signed-byte products per layer panel and reads the same 224 logical cache bytes per token. A padded full-256-key pass would spend 117,440,512 products, but that is not the fair baseline. Relative to two *causal* dense dots, this construction removes one 58,949,632-product pass and replaces it with roughly 1.1 million irregular int32 correction products. That is a logical-work result, not a latency ratio. Discovering and compacting exceptions, addressing the same value row for the correction, scheduling one sparse pass per head/query, converting count bytes and paying the existing output projection may erase the gain. Even the worst case has 15 correction keys per head/query, so a native implementation can use a fixed small correction list instead of an unbounded allocator. At long context the dense pass grows with keys, while the correction count remains at most 15 under the same conserved mass.

The next native question is whether a fused count builder emits the unsigned-byte vector and at most fifteen `(key, excess)` pairs cheaply enough that one dense byte dot plus sparse corrections beats two dense byte dots, with identical cache, append, scale, O and head work and occupied contexts. Preserve the 4,095-count quality map. A fresh quantized-producer language panel is still needed before selecting that cache map against E4M3 or BF16. There was no GPU run or engine change here.

From a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-mass-overflow/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
