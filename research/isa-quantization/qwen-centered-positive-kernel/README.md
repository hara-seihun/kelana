# One paid source-centered positive-kernel reader

**This is one coordinate change to the frozen 64-feature program, not a rank/seed search.** Use the exact [train-only uniform-causal-pair shared GQA key center](../qwen-kernel-gauge-screen/README.md), round its 128 coordinates to FP16 once, retain the original Gaussian 64×128 FP16 table, and substitute `k−c` for each scaled/rotated normalized key before the same stabilized positive-feature prefix update. The source checkpoint, both Q heads, K/V/O/gamma, learned norms, RoPE, original teacher, causal windows and values are unchanged. All 8 train +4 inspected-held windows were replayed. Held head0/head1 attention KL improves strongly against the unchanged uncentered reader (`851.196/1359.356 → 137.244/188.419`) but held complete two-head post-O **worsens** (`1.53503 → 1.69048`). Both outcomes remain much worse than the paid Q4/Q6 K/V caches on the same consumer. No candidate/rank/seed/center-precision selection follows.

## Paid fields and exact observation contract

The source/checkpoint and the original fixed feature table are the [primary 64-feature study](../qwen-positive-kernel/README.md). The [geometry study](../qwen-kernel-gauge-screen/README.md) fixed `c=E_train(u_i+v_j)` with **uniform mass over each causal query–prior pair** across the two shared-K GQA Q heads and eight train 256-position windows. It used neither held source states nor output error. [`center.py`](center.py) checks its FP64 NumPy receipt SHA256 `0f73d862603b687cc41ef4f37574cf7d87f13dd98bec4443386bed773fdb3023` then writes **one actual 256-byte per-model FP16 image**, [`shared-key-center-f16.bin`](shared-key-center-f16.bin), SHA256 `7f991ba8b77dc6199ad8ffb3ca5c9d13c14a2997efed7ac7277de9c21f3f99ca`. Maximum FP16 rounding from the train centroid is `.00344795`. [`center_reader.py`](center_reader.py) independently parses and hashes the paid image and imports no preparation code. Any fixed `c`, including the rounded one, changes the **exact** source score `u_i·v_j` by a query-row constant `−u_i·c`; ideal exact softmax, V mixing and O are invariant. This does **not** make the finite-feature approximation invariant.

[`measure.py`](measure.py) pins the original [reader source](../qwen-positive-kernel/measure.py) by SHA256 `a9e5ee5de5666759964bc93a619a1c78038eff072f18c81c0f55636c3b953c86` and changes **only the first, shared key feature call** to apply the independently decoded FP16 center in the scaled rotary coordinate. The two Q feature calls, 64×128 FP16 Gaussian table SHA256 `c79b3d345a0bfc6a1b2e4a6e8f04246e5b7750e885ae17f3eb36ad66d53d86f5`, per-feature FP32 log maxima, prefix numerator/denominator, actual source Q/K/V/O, score/softmax and causal-window numerical contract are identical. The wrapper asserts the exact call sequence and all asset hashes. Dense kernel evaluation is used **only** as an acceptance cross-check of the streaming numerator/denominator (max absolute discrepancy across held windows ≤`2.75e−6`), not as inference state. The source K feature is prepared at each actual token insertion and then discarded; both Q heads read one common moment state. No alternative centered table was generated.

| State/resource at 256-token two-head GQA group | Bytes | Owner |
| --- | ---: | --- |
| 64×128 FP32 value moment numerator | 32,768 | Live prefix state |
| 64 FP32 denominator and 64 FP32 log maxima | 512 | Live prefix state |
| unchanged 64×128 FP16 Gaussian table | 16,384 | Generic static table, charged once to standalone reader |
| new 128×FP16 shared key center | 256 | **Per-model static** field |
| **Combined table + center + live state** | **49,920** | Distinct static/live axes, not device-footprint total |

The original Q/K/V/O/gamma static 1,573,376 B affected group is common to all arms. The uncentered reader has 49,664 B table+state; the center adds exactly **256 B** and 128 key-coordinate subtracts per token. Conventional independently serialized/decoded per-token whole-vector affine K/V Q6 is 51,200 B at this horizon, **1,280 B larger**; Q4 is 34,816 B, **15,104 B smaller**. BF16 raw K/V is 131,072 B if Knorm/RoPE is done from cached raw K. Source projection, normalization, O, feature exponentials, update scaling, cache bit unpack and native code footprint/work are separate axes, not included in these data-byte totals. There is no native timing or full-model speed claim. A reader that instead wants an FP64 key center would pay 1,024 raw center bytes and is not this image.

## Complete frozen comparison

[`aggregate.py`](aggregate.py) requires all 12 new causal-window receipts and pins the **unchanged** primary [`results.json`](../qwen-positive-kernel/results.json) by SHA256 `e99a8f2238ae7540d279a5118697d4e4686eb1d2e3004ad5481b4d2a37adb71d`; it reuses the original uncentered/Q4/Q6 successes **without rerunning them**. The teacher uses the same original Q/K/V/gamma/RoPE/softmax/O; Q4/Q6 are conventional **per-token, per-vector** dynamic affine K/V caches (K encoded *after* Knorm/RoPE), not per-channel or SOTA KV. Attention KL is a mean over causal queries; O relative squared is a sum of squared output differences over all windows divided by the corresponding teacher squared norm. Two-head GQA post-O includes both original O column blocks.

| Panel | Program | Table + field + state | Head0 KL | Head1 KL | Head0 post-O | Head1 post-O | **Two-head post-O** |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| train | original uncentered rank64 | 49,664 B | 754.639 | 1265.955 | 2.08054 | 1.42317 | 1.52692 |
| train | **one FP16-centered rank64** | **49,920 B** | **117.821** | **162.824** | 3.09160 | 1.69275 | **1.84791** |
| train | K/V Q6 | 51,200 B | 1.36178 | 1.59681 | 1.01528 | .53940 | .58156 |
| train | K/V Q4 | 34,816 B | 1.66693 | 3.97785 | .59131 | .97078 | .92610 |
| inspected held | original uncentered rank64 | 49,664 B | 851.196 | 1359.356 | 1.95922 | 1.44101 | 1.53503 |
| inspected held | **one FP16-centered rank64** | **49,920 B** | **137.244** | **188.419** | 2.48401 | 1.56411 | **1.69048** |
| inspected held | K/V Q6 | 51,200 B | 1.44198 | 1.70317 | 1.15447 | .59772 | .65695 |
| inspected held | K/V Q4 | 34,816 B | 1.67075 | 4.06605 | .62296 | .96938 | .92367 |

The gauge screen showed that the train mean ideal iid Gaussian *per-score* variance exponent falls from ~3358 to ~395 under a real centroid but remains large; FP16 rounding does not change the exact softmax-row-gauge principle. Actual finite-feature held KL improves ~6–7× yet remains vastly larger than either paid scalar cache, while **the complete projected V/O metric worsens**. KL and final O need not rank candidate approximate programs the same; V directions and both O blocks matter. Train shows the same ranking conflict, so this is not a held-set tuning artifact. Neither the exponent alone nor this one realized center excludes other stationary positive kernels, source-specific features, value co-design or attention-free direct response maps. The parent's general gauge theorem and exact toy own the mathematical statement; this is the one paid real-source endpoint.

## Reproduction

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$PY research/isa-quantization/qwen-centered-positive-kernel/center.py
for i in 0 1 2 3 4 5 6 7; do $PY research/isa-quantization/qwen-centered-positive-kernel/measure.py train "$i"; done
for i in 0 1 2 3; do $PY research/isa-quantization/qwen-centered-positive-kernel/measure.py held "$i"; done
$PY research/isa-quantization/qwen-centered-positive-kernel/aggregate.py
```

Each CPU command is individually under one minute. [`center.json`](center.json), image SHA and all 12 new JSON receipts are retained; [`results.json`](results.json) contains the pinned old-control comparison. No existing image, cache fit, seed, table or control result is regenerated. No GPU, new capture or native performance measurement is involved.
