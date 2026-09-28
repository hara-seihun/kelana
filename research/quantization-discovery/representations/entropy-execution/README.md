# Page-local scale widths pay for dense scans, not sparse routes

A real Bonsai down-projection block has 5,120 rows of 128 ternary weights and one original FP16 scale per row. Its trits are almost maximally entropic, but the scale bit patterns occupy a narrow, locally varying interval. I encoded each 64-row scale page as a 16-bit minimum, an 8-bit width, and bit-packed unsigned deltas. An 81-entry uint32 offset array addresses pages independently. The ternary codes stay in the original 26-byte-per-row base-243 layout. The CPU reader extracts the scale directly from the page and multiplies it by the integer dot; it never expands a weight or scale tensor ahead of the query.

This is a lossless layout experiment. It tests whether variable rate can be confined to a page boundary while keeping row access bounded. The full map for row `r` is `float(sum_i trit(code[r],i) * q[i]) * fp16_to_float(base[page(r)] + delta[r])`. The trit table has 243 entries of five signed digits and is fixed decoder code, not model data. The scale remains the exact original FP16 bit pattern. The reproducer checks every trit and scale before timing and compares all three native consumer checksums for every route.

## Physical bytes and real scale/code census

The pinned [instance](../../instances/bonsai-layer00-down-block0.npz) has 655,360 trits and 5,120 scales. Its SHA-256 is in [results.json](results.json). There are 614 distinct scale bit patterns, with minimum 8,368 and maximum 12,405. The scale high byte is 33 for 2,847 rows and 34 for 2,120 rows; one outlier has high byte 48. Nineteen 64-row pages fit nine-bit deltas, 60 need ten bits, and the outlier page needs twelve.

| Format | Trit bytes | Scale data and metadata | Complete bytes |
| --- | ---: | ---: | ---: |
| Base-243 row plus raw FP16, array of structures | 133,120 | 10,240 | 143,360 |
| Same bytes, separate code and scale arrays | 133,120 | 10,240 | 143,360 |
| Page-local 64-row deltas, including 324-byte offset table | 133,120 | 6,828 | **139,948** |
| Global minimum plus 12-bit deltas | 133,120 | 7,683 | 140,803 |
| Exact 614-entry FP16 dictionary plus 10-bit indices | 133,120 | 7,628 | 140,748 |

The page saves 3,412 bytes, 2.38% of the original image, without changing any coefficient or FP16 scale. Scale payload is 6,504 bytes; the other 324 bytes are the offset array. Byte alignment, three-byte page headers, and the twelve-bit outlier page are included. There is no hidden row-length index. Row `r` loads its page offset and successor offset, then up to three adjacent bytes for the low-endian packed delta. One row takes constant-time address work regardless of the preceding pages' rates.

The page-size sweep in the results gives scale bytes of 10,103, 8,122, 7,192, 6,828, 6,652, 6,608, 6,602 and 6,695 for pages of 8 through 1,024 rows respectively. A 512-row page saves another 226 bytes over 64, but concentrates a random route on larger page extents and does not change the decode work. The experiment times the 64-row choice because it retains a useful small routing unit. Pages cannot be inferred by merely reading a variable stream: the offsets are part of the format.

I also tested whether the scale high byte predicts the weight code. Odd rows fit Laplace-smoothed frequencies for nine two-trit symbols; even rows supply 163,840 held symbols. Unconditional coding estimates 3.169691 bits per pair; conditioning on high byte 33, 34, or other estimates 3.169704. The conditional model *loses* 2.18 held bits in total even before conditional-table metadata. This does not rule out a different joint representation, but it gives no reason to pay for scale-conditioned code tables on this block. The underlying trits have counts 219,840 negative, 214,806 zero and 220,714 positive.

## Native reader cost

The native C++ program keeps the query and these small arrays hot. It uses one captured signed-byte operand, 26 base-243 bytes per row and the exact FP16 scale conversion. Each number is the median of nine runs, in nanoseconds per visited row. The integer dot and FP16 multiplication are included for the `dot` rows; `scale` isolates the address and scale extraction work. Sequential visits all 5,120 rows, random visits the same rows in a seeded permutation, and sparse visits 16 rows from 16 distinct pages. Checksums match all formats within each panel.

| Consumer / route | Raw AoS | Raw SoA | Paged scale |
| --- | ---: | ---: | ---: |
| Dot, sequential | 39.89 | 39.51 | 42.13 |
| Dot, random | 40.54 | 40.73 | 42.61 |
| Dot, sparse | 39.98 | 40.01 | 42.26 |
| Scale only, sequential | 0.30 | 0.30 | 2.29 |
| Scale only, random | 0.31 | 0.30 | 2.35 |
| Scale only, sparse | 0.30 | 0.30 | 2.94 |

The storage gain does not buy a native speedup on this resident block. It adds about 2.1 to 2.6 ns per dot row. Even under the optimistic fiction that every saved byte reduces traffic, recovering 0.666 bytes per row would need effective bandwidth below roughly 0.25 to 0.32 GB/s. More importantly, one isolated sparse row requires its 26 code bytes, a four-byte offset, a three-byte page header, its scale bytes and the successor offset. It can touch more bytes and more cache lines than the original 28-byte row. The full-page byte saving applies to dense scans or capacity, not automatically to sparse expert routing.

There is a straightforward two-level use for capacity-limited inference: store paged scales cold, then expand them into a 10,240-byte raw scale array once when a block becomes hot across many queries. That is a representation lifecycle, not a measured runtime win here. Its expansion, residency budget, traffic and reuse threshold must be priced against the actual expert schedule. The next discriminating test is a real MoE weight block with routed expert traces and a cold-to-hot lifecycle, where both page occupancy and number of queries per hot expert can be measured. This pinned down-projection has no expert routing, so the sparse panel is an access stress case, not a serving trace. No GPU, model quality, or whole-model throughput claim follows.

Run from the repository root with one CPU BLAS thread:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/representations/entropy-execution/measure.py
```

The command builds `reader.cpp` in a temporary directory, checks the exact round trip, runs the paired reader and writes `results.json`. It requires the host's native `g++` with FP16 conversion support. It changes no installed runtime or model image.
