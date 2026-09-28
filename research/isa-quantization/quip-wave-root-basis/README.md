# Wave-carried signed sums for exact E81B root dots

**Negative complete native result for this wave placement:** the exact [26-coordinate signed-sum map](../e8-root-program/WAVE.md) avoids building eight residual coefficients per high root and retains the 50,322-byte table-free model image, but this `gfx1151` whole-reader kernel runs **slower** than both the direct root and the frozen hot-table readers on batch one and eight real captured states. This is a measured placement result, not an ISA impossibility theorem or a reason to erase the independently valuable exact static-table saving.

## The map and paid lane placement

The parent [`wave_basis.py`](../e8-root-program/wave_basis.py) checks all 256 root-byte codes on every standard-basis input with exact rational arithmetic. For each post-Hadamard eight-input block `z`, the 26 live coordinates are 8 signed sums of `z0:z2`, 8 signed sums of `z3:z5`, 2 sums `z6±z7`, and the 8 original inputs. A high-root byte can be canonicalized by complementing its seven sign bits when bit 6 is set; the resulting half-root dot selects **three signed sums**, restores the global sign and halves. A sparse integer/axis root reads its two original inputs; code 127 contributes zero. The image codes, both Hadamard sign vectors, E8P absolute table, global FP16 scale and dynamic FP32 input are unchanged. There is no activation quantization, expanded weight image, code-index conversion, persistent 26-float dictionary or new model-specific byte.

[`native.hip`](native.hip) places each group of **32 output lanes** in a wave. Every eight-input block, 18 lanes cooperatively compute its signed sums from the transformed input in LDS: lanes 0–7 the first triple, 8–15 the second triple, 16–17 the last pair. All 32 lanes then issue **three index-dependent wave shuffles** (`ds_bpermute_b32` in [`assembly.s`](assembly.s)) to select these sums. The shuffles are unconditional even for lanes whose current model code is sparse: a divergent conditional would leave a possible selected source lane inactive. Sparse lanes then use their two original indexed input reads. Four waves in the 128-thread block duplicate this 18-value preparation per eight-input block. The arithmetic saved on the 8,798 half-root image codes therefore buys 128 groups ×4 waves ×18 = **9,216 prepared signed-sum values per full response**, plus **128 groups ×128 lanes ×3 = 49,152 dynamic shuffle selections** (including sparse/zero labels), parity/sign/canonicalization and branch work. The preparation's two triple families each have 16 additions and the final pair two, or `34×4×128=17,408` signed-sum additions per input response in this placement. Those values live in wave registers only for a group iteration; they are not a 9,216-float resident buffer. The input and output Hadamards still perform respectively 5,120 and 448 butterflies, two scalar add/sub operations per butterfly, per state.

This is a real reuse opportunity, but the code and communication matter: per-lane direct-root high codes evaluate eight signed input terms; the wave basis computes three selected values **after** per-wave preparation and has to pay three shuffles on every code. The 7,533 nonzero sparse roots and 53 zero codes do not benefit from the signed triples. This one placement finds that wave preparation and `ds_bpermute` latency erase the coefficient-arithmetic saving. A compatible upstream producer supplying the signed-sum label could change that cost boundary; this captured FP32 producer supplies only ordinary input states, so the complete online preparation is paid here.

## Complete reader contract and static bytes

The comparison inherits the established [`quip-full-native-root/prepare.py`](../quip-full-native-root/prepare.py): eight **distinct held 1,024-input states**, independently decoded old/root/scalar stored-image 128-output targets and original BF16-derived teacher. The prepared host file contains **inputs and target responses, never predecoded weights**. Each complete device kernel signs and transforms all 1,024 inputs, reads all 16,384 original E8P codes and 16,384 residual bytes, performs 131,072 base coefficient contributions, applies global FP16 scale and the 128-output Hadamard/signs, and writes the full 128-output response. The direct root, hot FP16 residual table and scalar arms use their corresponding reader from the [prior native study](../quip-full-native-root/README.md) as controls, compiled in this same executable. The wave arm's output is checked against the *same independent stored-image target* as the direct-root arm; its maximum discrepancy on all eight states is **4.47e−7**, and the old/direct/scalar controls are likewise under **4.77e−7**. The one/eight-state native teacher errors in [`timing.txt`](timing.txt) are subset numerical checks, not the full-held accuracy claim. Full-panel ideal QuIP root and scalar error remain .013109790 and .014627799; the [causal observer](../quip-complete-head-observer/README.md) establishes a different held ranking after RMSNorm and attention.

| Reader | Image bytes | Once-billed residual asset | Device body instruction bytes | Shared input-Hadamard helper | Total image + own body + helper |
| --- | ---: | ---: | ---: | ---: | ---: |
| Hot original FP16-table RVQ | 54,418 (including 4,096 FP16 residual) | already included | 2,744 | 10,872 | 68,034 |
| Table-free direct root | 50,322 | 0 | 3,056 | 10,872 | 64,250 |
| Table-free wave basis | **50,322** | **0** | **3,316** | **10,872** | **64,510** |
| Matched scalar Q2/Q3 | 50,320 | no table | 8,344 | none | 58,664 |

These emitted device body sizes come from `llvm-nm -S --size-sort native-hip-amdgcn-amd-amdhsa-gfx1151.out`, not the 200-KB-ish *textual* `.s`; descriptors, common host code and HIP runtime are outside this narrow static instruction accounting for all arms. The exact 4,096-byte generic table saving is **once per reader pool**, not once per matrix in a multi-layer model. Including this compiled-body difference, wave still saves 3,524 B versus the hot-table arm but costs 260 B more than direct root. Shared helper placement is compiler-specific. The table and wave comparisons have unchanged 4,608 B LDS per block (4,096 input +512 output), **44 VGPR / 35 SGPR per lane, zero scratch**; the scalar uses no LDS, 36 VGPR /24 SGPR, zero scratch. The wave signed sums are registers, not a 128-entry LDS lookup. For batch8 the hardware runs eight independent 128-thread blocks. The timing harness holds *all three Q images plus the old residual table* simultaneously for adjacent controls, not a single-arm deployment footprint; root and wave do not dereference the old table pointer. Input and output device buffers hold at most 32,768 and 4,096 B for the eight-state batch.

## Bounded native receipt

[`timing.txt`](timing.txt) retains **48 event and wall readings per arm per shape**, with rotating adjacent launches after independent numerical acceptance and 16 warmups. Every launch computes one whole response for **batch1 or batch8 actual distinct states**, not an artificially repeated element array. Model images and inputs are already device-resident/warm; measured event time includes the complete kernel but not one-time build, H2D preparation or D2H acceptance copy. Wall time includes event records, launch and synchronization. Median microseconds per complete invocation:

| Held-state batch | Hot original event/wall | Direct root event/wall | Wave basis event/wall | Scalar event/wall |
| --- | ---: | ---: | ---: | ---: |
| 1 | **22.519 / 36.699** | 31.158 / 42.199 | 37.639 / 56.298 | 62.238 / 82.017 |
| 8 | **22.479 / 36.759** | 31.159 / 42.809 | 37.679 / 56.258 | 62.158 / 81.998 |

The wave arm is ~20.8% slower than direct root and ~67.1% slower than hot table by batch-one event median. It is not an accuracy change: all three structured arms read exactly the same stored weight map. It is not evidence for full-model serving or a universal limit on alternate wave placements. Scalar is a concrete matched-byte reader, not an asserted optimized AMD lower bound.

Device use was serialized by the exclusive engine-start lease `/tmp/kelana-gpu-measure.lock` and bounded by `gpu-run --host-mib 1024 --gtt-mib 512`. Bonsai serving stayed active at PID **203054** before and after; the lease cannot exclude already-running requests to that resident. No service was stopped or altered.

```sh
cd research/isa-quantization/quip-full-native-root
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python prepare.py
cd ../quip-wave-root-basis
hipcc --offload-arch=gfx1151 -O3 -save-temps native.hip -o native
(exec 9>/tmp/kelana-gpu-measure.lock; flock -w 10 -E 75 9 || exit $?; gpu-run --host-mib 1024 --gtt-mib 512 ./native .. ../quip-full-native-root > timing.txt)
```

This is a CPU algebra checked elsewhere plus one native complete-map placement, not an optimization sweep. No GPU work remains requested.
