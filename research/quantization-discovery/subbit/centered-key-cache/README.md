# A centered one-byte cache for the paid Q/K score observer

The paid 128-plane Q/K score map can store signed one-byte key coordinates instead of BF16 without reconstructing a full key. A train-fitted post-RoPE translation is decisive at layer 0: on four previously inspected validation windows, teacher-to-candidate two-head causal KL is **.260361** with train-selected centered/raw groups, versus **.309766** for raw int8 and **.252318** for the real-valued selected-key observer. At layer 14 the raw int8 map is already close: **.308401** versus **.308216** real; train selection of two centered groups reaches **.307843**. These are original-producer CPU attention replays, not a complete-model loss, native timing, or sub-bit weight image.

| Layer | Real paid selected K | BF16 raw cache | Int8 raw | Int8 centered everywhere | Int8 train-selected group arms |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .252318 | .252335 | .309766 | .260476 | .260361 |
| 14 | .308216 | .308212 | .308401 | .308539 | .307843 |

The layer-0 centered map improves all four held windows against raw int8. Layer 14 does not support centering every group; the selected map centers groups 4 and 6 only. Each group picks its raw or centered arm and one clipping quantile from `.99, .995, .999, 1` by finite causal train KL on sixteen queries in each of eight train windows. The four held windows do not choose any scale or group arm. The BF16 center and each group's BF16 quantization step are frozen before held replay. The source, every train candidate, every group center, the selected arm, per-window KL and source/model/capture/paid-image/prior hashes live in `/path/to/workspace/data/kelana-subbit/centered-key-cache/layer{00,14}.json`.

## Whole observation and direct consumer

For one group and a fixed selected set `S` of 32 post-RoPE coordinates, let `b` be its position-independent train center and `s>0` its group step. Store `c_t = clip(round((k_{t,S}-b)/s),-127,127)` as 32 signed bytes per key. For either observing query head, prepare `q'_s = s q_{s,S}` once per query. The consumer scores `q'_s · c_t / sqrt(128)`. The reconstructed score would include `q_{s,S} · b / sqrt(128)`, but that term is identical for every key in this query's causal prefix and cancels **exactly over the reals** in softmax. There is no online restoration of the center and no need to expand codes into a 128-dimensional K. The proof applies even when quantization clips; clipping changes the approximation error but does not change the cancellation. The CPU replay reconstructs `s*c_t` to score in float64, which is algebraically the same score, not a claim of FP32 bit identity to a native int8 dot.

Both arms use identical frozen binary Q/K factors, original-producer hidden states, BF16 projection and normalization, the full 1,024-row K denominator, the 128 selected RoPE planes, and the paid BF16 group affine. The teacher has original Q/K. Only the post-RoPE selected cache rounding changes. Raw int8 uses the same group-scale grammar without `b`, and the BF16 arm rounds the same selected rotated keys. This is a one-byte *cache* experiment: it does not improve stored weight BPW or eliminate full raw K production.

At eight groups times 32 coordinates, the logical and 64-byte-line-padded key payload falls from 512 BF16 bytes to 256 int8 bytes per occupied token per layer. The centered image adds at most 512 FP16 center bytes per layer and sixteen FP16 scale bytes, independent of context length. A mixed layer needs centers only for its selected groups. Key writing adds up to 256 post-RoPE subtractions, 256 scale divisions or reciprocal multiplies, rounds, clips and packs per token. The query prepares 512 scaled coordinates for the two heads per query, which can be reused for all keys in its prefix. Both arms still require 512 scalar score products per key across the two heads; a useful native lowering must actually consume int8 directly, without a BF16/int4 expansion or a per-key floating decode. Cache traffic halves, but the query preparation, integer-to-score conversion, register occupancy and score throughput have not been timed. The 512-byte BF16 selected affine, the paid binary factors and the full K denominator remain unchanged.

The result changes the next question: **can an int8 direct score kernel keep its 256-byte cache advantage after paying for query scaling and packing, and does the centered map retain its small KL gap on fresh quantized-upstream text and complete-model loss?** A native cache allocation alone cannot answer that. If the full K denominator dominates producer work, combine this cache with the already measured sparse K norm before selecting a runtime route. Centering all groups by default is contradicted by layer 14.

Reproduce the bounded CPU panels with the pinned model and captures:

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/centered-key-cache/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/centered-key-cache/layer$(printf '%02d' "$layer").json"
done
```

No GPU reservation, Bonsai executable or resident service changed.
