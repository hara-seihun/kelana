# Native cost of learned transition maps

The [finite threshold toy](../finite/README.md) found a CPU win for byte-shuffle maps. That win does not carry over to the actual learned CDFs. On the frozen 32-context, six-position, 16-state conditional proposal, the cheapest online map-prefix path took 23.57 ns per stream, while sampling only the six visited rows with AVX2 took 17.80 ns. The proposal's neural scoring, softmax, table generation and target verification are outside this measurement. There is no inference-throughput or GPU claim.

The input is `/path/to/workspace/data/kelana-speculative/learned-transition-tables.npz`, SHA-256 `4c946d880fd22c669a71b71f284bb489a9b0863e59df291ea524c369ee551a52`. [The bridge](../qwen/transition_bridge.py) generated its `cdf` tensor of shape `[32,6,16,16]` from the learned conditional head. Each cumulative row ends at 256 and samples one of 16 top-candidate labels. The same independent uniform per position is shared across counterfactual predecessor rows. Position zero has identical rows because the anchor is known. This is exactly the declared truncated, quantized proposal, not its full-vocabulary continuous distribution. The NPZ belongs to `/path/to/workspace/data/kelana-speculative/`; this experiment reads it and keeps no second dataset.

[bench.cpp](bench.cpp) samples 8,192 seeded, random-context streams, starting at state zero. Every method returns all six emitted states, including all realized-path prefixes. The benchmark adds every output byte to a volatile-bound checksum. Before timing, it checks all 32 × 6 × 256 complete successor maps against scalar inverse CDF, including ties and zero-mass candidates, and checks all emitted paths across the 8,192 streams. The one-context regime validates the first context's maps instead. A full *counterfactual prefix function for every initial state* is more information than a sampled path; map composition computes one internally, but only the six states of the actual path are the common output contract here.

The row-major CDFs occupy 3,072 bytes per context. Direct linear search tests thresholds until success, binary search tests fewer unpredictable thresholds, and direct vector lookup compares one complete 16-candidate row in AVX2 and finds the first upper CDF with a bit scan. Vector map construction transposes the CDFs once, then does 15 AVX2 candidate comparisons over all 16 predecessor states at each position; the prefix consumer composes 16-byte maps with `VPSHUFB`. Scalar construction builds the same maps from 16 row searches; packed nibbles use 64-bit words and scalar composition. The inverse table stores all 256 uniforms for each row in one byte, 24,576 bytes per context; preparation walks each row's CDF intervals once. Neither table construction nor transposition is silently included in the online figures. `prepare_then_walk` builds all six maps before walking; `prepared_walk` and `prepared_prefix` exclude that construction and require a different 96-byte map payload per sampled stream.

Median nanoseconds per six-step stream from five rotated-order, paired short trials, GCC 15.3.0 `-O3 -march=native` on AMD Ryzen AI MAX+ 395:

| Operation | 32 random contexts | One context |
| --- | ---: | ---: |
| Direct linear CDF | 57.88 | 41.58 |
| Direct binary CDF | 75.02 | 56.39 |
| Direct AVX2 row CDF | 17.80 | 14.51 |
| Direct prepared inverse table | 17.17 | 6.48 |
| Construct vector maps then walk | 21.20 | 20.34 |
| Construct vector maps then compose all prefixes | 23.57 | 20.72 |
| Construct scalar maps then compose all prefixes | 405.70 | 160.12 |
| Construct vector maps then pack and compose nibbles | 86.82 | 77.68 |
| Prepared byte maps then walk, excludes construction | 4.46 | 4.39 |
| Prepared byte maps then compose prefixes, excludes construction | 3.52 | 3.56 |

The 32-context transpose took 2.27 μs and adds 98,304 bytes; the inverse-table preparation took 223 μs and adds 786,432 bytes. In the one-context case they took 0.48 μs and 7.62 μs, adding 3,072 and 24,576 bytes. Preparing all 8,192 maps separately took 23.88 ns per stream for 32 contexts and 22.68 ns for one; those maps take 786,432 bytes for the batch. A prepared prefix's 3.52 ns is therefore not its end-to-end cost for fresh randomness. These timing components are not necessarily additive after compiler optimization and cache effects, but their measured preparation and storage cannot disappear. See [receipt-32.json](receipt-32.json) and [receipt-1.json](receipt-1.json) for all five trials and checksums.

The toy's SIMD construction used one cheap threshold for each predecessor. A learned CDF has up to 16 thresholds for each predecessor. Vectorizing across predecessors still gives a competitive map build, but the visited-row AVX2 lookup does only one row per position. The 32-context inverse-table lead over direct AVX2 is about 0.6 ns and varies across trials, too small to pay its 223 μs preparation on short runs. At one context the 24 KiB inverse table sits close to the core and gives a clear online lookup advantage after roughly 950 fresh paths amortize its 7.62 μs preparation against direct AVX2. Byte-map prefix composition itself is cheap once maps exist; making all the unvisited successors is the bill. Packing to nibbles saves half the map bytes but loses at the scalar composition boundary. Balanced prefix trees were not measured here; they can reduce parallel span but cannot repair this single-thread online work deficit. Nothing here prices the larger neural-score/table producer, which must be included before adopting either path in an inference engine.

Reproduce from the Kelana repository root:

```sh
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/speculative-maps/native-learned/run.py --rounds 4 --active-contexts 32
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/speculative-maps/native-learned/run.py --rounds 4 --active-contexts 1
```

The runner uses NumPy to export the existing NPZ CDF to a temporary little-endian binary, compiles the C++ benchmark, runs it, and removes the binary payload. Output is JSON. These are warmed single-thread CPU measurements, with no GPU work or model inference.
