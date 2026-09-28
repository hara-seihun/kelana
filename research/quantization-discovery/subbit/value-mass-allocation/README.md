# Headwise probability precision for direct narrow-value attention

A frozen signed-nibble V cache does not require every attention head to quantize its probabilities at the same precision. A mass of 127 gives a nonnegative signed-byte count and **one** signed-byte dot against each packed nibble code. A mass of 4095 uses the existing two-byte-digit construction and **two** dots. Both conserve unit probability mass, so the value center, if present, remains a once-per-query output term. The original 128-dimensional value is never rebuilt.

On the frozen raw-coordinate rank-28 V/O image, an exact train-subset search assigns one-dot counts to 10 of 16 heads at layer 0 and 2 of 16 at layer 14 under a train relative post-O rounding-error budget of 1e-4 against the all-two-dot map. On the four already-inspected original-producer held windows, the selected masks incur 8.52e-5 and 8.65e-5 relative squared post-O error against that map. Layer 0 reduces signed-byte scalar products/key/layer from 896 to 616, but layer 14 only reduces them to 840. This is an achievable CPU arithmetic construction and a frozen-family quality/work trade, **not** native latency or improved language quality. E4M3 still wins the causal-output comparison.

## Map and certificate

For each head, construct prefix-rounded counts `n_t(M) = round(M sum_{i<=t} p_i) - round(M sum_{i<t} p_i)` from its causal probabilities, with final prefix fixed to `M`. Counts are nonnegative, sum to `M`, and assign no count to a masked future key. For a signed-nibble cached coordinate `c_tj` and its paid step `s_j`, the head consumes `(s_j/M) sum_t n_t(M)c_tj`. The center is added once after attention, not once per key. `M=127` counts fit signed byte. At `M=4095`, split `n=lo+256hi` with signed-byte `lo` and `0<=hi<=16`; the two integer dot passes are exact. Each full integer sum is bounded by `7M` and fits signed int32. An int4 cache is unpacked only into the registers feeding the byte dots.

For the real normalized softmax and a length-`T` code sequence, summation by parts bounds each head/coordinate's probability-rounding error at mass `M` by `|s_j|/(2M) sum_{t<T-1}|c_tj-c_(t+1)j|`. The difference between the two mass maps is bounded by the sum of their respective bounds; apply the paid O slice to obtain a post-O bound. It is deliberately loose on jagged code histories. The replay uses FP32 stored softmax probabilities, BF16-rounded producer coordinates and FP32 matrix products, so this real-number bound is not a bit-identity claim.

With frozen probability rows, cache codes, steps and O slices, let `y0` be the all-4095 output and `d_h` the output difference when head `h` uses 127 instead. For a chosen head set `S`, the real-arithmetic mixed output is `y0+sum_(h in S)d_h`. Its squared error relative to `y0` is `1_S^T G 1_S`, where `G_ij=<d_i,d_j>`. Enumerating all 65,536 subsets gives the global minimum train error at every cardinality **within this binary per-head grammar**. This is not an optimum over other counts, trained codes, or native schedules. The FP32 output accumulation is replayed separately for each selected subset; rounding can slightly perturb the quadratic. The mask is static, selected on eight train windows with no held-window labels.

## Frozen Qwen3-0.6B result

Both layers use 256-token original-producer captures, pinned Q/K and the same rank-28 paid V/O factors, raw signed-nibble steps and 112 logical/128 padded value-cache bytes/token/layer as the [integer-value parent](../value-integer-consumer/README.md). The held windows are the four repeatedly inspected validation windows. Relative post-O error in the last column uses the original dense V/O response; the separate rounding error uses the all-4095 direct nibble consumer as its reference.

| Layer | One-dot heads | Train rounding error | Held rounding error | Held error against original V/O | Products/key/layer |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 0 | 0 | 0 | .386705 | 896 |
| 0 | 10 | .00007997 | .00008516 | .386792 | 616 |
| 0 | 16 | .00038201 | .00038642 | .387033 | 448 |
| 14 | 0 | 0 | 0 | .365405 | 896 |
| 14 | 2 | .00008882 | .00008654 | .365493 | 840 |
| 14 | 16 | .01622322 | .01590669 | .378737 | 448 |

Every selected layer-0 held window's relative rounding error is below .000095; the layer-14 two-head mask reaches .000105 on one held window. The train budget is an aggregate, not a per-window certificate. Layer 14 has a sharp knee after four heads: the best fifth costs .000442 train rounding error. The prior one-byte E4M3 cache scores .379186/.326527 against original V/O on these layers, so selecting a better integer schedule does **not** fix this frozen half-byte cache. The mask costs two static bytes/layer. K, Q, the paid 688,128 V/O factor terms/token, V packing, byte/nibble conversion, 16 probability prefix scans/token/layer, 448 post-attention scale terms and O reduction remain. Each one-dot head saves 28 byte products/key, but a native kernel must account for mixed-head scheduling, registers and all preparation. No GPU, Bonsai executable or service state changed.

This tells us where to spend the next experiment: learn the V basis and paid O codes with the int4 cache and its direct consumer on quantized-producer text. A single low-count rule transferred to every layer is wrong even on the original producer. If the trained image survives fresh complete-model loss, compare native mixed-head and all-two-dot implementations at occupied contexts, with E4M3 and quality-matched higher-rate controls.

`measure.py` regenerates `/path/to/workspace/data/kelana-subbit/value-mass-allocation/layer{00,14}.json`. Each receipt retains every cardinality's exact train-selected mask, train/held errors, per-window held rounding error and source/model/capture/factor/parent hashes. From a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-allocation/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-allocation/measure.py --layer 14
```
