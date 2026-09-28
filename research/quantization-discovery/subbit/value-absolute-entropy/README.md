# Absolute-label rows beat temporal differences on the early value cache

The paid rank-28 Qwen3-0.6B V/O image has a more useful cache coordinate than its temporal differences at layer 0. Encode each signed-nibble value label directly, in an independently addressed append-only key row. The observing attention heads can then multiply decoded labels by their integer probability masses without a backward suffix-mass scan or an absolute-value reconstruction step. This does not alter the paid weight image, cache labels or integer attention response.

Eight train windows fit canonical Huffman lengths to the 16 possible absolute labels. Within each GQA group, one, two or four tables partition coordinates by train-label entropy rank. Every symbol has a pseudocount, so even unseen labels have codes. Four previously inspected 256-token validation windows price one 256-key arena per window. Each row has a 32-bit relative start; a block has a four-byte global address. One to eight separately byte-aligned streams per row pay one byte for each stream length except the last. The static tables store four bits per code length, with paid coordinate bucket IDs. Every held row is encoded, decoded and checked against its original labels. The script retains source, capture, paid-factor, parent-image and payload hashes in the receipts.

| Layer | Tables/group | Parsers/row | Charged bytes/token | Max dependent symbols/parser | Frozen difference-row comparator at width 256 | Static nibble |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 4 | 1 | **92.851** | 224 | 104.606, 1 parser | 112 |
| 0 | 4 | 2 | 94.288 | 112 | 106.003, 2 parsers | 112 |
| 0 | 4 | 4 | 97.083 | 56 | 108.934, 4 parsers | 112 |
| 0 | 4 | 8 | 102.879 | 28 | 114.619, 8 parsers | 112 |
| 14 | 4 | 1 | 104.100 | 224 | **101.713**, 1 parser | 112 |
| 14 | 4 | 2 | 105.499 | 112 | 103.151, 2 parsers | 112 |

The layer-0 one-parser arm saves 11.755 bytes/token against the prior difference row and 19.149 against static nibble. Layer 14 rejects an absolute-only rate replacement, even though it still saves 7.900 bytes/token against static. The table-count controls are in the receipts: layer-0 one-parser rate is 94.319/93.470/92.851 bytes/token for one/two/four tables, all metadata charged. These are original-producer frozen-cache rates on repeatedly inspected windows, not language-loss or latency results.

The 32-bit directory is intentional. The largest observed arena is 24,054 bytes at layer 0 and 26,611 at layer 14 for the four-table, one-parser arm, but a 16-bit row offset does not cover every signed-nibble history. The maximum fitted code length is 11 bits. For a 256-row block, even charging eleven bits for all 224 labels of every row, seven stream-length bytes per row and the full directory, the block occupies at most `1024 + 256*(ceil(224*11/8)+7) = 81,664` bytes, which fits 32-bit relative offsets. For two or more parsers, each non-final stream has at most 112 symbols and therefore at most 154 bytes, fitting the one-byte stream length on the full label domain. The one-parser arm needs no length byte. These bounds use the fitted table's maximum length; new tables must be checked before adopting this format.

There is a stronger consumer distinction than the rate table shows. For conserved nonnegative masses `n_t` with `sum n_t = 4095`, the integer response is `sum_(t:n_t>0) n_t c_t`. An absolute row can be addressed and decoded only when its count is nonzero. Thus no more than `min(T,4095)` of `T` cache rows require a value-code parse at any context, and no absolute value vector appears. The difference-row suffix identity instead multiplies each difference at position `j` by `sum_(t>=j)n_t`; all positions through the last positive count generally have a nonzero suffix, including zero-mass gaps. The directory and probability/count scan still inspect `T` positions, and arbitrary key gathers, output/O folding and count creation remain to price. A longer context is not automatically faster. This is an exact integer observation, not a claim of bit-identical FP32 execution or native elapsed-time savings. The earlier [zero-count panel](../value-zero-compaction/README.md) saw 48.0%/63.2% of causal pairs active at layers 0/14 on the same four-window shape; it did not time this Huffman parser.

Next compare a fused append, mass construction, indexed absolute-row parser, sparse integer value dot and paid O fold against static nibble, E4M3 and the difference-row suffix reader at an occupied context. Layer 0 is the first target. If native random access erases the byte gain, co-train the V labels and output image for directly consumed short absolute codes rather than tune frozen difference tables again. No GPU, Bonsai executable or service changed here.

Reproduce from a Kelana checkout, one CPU panel per command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-absolute-entropy/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-absolute-entropy/measure.py --layer 14
```

Receipts: `/path/to/workspace/data/kelana-subbit/value-absolute-entropy/layer{00,14}.json`.
