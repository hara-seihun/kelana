# Native direct consumer

[`direct_consumer.cpp`](direct_consumer.cpp) measures exact integer matrix-vector products from dense ternary weights, three compact base-3 layouts and two [sign-orbit SIMD layouts](SIMD.md). It is a CPU experiment, not a GPU kernel or a full inference benchmark. The original FP16 scales stay outside the timed integer block.

## Build and run

```sh
g++ -O3 -march=native -DNDEBUG -std=c++20 -Wall -Wextra -Wpedantic \
  research/quantization-discovery/direct_consumer.cpp -o direct_consumer
./direct_consumer WEIGHTS_I8 QUERIES_I8 ROWS COLUMNS QUERY_COUNT REPEATS
```

`WEIGHTS_I8` is a row-major `ROWS x COLUMNS` array whose bytes must be `-1`, `0`, or `1`. `QUERIES_I8` is a row-major signed-int8 `QUERY_COUNT x COLUMNS` array. The program rejects size mismatches and dimensions that could overflow an int64 result. The SIMD-inclusive panel limits columns to 255 so every signed16 partial sum remains in range; it requires AVX512VBMI, BW and VL.

The program writes one `kelana.direct-consumer.v1` JSON object to stdout. `formats` gives the exact bit layout and byte count. `methods` contains all output checksums, exact-match status, timing samples, and per-query summaries. Repeated samples use query-major order. P50 and p90 are nearest-rank statistics.

## Compact layouts

Each chunk encodes trits as base-3 digits `trit + 1`, with the first column in the least-significant digit. Codes are bit-packed into one continuous row-major stream. Rows use a fixed bit stride and are not byte-aligned, so no row-offset table is stored. The format reports any padding trits, final byte padding, and offset bytes even when those counts are zero.

For 128 columns the layouts are:

| Layout | Chunk plan | Row bits | Lookups per row | int16 LUT bytes per query |
|---|---:|---:|---:|---:|
| `packed_base3_k5` | 25 x 5, then 3 | 205 | 26 | 12,204 |
| `packed_base3_k8` | 16 x 8 | 208 | 16 | 209,952 |
| `packed_base3_mixed5_6` | 16 x 5, then 8 x 6 | 208 | 24 | 19,440 |

The mixed sequence repeats for dimensions above 128. Every layout uses a true short final chunk rather than encoding semantic padding when the dimension ends partway through a chunk.

The scalar packed methods extract each code and decode its base-3 digits. The direct methods instead prepare one response table per chunk for the current query, then sum one table result per chunk and row. Lookup preparation enumerates base-3 states with a carry counter. This is the standard base-3 table technique; there is no invention claim.

Compact evaluation receives only the packed bytes, chunk metadata, and query-dependent LUT. It does not retain decoded ternary rows. The benchmark process also keeps the source int8 matrix because it times the dense control in the same run.

## Timing contract

Dense and scalar methods report `evaluation`. Direct methods report:

- `preparation`: allocation and complete LUT construction for one query;
- `cold_evaluation`: evaluation immediately after a fresh preparation;
- `cold_total`: one clock interval around both steps;
- `warm_setup`: the separate preparation used by the warm arm;
- `warm_evaluation`: repeated evaluation with that query's LUT reused.

Every captured and control query takes every route. The program compares every row result with the dense int64 output outside the timed interval. It also emits FNV-1a checksums over canonical little-endian int64 output arrays. Dense accumulation uses int32 when `COLUMNS * 128` fits, then widens the row result to int64. The dense helper also has an int64 route, but the SIMD-inclusive panel rejects dimensions above 255. `dense_evaluate` is kept out of line to stabilize control code generation; [SIMD-CODEGEN.md](SIMD-CODEGEN.md) records the audit.

The `paired_` methods rotate dense, packed SIMD and byte-index SIMD order on every repetition and query. Their `evaluation` times include fresh query-table allocation, construction, evaluation and destruction. Use these paired totals for SIMD/dense comparisons rather than combining standalone timings. The runner records CPU affinity and selects a lightly occupied SMT sibling group unless `KELANA_BENCH_CPU` is provided. All formats reconstruct or compute exact integer responses; prepared-table workspace is reported separately from persistent weight bytes.
