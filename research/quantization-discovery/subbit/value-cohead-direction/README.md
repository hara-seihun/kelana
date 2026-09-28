# Which GQA head should start the signed-byte value dot?

The [exact two-head count reader](../value-cohead-mass-share/README.md) computes head A's paid signed-byte value dot and gets head B from a signed count difference. A and B are interchangeable in the integer algebra, but not in the number of sparse overflow corrections. I compared both static orientations with a per-query choice on the pinned Qwen3-0.6B count rows. This is a cheap way to test whether a dynamic head-order selector belongs in the native reader before building one.

Let `a_k,b_k >= 0`, with each row summing to `M=4095`, and let the shared cache code `q_kj` lie in `[-127,127]`. For a chosen first head `x` and second head `y`, compute

```
L_x = min(x,255)                 E_x = x-L_x
D   = y-x                      L_D = clip(D,-128,127)
E_D = D-L_D
X_j = dot_u8_i8(L_x,q[:,j]) + sum_{E_x != 0} E_x q[:,j]
Y_j = X_j + dot_i8_i8(L_D,q[:,j]) + sum_{E_D != 0} E_D q[:,j].
```

Every intermediate integer dot and correction fits signed int32: `|X_j|,|Y_j| <= 4095*127`, and `|Y_j-X_j| <= 8190*127`. Positive and negative masses of `D` are equal and at most 4,095 each. At most `floor(4095/128)+floor(4095/129)=62` difference keys fall outside signed byte, and at most 15 first-head counts exceed 255. Thus a fixed 77-entry correction list per group/query covers either orientation at **any context length**, without reconstructing a value row. This is an exact integer identity for the existing conserved-count map and paid codes; the static post-dot scales and separate paid output-head maps remain unchanged. Floating reductions may round differently if scheduled differently.

Within the grammar of **one complete first-head unsigned-byte dot, one sparse signed-difference byte dot, and scalar corrections exactly at saturated keys**, choosing the smaller of the two correction counts is the per-query optimum. Reversing direction cannot change the first dense dot length, the signed-difference nonzero support, the 32-key padding of its list, or cache bytes. It can change the base overflow count and which `|D|=128` endpoint needs a correction. The selector needs both counts and must route the two attended outputs back to their own output maps. It is not free.

Four previously inspected, separate 256-token original-producer validation windows at each layer use the same pinned Q/K producer, 4,095-unit causal prefix counts and paid narrow-V code domain as the parent. The script checks count hashes against the parent's receipt and replays both orientations at signed-code endpoints and deterministic interior codes. Each panel has 8,192 GQA group/query rows. Corrections in the table are **keys**, with 28 integer code-coordinate products per key, before irregular gathers and count/list creation.

| Layer | A first | B first | Per-query minimum | Additional keys removed vs B first | Per-query B selections | 32-padded first-byte plus difference key uses |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 70,938 | 64,636 | 60,691 | 3,945 | 4,530 | 1,904,608 |
| 14 | 56,946 | 56,055 | 51,215 | 4,840 | 2,939 | 1,886,592 |

The fixed B-first choice is free of per-query output routing if baked into the GQA head assignment. Relative to the parent A-first reader it removes 6,302/891 correction keys, or 176,456/24,948 coordinate products across the layer-0/14 panels. An optimal dynamic selector removes only another 110,460/135,520 coordinate correction products, at a cost of 8,192 two-way decisions plus output routing on each panel. Its extra saving is 0.207%/0.257% of the respective 32-padded first-byte plus difference coordinate work. This is an upper limit on the useful **additional** product reduction from adaptive direction inside this grammar; it is not a latency bound. Both heads' paid O operations and all V cache reads still need pricing.

The [new duplicate-label paired reader](../value-paired-label-difference/README.md) aggregates equal *whole value codes* before taking the signed difference. Aggregation can change both overflow counts and the orientation preference. This receipt measures the ungrouped parent exactly and does not transfer its correction counts to that grouped reader. The integer direction theorem and 77-entry list bound still apply to grouped nonnegative counts, since grouping preserves each head's total mass. A fused native reader should first compare a static B-first ungrouped schedule and grouped-label schedule, charging count/list building, byte dots, correction gathers, scale/O and branch routing. Do not add a per-query selector solely for its small ideal-product margin.

`measure.py` and the [data receipts](/path/to/workspace/data/kelana-subbit/value-cohead-direction/README.md) record source, model, capture, parent and count hashes plus per-window totals. This is a CPU exact-map and logical-work result, not a native timing, a new lossy model image or a full-model loss result. No GPU or engine executable changed.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-cohead-direction/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
