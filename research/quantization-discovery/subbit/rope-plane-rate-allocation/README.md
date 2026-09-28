# Paying 112 RoPE planes where the Q/K consumer uses them

The [whole-plane score consumer](../rope-plane-consumer/README.md) gave every GQA group fourteen planes. Its Q and K weights differ by group, so equal widths need not be the best way to spend a fixed key-cache and dot-product budget. This study allocates the same 112 planes across eight groups on the pinned Qwen3-0.6B layers 0 and 14. Both query heads of a group use the same mask. No source intermediate or 128-coordinate key is reconstructed.

## Objective and guarantee

The domain is independent zero-mean isotropic hidden query/key inputs, original BF16 Q/K projections cast to FP64, and a uniform average over relative RoPE offsets 0–4095. Both observing Q heads have equal weight. The 64 plane-score terms in group `g` have positive-semidefinite Gram `M_g`. With omitted-plane indicator `x_g`, the expected squared score error is exactly `x_gᵀ M_g x_g`. Minimize the sum of eight such errors subject to `sum_g (64 - |x_g|) = 112`, with four to sixteen planes per group when a one-line BF16 key-cache layout is required. We also price four to 28 planes per group without that layout restriction. The retained fraction below is **pooled score variance**, `1 - sum(error_g)/sum(full_variance_g)`; it weights high-variance groups more than the earlier report's arithmetic mean of eight fractions.

For a *fixed* family of one mask per group at each plane count, the dynamic program in `allocate.py` is globally optimal: its state after group `g` and paid count `b` is the minimum sum of the first `g` group errors with `b` retained planes. This follows by partitioning any candidate by its last group's count. For isotropic score queries, `M_g` is diagonal; choosing the largest `c` per-plane K energies is globally optimal at each count, so the ensuing allocation is **globally optimal among all plane masks** with these count limits and budget. That proof requires diagonal query covariance, not that K has independent planes. For the real Q-weighted covariance, each count's candidate comes from reverse greedy deletion and strict single-plane exchanges. The allocation is exact only conditional on those candidates; it is not a global mask optimum. The eight groups' errors are additive because the objective deliberately sums separate group score errors, not because full attention or post-O losses are additive.

## Pinned-weight result

All three arms in a row retain **112 planes**, 224 logical BF16 key scalars and 448 scalar products for both heads per occupied key. A group of at most sixteen planes occupies one 64-byte cache line in the stated aligned layout. The counts above sixteen require a second line for that group.

| Layer / observation | Uniform 14 pooled retention | Allocated, at most 16 | Allocated, at most 28 | Aligned key bytes uniform / capped / variable |
| --- | ---: | ---: | ---: | ---: |
| 0 / Q-weighted | .441703 | **.445371** | .449364 | 512 / 512 / 704 |
| 14 / Q-weighted | .557885 | **.567552** | .568000 | 512 / 512 / 640 |
| 0 / isotropic query | .342615 | **.345618** | .347633 | 512 / 512 / 640 |
| 14 / isotropic query | .405416 | **.410147** | .410827 | 512 / 512 / 704 |

The capped Q-weighted layer-14 ranks are `[7,12,13,16,16,16,16,16]`; its extra .009667 of pooled variance comes at the same logical budget, 512 aligned BF16 key bytes and 448 score products as uniform. The unrestricted variable arm adds just .000448 retained fraction while demanding two cache lines in two groups. This is a useful boundary: reallocate *within one line* before considering a 28-plane group on this surrogate. Layer 0's capped improvement is smaller, .003667, and spending extra lines buys another .003993. The per-group optimal isotropic and feasible Q-weighted curves, counts, masks, denominators, input hashes and source hashes are in `/path/to/workspace/data/kelana-subbit/rope-plane-rate-allocation/receipt.json`.

Uniform Q-weighted masks exactly reproduce the earlier group's 14-plane local-exchange means .443464 and .563333; the pooled .441703 and .557885 above answer a different aggregation question. The isotropic assignment is a genuinely exact budget allocation in its stated domain, while the Q-weighted receipt is a feasible improvement rather than an upper bound. Layer-specific masks cost eight 64-bit membership bitsets, 64 bytes per layer if stored without compression; both uniform and variable proposals need the same mask provenance. The 512-byte padded key cache is versus 448 logical bytes under dense packing and 2,048 original BF16 key bytes per token per layer. V is unchanged. Packing the group ranks into a native code format, producing only selected Q/K rows, vector utilization, per-group divergent work and score reduction still need pricing. Neither arm stores sub-bit Q/K weights yet, nor has held-text attention or model loss or native latency.

The next experiment should fit packed selected-row Q/K codes using **both heads' actual causal scores** after quantized upstream layers and compare an equal-paid-rate binary Q/K control on independent text. Freeze the mask using train inputs, then check attention KL, post-O response and complete-model gold loss. If the one-line unequal ranks survive, benchmark their direct score/cache consumer against uniform ranks, including the mask/producer mapping and occupancy. More weight-only mask optimization cannot answer that quality question.

Reproduce on CPU without the GPU lock:

```sh
cd /path/to/workspace/projects/kelana
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/rope-plane-rate-allocation/allocate.py \
  --output /path/to/workspace/data/kelana-subbit/rope-plane-rate-allocation/receipt.json
```

No Bonsai runtime or resident service changed.
