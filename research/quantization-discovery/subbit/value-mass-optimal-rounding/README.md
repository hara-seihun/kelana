# Mass concentration does not buy much issued work at 256 tokens

The radix-128 narrow-value attention consumer can eliminate a high-list key by moving its integer probability count below 128 and transferring the mass to a key already in the high list. That changes the lossy attention map, but preserves nonnegative counts summing to 4,095. On Qwen3-0.6B original-producer causal captures it removes almost every eligible high key. Four-lane issued dot slots barely move. The high list was already short; the low list and subgroup tail dominate this particular scheduling coordinate.

## Construction and finite bound

For a count row `n`, let `j` be its maximum-probability key. For each `i != j` with `128 <= n_i <= 127+d`, set `n'_i = 127` and add `n_i-127` to `n'_j`, provided `n_j >= 128`. Other counts do not move. There is no negative count, the mass remains 4,095, zero-mass keys remain zero and the number of radix-128 high-list keys falls by exactly the number of changed donors. The only extra arithmetic in the signed-nibble value observation is the changed count vector; the same direct dot and paid V/O image consume it. The exact integer map differs from prefix rounding. Its floating center remains valid because total mass is unchanged.

In the grammar where each removed key can lose at most `d` integer units and no other new high key is created, only keys with original counts in `[128,127+d]` can leave the high list. Their number is an upper bound for *any* policy in that grammar, regardless of how it chooses recipients or codes. The proposed policy reaches all but 48 of 14,577 eligible layer-0 held pairs at `d=32`, and all 10,403 at layer 14. It does not bound policies that move more mass per donor, change the original probability quantizer, or repartition the value codes. The receiving maximum key is not subject to the per-donor movement cap; it can receive many units.

For a signed-nibble code `c_i` in `[-8,7]`, moving `a_i` units to the owner changes each raw coordinate by `sum_i a_i(c_j-c_i)/4095`, whose magnitude is at most `15 sum_i a_i /4095`. This is an absolute coordinate guard, not a post-O or language-loss guarantee. The measured complete post-O response is the actual quality observation here.

## Captured result

Eight train and four previously inspected validation windows per layer use the original Q/K producer, prefix-rounded 4,095-unit probabilities, and the frozen rank-28 signed-nibble V/O image. Four-lane slots count `32 max_h ceil(list_length_h/4)` for eight adjacent heads in a wave, independently for compacted nonzero low and high radix-128 lists. The policy reads the already computed softmax maximum index but also needs a crossing predicate, moved-unit reduction, owner scatter and list construction. The table does not charge those operations, memory gathers or a GPU launch.

| Layer, held | Maximum donor move | Removed high pairs | Upper bound | Four-lane low+high slots | Change against prefix | Post-O relative teacher error |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 0 | 0 | 0 | 2,211,136 | baseline | .386705 |
| 0 | 4 | 2,225 | 2,227 | 2,207,616 | -0.16% | .386708 |
| 0 | 16 | 8,153 | 8,167 | 2,194,272 | -0.76% | .386740 |
| 0 | 32 | 14,529 | 14,577 | 2,181,888 | -1.32% | .386843 |
| 14 | 0 | 0 | 0 | 1,991,904 | baseline | .365405 |
| 14 | 4 | 1,524 | 1,524 | 1,989,632 | -0.11% | .365399 |
| 14 | 16 | 5,650 | 5,650 | 1,981,568 | -0.52% | .365359 |
| 14 | 32 | 10,403 | 10,403 | 1,972,832 | -0.96% | .365224 |

The cap-32 transfers have count L1 distances of .006614/.004838 after dividing by mass and averaging rows on layers 0/14. Against the unchanged prefix output, complete post-O relative squared differences are 3.30e-5/8.23e-5. The original-producer teacher-error movement splits by layer and is tiny beside the half-byte cache's gap to E4M3. Selecting cap 32 from these inspected windows would be unjustified. Train receipts also show only 1.43%/1.03% slot reductions at cap 32. Even granting *free* redistribution and a free high-list update, the tested policy offers less than 1.4% issued-slot savings at this context; the upper bound on removable high keys is not an upper bound on all possible slot reductions from other maps.

The next question is not another threshold move on these 256-token rows. At occupied contexts above 4,095, both lists have bounded total nonzero count while dense attention keeps growing; test the full native count/compaction/gather/O path after a half-byte V/O image survives quantized-producer model loss. If a changed mass quantizer is worth revisiting, optimize the two-head post-O response and complete issued slots together, not just the count of high keys.

`measure.py` supplies the conservation checks and count/slot panels; `replay.py` uses the same paid image, signed-nibble codes and complete two-head post-O response as the preceding value-mass studies. `/path/to/workspace/data/kelana-subbit/value-mass-optimal-rounding/layer{00,14}.json` retains source, model, capture, factor and cache-fit hashes, train and per-window held receipts. To reproduce from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-optimal-rounding/measure.py --layer "$layer"
  OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-optimal-rounding/replay.py --layer "$layer"
done
```

This is a CPU changed-map result, not a native timing, quantized-upstream language result or runtime change. Bonsai's executable and service did not change.
