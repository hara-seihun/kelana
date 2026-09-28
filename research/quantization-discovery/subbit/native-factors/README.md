# Packed Qwen projection factors on gfx1151

The [paired NanoQuant ADMM binary-factor panel](NANO.md) compares this rank-88 consumer with the actual equally sized packed competitor, including both scale passes and launches. Its spectral path takes 11.03 µs versus Nano's 12.17 µs at one query, and 53.24 versus 93.00 µs at 16 queries under that panel's paired clock regime.

At one query, decoding the 0.537-bit-per-weight factorization as two native HIP dots takes **13.12 µs**, against **20.34 µs** for a direct FP16 dot over the same factorization expanded to a full matrix. The packed consumer also beats this experiment's direct full-matrix int4 control at **16.86 µs**, but int4 is a different numerical map. At 16 queries, the packed path takes **63.39 µs** and loses to two BLAS calls over expanded FP16 *factors* at **37.93 µs**. That is the immediate instruction-level target: reuse packed factor coefficients across a batch rather than running one wave per output and query. Neither result is whole-model inference.

The source is Qwen3-0.6B layer 0 `self_attn.q_proj`, shape 2048 × 1024. Its rank-88 factors have 4-bit odd signed coefficients and one FP16 scale per row and 128 columns. The serialized payload is 140,704 bytes including shapes, 0.536743 bits per original weight. `right[88,1024]` is applied first, followed by `left[2048,88]`. Each packed kernel fetches nibbles and scales from the original image during the dot, multiplies against the current input, reduces across a 32-lane wave, and writes FP32. It does not prepare expanded factor weights. Both launches and the FP32 intermediate write/read are inside the interval. With 16 queries the intermediate is 5,632 bytes; with one query, 352 bytes. Outputs are FP32, 8,192 or 131,072 bytes.

## Paired panel

Radeon 8060S `gfx1151`, HIP 7.2.53211, device-resident validation activations rounded to FP16, first 1 or 16 rows. Each number is the median of nine rounds, each an event interval across 32 host-submitted complete invocations. Arm order rotates every round; each arm warms with six complete invocations before that round's measurement. Ranges show every per-round sample in [`samples.json`](samples.json). The interval includes inter-launch submission gaps. It excludes initial weights/input transfer, output copy for comparison, and offline image creation. [`clock.json`](clock.json) is the wrapper's pin-clock telemetry. Host work remained heavy: median reported shader clock 1089 MHz and 12.6 other busy host cores, with package-power limiting over 63% of the second window. The first four-arm panel gave packed/dense-int4/expanded-factor-BLAS medians 13.03/17.53/31.81 µs at one query and 61.74/182.28/36.59 µs at 16. The four-arm panel's [`samples-initial.json`](samples-initial.json) and [`clock-initial.json`](clock-initial.json) are retained too; its executable and source hashes are in `identities.txt`. The five-arm source in this directory adds the direct dense FP16 wave control. Ratios, not the absolute microseconds, are the useful reading of this contended machine.

| Consumer | Resident weight bytes | Launches | 1 query, µs median [range] | 16 queries, µs median [range] | Relative squared output error vs FP32 factors, 16 rows |
| --- | ---: | ---: | ---: | ---: | ---: |
| Direct packed rank-88 factors | 140,704 | 2 | 13.12 [12.79, 15.09] | 63.39 [58.10, 65.07] | 6.75e-14 |
| Expanded rank-88 FP16 factors, hipBLAS | 540,672 | 2 | 32.23 [28.44, 33.75] | 37.93 [33.48, 39.33] | 1.11e-7 |
| Expanded full FP16 map, native wave dot | 4,194,304 | 1 | 20.34 [19.05, 20.85] | 198.57 [196.73, 200.55] | 5.66e-9 |
| Expanded full FP16 map, hipBLAS | 4,194,304 | 1 | 76.35 [68.46, 79.24] | 80.89 [77.77, 87.45] | 5.66e-9 |
| Full matrix int4, direct wave dot | 1,081,344 | 1 | 16.86 [15.11, 20.00] | 194.62 [184.34, 198.22] | 0.001173 |

The full FP16 matrix is the FP16 rounding of the decoded factors' FP32 matrix product; its output error is FP16 storage rounding, not a different trained approximation. The hipBLAS dense route is slow at this shape, so the direct wave dot is the useful one-query expanded-map comparison. At 16 queries the two-call hipBLAS expanded-factor control is the fastest measured path. The packed kernel exposes 88 first-stage output waves at one query and 2,048 second-stage waves. Its second stage scales that per-output work with query count. The BLAS factor path pays for 540,672 resident FP16 weight bytes and a rounded FP16 intermediate, and amortizes across 16 queries. No packed WMMA consumer or high-throughput int4 GEMM is represented by this panel.

The int4 image is an **additional quantization of the decoded full factor map**, with one FP16 scale per output row and group of 128 and odd levels `[-15,15]`. It is a rate/speed control, not the identical map or a quality-matched NanoQuant competitor. Its extra relative squared error against the factor response is 0.001173 on 16 rows; per-batch measured errors, including the one-query value, are in `samples.json`. The factor response itself differs from this subset's original FP32 projection by relative squared error 0.04249. That is *not* the previously reported 0.081453 on the broader held-out response set. No conclusion about whole-model quality follows from either subset number.

The expanded dense comparison reads about 30 times the packed factor storage. The factor algorithm performs 88 × (1024 + 2048) scalar FMA terms per query, rather than 2048 × 1024 for the dense map, but its two kernel submissions, group-scale conversion, first-stage write and second-stage read remain online. The prefill loss to prepared expanded factors says storage alone is insufficient. A next consumer should tile several queries together around the packed weights and use matrix instructions or otherwise avoid one independent FP32 wave dot per output and query. It must still price both factor stages and any unpack preparation, not time a precomputed intermediate.

## Reproduce

[`inputs.json`](inputs.json) pins the artifact and fixture SHA-256, each generated image hash and the measured map errors. [`identities.txt`](identities.txt) pins the HIP source, preparation source and measured executable hashes. `samples.json` preserves every 90 timing and output-error sample. `clock.json` preserves the wrapper telemetry. The initial panel contributes another 72 samples, with its hashes and telemetry retained separately. No binary input blobs are in Git. From this directory:

```sh
mkdir -p build
OPENBLAS_NUM_THREADS=4 python3 prepare.py build
hipcc --offload-arch=gfx1151 -O3 -std=c++17 probe.hip -lhipblas -o build/probe
/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 42s \
  --memory-gib 6 --pin-clock --clock-log "$PWD/build/clock.json" \
  --exec "$PWD/build/probe" "$PWD/build" "$PWD/build/raw.json"
```

The wrapper holds the exclusive GPU reservation, bounds the process scope, and restores the resident Bonsai service. The service was active after both recorded panels. All methods consume the same device-resident input and produce FP32 output at the projection boundary. The CPU reference uses FP32 decoded factors and two FP32 matrix multiplies. The direct packed GPU result agrees within 6.75e-14 relative squared error on all 16 measured validation rows. The source records precise packed bit order and each comparator's arithmetic.
