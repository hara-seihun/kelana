# The zero-mass cost of a wider value radix

The biased radix-256 value-mass identity halves the high-digit list relative to radix 128, but it turns every zero-mass key into a nonzero low operand. On the frozen Qwen3-0.6B attention rows, compacting both unsigned radix-128 lists beats the biased radix-256 dense-low program's modeled four-lane dot work at layer 14. Layer 0 can save a little by choosing the program per fixed wave, but that saving is smaller than the prefix bookkeeping even as a count of coordinate operations. This is a bounded negative for a **256-token, two-list, four-lane** consumer, not a GPU timing or a statement about longer occupied contexts.

## Exact boundary

Let `n` be an integer count between 0 and 4095, `c` any signed-nibble value code and `B` a radix. An unsigned two-list representation `n=l+B*h` with `0<=l<=127`, `0<=h<=127` needs `32<=B<=128` if `l=n mod B` and `h=floor(n/B)` must cover the full domain. Radix 128 minimizes high-list support among these radices, though it need not minimize the sum of both padded list costs on every distribution. We measured radices 32, 64 and 128 rather than assume that support theorem decides SIMD scheduling.

There is also a structural trade. Suppose zero-count keys must contribute to neither dot, the low operand is one signed byte, and every count up to `T` must avoid the high list. The zero count fixes the constant bias at zero, and for `0<=n<=T` the low operand must equal `n`. Therefore `T<=127`. A radix with its first high key at 256 cannot preserve zero-mass sparsity with one signed-byte low operand and no other correction. The biased radix-256 identity instead has low operand `(n mod 256)-128`, high operand `floor(n/256)` and an `128*sum_t c_t` correction. Every zero-count key contributes `-128*c_t` to its low dot. Changing a zero-count key's arbitrary code changes that dot but cannot change the target `sum n*c`; the correction must depend on that code. A shared running code sum provides it, but its update, state and output correction are genuine work. The proof applies to this digit grammar, not all possible encodings or multi-pass consumers. Both programs compute the same exact integer response before floating conversion.

## Captured work

The source replays the existing prefix-rounded 4095-count map from frozen original-producer Q/K on eight train and four previously inspected validation windows of 256 tokens per layer. A 32-lane wave owns eight adjacent heads with four lanes/head. It issues `32*max_h ceil(list_length_h/4)` lane-key slots per list. Radix 128 compacts low and high lists separately. The biased radix 256 computes a dense low dot and compacts its high list. A static wave choice uses train totals; the oracle chooses after seeing each query's list lengths, so it is an optimistic scheduling bound rather than a free program.

| Layer, held | Sparse radix 32 | Sparse radix 64 | Sparse radix 128 | Dense-low prefix 256 | Train-fixed wave choice | Per-query-wave oracle |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 2,579,584 | 2,346,560 | 2,211,136 | 2,228,768 | 2,199,456 | 2,166,752 |
| 14 | 2,182,912 | 2,067,264 | 1,991,904 | 2,232,128 | 1,991,904 | 1,976,320 |

These are issued lane-key slots, including list padding, not elapsed cycles. At layer 0 the train policy assigns one of the two eight-head waves to prefix 256. Its held gain over sparse 128 is 11,680 slots, or 0.53%; the free per-query-wave oracle's ceiling is 44,384 slots, or 2.01%. At layer 14 train selects sparse 128 for both waves; even the free oracle can save only 15,584 slots, or 0.78%. Prefix 256 still needs 224 int32 code additions per written value token, 896 bytes of per-sequence state per layer and 448 integer corrections per query, even when some queries select sparse 128. For 1,024 held query/value tokens those are 229,376 state updates and 458,752 output corrections before selection, memory traffic or list construction. Signed-byte dot slots and scalar additions are not interchangeable cycles; this is a work/prerequisite comparison, not a proof of latency dominance. Compacted radix 128 itself pays for two lists, so a native kernel might still prefer dense low if the second list is expensive.

At the held layer-0/14 panels, radix-128 nonzero low pairs are 1,009,064/1,329,355, high pairs 75,633/68,350, versus 2,105,344 dense causal pairs and prefix-256 high pairs 38,246/40,770. The prefixes do not reduce the count scan, cache gathers or O projection. The still-frozen signed-nibble V/O image loses to E4M3 in post-O error, so none of these work counts is a model-quality or full-inference win.

`measure.py` and `/path/to/workspace/data/kelana-subbit/value-radix-sweep/layer{00,14}.json` hold the per-split slot components, pair counts, wave choices, source/model/capture hashes and cost contract. No GPU, installed executable or Bonsai service changed. Reproduce from a Kelana checkout with:

```sh
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-radix-sweep/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-radix-sweep/measure.py --layer 14
```

The next useful question is the occupied-context native crossover of **compacted radix 128 versus a dense low dot**, with count construction, both lists, nibble-cache gathers, the shared O consumer and prefix state inside the timed region. Do it after the half-byte V/O codes and basis survive quantized-producer complete-model quality. Repeating a prefix-256 high-list-only slot comparison at 256 tokens is unlikely to change the decision.
