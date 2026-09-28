# Pairing temporal key differences before scoring

A direct temporal K-score code need not encode every coordinate's difference separately. I tested a five- or six-bit label for each pair of differences, with a ten-bit escape for pairs outside a train-chosen table. A key's sixteen labels occupy fixed 10- or 12-byte rows. Escapes are in a separate block stream, so the parallel count-prefix and score-prefix construction from [split temporal deltas](../key-delta-parallel/README.md) still applies. The six-bit arm saves only 901 cache bytes on the four inspected layer-14 validation windows against that split scalar code, while adding a 16,384-byte static dictionary and a pair lookup or decoder. It is not a better native target on this frozen image.

## Whole score map

For each GQA group, pair its 32 cached signed-nibble key coordinates. In a 32-key block store the first key in sixteen bytes. Each later key stores one fixed-width label per pair. A label names two signed differences, each in `[-14,14]`; the last label is an escape with two independently packed signed-five-bit differences. Pair dictionaries and the coordinate pairing are fixed across queries. A 32-lane consumer gets its escape-stream address from five cross-lane count-prefix stages and the preceding escapes in its own row from a population count. It can dot the sixteen signed delta pairs against either head's step-scaled query, then scan the 32 scalar scores in five stages. It never forms the preceding absolute key vector.

For real arithmetic, the score identity is `u·c_0 + sum_{j=1}^t u·(c_j-c_{j-1}) = u·c_t` for either head and every possible signed-nibble key history. The encoder and decoder replay *all* frozen held codes, including packed symbol and escape bits, exactly. The finite FP32 score reduction need not reproduce direct per-key dot bits; the previously measured split scalar path already demonstrated that distinction. No language quality changes because the code vector and real score map are unchanged. This is a representation of the K cache, not sub-bit weight storage.

The frozen family has 31 or 63 regular pair symbols plus an escape, with a 32-key restart. On eight Qwen3-0.6B train windows, choose each pair's most frequent joint differences. Adjacent pairing is a control; the other arm maximizes the *sum* of top-symbol train counts over a disjoint perfect matching of 32 coordinates per group. This is exactly the escape-bit-minimizing matching at each width for the fixed table grammar: every escaped pair costs ten bits. Independent byte alignment at each block can reorder candidates within a few bytes, so this is not an optimum over aligned payloads. The tables and matching never inspect the four validation windows.

## Measured rates

All bytes include each block's anchor, byte-rounded escape stream and four-byte offset. There are four 256-token validation windows, eight groups per layer, and 126,976 non-anchor pair positions per layer. The windows were inspected by the earlier cache studies, so these are not fresh model-quality data.

| Frozen cache arm | Layer 0 bytes | Layer 14 bytes | Layer 14 escapes |
| --- | ---: | ---: | ---: |
| Split scalar 3-bit difference plus 5-bit escape | 129,608 | 109,299 | 14,137 coordinate escapes |
| Adjacent pairs, 5-bit labels | 152,489 | 113,703 | 23,299 pair escapes |
| Train-optimal pairs, 5-bit labels | 147,677 | 110,633 | 20,843 pair escapes |
| Adjacent pairs, 6-bit labels | 136,401 | 110,051 | 7,681 pair escapes |
| Train-optimal pairs, 6-bit labels | 131,334 | **108,398** | 6,362 pair escapes |
| Static mixed three/four-bit cache, different score map | 114,688 | 114,688 | none |

The best paired arm saves 0.825% versus scalar temporal deltas at layer 14 and loses 1.33% at layer 0. It stores 63 two-byte pair entries for each of sixteen pairs in eight groups, plus 32 pairing bytes/group: **16,384 static bytes/layer**. Charging that table to one 1,024-token layer-14 sequence turns 108,398 into 124,782 bytes, above both scalar temporal and static mixed. At the measured per-token advantage of 901/1,024 bytes, the dictionary needs at least 18,621 occupied tokens to amortize *against the scalar code*, assuming the held rate remains stationary. The 5-bit matched table costs 8,192 static bytes and still loses cache bytes before metadata.

Each encoded 32-key block retains fixed per-key symbol rows but a variable escape plane. Both heads still pay 32 coordinate products per key if they decode pairs into a direct delta dot. A query-dependent lookup table of pair-score responses instead needs `8 groups × 2 heads × 16 pairs × 63 = 16,128` two-coordinate entries prepared per query and up to 64,512 bytes of temporary FP32 table, before fetching one response per pair/key, correcting escapes, scanning scores, and softmax. The dictionaries, two prefix scans, table traffic, packing, and append update are not free. A six-bit label also crosses a byte boundary on most pair reads. This 0.88-byte/token layer-14 win is too small to justify building that reader ahead of the existing scalar split-code native panel. More pairs, a shared response codebook or codes learned for temporal differences could change the rate substantially; squeezing a *frozen* signed-nibble image with a table built after its producer does not.

The [source](measure.py) uses CPU-only original-producer captures, pinned binary Q/K and the earlier selected signed-nibble cache. Receipts are `/path/to/workspace/data/kelana-subbit/key-pair-delta/layer{00,14}.json`. They retain all pairings, dictionaries, per-window byte counts, escape counts and hashes of source, paid images, model, nibble selection and the scalar predecessor. The payload hash covers all encoded blocks. Reproduction uses the installed CPU environment, with no GPU or Bonsai executable change:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-pair-delta/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/key-pair-delta/layer$(printf '%02d' "$layer").json"
done
```
