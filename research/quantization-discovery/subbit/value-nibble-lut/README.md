# A learned byte table behind the half-byte value cache

The frozen rank-28 shared V/O image loses quality when its value cache uses a uniform signed nibble. A per-coordinate sixteen-entry signed-byte table improves the complete two-head post-O response while keeping one nibble per cached coordinate and the two signed-byte probability dots. The table is read into registers when codes are consumed, not materialized as an expanded cache. This is a new quality/rate point, not a native speed result or a quality match for E4M3.

On Qwen3-0.6B layers 0 and 14, use eight 256-token original-producer training windows and four previously inspected validation windows. Fit each of 224 codebooks by twelve one-dimensional Lloyd steps on the BF16-rounded narrow V producer. Round each learned center to an int8 level times one FP16 coordinate step, assign codes to the nearest rounded center, then fit the same paid two-bit O codes and FP16 row scales for each arm. The O fit uses the first four train windows for ridge candidates, the next four to choose the ridge, all eight for its final fit, and two response-code sweeps. Both uniform-nibble and group-scaled E4M3 controls receive that identical O refit. The right basis and original Q/K are frozen.

| Layer | Uniform nibble | Learned table | E4M3 | 4095-count table consumer |
| --- | ---: | ---: | ---: | ---: |
| 0 | .385148 | .384126 | .377798 | .384128 |
| 14 | .334500 | .330807 | .325434 | .330814 |

The entries are held relative post-O squared errors against original V/O. The learned table beats the fitted uniform nibble on all four inspected windows in both layers. At layer 14 it closes another .003693 of the .009066 uniform-nibble/E4M3 gap. The table's train error is .161616 versus uniform .162126 there; at layer 0 it has *worse* train error .209887 versus .208893 despite better held error. This is not evidence that an unconstrained table fit will generalize. E4M3 still wins by .005373/.006328 at layers 14/0.

## Direct arithmetic and paid rate

Let `b_tj` be a packed four-bit code, `L_j[b]` its signed-byte table entry, and `s_j` its FP16 step. Prefix-rounded causal probability counts `n_t >= 0` conserve `M=4095`. The output coordinate is

```
  a_hj = s_j/M * sum_t n_ht * L_j[b_tj].
```

The dot is integer before the single coordinate scale. Each table entry lies in `[-127,127]`, so the exact signed integer result is at most `127*4095=520065` in magnitude, well within int32 and exactly representable in FP32. Two signed-byte probability digits compute it without per-key FP32 value expansion. The held replay computes the prefix-count map and reports .384128/.330814; the maximum observed integer coordinates are 520065/514550. The table changes the lossy V map; integer mass changes it again, so neither is an FP32 identity to the teacher. The probability-rounding error has the same summation-by-parts certificate as [the integer consumer](../value-integer-consumer/README.md), now using the temporal variation of `L_j[b_tj]` multiplied by `s_j`.

The table costs `224*16=3584` signed bytes plus 448 FP16 step bytes per layer. The paid right/left factors remain 208,640 bytes; the new complete V/O image plus table is 212,672 bytes, about .540852 BPW over 3,145,728 original V/O weights, before container headers. Uniform nibble has a 476-byte step/endpoint descriptor and E4M3 uses its own group-scale metadata. The cache remains 112 logical/128 padded bytes per token per layer, versus E4M3's 224/256. For each cached value token the producer chooses 224 nearest table entries. The consumer must unpack 224 labels, perform 224 byte-table selections per KV group/key, and do the two signed-byte dots across 448 head-coordinate pairs per key, plus count preparation, coordinate scaling and the paid O work. Both query heads may share the table selection of their KV group. A literal per-coordinate sixteen-way search at inference is not free; native producer/lookup instruction counts, occupancy and memory traffic remain to be measured. The CPU replay expands to floating values for quality and does not time this native program.

The narrow right basis, original producer and four validation windows have all been inspected repeatedly. This result does not establish fresh language loss, quantized-upstream behavior or a win over E4M3. The next useful experiment fits table levels, the right basis and paid O codes against fresh quantized-producer complete-model continuation. Compare the resulting image with a same-budget E4M3 control before building the native table lookup/count consumer. A static byte table is useful only if its extra selection work is cheaper than the bandwidth and arithmetic it saves.

`measure.py --layer 0` and `--layer 14` regenerate `/path/to/workspace/data/kelana-subbit/value-nibble-lut/layerXX-8x4.json`, the signed-byte tables and the three paid O images. Each receipt includes per-window errors and source, model, capture, factor, parent and output-image hashes. Use `/path/to/workspace/data/fish-s2-pro/venv/bin/python` with `OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8`. No GPU, Bonsai executable or service changed.
