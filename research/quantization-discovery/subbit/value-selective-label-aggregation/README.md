# Aggregate only repeated narrow-value labels

The paid Qwen3-0.6B rank-28 signed-byte V cache has identical whole value rows at layer 0. [Full label aggregation](../value-label-overflow/README.md) reduces its low-byte dot work, but initializes a count bin and scatters a mass for **every** key, including labels that appear only once. Those singleton operations do not help the dot. Group only labels that have appeared at least twice in the current causal block; send singleton counts straight to the existing key-wise sparse-overflow reader. This exactly retains the full histogram's byte and correction products while removing most of its histogram work on the observed early layer. At the all-unique later layer it reduces to the raw key-wise reader.

## Map and proof

For a prefix of keys `0..t`, let `i(k)` name its exact 28-byte value code `c_i` and `m_i(t)` be the number of keys with that label. For a chosen multiplicity threshold `r`, set `G={i:m_i(t)>=r}` and `H_i=sum_{k:i(k)=i} n_k` for `i in G`. The nonnegative integer counts satisfy `sum n_k=M=4095`. The observed integer coordinate is

```
sum_{i in G} [min(H_i,255) + (H_i-255)_+] c_i
  + sum_{k:i(k) not in G} [min(n_k,255) + (n_k-255)_+] c_{i(k)}.
```

This is `sum_k n_k c_{i(k)}` over the entire conserved-count domain. Each selected label consumes one unsigned-byte/signed-byte dot term and at most one scalar excess term; each unselected key does the same directly. The sum of all aggregated and direct counts is 4,095, so at most `floor(4095/256)=15` terms overflow, regardless of prefix length or duplicate pattern. A coordinate has magnitude at most `127*4095=520065`, within int32. Static FP16 scale and paid O consumption follow the same integer result. This does not assert bit equality for an FP32 reassociation of the floating output.

At `r=2`, every unselected label is a singleton. Compared with grouping all labels, it still has **one low-byte term per distinct label**, and its overflow count is identical because a singleton's aggregated mass is its original key mass. It saves one scatter for every singleton key and one bin initialization for every singleton label, without changing any dot or correction. Thus full aggregation is strictly dominated within this logical-work grammar whenever a singleton exists. For `r>2`, dropping a group with multiplicity `m` saves its `m` scatters and one initialization, but adds `m-1` low-byte terms; correction terms can move either way. This is not a lower bound on a native schedule: dictionary routing, cache-line reads and vector padding may reverse these preferences.

The group decision can use append-maintained prefix multiplicities. At the second occurrence, mark both its first key and the new key as grouped, and mark subsequent occurrences when appended. A group-owned dictionary already records first-occurrence IDs. A current-prefix query then routes once per key using the stored mark, with no extra multiplicity scan. Replaying an earlier prefix after further appends, rollback and mutable block closure would require prefix-specific marks or rebuilding them. The CPU experiment below recomputes multiplicities for each historical prefix; its recorded multiplicity-test count describes that replay, **not** a charged online scan or a native implementation.

## Captured Qwen panel

Four previously inspected, separate 256-token original-producer validation windows at each layer; all 16 heads and every causal query. Frozen paid image, FP16-rounded signed-byte coordinate scales, prefix-rounded 4,095 counts, and parent whole-row IDs are unchanged. The mixed `r=2` integer response hash equals the full histogram and key-wise parent on every query. These counts are logical 28-coordinate products, not issued matrix instructions or native latency.

| Layer | Minimum prefix multiplicity to group | Low-byte products | Excess products | Count scatters | Bin initializations |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 1, full histogram | 36,140,608 | 1,270,920 | 2,105,344 | 1,290,736 |
| 0 | **2, duplicate only** | **36,140,608** | **1,270,920** | **1,133,536** | **318,928** |
| 0 | 3 | 40,548,928 | 1,247,456 | 818,656 | 161,488 |
| 0 | 4 | 43,477,056 | 1,219,540 | 661,792 | 109,200 |
| 0 | 8 | 52,948,224 | 1,129,744 | 236,576 | 22,240 |
| 0 | raw key-wise | 58,949,632 | 1,070,888 | 0 | 0 |
| 14 | 1, full histogram | 58,949,632 | 1,141,560 | 2,105,344 | 2,105,344 |
| 14 | **2, duplicate only** | **58,949,632** | **1,141,560** | **0** | **0** |

At layer 0, grouping duplicates saves 22,809,024 byte products against raw key-wise at the price of 200,032 additional scalar correction products, 1,133,536 count scatters and 318,928 touched bins. Relative to full aggregation, it removes 46.16% of scatters and 75.29% of bin initializations with identical dot/correction work. The `r=3` point saves another 314,880 scatters and 157,440 initializations but adds 4,408,320 byte products and removes 23,464 correction products. At layer 14 none of these windows repeats a whole row in any group. The duplicate-only schedule therefore has zero histogram work there, though an indexed cache still pays its dictionary/ID storage unless the producer chooses raw rows for an all-unique block.

This is an exact whole-integer-map construction and an input-dependent logical-work frontier, not a GPU speedup. Mass generation, append bookkeeping, reading IDs, dynamic routing, scatter conflicts, padded byte dots, the sparse correction list, cache traffic, scaling and O remain in the native bill. On gfx1151, the next useful experiment is a complete group-owned append/count/duplicate-route/byte-dot/correction/O reader at occupied context against raw signed-byte and E4M3, with the early repeated layer and an all-unique bypass measured together. If routing costs more than the 22.81-million-product margin, train codes for more repeated rows rather than add a denser histogram.

The [CPU receipts](/path/to/workspace/data/kelana-subbit/value-selective-label-aggregation/README.md) bind source, parent integer output, paid image, model, capture and exact per-group value codes. From a Kelana writer checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-selective-label-aggregation/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
