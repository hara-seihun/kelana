# Scores directly from self-contained temporal key differences

The [previous cache study](../key-delta-cache/README.md) stores a four-bit absolute key on an escape. That saves one bit per escape, but a random reader must recover the preceding coordinate before it knows the escaped difference. Here an escape instead carries the **signed five-bit difference**. Every stored delta is self-contained, and a query consumes it without reconstructing a vector of absolute key codes. At layer 14 this still uses fewer bytes than the independently addressable 112-byte mixed three/four-bit key cache; at layer 0 it does not. This is a compressed-cache and score-map construction, not a weight-rate improvement or measured GPU speedup.

For a 32-key block, store the first 32 signed-nibble codes as a 128-bit anchor. Subsequent coordinates use three bits for differences in `[-3,3]`; code 7 signals a five-bit two's-complement difference in `[-14,14]`. All nibble codes are in `[-7,7]`, so five bits cover every possible difference. The block has `128 + 31*32*3 + 5e` bits, where `e` is its escape count. Byte-align each block and store its four-byte address separately. A score reader can stream the three-bit symbols, apply a byte-valued signed-delta correction on escapes, and perform its usual two query-nibble dot passes against each 32-coordinate delta. It does not have to load or rebuild an absolute key vector. Variable-length payload addressing, extraction, dot preparation and the scan remain real costs.

For fixed query `u`, define `D_t = c_t-c_{t-1}` as an integer vector. Then the *real* scores in a block obey `u·c_t = u·c_anchor + sum_{j=anchor+1}^t u·D_j`. This is exact for every possible signed-nibble history and every real query, including escapes. Centering the key adds the same per-query score to every key, so softmax can discard that center separately. The recurrence can scan 31 scalar scores after the dot, rather than 31 vectors of 32 keys. Integer query coordinates make the dot and prefix exact in a sufficiently wide accumulator; FP32 dot-and-scan reorders floating operations and is not bit-identical to the per-key dot. No source K or int4-expanded cache need appear in the consumer.

| Four inspected 256-key validation windows, Qwen3-0.6B | Layer 0 | Layer 14 |
| --- | ---: | ---: |
| Absolute nibble bytes over 1,024 tokens | 131,072 | 131,072 |
| Static train-allocated mixed 3/4-bit bytes | 114,688 | 114,688 |
| Signed-delta escapes across 253,952 transitions | 46,628 | 14,137 |
| Delta bits including anchors, before alignment | 1,027,764 | 865,309 |
| Byte-aligned blocks plus four-byte offsets | 129,608 | 109,299 |
| Bytes/token including offsets | 126.57 | 106.74 |
| Max FP32 score difference, sampled causal queries | 1.3733e-4 | 6.1035e-5 |
| Mean direct-to-scan softmax KL, sampled queries | 1.56e-13 | 8.28e-14 |

The layer-14 cache saves 16.61% against the absolute nibble and 4.70% against the **stronger** static mixed cache. Layer 0 saves just 1.12% against nibble and uses 13.01% more bytes than static mixed. The earlier four-bit absolute-escape code uses 120.83/104.96 bytes/token at layers 0/14, but does not offer this direct independent-delta score map. All three caches encode the same frozen key codes, so their ideal real-score/softmax quality is identical; the FP32 differences above measure only score reassociation. The sampled query positions are 31, 63, 127 and 255 on each window and both heads of each group. The KL uses FP64 softmax on FP32 direct and serial-scan scores; it is not language loss.

There is a useful threshold before a native build. With `p` escape frequency among transitions and ignoring per-block byte alignment, the effective bits/code over 32 keys are `3 + 1/32 + 5*(31/32)*p + 1/32` including four-byte offsets per group block. Beating a 3.5-bit/code static mixed cache requires `p < 0.09032`; block alignment reduces that threshold slightly. The observed layer-14 fraction is 0.05567, and layer 0 is 0.18361. At layer 14 the program still spends the same 512 query-coordinate products per key across both heads as the direct two-nibble-dot map, plus about 3.56 escape correction products per key, 31 scalar prefix additions per head per block, variable-length code extraction and offsets. Its input key producer and 512 query-step multiplications/token/layer are unchanged. Traffic savings cannot be multiplied into a latency gain; the next experiment is one *native* occupied-context score panel that includes the payload parser, two dot passes, sparse correction, scalar scan and softmax against nibble and static mixed controls. It should target layer 14 and drop layer 0 unless a new producer lowers its escape fraction below the threshold.

`measure.py` replays the frozen paid Q/K producer and train-selected nibble codes on the four repeatedly inspected original-producer validation windows. The receipts under `/path/to/workspace/data/kelana-subbit/key-delta-score/layer{00,14}.json` include source, model, capture, Q/K image and predecessor hashes, per-window score differences and per-block escape summary. This was CPU-only; no Bonsai executable or service changed. Reproduce one panel with:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-delta-score/measure.py \
  --layer 14 --output /path/to/workspace/data/kelana-subbit/key-delta-score/layer14.json
```
