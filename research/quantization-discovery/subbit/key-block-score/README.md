# Independent scores from block-centered key codes

The signed-nibble key cache has a second lossless temporal representation besides the [delta-score scan](../key-delta-score/README.md). Give each group of 32 keys a 32-coordinate signed-nibble anchor. Each key stores a three-bit residual in `[-3,3]`, or the escape symbol plus a signed five-bit residual in `[-14,14]`. A query computes its two anchor dots once per block and dots each packed residual directly. Scores can be read independently and in parallel; no absolute key-vector reconstruction or scalar prefix scan is required. The block-mode anchor beats the independently addressable static mixed three/four-bit cache on the inspected layer 14, but only by 2.42% of its bytes, and needs future keys to choose the anchor. Its streaming first-key version loses even to plain nibble on that layer. This is a useful bound against building a native reader for this frozen key image.

## Exact map and conditional optimum

For codes `c_t in {-7,...,7}^32`, anchor `a in {-7,...,7}^32`, and either observing query `u`, store `r_t=c_t-a`. Every residual fits a signed five-bit field; a three-bit symbol handles `[-3,3]` and the eighth symbol marks an escape. The consumer computes `u·a+u·r_t=u·c_t` over the reals. The real softmax observation is therefore the same as for the frozen nibble cache. Floating score additions can reassociate and need not reproduce native FP32 bits.

Within this 4-bit-anchor, fixed `[-3,3]` three-bit alphabet and five-bit escape grammar, selecting each anchor coordinate independently to minimize its number of escapes is globally optimal for payload size: the three-bit fields and anchors have fixed lengths, and each escape adds exactly five bits. The script enumerates all fifteen anchors per coordinate. Ties choose the least absolute anchor. The theorem is conditional on the *entire block being known*, fixed width, this independent-coordinate grammar and the observed code image. It says nothing about a different learned producer, entropy code or a variable anchor field.

A mode-anchor block of width `T` takes `128+96T+5e` bits, where `e` is its escape count, plus four bytes for its byte offset and up to seven bits of byte alignment. Before alignment, it beats the static 3.5-bit/code cache iff the residual escape fraction is below `0.1-1/T`. At `T=32` that is 6.875%; the observed layer-14 fraction is 5.110%, and layer 0 is 13.571%. The first-key anchor stores its first key only once and encodes `T-1` residual vectors, but is not the blockwise rate optimum. Both variants still need a variable-length parser and sparse escape correction.

## Frozen Qwen3-0.6B receipts

Four repeatedly inspected 256-token original-producer validation windows, eight GQA groups, and the pinned paid Q/K planes and nibble steps. The table charges byte alignment and a separate four-byte offset per group/block. Bytes per token divide the four-window total by 1,024.

| Cache or score map | Layer 0 bytes/token | Layer 14 bytes/token |
| --- | ---: | ---: |
| Plain nibble, independent keys | 128.00 | 128.00 |
| Train-allocated static mixed three/four-bit keys | 112.00 | 112.00 |
| Signed-five-bit temporal delta, scalar score scan, width 32 | 126.57 | 106.74 |
| Block-mode direct score, width 16 | 123.28 | 111.50 |
| Block-mode direct score, width 32 | 122.83 | **109.29** |
| Block-mode direct score, width 64 | 124.42 | 110.05 |
| First-key direct score, width 32, appendable | 145.28 | 128.24 |

The width-32 layer-14 mode encoder chooses 13,395 escapes out of 262,144 residuals, an exact optimum within this fixed grammar for these codes. The direct score saves 2.71 bytes/token versus static mixed but costs 2.55 bytes/token more than signed temporal deltas. It avoids the latter's 31 dependent score additions/head/block at the price of two amortized anchor-score coordinate products per cached key/GQA group across both heads, plus 3.27 sparse escape correction products per cached key/group on average. Across eight groups that is 16 anchor and 26.16 escape products per token/layer. The residual dots still need 512 query-coordinate products per token/layer across eight groups and two heads. Neither this arithmetic count nor the byte count measures a native speedup. Both modes keep the full K norm producer and unchanged weight BPW.

Choosing a mode for a live autoregressive cache requires waiting for the last key of the block. At most 31 incomplete keys must be held as plain nibbles per sequence/layer, up to 3,968 bytes in this layout, before a block can be repacked. The naive exact encoder tests fifteen anchors against 32 keys per coordinate, 122,880 absolute-difference/threshold comparisons per completed layer-wide block, amortized to 3,840 comparisons per appended token; a histogram/window-count implementation might reduce this but is not paid here. An already-chosen first-key anchor can stream without staging. Its measured layer-14 128.24 bytes/token eliminates the supposed rate advantage. Width 16/64 mode arms also lose some savings. The small mode-only rate edge does not justify a native frozen-code build ahead of jointly training a producer that makes *streamable* anchors cheap, or training a lossy score representation with its two-head consumer.

The width-32 FP32 replay dots an anchor and each residual separately on four query positions per validation window and both heads. Maximum difference from direct FP32 key dots is 4.58e-5 at layer 0 and 3.05e-5 at layer 14; average direct-to-block softmax KL over the 256 sampled query rows/layer is below 1e-13. This is numerical reassociation on the same finite code map, not fresh model loss or an FP32 identity claim.

`measure.py` and `/path/to/workspace/data/kelana-subbit/key-block-score/layer{00,14}.json` hold all width/policy counts, window bytes, sampled score comparisons and source/model/capture/paid-image hashes. CPU only. No GPU, Bonsai executable or resident service changed. Reproduce a layer from the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-block-score/measure.py \
  --layer 14 --output /path/to/workspace/data/kelana-subbit/key-block-score/layer14.json
```
