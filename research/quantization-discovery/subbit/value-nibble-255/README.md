# Spend eight probability bits as two direct nibble dots

The earlier 4,095-unit narrow-value attention uses three unsigned probability nibbles against packed signed-nibble V codes. Reducing the conserved mass to 255 needs only two direct `v_dot8_i32_iu4` passes. This is a different approximate attention map, not an exact lowering of the 4,095-unit map. It does not change the .53060-BPW paid V/O image, the 112 logical/128 padded cache bytes, or the O consumer. Its probability precision can be assigned separately to each head.

On frozen Qwen3-0.6B original-producer 256-token captures, an exact train-set search over 16 head switches at a relative post-O rounding-error budget of 1e-4 chooses 15 short-mass heads at layer 0 and four at layer 14. On four previously inspected validation windows the held errors against the all-4,095 map are 8.79e-5 and 6.06e-5. The selected maps reduce modeled four-lane packed-dot slots by 50.2% and 12.3%, respectively. The layer dependence is decisive: forcing all sixteen heads to 255 units costs .0001145 relative error at layer 0 but .005709 at layer 14. Unlike the earlier 127-unit signed-byte study, the 255-unit arm has a direct packed-nibble consumer, with no value-code byte expansion. Under the same train error budget that byte study selected ten/two heads; this arm selects fifteen/four. The arithmetic units and probability maps differ, so this is not a native speed comparison.

## Map, bound and scope

For a normalized causal probability row, set `N_t(M) = round(M sum_{i<=t} p_i) - round(M sum_{i<t} p_i)`, fixing the last prefix to `M`. Monotonicity makes the counts nonnegative, and they sum to `M`. For `M=255`, write `N_t=d0_t+16*d1_t` with unsigned four-bit digits. For every cached signed-nibble coordinate `c_t` in `[-8,7]`,

```
sum_t N_t c_t = sum_t d0_t c_t + 16 sum_t d1_t c_t.
```

Each term is a signed-first/unsigned-second dot8 on already-packed value codes; the FP32 value step is applied after integer reduction. The numerator magnitude is at most `8*255=2040`, and each partial sum fits signed int32. The same construction at `M=4095` has three digits and maximum numerator magnitude 32760. A real-probability summation-by-parts error bound is `|step|/(2M) sum_{t<T-1}|c_t-c_{t+1}|` per coordinate when the prefixes are rounded to nearest. Floating probability accumulation and the final FP32 output reduction have separate rounding; this bound does not claim FP32 bit identity.

For each head, the script replays its paid O slice at both masses. Let `d_h` be the complete output difference from switching head `h`. The train relative squared response difference for a subset `S` is `1_S^T G 1_S / ||y_4095||²`, with `G_ij=<d_i,d_j>`. Enumerating all 65,536 subsets yields the optimum at each cardinality **within this frozen two-mass, per-head grammar**. It does not optimize value codes, the right basis, model loss, or a native schedule. The selected subset is replayed with actual FP32 accumulation on held data.

| Layer | 255 heads / mask | Held relative error, selected / all-255 | Four-lane dot8 slots, all-4095 / selected / all-255 |
| ---: | ---: | ---: | ---: |
| 0 | 15 / `ffbf` | .00008794 / .00011448 | 5,831,456 / 2,904,400 / 2,520,560 |
| 14 | 4 / `3300` | .00006063 / .00570919 | 6,842,432 / 5,998,160 / 2,472,304 |

The slot model counts nonzero low and high digits, rounds each head's list to four-key subgroups, and charges four dot8 instructions for 32 padded value coordinates per active digit/key. With 255 units, at most 255 low-digit keys and 15 high-digit keys can be nonzero at any context length. The held all-255 low/high support is 531,138/39,282 pairs at layer 0 and 519,993/41,581 at layer 14, across four windows, sixteen heads and 256 causal queries/window. The short-mass branch needs a distinct count scan, digit lists and per-head mass division; mixed-head scheduling and divergent wave lists may spend the modeled slot saving. These are issued arithmetic slots, not elapsed GPU time. The paid V/O producer, softmax, count preparation, compaction, nibble gathers, O and output reductions remain online. The frozen V cache itself loses to E4M3 on post-O response. There is no fresh quantized-producer loss or whole-model result here.

The useful next experiment is a fused native panel with this two-digit arm and the three-digit control, **after** joint V basis/cache/O fitting on quantized-producer complete-model text has made the nibble cache a credible quality point. Layer 14 needs per-head assignment rather than a uniform 255 rule; train the mass allocation with the changed codes instead of transferring this mask.

The replay lives in `measure.py`. Its receipts at `/path/to/workspace/data/kelana-subbit/value-nibble-255/layer{00,14}.json` retain per-window rounding errors, masks, slot components, and source/model/capture/factor/cache-fit hashes. Run from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-nibble-255/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-nibble-255/measure.py --layer 14
```
