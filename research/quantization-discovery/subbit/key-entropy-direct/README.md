# Entropy-coded temporal keys with direct two-head scores

The frozen signed-nibble K cache has more temporal structure than its three-bit-difference/five-bit-escape stream uses. A train-fitted canonical Huffman code over all 31 possible signed differences reduces the layer-14 Qwen3-0.6B cache to 94.58 bytes/token with 32-key restarts, including anchors, block offsets and the 155-byte table. That is 17.42 bytes/token below the train-allocated 112-byte static mixed cache, rather than the preceding fixed stream's 5.26-byte saving. Its one bitstream per group/block is serial, however. Splitting the same code into independently decoded key rows costs 105.52 bytes/token. This buys parallel direct score dots and a five-stage score scan, but only saves 1.22 bytes/token against the existing parallel fixed-symbol stream. The decoder, not just the number of bits, decides whether this is useful.

## Exact map and charged formats

Each group stores a 16-byte absolute signed-nibble anchor at every restart, then Huffman codes for `d[t,j] = c[t,j] - c[t-1,j]`. The train-only histogram pools the 32 coordinates within each group, with one pseudocount on every signed difference from -15 to 15. Canonical code lengths cost `ceil(8*31*5/8) = 155` bytes/layer. For each group/block we charge a four-byte block offset and byte-align each independently addressable stream. A group stream has one parser. A row layout stores one byte of length for each of its `B-1` independently decodable key rows; their maximum encoded length on held text is 22 bytes. A coordinate layout instead stores 32 byte lengths/block and gives 32 independent parsers, but must parse time serially per coordinate. The report charges every length and alignment byte, not just Shannon entropy. It does not charge a native expanded decoder table or open-block append storage.

For any real query vector `u`, the two heads can share the decoded differences and compute their own scalar dots. In exact arithmetic, `u·c[t] = u·c[anchor] + sum_{s=anchor+1}^t u·d[s]`. This induction works for every code history, not only Qwen's reachable labels, and never reconstructs an absolute vector key online. The row stream can parse 31 rows in parallel and use a five-stage inclusive score scan per head at `B=32`, after a length-prefix scan to find each row. It still performs 32 query-coordinate products per decoded key/head, has variable Huffman decoding inside each row, plus anchor dots. FP32 association differs from direct dots, so bit identity is not claimed. The script round-trips every held stream and checks the two-head integer score scan against direct absolute-code dots on the first block of each group at both restart lengths in the first held window.

## Frozen Qwen result

Eight train windows fit the tables; four repeatedly inspected 256-token validation windows supply bytes. The paid binary Q/K factors, full key-norm producer, selected post-RoPE coordinates, centers and signed-nibble labels are unchanged. These are cache bytes, not weight BPW or model loss. The row and coordinate layouts encode exactly the same score map as the group layout.

| Layer | Restart | Held difference entropy, bits | One group stream, B/token | Key-row streams, B/token | Coordinate streams, B/token | Prior parallel fixed stream, B/token | Static mixed, B/token |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 32 | 3.4733 | 113.581 | 124.644 | 124.951 | 126.570 | 112 |
| 0 | 256 | 3.4746 | 112.207 | 123.683 | 113.629 | 126.570 at restart 32 | 112 |
| 14 | 32 | 2.8411 | 94.576 | 105.521 | 105.880 | 106.737 | 112 |
| 14 | 256 | 2.8411 | 92.615 | 103.979 | 94.045 | 106.737 at restart 32 | 112 |

The 32-key layer-14 row stream takes 108,053 bytes over 1,024 tokens; the fixed parallel stream takes 109,299. The serial group stream takes 96,846. All four held windows separately beat 28,672 static bytes at layer 14 in the row layout: 26,948, 26,828, 27,212 and 26,910 before the once-per-layer table. Layer 0's best group stream still loses to the 112-byte static mixed image even at restart 256. The 256-key group/coordinate streams are rate points, not low-latency readers: each parser has up to 255 temporal differences and a 256-key score scan costs eight stages instead of five.

The train-fitted variable code removes the previous fixed alphabet's apparent rate ceiling. But the first readily parallel 32-key lowering has a 1.22-byte/token advantage over the fixed split reader, before variable decode, row-length addressing and append. A native reader for the frozen codes is not justified by that margin. The next experiment should co-train a K producer for shorter *independently decodable* differences and its two-head score observer, while charging append/repacking and native parse/scan time. Increasing the serial restart simply to report 92.62 bytes/token does not solve online access.

Run each layer in under a minute on the installed CPU environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-entropy-direct/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-entropy-direct/measure.py --layer 14
```

`/path/to/workspace/data/kelana-subbit/key-entropy-direct/layer{00,14}.json` holds per-window byte counts, fitted lengths, stream hashes, entropy, source/model/capture/paid-image hashes and maximum row/coordinate stream sizes. No GPU, Bonsai executable, serving default or service changed.
