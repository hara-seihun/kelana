# Packed length directories for direct key-score streams

The previous K-score stream stored each four-row segment length in one byte only after limiting its Huffman tree to depth 15. That is one valid point, but the address directory is itself a small code. Packing its fields and giving exceptional lengths an inline two-byte extension changes the frozen layer-14 four-row image from 97.079 to **96.837 bytes/token** without limiting the original tree. At eight rows per parser, three eight-bit fields occupy three bytes rather than six, reducing the image from 96.419 to **95.669 bytes/token** at the same maximum 256-symbol parser chain. This is a cache-rate construction with a direct score consumer, not native latency or a changed model.

## Format and consumer

Each group/32-key block still has a 16-byte signed-nibble anchor and four-byte block offset. The next 31 signed difference rows are partitioned into fixed consecutive segments of at most S rows. All but the final segment have a fixed-width length field in a byte-aligned directory. Field value `2^b-1` means an inline unsigned 16-bit actual length immediately before that segment's Huffman payload; otherwise the field is the segment's byte length. The last length follows from the next block offset (or the open block's known tail). Directory fields are packed most-significant first; trailing directory bits are padding. No exception is needed for the last segment.

A canonical table selected on eight train windows has at most 16-bit symbols. Therefore four/eight/sixteen difference rows occupy at most 256/512/1024 bytes over the **entire signed-nibble history domain**, including unobserved sequences. The 16-bit extension covers every case. The record encoder and address decoder round-trip every held segment, including lengths and inline exceptional prefixes. The separate Huffman decoder round-trips first held blocks. For both heads, the exact integer/real score is `u·anchor + cumulative_sum(u·decoded_difference)`, so the reader never has to materialize absolute int4 keys. This identity does not promise identical FP32 reduction bits.

The directory and completed segments are append-only within each group's stream. A new segment can append after its predecessors. If its length crosses the sentinel while it is the open tail, insertion of two prefix bytes may move that **current** segment by at most its then-current byte count; completed segments do not move. A native writer could instead buffer the open segment until closure. Either choice costs work. The query reader prefix-scans at most seven directory fields, reads any exceptional length words, and only then addresses its independent Huffman parsers. The extension check and scan are not free even when no held block needs an extension.

## Paid frozen-image rates

Eight Qwen3-0.6B train windows choose one canonical Huffman table per group, then four previously inspected 256-token validation windows charge anchors, offsets, directory padding, payload padding, all exception words and the 155-byte once-per-layer table. The Q/K producer, steps, labels and score map are unchanged. All rates are bytes per cached token per layer, not weight BPW.

| Segment grammar | Max dependent symbols/parser | Layer 0 | Layer 14 | Layer-14 exceptional lengths / 1,024 tokens |
| --- | ---: | ---: | ---: | ---: |
| Four rows, depth-15 tree, seven byte lengths | 128 | 116.112 | 97.079 | 0 |
| Four rows, original tree, seven packed 6-bit lengths | 128 | 116.172 | **96.837** | 3 |
| Eight rows, original tree, three 16-bit lengths | 256 | 115.417 | 96.419 | 0 |
| Eight rows, original tree, three packed 8-bit lengths | 256 | 114.667 | **95.669** | 0 |
| Eight rows, original tree, three packed 10-bit lengths | 256 | 114.917 | 95.919 | 0, guaranteed no exceptional length |
| Sixteen rows, original tree, one 8-bit length | 512 | 113.956 | **94.938** | 0 |
| Static mixed cache | parallel fixed reader | **112** | 112 | none |

The layer-14 four-row arm saves 15.163 bytes/token against static mixed, and every held window is below its 28,672-byte static bill. Its three exceptions add six bytes total, not six bytes per block. The eight-row arm improves the old layout by exactly 768 bytes over 1,024 tokens; the 10-bit no-exception arm still saves 512 bytes over the old layout under every signed-nibble history. Seven and eight directory bits both occupy three bytes at eight rows; eight avoids 27 exceptional lengths at layer 0 without raising the layer-14 rate. Sixteen-row 8-bit has one layer-0 exception and no layer-14 exceptions. Layer 0 remains above static mixed in every arm.

We also solved the train-optimal **fixed per-group segment boundaries** by shortest path in `(segment count, difference-row position)`. For any fixed Huffman table, segment count and maximum rows per segment, segment byte costs add across the training blocks, so this DP is globally optimal within that family. Its 5-bit stored boundaries per group are charged. Eight segments of at most four rows cost 97.121 bytes/token at layer 14 against 96.837 for the fixed packed-directory arm; four segments of at most eight rows cost 96.423 against 95.669. The seven-, six- and five-parser boundary fits cost 98.251, 97.641 and 97.044 with maximum 5, 6 and 7 rows respectively. Each is worse in both rate and maximum parser depth than the fixed four-row packed-directory arm on these held labels. Optimizing where the shorter segment falls is not the missing saving.

The code and source/model/capture/paid-image-hashed per-window receipts are in `measure.py` and `/path/to/workspace/data/kelana-subbit/key-segment-frontier/layer{00,14}.json`. Run with the installed CPU environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-segment-frontier/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-segment-frontier/measure.py --layer 14
```

The next native panel should compare four-row packed-length, eight-row packed-length and static mixed at an occupied context with append, directory scan, two-head direct scores and softmax included. The packed eight-row arm buys 0.75 byte/token over the prior eight-row format without increasing parser depth; whether it buys time depends on the extension branch, length scan and serial Huffman work. Neither weight BPW, whole-model loss, GPU latency, Bonsai executable, service nor serving default changed.
