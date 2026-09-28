# Parallel direct scores from temporal key deltas

The [temporal score code](../key-delta-score/README.md) saves layer-14 cache bytes but described a serial scalar score scan and a variable-length inline escape parser. Both serial chains are avoidable without adding a byte to its frozen payload. Split each 32-key block into a fixed-width symbol plane and a packed escape plane. One lane reads one key's 12-byte symbol row; a warp prefix count locates that key's escapes. After dotting the signed deltas, a second five-stage warp scan gives all 32 scalar scores. No absolute key vector is reconstructed. This is a checked CPU construction and program-count result, not a native timing result.

## Code and observation

A block stores the first 32 signed-nibble coordinates in 16 bytes. For each subsequent key and coordinate, a three-bit symbol codes differences -3..3, or 7 marks an escape. The 31 rows have 32 symbols each, exactly 12 fixed bytes per row. Put every escaped signed difference, shifted by 14, in a separate five-bit stream in key-major, coordinate-major order. Its range is [-14,14]. Both planes together carry the same `128 + 31*32*3 + 5e` bits as the inline-escape predecessor. Align only the end of each block to a byte and retain the predecessor's four-byte block address. The encoder can append a key with only its immediately preceding 32-code state and its open block streams; it does not select an anchor after seeing future keys.

Assign 32 lanes to a block's 32 keys. Lane 0 gets zero escapes; lane `t>0` counts symbol 7 in its own row. Five inclusive shuffle-add stages produce `P_t`, the escape count before lane `t`'s row. Within a row, `popcount(mask & ((1<<j)-1))` locates coordinate `j`'s escaped payload at bit offset `5*(P_t + local_rank)`. That index depends on preceding lanes' **counts**, not on decoding their code vectors. Each lane independently obtains its signed delta and computes its two observing heads' `u_h·D_t`. Give lane 0 the anchor dot and zero delta. Five more shuffle-add stages produce all inclusive delta-score prefixes; add the anchor score to each lane. Across eight groups, both heads can share the parsed deltas and escape ranks.

For any real query and every signed-nibble code history, the resulting score at key `t` is

`u·c_anchor + sum_{j=anchor+1}^t u·(c_j-c_{j-1}) = u·c_t`.

The equality is telescoping, not a claim about FP32 bits. Softmax across blocks sees the original real scores, including each independent anchor. The row-aligned base and escape count-prefix make all 31 delta dots and all scores within a block accessible with logarithmic cross-lane depth. A lane still loops across its 32 coordinates; no claim of constant work or independently random-addressable *single-key* decoding follows.

## Frozen-image replay and costs

`measure.py` encodes and decodes every 32-key block of four previously inspected Qwen3-0.6B original-producer validation windows at layers 0 and 14. The decoder reconstructs every frozen code for the purpose of checking the codec; the direct score path consumes only deltas. Per-window receipts hash source, model, capture, paid Q/K images, selected nibble-code parent, predecessor and concatenated payload. The split layout has exactly the predecessor's bytes and escapes, not an estimate.

| Four 256-key windows, 8 groups | Layer 0 | Layer 14 |
| --- | ---: | ---: |
| Escapes in 253,952 transitions | 46,628 | 14,137 |
| Split payload, alignment and four-byte block offsets | 129,608 bytes | 109,299 bytes |
| Bytes/token/layer | 126.57 | 106.74 |
| Static mixed three/four-bit control | 112 | 112 |
| Maximum FP32 direct-dot versus five-stage-scan score difference, 256 sampled causal rows | 1.259e-4 | 4.578e-5 |
| Mean direct-to-scan softmax KL on sampled rows | 2.23e-13 | 7.31e-14 |

The observed real score map and frozen quantizer have not changed. FP32 prefix association differs from both direct dots and the earlier serial scan; the sampled KL is not model loss. Layer 0 remains byte-dominated by static mixed. Layer 14 saves 4.70% of cache bytes versus static mixed, still with only 5.26 bytes/token of headroom for parser and shuffle costs.

Each block needs 992 three-bit symbol extracts, one escape test/rank per symbol and its actual escape loads. The held layer-14 blocks average 55.22 escapes and reach 133; layer 0 averages 182.14 and reaches 287. Both observing heads still require 32 query-coordinate products per key, so the split does **not** lower dot work. There are five cross-lane count stages per block and five score stages per query/head/block, along with the anchor dots and a variable escape read. The fixed rows permit coalesced block addressing but a query reads the escape side stream through computed bit offsets. The ten shuffles, extraction, divergent escape loads, registers, softmax and cache layout must be timed together; a stage count is not a latency bound. The encoder's update and final alignment also belong in a native append path. No GPU lock, Bonsai executable or service changed.

This removes the serial-scan objection to a native *experiment*, not the prior rate/cost skepticism. The useful next experiment is one fused occupied-context layer-14 native score/softmax panel, with this split layout against the same-code plain nibble and the train-allocated mixed three/four-bit control. The mixed arm has a different quantized score map, so compare its quality as well as time. Include append/update, both query heads, the scan, actual offsets, cache traffic and numerical quality on the changed FP32 map. Do not build a layer-0 path from this frozen image.

Reproduce a layer in under a minute on the installed CPU environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-delta-parallel/measure.py \
  --layer 14 --output /path/to/workspace/data/kelana-subbit/key-delta-parallel/layer14.json
```
