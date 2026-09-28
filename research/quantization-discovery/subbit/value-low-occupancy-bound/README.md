# Group the sparse value heads by count occupancy

The exact radix-128 signed-byte value consumer has a second scheduling coordinate besides subgroup width: which heads share a wave. Its two sparse lists have very different lengths across heads of the same query. Adjacent assignment makes the longest subgroup hold the entire wave, even though the other subgroups have finished. A fixed head assignment selected on training counts changes neither the integer map nor the stored V/O image. In the GQA-preserving version it also keeps each two-head KV group together, so a wave visits the same number of distinct value-cache groups as the adjacent layout.

For each query and digit, let `r_h` be the nonzero list length for head `h`. A 32-lane wave with `g=32/l` subgroups of `l` lanes issues `32 max_h ceil(r_h/l)` lane slots for the heads assigned to it. The two digits can use the same static assignment. We enumerate all partitions of the eight two-head GQA groups into waves: 35 distinct four-group partitions at `l=4`, 105 pairings at `l=8`; at `l=16`, the groups are already whole waves. The train objective is the sum of low and high issued slots. These are **global optima for fixed whole-GQA-group wave assignments on the recorded train rows**. Each wave still reads four or two KV groups respectively, and outputs can be addressed by their original head ID. Their ordering in memory changes, however, and its cost has not been timed.

For comparison, train-only local swaps choose an unrestricted fixed head permutation. A per-query oracle sorts the 16 list lengths independently for *each digit*. Its grouping minimizes the sum of wave maxima: if the sorted lengths are `a_1 <= ... <= a_16`, any partition into groups of `g` has the `k`th smallest group maximum at least `a_(kg)`; grouping successive sorted blocks attains all those bounds. This oracle is not a zero-cost instruction. It changes head assignment per query and per digit, and must pay for sorting, index/accumulator remapping and cache effects. An unconstrained `32 ceil(sum_h r_h / 32)` floor is also recorded, but assumes freely distributable coordinate work and is not a lower bound on this fixed-subgroup grammar's issue time.

Four frozen, repeatedly inspected, 256-token original-producer validation windows have these **low plus high** lane slots, each including idle subgroup lanes but excluding list construction:

| Layer | Lanes/head | Adjacent | Train-optimal whole-GQA grouping | Train-local arbitrary grouping | Per-query sorted oracle |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | 4 | 2,211,136 | 1,924,032 (-13.0%) | 1,777,536 | 1,630,528 |
| 0 | 8 | 2,004,928 | 1,856,032 (-7.4%) | 1,546,400 | 1,422,112 |
| 14 | 4 | 1,991,904 | 1,897,472 (-4.7%) | 1,861,248 | 1,763,968 |
| 14 | 8 | 1,902,400 | 1,820,480 (-4.3%) | 1,760,416 | 1,669,376 |

For layer 0 the GQA-preserving four-lane construction makes sparse low/high's apparent 4.1% saving against adjacent dense-low/sparse-high larger: 2,306,656 to 1,924,032 modeled slots, or 16.6%. This comparison changes *both* low compaction and the wave assignment; it does not assign all the gain to compaction. Layer 14's corresponding difference is 2,283,680 to 1,897,472, or 16.9%. The unrestricted eight-lane assignment has a tempting layer-0 22.9% gain against adjacent eight-lane sparse lists, but its waves visit three to four KV groups rather than two. Do not select it on slots alone. The single-head-wave control and logical-pair floor are in the receipts.

The semantic map remains `sum_t n_t c_tj = sum_(l_t>0) l_t c_tj + 128 sum_(h_t>0) h_t c_tj`, with `n_t=l_t+128h_t`, for each head and coordinate. A fixed permutation only changes which wave computes that head's independently accumulated integer dot; the output address uses the original head ID. Integer partials fit int32 by mass conservation. This does not claim bit identity with a differently ordered floating reduction.

The CPU receipts at `/path/to/workspace/data/kelana-subbit/value-low-occupancy-bound/layer{00,14}.json` include train and held counts, the selected orders, parent/source/model/capture hashes and every slot component. The frozen V/O nibble image still loses to E4M3 in post-O quality. No GPU, quantized-producer model loss, native timing, executable or service changed. The worthwhile native question is a fused occupied-context panel that compares the GQA-preserving grouping to adjacent assignment with the same count scan, list construction, cache gathers, O fold and producer. Only if it pays there should a cross-GQA permutation be considered.

From a Kelana checkout, each CPU panel finishes within the command ceiling:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-low-occupancy-bound/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-low-occupancy-bound/measure.py --layer 14
```
