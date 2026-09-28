# Zero-count compaction changes the value-attention question at long context

The exact radix-128 integer value consumer need not multiply a signed-nibble cache code by a zero probability count. This sounds obvious, but the distinction between logical products and issued wave work matters. On four already inspected Qwen3-0.6B 256-token validation windows, removing zero counts halves layer-0 logical value products. With the existing four-lane high-digit schedule, the same change saves only 4.1% of modeled dot slots before paying for the *second* compacted list. Layer 14 saves 12.8%. This rejects short-context four-lane zero compaction as a compelling native build on product counts alone. The long-context case is different: conservation of the 4,095-count mass gives a context-independent bound on the list length.

For a causal query/head, prefix rounding produces nonnegative integer counts `n_t` with `sum_t n_t = 4095`. Let `l_t = n_t % 128` and `h_t = n_t // 128`. With signed-nibble value code `c_tj`, the complete integer coordinate is

```
  sum_t n_t*c_tj = sum_(t: l_t>0) l_t*c_tj + 128*sum_(t: h_t>0) h_t*c_tj.
```

Both digits fit signed-byte dot operands (`0 <= l <= 127`, `0 <= h <= 31`). This is an exact integer identity for every count row and code history, with no reconstructed value vector or changed value image. Each partial and final sum fits int32: its absolute value is at most `7*4095 = 28665`. Convert only the final integer before the existing step/4095 and O operations. This does not assert FP32 identity with a differently scheduled float reduction, nor does it repair the frozen nibble V/O image's deficit against E4M3.

Let `L` be the number of nonzero low digits, `H` the number of nonzero high digits, and `T` the occupied context. The direct sparse consumer spends `28*(L+H)` logical signed-byte coordinate products per head, compared with `28*(T+H)` for dense-low/sparse-high. Conservation proves `L <= min(T,4095)` and `H <= 31`, so for **every** count row at `T > 4095` the sparse low dot has fewer logical products than the dense low dot. It does not prove less elapsed time: probability/scan remains length `T`; compaction, index traffic, irregular nibble reads, synchronization and occupancy can swallow the reduction. At `T=32768`, the exact bound is at most 4,126 key/digit products per head against at least 32,768 for the dense low alone. This is a domain bound, not an ISA or latency lower bound. If a low digit is zero but its high digit is not, the high list still includes it.

## Frozen 256-token panel

Each layer has 2,105,344 causal query/head/key pairs. Four windows times 256 positions times 16 heads are grouped in position-major, adjacent-head order. The table charges one 32-lane wave with eight four-lane head subgroups, seven value coordinates per lane and `max(ceil(list_length/4))` iterations across its eight subgroups. It includes idle lanes due to divergent list lengths, but no instruction or traffic cost for constructing either list.

| Layer | Nonzero low / high pairs | Logical digit-pair saving against dense-low | Dense-low + sparse-high wave slots | Two sparse lists wave slots | Modeled slot saving |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | 1,009,064 / 75,633 | 50.27% | 2,306,656 | 2,211,136 | 4.14% |
| 14 | 1,329,355 / 68,350 | 35.70% | 2,283,680 | 1,991,904 | 12.78% |

Eight-lane subgroups save 14.67%/18.11% of their own dense-low/sparse-high slot totals; they are a different issue schedule, not a free improvement over four-lane subgroups. The maximum nonzero low-list lengths at `T=256` are 250/243. Although 48.0%/63.2% of all causal pairs have nonzero counts on layers 0/14, one wave's subgroups often have a much denser row than their pooled mean. That explains the gap between product counts and four-lane issue slots. The nonzero count and low-digit lists differ by only 932/772 pairs, those divisible by 128; one active list can avoid a second low index stream if the rare low-zero case is predicated. It cannot avoid the high digit's extra work. At 256 tokens, writing two uint16 indices for every retained low/high entry is already about 2.17/2.80 MB per layer across these four windows before reading them. A one-list predicated lowering trades those index writes for branch/ballot work.

`measure.py` reuses the frozen original-producer Q/K probability and prefix-rounding path. It checks the integer map on seeded signed-nibble histories at causal positions 0, 7, 128 and 255. Eight train windows and four repeatedly inspected validation windows have separate counts. Receipts at `/path/to/workspace/data/kelana-subbit/value-zero-compaction/layer{00,14}.json` bind the script, parent, model and capture hashes. CPU only; no new quality, native latency, GPU, Bonsai executable or service change.

A better next native question is whether a fused count/compaction/direct-nibble/O program breaks even at occupied contexts above 4,095, compared with dense radix-128 and E4M3, measuring list traffic and the count scan inside the clock. The 256-token four-lane arithmetic gap is too small to justify another isolated high-list microbenchmark. Separately, fit the paid half-byte V/O image on quantized-producer model loss before selecting this consumer for serving.

From a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-zero-compaction/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-zero-compaction/measure.py --layer 14
```
