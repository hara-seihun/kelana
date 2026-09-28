# Entropy coding changes the frozen narrow-value rate question

The preceding seven-label temporal difference stream [barely saves bytes](../value-delta-suffix/README.md) on the frozen Qwen3-0.6B rank-28 signed-nibble V cache. That result is a limit of its fixed three-bit symbol and escape grammar, not of the labels themselves. I trained one canonical Huffman table per GQA group on eight train windows and encoded four previously inspected 256-token validation windows without changing a single cached code. Every possible difference from -15 to 15 has a codeword. The decoder reconstructs every value label; the preceding integer suffix-mass identity then consumes the differences directly without expanding the absolute cache online.

The exact charged payload includes a packed 112-byte absolute anchor and four-byte block offset per restart, byte alignment for each stream, and 155 bytes/layer for eight tables of 31 five-bit code lengths. A pseudocount gives even unseen train symbols a code. The encoder packs and decodes every held stream and checks the recovered labels. Two layouts expose the price of access: eight group-serial bitstreams per block, or 224 independent coordinate bitstreams per block, with a one-byte length per coordinate and a 28-element prefix sum to find its offset. Every coordinate stream here fits in 255 bytes. The latter can spread decoding across coordinates but pays 224 more bytes and more alignment per block. It is not an append-ready allocation.

| Layer | Restart | Group stream bytes/token | Coordinate streams bytes/token | Previous fixed-three-bit bytes/token | Static nibble bytes/token |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 32 | 103.364 | 113.322 | 114.910 before 35-byte table | 112 |
| 0 | 256 | 102.886 | 104.128 | 114.845 before table | 112 |
| 14 | 32 | 101.415 | 111.397 | 112.067 before table | 112 |
| 14 | 256 | 100.912 | 102.146 | 111.957 before table | 112 |

The new numbers include the 155-byte table once across the 1,024 held keys. At 32-key restarts the group-serial stream beats static nibble on every held window of both layers: layer 0 uses 26,462/26,906/26,268/26,054 bytes versus 28,672 per window; layer 14 uses 25,669/25,913/26,218/25,894. The held group symbol entropies average 3.626/3.559 bits/difference at layers 0/14 for width 32. A short fixed code with five-bit escapes was leaving compression on the table. At 256-key restarts, separately addressable coordinate streams retain 7.0%/8.8% of the static cache-byte saving at layers 0/14, but cannot serve an incremental append without reserving slack, moving subsequent streams or repacking. At 32 keys those streams lose to static at layer 0 and save only 0.603 byte/token at layer 14. An offset instead of a length for every coordinate needs two bytes here, because cumulative group lengths exceed 255 bytes; the listed coordinate layout charges a prefix scan of its byte lengths rather than pretending addresses are free.

## Observation and cost boundary

For each block anchor `a=c_b`, signed difference `d_j=c_j-c_{j-1}`, and integer mass row `m`, the direct response equals `a sum m_t + sum_{j>b} d_j sum_{t>=j} m_t` over integers. Each Huffman symbol decodes a signed difference, so the exact same two-head direct suffix consumer from the parent applies to this new bitstream. The source checks packing, canonical decoding, all recovered code rows, and valid difference values on the held image. This is an exact integer map, not an FP32 bit-identity statement. Weight BPW and the frozen value/O map do not improve; the already reported nibble-versus-E4M3 post-O gap remains.

The group stream serially parses up to 255*28 symbols per group at the long restart, and the suffix reader still needs two backward mass scans, escape-free but variable-length prefix parsing, anchor products and difference products. The coordinate stream permits 224 parallel parsers but must find starts and stores 224 lengths per block. The current signed-nibble reader instead directly addresses each packed key and uses packed nibble dots. These byte counts are not latency predictions. There is no native decoder, full-model loss or GPU measurement. The useful next experiment is an appendable, independently decodable entropy representation with a native fused score/value reader, after jointly fitting a low-difference V producer and post-O decoder on quantized-upstream text. It must beat this cache-byte point *and* pay its append, prefix/suffix scan and decode work; another seven-symbol alphabet sweep is the wrong question.

`measure.py --layer 0` and `--layer 14` run in under one minute each with the pinned CPU PyTorch environment. `/path/to/workspace/data/kelana-subbit/value-entropy-ceiling/layer{00,14}.json` retains per-window bytes for both layouts, the 31 code lengths of every train table, held entropies, bitstream hashes and source/capture/factor/parent hashes. Run from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-entropy-ceiling/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-entropy-ceiling/measure.py --layer 14
```
