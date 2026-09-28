# Two queries through one sign-orbit code stream

The [single-query SIMD consumer](../SIMD.md) decodes packed five-bit sign-orbit keys with `VPERMB` and `VPMULTISHIFTQB`, then uses `VPERMW` to look up the response to a runtime int8 query. Two queries for the same weight block need the same keys. `paired.cpp` unpacks each key once and reads two independently prepared response tables. Neither trits nor individual weight products reappear.

The complete map is the ordered pair of signed integer dot products, each with 5,120 output rows and 128 arbitrary signed-int8 query coordinates. The 43 chunk response tables for the two queries occupy 5,504 bytes total. Both outputs accumulate in signed16: for any prefix of 128 ternary terms its magnitude is at most `128 * 128 = 16,384`. The final signed16 values widen to int64. The existing [sign-orbit proof](../../../Kelana/SignOrbitConsumer.lean) establishes one table's answer for every query. Applying that identity to each table, and observing that the fused loop feeds both the same key, establishes the two-output equality. This is a source-level map argument, not a native compiler proof.

## Native cost and measurement

The baseline calls the existing SIMD `evaluate` twice on the same packed weights. The candidate keeps eight SIMD accumulators instead of four and loads both lookup tables per chunk, but issues the packed key load, unpack and widening only once. For 5,120 rows, there are 40 groups of 128 rows, 43 chunks and four 32-row tiles: 6,880 key extractions per evaluation. Two independent evaluations perform 13,760; fusion performs 6,880. The packed weight image is 136,960 bytes and the byte-index control is 220,160 bytes. These are block bytes, excluding the unchanged FP16 scales. This count is not an assertion about cache-line transactions or GPU issue cost.

The timed workload comprises 12 pairs of deterministic pseudorandom queries, 17 repetitions of each, rotating AB/BA order for each pair. The fresh arm allocates and prepares both tables inside the timer for *each* method; the warm arm prepares them before the timer. Every row of both queries is compared to an independent scalar dot product on the first repetition, and every timed output to the independent SIMD method. Weight wire round-trip is checked for both formats. `sink` consumes timed outputs. CPU 15 of the Ryzen AI MAX+ 395, GCC 15.3.0, `-O3 -march=native`, one process per prep policy. Medians below are over the 204 individual measurements per cell, in microseconds for **two queries**, not one:

| Wire | Fresh independent | Fresh fused | Fresh ratio | Warm independent | Warm fused | Warm ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Packed sign-orbit | 11.460 | 6.889 | 0.601 | 11.049 | 6.580 | 0.596 |
| Byte indices | 4.690 | 3.510 | 0.748 | 4.590 | 3.400 | 0.741 |

Both outputs match all 12 scalar query pairs at every row. The gain survives including fresh table preparation, although this test reuses the weight block in cache. The raw 1,632 sample records, source and executable hashes live in [`/path/to/workspace/data/kelana-ffn/paired-consumer`](/path/to/workspace/data/kelana-ffn/paired-consumer/README.md). The synthetic inputs are fixed by the xorshift seed `0x4f3a127b`; they are not captured model activations. This is a CPU integer-block result, with no FP16 scales, GPU dispatch, full FFN, or whole-model throughput implied. The single-query GPU sign-orbit lowering [already lost](../gpu-direct/README.md); this experiment changes the next GPU question to whether two output rows can share the packed-key extraction **without** doubling wave register pressure or table traffic enough to erase the gain.

Reproduce with the current single-query header and a local AVX-512VBMI/BW/VL host:

```sh
cd research/quantization-discovery/paired-consumer
g++ -O3 -march=native -std=c++20 -Wall -Wextra paired.cpp -o paired
taskset -c 15 ./paired 17 fresh
taskset -c 15 ./paired 17 warm
```

Each invocation finishes in seconds. `paired` is generated output, not a source dependency.
