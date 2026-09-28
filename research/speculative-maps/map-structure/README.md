# Structure of the learned 16-state transitions

The frozen [learned CDFs](../native-learned/README.md) have one useful exact encoding change: all 15 nonterminal cumulative thresholds fit in a byte. The last threshold is always 256, so a 16-byte row carries the same inverse-CDF function as the original 32-byte row on this dataset. A visited-row SSE byte comparison is slightly cheaper than the AVX2 16-bit comparison with 32 active contexts. It does not make full successor-map construction worthwhile for a fresh six-step path.

`census.py` reads `/path/to/workspace/data/kelana-speculative/learned-transition-tables.npz`, SHA-256 `4c946d880fd22c669a71b71f284bb489a9b0863e59df291ea524c369ee551a52`. Its exact counts are in [census.json](census.json). The tensor has 32 contexts, six positions, 16 predecessor states and 16 candidate outcomes. All 32 position-zero tables have identical predecessor rows, as expected from the known anchor. Of the other 160 context-position tables, 159 have 16 distinct rows; one has 11. Across all 3,072 rows there are 2,586 distinct rows. Only 537 rows have fewer than 16 positive outcomes, so a generally sparse-row representation adds indexing for most rows.

Uniform-to-complete-map deduplication is limited too. At positions one through five, the median count of distinct 16-successor maps over all 256 uniforms is respectively 108.5, 116, 115, 124 and 118.5 per context. Their ranges are 10–144, 44–154, 42–149, 53–153 and 34–144. Every position-zero map is constant across predecessor states. In 32,768 seeded six-uniform streams, the complete prefix function has image size one at every position after zero. This is a useful coalescence fact, but it is already exploited by sampling the single visited row; materializing every counterfactual successor later cannot help this single-path contract. Individual maps at the remaining positions have mean image sizes between 3.44 and 3.79. These counts do not imply an efficient table-generation method for new contexts.

`bench.cpp` compares the original AVX2 16-bit visited-row lookup with an SSE byte lookup on the same 8,192 seeded streams, starting in state zero. Both compare all six rows along the actual path and return all six labels. It checks all 32 × 6 × 16 × 256 row/uniform outputs against scalar 16-bit inverse CDF, including ties, then checks complete sampled paths. The byte lookup XORs threshold and uniform with `0x80` for unsigned ordering, compares 16 lanes, and inserts a guaranteed bit at position 15 for the terminal 256. The 16th byte is padding; a 15-byte row would need an overread-safe layout or extra load handling. A producer must check that *each nonterminal CDF is at most 255*. That property holds in this frozen tensor, but is not guaranteed for every future quantized distribution. A table with an earlier 256 needs a different encoding or a wider threshold.

Median nanoseconds per six-step stream, five rotated-order paired trials with 20 repeats of 8,192 streams each, GCC 15.3.0 `-O3 -march=native` on Ryzen AI MAX+ 395:

| Active contexts | AVX2, 16-bit | SSE, 8-bit | Conversion from 16-bit | Bytes for all CDFs, 16-bit → 8-bit |
| --- | ---: | ---: | ---: | ---: |
| 32 | 12.03 ns | 10.98 ns | 22.4 μs | 98,304 → 49,152 |
| 1 | 10.16 ns | 10.20 ns | 0.9 μs | 3,072 → 1,536 |

See [receipt-32.json](receipt-32.json) and [receipt-1.json](receipt-1.json) for trials. At 32 contexts the conversion costs roughly 21,000 sampled streams to repay at the measured ~1.05 ns per stream. If the learned-CDF producer emits byte thresholds directly after checking the range, it can avoid that conversion; this experiment does not measure or modify that producer. At one context there is no reliable online gain. The AVX2 number differs from the earlier [native probe](../native-learned/README.md) because this benchmark has a smaller method/data working set and separately compiled loop. Compare paired figures within this benchmark, not the two reports' isolated baselines. Neither result includes neural scoring, softmax, target verification, or GPU transfer.

Reproduce from the repository root:

```sh
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/speculative-maps/map-structure/census.py
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/speculative-maps/map-structure/run.py --rounds 20 --active-contexts 32
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/speculative-maps/map-structure/run.py --rounds 20 --active-contexts 1
```

The native runner exports the existing CDF tensor to a temporary binary, builds the CPU benchmark, then removes the binary. The NPZ stays under its current data owner; the repository contains scripts and receipts, not another copy of the dataset.
