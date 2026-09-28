# Sparse high digit for direct narrow-value attention

[The radix-128 follow-up](../value-mass-radix/README.md) keeps this exact integer map and reduces its held high-key support to 3.59%/3.25% on layers 0/14. Use that radix when pricing a native consumer; radix 32 below is the original measured control.

The [headwise mass allocation](../value-mass-allocation/README.md) spends one 127-count dot on some heads and two dots on the others. That saves arithmetic by changing the probability map. I asked a different question: can the existing 4,095-count map itself use less than two dense dots? Yes, conditionally. The high digit touches only 8.7–11.1% of causal key/head pairs on the frozen layer-0/14 Qwen3-0.6B captures. A dense low-digit dot plus a compacted high-digit dot would do 44.5–45.7% fewer signed-byte coordinate products than two dense dots while retaining the *same integer attention map*. This is an arithmetic and scheduling opportunity, not a native speed measurement.

For each query and head, let `n_k` be the existing prefix-rounded probability counts, with `sum_k n_k = 4095`. The signed-nibble value code `c_kj` is in `[-7,7]`. Set

```
l_k = n_k % 32                  # 0..31, dense
h_k = n_k // 32                 # 0..127, sparse
S_j = sum_k l_k*c_kj + 32*sum_{k:h_k!=0} h_k*c_kj
```

Every operand fits signed byte; `S_j = sum_k n_k*c_kj` exactly as an integer. Each constituent sum and the result fit signed 32-bit. In fact `|S_j| <= 7*4095 = 28665`. The existing FP32 scale, value center and paid O consumer can follow this integer result unchanged. This identity is not a proof that different floating scheduling or FMA contraction reproduces final FP32 bits; the proposed observation is the integer vector before scaling. The weight image stays at the frozen paid rank-28 V/O rate, and the signed-nibble cache remains 112 logical, 128 padded bytes/token/layer. No int4 weight expansion appears online.

The `h_k` support obeys a useful worst-case bound: every nonzero high digit consumes at least 32 of the 4,095 mass units, so a query/head has at most `floor(4095/32) = 127` high-key entries at any context length. This is a bound on correction *keys*, not on the cost of finding them. The count prefix and compaction must still visit the causal attention row. Both heads in a GQA group can form the union of their high-key indices and share cache-line visits, but each head needs its own high count and integer dot.

## Frozen-capture measurement

[`measure.py`](measure.py) computes the original-producer Q/K probabilities and the same 4,095-mass prefix counts as the [integer consumer](../value-integer-consumer/measure.py). Eight 256-token train windows and four already inspected validation windows are separate. All 16 query heads enter each count; the rightmost causal keys, not padding above the causal diagonal, enter the denominators. Receipts with model, capture and source hashes are in `/path/to/workspace/data/kelana-subbit/value-mass-residual/layer{00,14}.json`.

| Layer / split | Causal head-key pairs | Nonzero high pairs | High fraction | Both-head union per group-key | Ideal signed-byte product reduction |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 train | 4,210,688 | 456,678 | 10.85% | 17.56% | 44.58% |
| 0 validation | 2,105,344 | 232,887 | 11.06% | 17.77% | 44.47% |
| 14 train | 4,210,688 | 373,338 | 8.87% | 12.54% | 45.57% |
| 14 validation | 2,105,344 | 182,460 | 8.67% | 12.33% | 45.67% |

The product count is `28*(causal pairs + high pairs)` over both heads, compared with `28*2*causal pairs` for two dense dots. A packed dot8 implementation pads 28 coordinates to 32 in *both* arms, so its corresponding number of dot8 coordinate groups is four times these pair counts and retains the same ratio before scheduling. In the last 128 query positions, high pairs occupy only 8.2%/6.2% of causal pairs on layer-0/14 validation. By contrast the low residue is nonzero on 47.5%/62.8% of pairs and on more than 99% of pairs having a nonzero count. Sparsifying the **low** digit is the wrong polarity.

A dynamic exact single-dot switch based on `max_k n_k <= 127` does almost nothing here: 8 of 16,384 layer-0 validation query/head rows qualify, covering 0.088% of weighted causal pairs, and none qualify in layer 14. No layer-0 train or validation query has both group heads eligible at once. Merely checking the maximum does not pay for itself. The concentrated *high support* is the useful structure, even when the peak count is too large for a single dot.

## Native question this opens

A candidate GPU program must produce the counts and compact high keys while the attention row is live, run the low dot across every key, then run high dots from the compact list. That adds a predicate/scan, index writes or a wave ballot, scattered value-cache reads, a second accumulation with radix 32, synchronization and register lifetime. The saved products are an achievable **logical** reduction, not a latency lower bound or evidence of fewer memory transactions. Because the low pass already loads each group's 16-byte packed value code per key, a second pass may find high keys in cache, but that must be measured at occupied contexts and both heads. The high list must be generated inside the timed query; moving it out of timing would make the comparison invalid.

Before native integration, measure a model-less gfx1151 attention kernel at the frozen 256-key captures and longer occupied contexts, comparing dense two-dot with compacted high-dot under equal count preparation and the same nibble cache. If compaction/scheduling erases the 44–46% product saving, the next quality question is still to train the V basis and O codes for the cheap lossy one-dot consumer on quantized-producer complete-model text, rather than look for a rare exact single-dot row. The existing half-byte value cache loses post-O quality to E4M3 on these frozen factors; this arithmetic result alone does not change that selection.
