# Fixed-width pair rows for the narrow value cache

A directly addressable value row need not follow 224 Huffman transitions. The frozen paid rank-28 Qwen3-0.6B V/O cache has 112 pairs of signed-nibble labels per key. Store a fixed-width symbol for each pair, with an all-ones escape followed by its raw eight-bit pair. A row has one byte-aligned fixed plane and one escape tail. For pair `k`, the address of an escaped byte is the population count of earlier escape symbols. The direct integer attention response multiplies its two decoded labels by the same conserved mass; it never builds an int4 value vector. This is a source-level consumer construction, not a native timing result.

The table for each pair takes the most frequent absolute label pairs on eight train windows. The fixed-width controls use 4, 5, 6 or 7 bits for every pair. A train-only mixed arm selects 4–8 bits per adjacent pair, charging a three-bit width ID; eight bits means a raw byte with no table or escape. Each table entry is one byte. The greedy-pair control chooses disjoint coordinate pairs by train frequency and charges two five-bit indices per pair. All 1,024 labels rows on four previously inspected validation windows round-trip after bit packing, including their escaped symbols. Exact integer values imply identical mass-weighted responses in integer arithmetic, independent of row visit order. This does not claim the FP32 accumulation order is unchanged.

| Layer | Arm | Charged bytes/token | Static bytes/layer | Escapes in four held windows | Comparator |
| ---: | --- | ---: | ---: | ---: | --- |
| 0 | Adjacent, five bits | 101.421 | 3,472 | 26,639 | 112 static nibble |
| 0 | Adjacent, mixed widths | **100.560** | 5,147 | 16,914 | 92.851 absolute Huffman |
| 14 | Adjacent, six bits | 122.234 | 7,056 | 30,032 | 112 static nibble |
| 14 | Adjacent, mixed widths | **110.231** | 2,682 | 6,755 | 101.713 difference Huffman; 104.100 absolute Huffman |

The mixed layer-0 image saves 11.440 bytes/token against static nibble, but pays 7.709 more than the absolute Huffman row. It has no data-dependent symbol-chain depth, instead needing 112 fixed bit extractions, escape ranks, table lookups or raw-byte reads, and two integer mass products per pair. At layer 14 mixed widths barely beat static nibble on bytes, and lose substantially to either Huffman image. Train-selected greedy pairing loses to adjacent mixed width on layer 0 at fixed widths; its selection charge and the row alignment eat the small hit-rate gain. This is a frozen-image rate/dependency trade, not a claim of higher quality or lower elapsed time. The paid factor and code labels are identical in each comparator.

A two-byte block-relative row directory is valid for *every* signed-nibble history in this grammar, not only the observed rows. For fixed width `b <= 7`, the row costs at most `14b + 112 <= 210` bytes: 112 symbols at `b` bits plus 112 raw escapes. A mixed row cannot exceed 224 bytes, since each pair costs at most eight code bits and one eight-bit escape. A 256-row arena with its 512-byte directory therefore occupies at most `512 + 256*224 = 57,856` bytes. Four bytes locate each arena globally. New rows append without moving any previous row, and their known fixed plane plus an escape rank gives independent pair access. The fixed table index and bit offset for each pair depend only on the static width schedule; no earlier pair must be decoded to locate it. The directory cost is two bytes per token and the block pointer adds four bytes per 256 tokens. A coordinate-wise Huffman image cannot borrow this two-byte guarantee merely from its small observed extent: its full-domain maximum exceeds 65,535 bytes.

A decisive next test is native fused append, conserved-mass construction, sparse absolute-row gather, fixed-width pair decode and paid post-O response on layer 0 against the matched nibble and absolute-Huffman readers. Charge index scans, escape ranks, scattered gathers and actual occupancy. The 7.709-byte/token penalty to Huffman buys random-access decoding without a serial Huffman chain; whether it buys time is the experiment. The layer-14 1.769-byte/token advantage over nibble leaves little room for that machinery. A better learned producer could put more common pairs into short tables, but changing the frozen pair selector alone is not the next useful experiment. There was no GPU run, model loss change, Bonsai executable or service change.

Run from a Kelana checkout with the existing CPU environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-pair-absolute/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-pair-absolute/measure.py --layer 14
```

Receipts under `/path/to/workspace/data/kelana-subbit/value-pair-absolute/layer{00,14}.json` retain per-window sizes, escape counts, all pair tables and widths, packed payload hashes, and source/capture/factor/parent-image hashes. The scripts regenerate both images from train-only tables and test the packed decoder against every held row.
