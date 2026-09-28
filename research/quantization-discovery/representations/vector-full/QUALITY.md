# Full-channel paired gate/up quality

The one-byte polar result on a 512-pair slice does not carry over at the selected ternary image's rate. On complete Qwen3-0.6B MLPs, a learned eight-bit paired table improves held response in layers 0 and 14, but its gate/up payload is 4 bits per weight. At almost exactly the selected ternary MLP's physical byte count, a row-selected three/four-bit paired code loses in every tested layer. Layer 27 is particularly sensitive: the learned eight-bit pair table has lower weight error than polar, yet much worse nonlinear output error.

## Paired local measurement

Each layer has all 3,072 hidden channels, all 1,024 input columns, SiLU gate times up, and all 1,024 down outputs. The input is the *actual* complete expanded-scale384 ternary model producer, not the earlier narrow-V/O layer-0 capture. Train windows 464–467 and held validation windows 8–11 come from separate text. I take positions 0–31 of each 256-token window, 128 positions per split. The target is the original BF16 gate/up/down MLP response on each captured producer input. Every compressed arm uses the **same existing packed expanded-scale384 ternary down** decoded to its effective FP32 coefficients for local arithmetic. The down-only control isolates its error. This experiment does not replace the model's residual or measure gold-token loss. The parent full-model experiment owns that acceptance.

The tables below give train / held relative RMS against the BF16 MLP response. No BF16 down is silently carried by a compressed arm.

| Image, complete MLP bytes | Layer 0 | Layer 14 | Layer 27 |
| --- | ---: | ---: | ---: |
| Original BF16 gate/up, shared packed down, 13,261,606 | .42180 / .37815 | .37835 / .35593 | .16184 / .14156 |
| Selected ternary gate/up/down, 2,035,570 | .53501 / .48970 | .52433 / .49800 | .33266 / .29369 |
| Joint learned 3-bit, 1,858,388 | .72085 / .69242 | .78752 / .72834 | .71893 / .66716 |
| Joint learned 4-bit, 2,251,636 | .59940 / .57113 | .62430 / .57272 | 1.47077 / 1.04269 |
| Joint learned mixed 3/4-bit, 2,035,482 | .60016 / .59608 | .67708 / .64598 | .81812 / .56718 |
| Joint polar 6-bit, 3,038,260 | .50095 / .46160 | .49110 / .46560 | .69836 / .59329 |
| Joint learned 6-bit, 3,038,260 | .48331 / .44347 | .47405 / .44294 | 3.70688 / 2.38297 |
| Joint polar 8-bit, 3,825,460 | .44249 / .40070 | .41272 / .38741 | .64773 / .55477 |
| Joint learned 8-bit, 3,825,460 | .43989 / .39728 | .40643 / .38202 | 2.08687 / 1.30685 |
| Paired-pattern fitted scalar-scale 8-bit, 3,824,468 | .51882 / .48186 | .49065 / .45426 | 13.06239 / 8.50282 |
| Independent group-128 scalar4 gate/up, 3,922,758 | .43759 / .39464 | .41007 / .38629 | 4.05559 / 2.55453 |

The original-gate/up diagnostic pays 12,582,912 BF16 gate/up bytes plus 678,694 packed-down bytes. It isolates down error, not a cheap deployable pair code.

The 8-bit pair holds one index per gate/up pair, or **4 bits per gate/up weight**, not 1.7. Its 3,146,766-byte paired image plus 678,694-byte common down exceeds the selected ternary MLP by 1,789,890 bytes. The mixed 3/4-bit image is 88 bytes *smaller* than the selected ternary MLP, including its 384-byte row mask, two FP16 tables, gains, index planes and descriptors. It selects 1,380 four-bit rows using the train response's first-order per-row loss improvement over the three-bit image; validation never selects rows. Pair interactions remain, so this finite selection is not a global optimum. It still loses to selected ternary on held text in all three layers. The unselected three-bit image is also below selected ternary's byte count, but loses more.

The fitted scalar-scale comparator is a four-bit shared scale index plus two two-bit signed labels per pair. It fits its 16 FP16 scales by 16 alternating least-squares/assignment steps on a deterministic 32,768-pair source-weight sample and stores just those 32 bytes, not a hidden 1,024-byte model table. Its 1,024-byte prepared table is a runtime cost. This is **not** a universal control for independent 4-bit per-weight scalars: the separate existing group-128 scalar4 image is the latter, with 97,298 more physical bytes per full MLP than the eight-bit paired code. The learned-pair comparator trains a true 256-vector FP16 table on the same 32,768-pair weight sample for eight Lloyd iterations, pays all 1,024 table bytes, and uses the same index assignment and lookup geometry as polar. In layers 0 and 14 it is stronger than the fixed polar table at the same exact physical byte count. Layer 27 demonstrates why weight SSE alone is not a safe quality criterion.

## Stored contract and custody

[codec.py](codec.py) exports `decode_image(path) -> (gate, up)` as two FP32 arrays `[3072,1024]`; rows are hidden channels. A uniform image has `codes` uint8 `[3072,1024]` at width 8, or `packed` uint8 at widths 3, 4, 6. Packed indices flatten row-major, put the low bit of each index first, and pack bit zero at the low bit of each byte; codes may cross byte boundaries. `table` is little-endian FP16 `[2**width,2]`, already gain-folded, except the fitted scalar-scale image stores `scales` FP16 and deterministically prepares the FP16 pair table from signed labels. `gain` is paid two-byte informational metadata and must **not** be multiplied into the stored table again. Both `width` int32 and `shape` int32[2] are paid descriptors. The mixed image stores separate row-major 3-/4-bit planes, their FP16 tables, two gains, a low-bit-first row mask, and width/shape descriptors. The original ternary down stays identical across every arm and contributes 678,694 physical bytes including its own shape/rotation descriptors.

The image receipts record charged physical payload bytes separately from larger `.npz` file/container bytes, the image digest, source digest, weight SSE, table size and gain/descriptor charges. The [capture directory](/path/to/workspace/data/kelana-subbit/vector-full/capture/) contains paired train/validation BF16 input bits and source/token/image hashes. Each `*.quality.json` identifies exact image and capture digests, chosen positions, target norm, train/held RMS, and common-down-only scores. `layer{00,14,27}-selected-baseline.json` and `layer{00,14,27}-independent-scalar4-g128.json` hold the two source controls. All full code arrays/tables/gains are retained in the image `.npz` files; the receipts are not substitutes for the images.

Run from the Kelana checkout with `OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/representations/vector-full/quality.py fit --layer 0 --width 8 --method learned_pair`, then `quality.py score /path/to/workspace/data/kelana-subbit/vector-full/images/layer00-learned_pair-8bit.npz`. `quality.py baseline --layer 0`, `quality.py scalar4 --layer 0`, and `mixed.py --layer 0` reproduce the controls. CPU fitting and scoring use no GPU reservation. Full-model capture and image preparation have separate owners; no native throughput is inferred from these FP32 local matrix products.
