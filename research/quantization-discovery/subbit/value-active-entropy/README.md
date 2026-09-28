# The cost of skipping absolute value rows

The absolute Huffman V cache seemed to offer two savings at once: its layer-0 stored rate beats static nibble, and integer attention can skip rows whose 4,095-conserved probability count is zero. That second saving nearly disappears when the eight GQA groups share one Huffman parser. On four inspected Qwen3-0.6B validation windows, seven of 131,584 causal query/key pairs at layer 0 have zero count in *all* sixteen heads. Layer 14 has 1,134. A row is visited if any head needs it, even though individual heads have many zeros.

This is a CPU original-producer cache and traffic study, not native timing or model loss. It leaves the frozen paid rank-28 V/O image, all signed-nibble labels and the integer value response unchanged. The result changes the native question: do not count each head's zero-mass rows as skipped memory traffic for a cache row shared across heads. If a reader is worth building, compare its real 64-byte requests and variable decode dependency against nibble and E4M3, or train a different producer whose *group-union* count support is sparse.

## Observation and priced grammar

For a causal query and key, let `a_g` say whether either observing head in GQA group `g` has positive conserved integer mass. All eight groups share one append-only key row. With `s` independent contiguous streams, where `s` is 1, 2, 4 or 8, the parser for stream `i` need only decode through the last active group in that stream. If its groups' code-bit lengths are `b_g`, the required prefix is `ceil(sum_(g <= last_active) b_g / 8)` bytes. A stream with no active group needs no parse. The integer response for each head still dots only its positive-count labels. This identity is exact for the conserved counts; it neither asserts FP32 bit identity nor changes the attention approximation.

Each 256-key window has a 32-bit row directory and a four-byte block address. Every row body byte-aligns each stream and stores one-byte lengths for all but the last. Four-bit canonical code lengths, coordinate-to-table assignments and optional position-bank tables are charged once across 1,024 held keys. All sixteen signed-nibble states remain encodable. The train fit partitions coordinates by storage entropy exactly as the [absolute-row baseline](../value-absolute-entropy/README.md), then fits a Huffman tree to stored-label counts plus `lambda` times active-label counts, normalized to equal histogram mass. The fitted `lambda` values are 0, .25, 1 and 4; one or two position banks and one, two or four tables per group are compared. Training uses eight windows. The four validation windows have been inspected by previous studies, so this is a bounded frozen-image comparison, not a new generalization test.

For the strongest parent control, one position bank and four tables per group with `lambda=0`, the charged rate agrees exactly with its independent packing receipt for every stream count:

| Layer | Streams/key row | Stored bytes/key | Active stream starts/query | Decoded prefix bytes/query | Cold union of 64-byte lines/query |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 1 | 92.851 | 128.49 | 10,293 | 11,958 |
| 0 | 2 | 94.288 | 256.07 | 10,280 | 12,144 |
| 0 | 4 | 97.083 | 459.81 | 9,099 | 12,502 |
| 0 | 8 | 102.879 | 725.19 | 8,069 | 13,247 |
| 14 | 1 | 104.100 | 127.39 | 11,486 | 13,243 |
| 14 | 2 | 105.499 | 247.32 | 10,923 | 13,421 |
| 14 | 4 | 108.425 | 461.29 | 10,712 | 13,800 |
| 14 | 8 | 114.167 | 773.63 | 9,905 | 14,502 |

Each query has 128.5 causal keys on average. Layer 0's one-stream reader accesses 128.493 rows per query, so a mass-based sparse row gather cannot save meaningful work on this image. The eight-stream reader cuts logical parsed bytes by 21.61% at layer 0, but increases stored bytes/key 10.80%, cold unique-line traffic 10.78%, and parser starts from 128.49 to 725.19. At layer 14 the corresponding changes are 13.77% fewer parsed bytes, 9.67% more stored bytes/key, 9.51% more cold lines and 6.07 times as many starts. The eight-stream layer-14 rate also exceeds static nibble's 112 bytes/key. The union model includes row directory lines and stream-length headers, charges each 64-byte line once per query, and assumes no line reuse between queries. It does not claim actual DRAM traffic. Cache reuse, divergent parser scheduling, codebook reads, mass creation, output dots and paid O remain unmeasured.

One-parser mass-aware Huffman lengths have little room here. At layer 0, `lambda=.25` changes the strongest control's stored rate 92.8506 to 92.8516 bytes/key and its parsed prefix 10,293.0 to 10,288.8 bytes/query. At layer 14, it changes 104.0996 to 104.0908 bytes/key and 11,486.5 to 11,485.6 prefix bytes/query. A second position bank raises held stored rate for the four-table `lambda=0` arm to 93.322/104.320 bytes/key. These are small code-family effects, not a theorem that all jointly trained labels lack consumer-aware savings. Prefix-bit savings do not buy a line saving in this panel: splitting rows moves starts and headers across more lines.

The next useful question is a native complete reader with one or two parsers at occupied context, or a jointly learned cache/O image whose labels and mass support permit a cheaper *physical* read. Improving the frozen Huffman histogram alone will not pay for variable decoding. The layer-14 [mixed absolute/difference row](../value-absolute-work/README.md) is a separate 100.661-byte/key rate point; its suffix work and extra parsed rows need the same full-consumer accounting.

## Reproduction and provenance

`measure.py` writes prepared signed-nibble codes, per-group/head positive-count exposures and query/key group masks under `/path/to/workspace/data/kelana-subbit/value-active-entropy/`. Its JSON receipts retain source, model, capture, factor, selection and prepared-input SHA-256 identities, all train-fitted tables, held rates and the cold-line calculation. The probability counts use the frozen original-producer Q/K and prefix rounding to 4,095, as in [the integer-mass study](../value-integer-consumer/README.md). The stored-row image is the same paid rank-28 cache as the absolute-row parent.

From a Kelana checkout, each preparation and each scoring command is bounded separately:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  for split in train validation; do
    OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-active-entropy/measure.py --layer "$layer" --prepare "$split"
  done
  OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-active-entropy/measure.py --layer "$layer"
done
```

The complete 16-label Huffman tree and 32-bit directory cover the full signed-nibble history domain; the reported costs, mask union and traffic apply to these 256-token captures and the declared parser/line model. No GPU reservation, engine executable, service or serving default changed.
