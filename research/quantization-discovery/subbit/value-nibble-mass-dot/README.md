# Consume probability mass and value codes as nibbles

The 4,095-unit narrow-value attention map has a cheaper packed integer dot than the two signed-byte digits used in the radix-128 study. Split each nonnegative probability count into **three unsigned nibbles**. The cached 28 signed-nibble value codes enter `v_dot8_i32_iu4` directly, with four padded zeros per head. No code is expanded to an int4 or byte cache. This is the *same integer numerator* and stored V/O image as radix 128, not a new quality point.

For a causal row with counts `n_t` summing to 4095, let `d_{jt}=(n_t >> 4j)&15` for `j=0,1,2`. Then for each cached coordinate `c_t` in `[-8,7]`,

```
sum_t n_t c_t = sum_t d_0t c_t + 16 sum_t d_1t c_t + 256 sum_t d_2t c_t.
```

The first dot operand is the signed nibble cache; the second is an unsigned digit repeated eight times in a dword. Each `dot8` accumulates eight coordinates and has independent signedness selectors. `probe.hip` compiles for gfx1151 to `v_dot8_i32_iu4 ... neg_lo:[1,0,0]` with signed first and unsigned second operand. `measure.py` checks the packed arithmetic for every one of 4,096 counts against all 16 signed nibble codes, plus 64 mixed-code/count vectors. The total numerator is bounded by `8*4095=32760`; intermediate digit sums are bounded by `8*4095` and therefore fit int32. FP32 scale/O scheduling is a separate numerical map and has no bit-identity claim.

Mass conservation gives support ceilings independent of context length: at most 4,095 nonzero low-digit keys, 255 middle-digit keys and 15 high-digit keys per query/head. Each head needs four dot8 instructions for 32 coordinates per active digit/key, instead of eight dot4 instructions for 32 byte-expanded coordinates per active radix-128 digit/key. This is a conditional instruction count. It is **not** a native time result: constructing the prefix-rounded counts, three digit broadcasts per key, compaction, gathers, subgroup divergence, reductions and O are all online. Dense execution still uses 12 dot8 rather than 16 dot4 per key, but extra digit preparation can lose that advantage. The cached value payload remains 112 logical/128 padded bytes/token/layer and the paid factor image remains .53060 V/O BPW. Each code dword is read once per active key and can feed all its active digit dots.

The CPU support panel uses the same pinned original-producer Q/K probabilities and counts as the radix-128 study. Four repeatedly inspected 256-token validation windows per layer each contribute 2,105,344 causal key/head pairs. All figures count both heads and all eight groups; the 28 coordinates are padded to 32 in both arms.

| Layer | Nonzero digit pairs, low/middle/high | Radix-128 byte pairs, low/high | Ideal dot instructions, nibble / byte | Four-lane issued dot slots, nibble / byte |
| --- | ---: | ---: | ---: | ---: |
| 0 | 981,477 / 351,338 / 38,246 | 1,009,064 / 75,633 | 5,484,244 / 8,677,576 | 5,831,456 / 9,132,064 |
| 14 | 1,306,241 / 282,683 / 40,770 | 1,329,355 / 68,350 | 6,518,776 / 11,181,640 | 6,842,432 / 11,608,352 |

The four-lane dot-slot reduction is 36.1%/41.1% at layers 0/14 *before* three-list preparation and code-gather costs. An eight-lane assignment still reduces modeled slots 34.8%/39.8%. The highest digit needs at most 15 keys on any normalized 4,095-unit row; the held maxima are 10/9. Train and held receipts, all support/list widths, source/model/capture/parent hashes and the checked packed identity live under `/path/to/workspace/data/kelana-subbit/value-nibble-mass-dot/`. The panel does not change V/O quality; the frozen signed-nibble cache still trails E4M3 on held original-producer post-O response. The concurrently explored nonuniform code levels can use this lowering only if each trained cache code remains a signed nibble or has a cheap signed-nibble relabeling.

The next experiment is a **complete fused native panel** comparing radix-128 byte and radix-16 nibble paths on occupied contexts, with count scan, digit broadcasts, three compacted lists, nibble-cache gathers, subgroup reductions and paid O included. Compare dense radix-16 as a control to isolate list overhead. First test a nibble V/O image on fresh quantized-producer model loss against E4M3 so the native arm has a credible quality target. A lower dot count on these inspected short captures alone is not an engine selection.

From a Kelana checkout:

```
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-nibble-mass-dot/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-nibble-mass-dot/measure.py --layer 14
hipcc --offload-arch=gfx1151 -O2 -S --cuda-device-only research/quantization-discovery/subbit/value-nibble-mass-dot/probe.hip -o /tmp/value-nibble-mass-dot.s
```
