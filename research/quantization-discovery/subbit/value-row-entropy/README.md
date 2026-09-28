# Append-only narrow-value rows

A frozen signed-nibble value cache can be entropy coded without allocating a worst-case slot for every coordinate. Append one self-contained key row at a time into a block arena. Store a two-byte start offset for each row relative to the restart block, byte-align each of its independently decoded streams, and store one-byte lengths for all streams except the last. The block starts with its packed 112-byte absolute anchor and a four-byte global block address. No old row moves when a key arrives. There is no reserved per-coordinate tail or overflow page. The maximum observed 256-key block is 29,814 bytes; even the eight-stream format fits its 16-bit relative offsets. The per-stream row length fits one byte on every held row. Those are observed limits, not a guarantee for every future signed-nibble history; a native implementation would need a wider address or a guarded block split for a general model.

Eight Qwen3-0.6B train windows fix the parent coordinate-entropy tables and bucket assignments. Four previously inspected validation windows determine the following actual payloads on the paid rank-28 V/O signed-nibble image. At layer 0 there are two canonical tables per GQA group, and at layer 14 four. The table lengths and coordinate bucket IDs cost 338 and 676 bytes per layer, respectively, included once over 1,024 held keys. Each row stream contains complete groups in coordinate order, with a known tree for each coordinate. The encoder packs and decodes every stream and checks its signed differences; anchors and row-offset/length directory are serialized in the image.

| Layer | Restart keys | Independent row parsers | Serial symbols/parser | Charged bytes/token | Static nibble |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 32 | 1 / 2 / 4 / 8 | 224 / 112 / 56 / 28 | 104.940 / 106.291 / 109.152 / 114.672 | 112 |
| 0 | 256 | 1 / 2 / 4 / 8 | 224 / 112 / 56 / 28 | 104.606 / 106.003 / 108.934 / 114.619 | 112 |
| 14 | 32 | 1 / 2 / 4 / 8 | 224 / 112 / 56 / 28 | 102.092 / 103.487 / 106.286 / 111.817 | 112 |
| 14 | 256 | 1 / 2 / 4 / 8 | 224 / 112 / 56 / 28 | 101.713 / 103.151 / 106.011 / 111.702 | 112 |

The eight-parser layer-14, width-256 row costs 28,164/28,427/28,774/28,342 bytes across the four 256-key windows, plus the 676 static bytes. It saves only 0.298 byte/token over static nibble. One parser instead saves 10.287 bytes/token but follows 224 variable-length symbol transitions per key. This is a real append-rate/decode-depth trade rather than the parent's compact offline coordinate streams, whose new differences require relocation, or its fixed no-overflow slots, whose exact worst-case minimum is 361.504 bytes/token on this layer. The width-256 offline coordinate stream is 100.540 bytes/token, but it cannot be appended into that packed layout in place. The row format pays at least a two-byte directory entry per non-anchor key for that ability. Layer 0 cannot afford eight group parsers below the static byte baseline.

For a block anchor `a=c_0`, differences `d_j=c_j-c_{j-1}` and integer attention masses `m_t`, the complete value response in each coordinate is `a sum_t m_t + sum_{j>0} d_j sum_{t>=j} m_t`. Decoding rows in parallel followed by the backward mass scan consumes their labels directly, without creating the absolute value cache. A 256-key layer-0 held integer witness gives -12,615 on both sides, and layer 14 gives 1,683. This identity concerns integer maps; it does not promise the original floating reduction order. The row directory makes each key independently addressable, but parsing each stream remains serial within its group. Probability/count creation, suffix scan, byte-aligned extraction, append bandwidth, irregular gathers and the output projection have not been timed. The paid weight image and its quality are unchanged. No native consumer, full-model loss or serving default is selected.

The useful native experiment is a fused row parser, backward integer suffix scan and paid narrow-value response at occupied context, including one append per generated key. Compare the one/two-parser arms against the direct static nibble and E4M3 consumers under the same V/O producer and quality, then vary the producer only if the latency bill is competitive. Eight parsers have almost no byte margin to fund their decode, so native work should start with the one/two-parser arms, not presume that the highest parallelism wins.

`measure.py --layer 0` and `--layer 14` regenerate the CPU image bills within one command each. Receipts in `/path/to/workspace/data/kelana-subbit/value-row-entropy/layer{00,14}.json` retain every window's bytes, tables/assignments, encoded payload SHA-256, source/capture/factor/parent hashes, maximum block extent and the integer response witness. Run from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-row-entropy/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-row-entropy/measure.py --layer 14
```
