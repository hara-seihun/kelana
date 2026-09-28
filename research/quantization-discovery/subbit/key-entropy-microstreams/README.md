# Bounded-depth direct K score streams

The frozen layer-14 signed-nibble key differences have a useful middle point between a 31-row serial Huffman parser and 31 independent row parsers. Put four successive difference rows in each byte-aligned Huffman segment. Eight segments within a 32-key restart can decode concurrently; a length prefix locates their starts. On the inspected Qwen3-0.6B layer-14 cache this costs 98.831 bytes/token, versus 105.521 for the previous independently decoded row layout, 94.576 for a single serial group stream and 112 for static mixed three/four-bit keys. The same four-row format costs 116.113 bytes/token at layer 0 and loses to static mixed. This is a rate/dependency construction, not measured native inference.

## Map and addressability

Each group and 32-key block has a 16-byte absolute signed-nibble anchor, a four-byte block offset, and Huffman codes for the next 31 signed difference vectors. Eight train windows choose one canonical code per group over all 31 difference values. The 155-byte layer table stores 31 five-bit lengths for each of eight groups. Segment widths `S=1,2,4,8,16,31` split the 31 difference rows into consecutive runs of at most `S`. Byte-align the runs, and record the byte length of each but the last. Its end is the next block offset. Lengths take one byte at `S<=2`, two at `S=4,8,16`, and none at `S=31`. The trained Huffman tables include 16-bit symbols, so even four rows can take 256 bytes in the full label domain. A one-byte length would fail there despite every observed four-row run fitting. The query reader prefix-scans at most seven lengths for `S=4` to address eight independent parsers.

For either observing head's real prepared query `u`, let `a` be the anchor and `d_t` the decoded vector difference. Then `u·c_t = u·a + Σ_{r<=t} u·d_r`, by induction on `c_t=a+Σd_r`. The reader can dot decoded differences directly and perform a five-stage inclusive score scan over 32 keys. It does not need to reconstruct absolute key vectors or pass through int4. The equality holds for every signed-nibble key history in exact arithmetic. Different FP32 summation order need not preserve score bits. The reproducer round-trips the byte streams, all held differences, and both integer score heads on the first block of every group in the first held window. The parent code checks the other blocks by its own round-trip and difference identity.

The mutable final segment can append without reserving its worst-case fixed-width capacity: keep its last partial byte and bit count at the tail of **each group's separate stream**. Append the next 32 Huffman symbols into that tail, replacing only the prior partial byte and adding new bytes. At segment completion, pad the byte, write its length before starting the next segment, and add an offset when the 32-key block closes. A reader during an incomplete block uses the known context length for its final segment count and end. This requires mutable group tails and a length/offset update, not relocation of prior segments. It does not make variable decode, query-time length scans, concurrent cache updates or allocation free. A single interleaved shared stream would need relocation and is not this format.

## Charged frozen-image result

Eight train windows fix the tables, and four repeatedly inspected 256-token validation windows price the paid binary Q/K projection's unchanged signed-nibble cache. Four bytes per group/block, sixteen anchor bytes, all segment lengths, byte alignment and the once-per-layer table are included. Numbers below are bytes/token/layer across 1,024 held tokens. Maximum segment bytes are observed across this panel, not a worst-case decoder allocation.

| Difference rows/parser | Parsers/group/block | Serial Huffman symbols/parser, at most | Layer 0 bytes | Layer 14 bytes | Layer 14 maximum segment bytes |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 31 | 32 | 124.394 | 105.271 | 22 |
| 2 | 16 | 64 | 118.966 | 99.964 | 43 |
| 4 | 8 | 128 | 117.863 | **98.831** | 66 |
| 8 | 4 | 256 | 115.417 | 96.419 | 115 |
| 16 | 2 | 512 | 114.204 | 95.188 | 220 |
| 31 | 1 | 992 | 113.581 | 94.576 | 412 |

The `S=1` number saves 0.25 bytes/token over the parent row format because the final row's length is implicit. At `S=4`, layer 14 saves 6.69 bytes/token against the parent's row format and loses 4.25 against the fully serial group stream. Each of the four held windows individually costs 25,239, 25,106, 25,503 and 25,200 bytes before the shared table, below the static mixed cache's 28,672 bytes/window. The eight-way parser incurs up to 128 dependent Huffman symbols per segment, then a segment-length address scan and score scan; eight parsers do not imply eight-way GPU speedup. Even ideal dot work is unchanged at 32 coordinate products per difference per head, plus the anchor dots. The paid K producer and full RMSNorm denominator are unchanged. Segment-bit assembly on append, lookup storage, parsed-bit control flow, query preparation, softmax, FP32 rounding, occupancy and whole-model quality remain unpriced.

This middle point changes the next experiment. Native time should compare a fused eight-parser/score/softmax reader with the static mixed and fixed-width parallel score readers at matched occupied context, including append and the paid producer boundary. If variable decode overwhelms the 13.17-byte/token margin over static mixed, jointly train the K producer and independently decoded differences for shorter codes instead of lengthening the serial segment. Layer 0 should keep static mixed on this frozen image.

Run each layer in the installed CPU environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-entropy-microstreams/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-entropy-microstreams/measure.py --layer 14
```

`/path/to/workspace/data/kelana-subbit/key-entropy-microstreams/layer{00,14}.json` contains per-window byte counts, fitted-source and model/capture/paid-image SHA-256 identities, stream digests and maximum observed segment sizes. No GPU, engine executable, service or serving default changed.
