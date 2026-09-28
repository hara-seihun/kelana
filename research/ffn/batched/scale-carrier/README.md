# Direct scale carriers

Two working changes, measured on the whole FFN at layers 0 and 10. Neither has been adopted into the full model. The later [integrated comparison](../RESULTS.md) finds the new precision-preserving scaled-FP16 ownership schedule nearly tied with this higher-error carrier at 128/256 rows. The carrier's initial advantage over compact-scaled does not survive as a clear advantage over that stronger schedule.

1. Map a packed weight code directly to the scaled byte consumed by IU8 WMMA. This is bit-identical to the earlier grouped-scale construction and makes it 1.08–1.16x faster across the measured sizes.
2. Keep one integer accumulator through the whole projection. This is 1.17–1.19x the compact A8 control at 256 rows, and 1.04x the stronger compact-scaled FP16 candidate. It changes the quantizer and fitted weight scales. Its residual error against the engine is 0.113% at layer 0 and 0.167% at layer 10.

The implementation reuses [grouped-scales/candidates/gs_maps.hip](../grouped-scales/candidates/gs_maps.hip). [global.hpp](global.hpp) supplies the whole-row producer and whole-K projection. There is no second copy of the transform, weight layout, fitter or plan lifecycle.

## The direct map

The stored two-bit labels are 0, 1 and 3. For a block multiplier `m`, the consumer wants signed bytes 0, m and -m. Build the byte palette `[0,m,0,-m]` once and use the labels as `v_perm` selectors. No signed trit, sign mask or multiplied magnitude is needed in between.

The previous map used two permutations, a multiply and sign arithmetic for each four-weight group. The direct map needs one permutation after selector placement. `check_palette.py` exhausts all 256 packed bytes and 127 multipliers, 32,512 cases. Composition over the four bytes gives the 16-weight operand. The unused label 2 maps to zero in both constructions.

`gs-palette1024-iu8-a8` and `gs-absorb1024-iu8-a8` have identical output hashes at 32, 128 and 256 rows on both layers. This comparison changes no numerical map. The two- and four-block variants are also retained from the initial sweep.

## One integer state through K

For each output row, fit one positive scale L and one integer multiplier m in 1..127 per 128-wide block. The finite grid fitter is the existing grouped-scale fitter, now allowed to see all 40 or 136 blocks in a row. Its measured weight-scale relative RMS is 0.2460% at layer 0 and 0.2457% at layer 10.

For each activation row, transform first, then choose one scale c from the maximum over the whole transformed row and quantize directly to signed A8. This is not a requantization of an existing A8 grid. A scratch image and a second producer kernel let the chunks share that maximum. Both are inside the timed `run`.

The represented projection is

```
y[r,t] = L[r] * c[t] * sum_k trit[r,k] * m[r,block(k)] * q[t,k].
```

The sum is an ordinary signed IU8 WMMA accumulation, with no floating drain until the final store. For this model every partial sum has magnitude at most

```
17408 * 127 * 127 = 280773632 < 2^31.
```

[IntegerScaleCarrier.lean](../../../../Kelana/IntegerScaleCarrier.lean) proves the exact scale factoring, the signed product bound and the finite-sum range bound. Build it with `lake build Kelana.IntegerScaleCarrier`. This bounds all input values in the declared quantized domain, not only the observed rows. The fitted scales, activation quantization and final floating operations remain approximate relative to the deployed FFN.

The general construction is a separable scale with integer local detail. It works whenever coefficients admit `L[r] * integer[r,k]` and activations admit `c[t] * integer[t,k]` inside the ISA's operand and accumulator ranges. The representation persists through addition because every term has the same outer scale. No per-block relabeling is required. Whether the fit is accurate enough and whether it runs faster are separate questions.

## Measurements

Authoritative results are `results/final-layer{0,10}.json`. Each run has 60 calls per candidate, 12 randomized rounds, a two-second timed workload ramp before each batch, raw samples, sensor traces and visible DRM clients. Research workers share `hardware-run`; the server and browser are outside that lock. No sample was discarded, and none exceeded twice its candidate's median. `summarize.py` checks the output-hash equalities and joins clock samples to timed blocks, excluding the ramp. Median clocks across candidates were 2653–2730 MHz; within a layer and batch size the largest median spread was 18 MHz. These sensor observations do not establish exclusive device use.

Median milliseconds, layer 0:

| map | 32 rows | 128 rows | 256 rows |
|---|---:|---:|---:|
| compact A8 control | 1.093 | 2.279 | 4.556 |
| grouped A8, original operand | 1.142 | 2.420 | 4.678 |
| grouped A8, direct palette | 1.045 | 2.108 | 4.201 |
| whole-K integer, TT4 | 0.953 | 2.502 | 4.756 |
| whole-K integer, TT8 | 0.970 | 2.164 | 3.846 |
| whole-K integer, TT8, unroll 2 | 0.907 | 2.077 | 3.828 |
| compact-scaled FP16 A8 | 1.070 | 2.253 | 3.984 |

Round-geometric speed ratios for the whole-K unroll-2 candidate:

| layer | rows | against compact A8 | against compact-scaled FP16 |
|---|---:|---:|---:|
| 0 | 32 | 1.204 | 1.180 |
| 0 | 128 | 1.096 | 1.082 |
| 0 | 256 | 1.188 | 1.039 |
| 10 | 32 | 1.180 | 1.169 |
| 10 | 128 | 1.084 | 1.081 |
| 10 | 256 | 1.170 | 1.041 |

At 256 rows the 95% round-bootstrap interval against compact-scaled is [1.031, 1.047] at layer 0 and [1.030, 1.049] at layer 10. The latter wins 11 of 12 rounds; all other entries in this table win all 12. The unroll-1 and unroll-2 whole-K variants nearly tie at 256 rows. Unroll 2 was chosen from the initial layer-0 sweep, before the final two-layer run.

`TT8` is a width cap. At 32 rows these candidates use two tiles; the extra low-batch gain comes from the unrolled loop, not eight live tiles.

The tile-width ablation matters. TT4 whole-K loses to the regular A8 control at 128 and 256. TT8 recovers the gain without changing any output bits. Compile-time resources for the unroll-1 gate/up kernel are 129 VGPRs and 10 waves/SIMD at TT4, 210 and 7 at TT8. Unroll 2 at TT8 uses 212 VGPRs. All have zero spills. This establishes a width effect; it does not isolate the relative contributions of traffic, scheduling and register allocation.

At 256 rows, relative RMS against the engine residual:

| map | layer 0 | layer 10 |
|---|---:|---:|
| compact A8 | 0.0117% | 0.00405% |
| compact-scaled FP16 A8 | 0.0158% | 0.0194% |
| direct palette, 1024 grouping | 0.0797% | 0.1399% |
| whole-K integer | 0.1126% | 0.1666% |

The whole-K variants have identical outputs across tile widths and unroll factors. These error numbers do not isolate activation grouping from weight-scale fitting. No full-model logits, held-out loss or TPS have been measured for this construction. It is a different accuracy/speed point, not a free replacement for A8.

## Composing the wide-load result

The [dense-consumer](../dense-consumer/README.md) experiment found that lane-contiguous 128-block loads help its IU4 map. `gs-global-wide-iu8-a8` applies that layout to this integer carrier without changing its outputs. At 32 rows it improves the whole-K unroll-2 candidate by 1.171x, 0.781 versus 0.910 ms. At 128 and 256 it loses badly, 3.992/6.158 versus 2.078/3.784 ms. All output hashes match.

This is not a spill failure. The wide TT8 gate/up kernel uses 218 VGPRs and reports six waves/SIMD, with zero scratch or spills; down uses 216 and seven. A TT4 wide ablation is faster than TT8 wide at large batches but still loses to the original TT8 narrow-load carrier, 2.330/4.166 versus 2.028/3.825 ms in the matched follow-up. Layout, unrolling and live operand scheduling move together here, so these observations do not isolate a cause. The low-batch gain and the large-batch failures are retained in `wide-layer0.json` and `wide-tiles-layer0.json`.

The combined run independently repeats the dense worker's A4 result: dense storage is 1.903x arithmetic A4 at 32 rows, and the two-bit wide pair-code map is 1.356x/1.257x at 128/256. Those comparisons preserve the arithmetic A4 output hashes, but A4 remains a different quantizer from the A8 carrier discussed here.

## A rejected scale factorization

`scale_field.py` reads every stored block scale, divides each row by its mean and computes the singular spectrum of that normalized scale field. A single row scale leaves about 6.5% relative Frobenius error. Even the best rank-eight approximation leaves 5.8–6.3% on these two layers. Results and weight hashes are in `results/scale-field-layer*.json`.

That is a poor lead for paying for several projections to reconstruct the scale field. It is not a lower bound on other encodings or on the resulting model error. The integer-multiplier representation keeps the local scale detail instead.

## Reproduce

```sh
cd research/ffn/batched/bench
make -j4 PEER_DIRS='../arithmetic ../grouped-scales ../compact-scaled' build/batch-bench
../hardware-run ./build/batch-bench \
  --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
  --rows 32,128,256 --iters 60 --rounds 12 --warmup 12 --seed 22034 \
  --candidate arith-iu8-a8,gs-absorb1024-iu8-a8,gs-palette1024-iu8-a8,gs-global-iu8-a8-tt4,gs-global-iu8-a8-tt8,gs-global-iu8-a8-tt8-u2,cs-scaled-f16-a8 \
  --reference-candidate gs-absorb1024-iu8-a8 \
  --json ../scale-carrier/results/final-layer0.json
python3 paired_analysis.py ../scale-carrier/results/final-layer0.json \
  --baseline cs-scaled-f16-a8 --out ../scale-carrier/results/final-layer0-vs-cs-scaled-f16-a8.json
cd ../scale-carrier
python3 check_palette.py
make resource
```

Use layer10 and seed 22134 for the second layer. Build products stay under `bench/build`. `make resource` writes the compiler's register report without running the GPU.

The benchmark fingerprint now includes recursively quoted local headers, including `global.hpp`. Earlier exploratory records predate that repair and are retained under their original filenames; the final records carry the repaired hash. A subsequent row-tail repair chooses only tile widths dividing the padded token axis. It leaves the measured 32/128/256 dispatches unchanged. `tails-layer0.json` covers 88 and 200 rows, confirms palette equality there, and confirms unchanged output hashes at 32 and 256. Prime tile counts currently sacrifice width rather than read beyond the allocation. `bench/test_fingerprint.py` checks that changing a transitive header changes the digest and a missing header is rejected.
