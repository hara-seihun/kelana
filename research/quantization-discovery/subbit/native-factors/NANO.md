# Direct NanoQuant binary factors against the rank-88 spectral map

The actual matched ADMM-only NanoQuant image is not faster simply because its factors use single-bit signs. On gfx1151, the rank-88 spectral image took **11.03 µs** per query versus **12.17 µs** for NanoQuant's rank-352 binary image in this paired direct-kernel panel. At 16 queries, the times were **53.24 versus 93.00 µs**. The arithmetic reduction survived as a 1.11x and 1.74x latency gain here, not as a fourfold gain. This changes the earlier comparison from an expanded-map/int4 control to an actual competing sub-bit quantizer, while retaining distinct numerical maps and quality evidence.

Both images target layer 0 Qwen3-0.6B `self_attn.q_proj` at nearly the same matrix payload rate. Spectral's FP16 per-row/group128 scales and four-bit odd signed coefficients occupy 140,704 bytes including two shape arrays, 0.536743 BPW. NanoQuant ADMM's U[2048,352] and V[352,1024] are little-bit-order signs with FP16 pre[1024] and post[2048] scales. Its payload is 141,312 bytes excluding its 12-byte dimension array, or 141,324 bytes including it, 0.539108 BPW. The Nano source is the [ADMM-only adaptation](../binary-factors/README.md), not a trained NanoQuant model or its CUDA GEMV kernel.

For Nano, the first kernel computes each `V` signed dot from FP16 `x[i] * scale_pre[i]` in FP32, writing one FP32 intermediate per rank channel. The second kernel sums `U` signed dots over those intermediates in FP32 and multiplies `scale_post[row]` on output. Each dot is one 32-lane wave. No scaled input or intermediate is precomputed or excluded. The spectral arm compiles the previous [`probe.hip`](probe.hip) packed kernel verbatim, applies right then left with on-dot nibble decode and FP16 group scales, and writes its FP32 intermediate. Both methods have two host-submitted launches and identical device-resident FP16 query and FP32 output boundaries. Intermediate scratch per query is 1,408 bytes for Nano versus 352 for spectral; output is 8,192 bytes. At 16 queries the scratch is 22,528 versus 5,632 bytes. The Nano work is 352 × (1024 + 2048) signed FMA terms per query, versus 88 × (1024 + 2048) for spectral, plus each arm's scale work.

## Paired gfx1151 panel

The event interval spans 32 successive complete two-launch invocations, including host submission gaps. Eleven rounds each warm both arms with eight complete invocations and rotate their order. Inputs, images and scratch are device-resident before the interval. The paired output comparison and initial copies are outside it. The shared Bonsai reservation wrapper bounded the process scope, pinned performance mode and restored its resident service. [`nano_samples.json`](nano_samples.json) has every individual timing and both output errors, and [`nano_clock.json`](nano_clock.json) retains the clock and contention telemetry. This panel reported median shader clock 1052 MHz and another 3.5 busy host cores, with package-power limiting for 30% of the window. The earlier five-arm panel ran under heavier host contention, so use this panel's paired comparisons rather than comparing its absolute times to the old panel.

| Batch | Spectral µs, median [range] | Nano ADMM µs, median [range] | Median paired Nano/spectral |
| ---: | ---: | ---: | ---: |
| 1 | 11.03 [10.86, 13.35] | 12.17 [12.05, 17.89] | 1.108x |
| 16 | 53.24 [47.34, 56.19] | 93.00 [82.56, 106.66] | 1.741x |

The direct spectral GPU result has relative squared error **4.85e-14** versus its FP32 factor reference at one query and **6.75e-14** at 16. Nano's corresponding errors versus *its own* FP32 factor reference are **2.81e-14** and **2.23e-14**. This is a kernel accuracy check, not an equality assertion between quantizers. On the first 16 validation activations rounded to FP16, spectral and Nano responses differ by relative squared error 0.08077 with spectral as denominator. Relative to the original projection, spectral is 0.04249 and Nano is 0.07990 on this small subset. On the full held-out response set, the owning CPU reports give 0.081453 and 0.09666; whole-model NLL, KL and downstream behavior have their separate programme receipts. In particular, speed does not decide which projection error is acceptable.

The first stage has four times as many Nano rows and the second reduces four times as many rank coordinates. Nano also reads each input pre-scale inside its direct signed dot, while spectral reads a row/group scale there. This is one honest straightforward lowering, not an optimality result. A shared pre-scale pass, sign-dot ISA instructions, cooperative tiling or batched matrix instructions might change the timing, and would need their own online preparation and launch costs. The result says the cheap *arithmetic count* is a useful lead even against the real packed binary comparator, but at one query two launches and wave reduction leave only about 1.1x measured advantage.

## Inputs, identity and reproduction

[`nano_inputs.json`](nano_inputs.json) pins the Nano NPZ hash `1a8bf5e2071a1cff6133bfffbd610deb0eb5b814d5f77c8e7464b48df1f56d55`, the shared input hash, staged image hashes and Nano FP32 reference hash. The spectral fixture and factor hashes remain in [`inputs.json`](inputs.json). [`nano_identities.txt`](nano_identities.txt) names the two source hashes, included spectral source and executable hash. The measured executable, staged binary images and reference are kept in `/path/to/workspace/data/kelana-subbit/native-factors/` rather than Git. The initial four-arm executable is still not available; its hashes and raw records are retained without inventing a replacement.

```sh
mkdir -p build
OPENBLAS_NUM_THREADS=4 python3 prepare.py build
OPENBLAS_NUM_THREADS=4 python3 nano_prepare.py build
hipcc --offload-arch=gfx1151 -O3 -std=c++17 nano_probe.hip -lhipblas -o build/nano_probe
/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 42s \
  --memory-gib 6 --pin-clock --clock-log "$PWD/build/nano_clock.json" \
  --exec "$PWD/build/nano_probe" "$PWD/build" "$PWD/build/nano_samples.json"
```
