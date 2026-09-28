# Full native path for instruction-induced cells

**Finding:** The nonuniform square cells preserve their structural advantage over the *searched* same-size affine and uniform tables after a dynamic continuation, but **do not make this small native kernel faster**. All four reader/consumer kernels fetch their table and produce the same scalar endpoint; the 32-cell direct table is substantially more accurate, uses four times the static table space, and runs at effectively the same measured time while its entire table fits cache. This is a distortion/storage tradeoff, not a native-speed win. No trained-model prevalence or whole-model gain follows.

## Contract and controls

The source is the independent, unplanted seed-0 three-coordinate SiLU gate/up teacher from [`../instruction-cells/search.py`](../instruction-cells/search.py), with unsigned `x=0..31`. Interpret its three outputs `y0,y1,y2` as coefficients of the **live consumer** `F(x,t)=y0(x)+t*y1(x)+t²*y2(x)`, with runtime `t∈{-1,-.25,.5,1.25}`. This t range is not known to the table lookup: all three FP16 coefficients remain needed by the same compiled consumer. Score all 128 `(x,t)` cases by squared error divided by centered response energy. All arms fit each cell's three conditional means, round to FP16, and use aligned 8-byte rows (three FP16 and a paid padding half). The `t` basis has the same full-rank Gram matrix for every cell, making those means the best real coefficient vector under this endpoint loss; the rounding is scored afterwards.

| Producer/reader | FP16 table bytes | Relative RMS at scalar endpoint |
| --- | ---: | ---: |
| `(x*x)>>7`, 8 cells | 64 | 0.11095661 |
| `(31*x)>>7`, best of 797 distinct affine partitions with `(a*x+b)>>s`, 8 cells | 64 | 0.13886374 |
| `x>>2`, 8 uniform cells | 64 | 0.14988104 |
| `x`, 32 direct cells | 256 | 0.00021758 |

[`structural.json`](structural.json) records the exact coefficients, continuation points, affine witness and SSE. The affine search examines the broad grid in the prior report before the native choice; its winner on this endpoint is exactly `(31*x)>>7`, so it has the same producer instruction count and table bytes as the square, without an unpaid bias or extra instruction. The 32-cell control is the strong distortion benchmark rather than a same-byte control. For a fixed `t`, a *scalar* 32-entry FP16 direct table also costs 64 bytes, avoids the continuation, and dominates this construction in accuracy: keeping `t` genuinely dynamic is indispensable. A different layout or a fused downstream observer may change the frontier.

## Emitted full reader and consumer

[`native.hip`](native.hip) compiles four independent `gfx1151` kernels. Each lane loads `x` and runtime `t`, forms its address, issues two global table loads for the three FP16 labels, computes `t²` and two packed half-to-float `v_fma_mix_f32` operations, then stores a float. The compiler folds the shift and 8-byte row offset into `v_lshrrev_b32 4` plus `v_and_b32 0xff8` for both square and affine; their producer multiply differs only in second operand (`v2` versus literal `31`). The uniform producer uses mask and shift; direct indexes `x`. [`assembly.txt`](assembly.txt) preserves the complete short instruction bodies from the compiler. All four use six VGPRs, eight numbered SGPRs, no scratch, with the same table fetch/continuation instructions. This is stronger than the prior stand-alone producer assembly: the reader and live continuation are emitted, not assumed free. It still does not establish instruction-retirement cost or cache misses in a larger kernel.

The [`timing.txt`](timing.txt) GPU receipt verifies **every output** against an independent CPU FP16 decoder and FMA (max discrepancy zero). At 1,048,576 outputs, the five-round medians in microseconds are square 15.885, affine 15.856, uniform 15.855, direct 15.780; at 8,192 outputs, 2.391, 2.412, 2.456, 2.448. Large outliers occur, so the 0.1–0.7% bulk differences are not a robust speed ranking. The table is hot, inputs and output are device-resident and each launch computes one scalar. At this scale, the extra 192 table bytes buy much better accuracy without an observed runtime penalty. Structural fidelity, emitted legality and elapsed time are separate results.

## Reproduce

```sh
cd research/isa-quantization/cell-native
OPENBLAS_NUM_THREADS=1 python3 make_tables.py
hipcc --offload-arch=gfx1151 -O3 native.hip -o /tmp/kelana-cell-native
flock -n /tmp/kelana-gpu-measure.lock \
  gpu-run --host-mib 1024 --gtt-mib 512 /tmp/kelana-cell-native 1048576 128
```

Use the machine's [GPU admission](/path/to/workspace/machine/gpu-jobs.md) rules when reproducing a device timing; do not run an unadmitted kernel beside resident work. `hipcc --offload-arch=gfx1151 -O3 -save-temps native.hip -o /tmp/kelana-cell-native` emits the `.s` used for the compact assembly receipt. Each native run takes seconds. The tables are generated, not independently hand-tuned. The event window excludes installation, launch and transfer, but **includes** instruction production, random table addressing, two label loads, conversion/continuation and output store. Finite numerical teacher and FP16 entries are distinct from an exact proof of SiLU or of hardware timing across workloads.
