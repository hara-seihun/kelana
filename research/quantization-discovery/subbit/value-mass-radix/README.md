# The exact value-mass radix should be 128, not 32

The [sparse high-digit consumer](../value-mass-residual/README.md) used radix 32 for the 4,095-mass probability count. That was a feasible signed-byte split, but a poor choice within the same two-digit grammar. Radix 128 cuts its held high-key support from 11.06% to 3.59% at layer 0 and from 8.67% to 3.25% at layer 14. The integer attention coordinate is unchanged. This is an improved logical program and a sharper native scheduling question, not a measured GPU speedup or a repair of the frozen nibble V/O image's quality deficit.

For a nonnegative integer count `n` in `[0,4095]`, let `l=n%128` and `h=n//128`. Then `0<=l<=127`, `0<=h<=31`, and for every signed nibble code `c` in `[-7,7]`,

```
 n*c = l*c + 128*h*c.
```

Both dot operands are signed bytes. Sums over a causal row obey `sum n=4095`, `sum h<=31`, `sum l<=4095`. Thus the complete integer coordinate has absolute value at most 28,665, the low dot at most 28,665 and the high dot at most 217. Integer partial sums fit int32 regardless of key order. The last FP32 scale and paid O consumer can follow the same integer result; different floating schedules need not reproduce their old final bits. At most 31 keys per query/head have `h>0`, independent of context length. No per-key value reconstruction or extra stored model payload is necessary.

Within the grammar `n=B*h+l`, unsigned nonnegative digits, both fitting signed byte for **every** count, and power-of-two `B`, `B=128` is the largest feasible radix. Smaller `B` cannot have fewer high keys, since `h>0` iff `n>=B`. `B=256` makes `l=255` possible and cannot feed a signed-byte dot unchanged. The bound does not apply to signed remainders, multi-pass decompositions, heterogeneous row formats or a different instruction alphabet.

[`measure.py`](measure.py) uses exactly the predecessor's frozen original-producer Q/K probability and prefix-rounding functions. Eight 256-token train windows and four repeatedly inspected validation windows enter each layer panel, with 16 query heads. Model, capture, predecessor source/receipt and new source hashes live in `/path/to/workspace/data/kelana-subbit/value-mass-radix/layer{00,14}.json`. The source checks the digit identity and signed-byte range on all observed counts. The denominator is every causal key/head pair, including zero masses.

| Layer / split | High at radix 32 | High at radix 128 | Ideal two-dot product saving at radix 128 | High-key union for both heads in a group | Radix-128 padded high work, 8 / 32 keys per list |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 train | 456,678 / 4,210,688 | 149,509 / 4,210,688 (3.55%) | 48.22% | 122,186 | 302,776 / 1,047,232 |
| 0 validation | 232,887 / 2,105,344 | 75,633 / 2,105,344 (3.59%) | 48.20% | 61,707 | 151,384 / 524,032 |
| 14 train | 373,338 / 4,210,688 | 138,932 / 4,210,688 (3.30%) | 48.35% | 100,687 | 279,232 / 1,048,576 |
| 14 validation | 182,460 / 2,105,344 | 68,350 / 2,105,344 (3.25%) | 48.38% | 49,133 | 139,264 / 524,288 |

A dense low dot plus a sparse high dot needs `28*(causal pairs + high pairs)` logical signed-byte coordinate products over two heads, compared with `28*2*causal pairs` for two dense dots. Padding the 28 coordinates to 32 for dot8 preserves these ratios. The low pass still visits every key; its nonzero residue occurs on 47.9%/63.1% of layer-0/14 held pairs. The high support's held maxima are 18/15 keys per row, versus a worst-case bound of 31; 90th percentiles are 9/8. In the last 128 positions, only 2.19%/2.19% of causal pairs need the high digit. These are product counts, not a memory-traffic bound.

The catch is SIMD list width. If one 32-key workgroup is reserved per query/head for the correction, the held high work rounds to 524,032/524,288 pairs, only 10.1%/0.4% below radix 32's similarly rounded 582,720/526,336. An eight-key list granularity rounds to 151,384/139,264 pairs, versus radix 32's 307,816/243,112. The native experiment must map several queries/heads to a workgroup or use smaller lane groups to earn the radix gain. It must include count prefix/rounding, selection and compaction, irregular nibble-cache reads, synchronization and the low dot inside its clock. A compacted high list cannot be treated as input. At a 32-lane correction with one row per wave, raising the radix alone barely moves scheduled high work on layer 14.

The same nibble V/O image still loses held original-producer post-O quality to E4M3; no fresh quantized-upstream loss or native timing was taken here. The next experiment is a model-less native panel at occupied contexts with full in-kernel count and high-list preparation, comparing dense two-dot, radix-32 and radix-128 arms at multiple list widths. In parallel, fit the V basis and O codes for the integer consumer on quantized-producer text. Neither logical product reduction nor sparse cache bytes establishes whole-model speed or quality.

From a Kelana checkout, reproduce each CPU panel in under the normal command ceiling:

```
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-radix/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-radix/measure.py --layer 14
```
