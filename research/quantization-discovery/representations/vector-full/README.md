# Full-layer joint gate/up transfer

The joint pair code did not earn a model replacement. At the selected ternary image's byte budget, it loses on all three complete MLPs tested. At four bits per weight it improves early/middle local response, but ordinary group-128 four-bit quantization is competitive. Whole-model substitutions slightly improve test loss while worsening validation. The source `expanded-scale384` remains selected.

This follows the [four-channel polar experiment](../vector-geometry/README.md). The [local quality report](QUALITY.md) covers complete MLPs at layers 0, 14 and 27, including lower index rates and fitted controls. The [native reader report](../vector-native/README.md) covers the direct packed gate/up plus SiLU endpoint. None of these measurements is a full-model packed serving speedup.

## Whole-model result

The frozen [panel configuration](early-middle-frozen.json) replaces gate/up at layers 0 and 14 only. The local train/held response measurements motivated these layers before any whole-model scoring. All arms were frozen together. Every other matrix, including the selected ternary down projections and tied embedding/head, remains unchanged. The evaluator decodes actual packed images and runs BF16 forward passes.

| Whole image | Payload bytes | BPW | Validation NLL | Test NLL | Test perplexity |
| --- | ---: | ---: | ---: | ---: | ---: |
| Selected ternary source | 128,678,649 | 1.72709 | 4.733112 | 4.646432 | 104.212 |
| Polar 8-bit pair | 132,258,429 | 1.77513 | 4.743336 | 4.635783 | 103.109 |
| Learned 256-pair table | 132,258,429 | 1.77513 | 4.740782 | 4.636486 | 103.181 |
| Fitted paired scalar-scale | 132,256,445 | 1.77511 | 4.779323 | 4.668424 | 106.530 |
| Independent group-128 scalar4 | 132,453,025 | 1.77774 | 4.737979 | 4.630793 | 102.595 |

Validation uses fixture rows 0–7, 2,040 predicted tokens. Test uses rows 0–31, 8,160 predicted tokens. No image was refitted after these results. [Compact results](model-results.json) link and hash the immutable per-window receipts.

The joint images add 3,579,780 bytes to the complete source and reduce test NLL by about .01. They lose on validation, and the ordinary grouped scalar4 replacement beats both joint alternatives on both splits for 194,596 additional complete-image bytes. This does not establish that joint pair coding is the best decomposition. It also shows why a better local response does not guarantee improved complete-model loss.

## Complete-layer and native outcomes

At essentially equal complete-MLP bytes, the learned mixed 3/4-bit pair image scores held relative response RMS .5961/.6460/.5672 at layers 0/14/27, versus .4897/.4980/.2937 for selected ternary. Its 2,035,482 bytes are 88 fewer than the selected MLP. The lower-rate family tested here does not replace ternary.

The eight-bit pair image is four bits per gate/up weight, not sub-bit or ternary. Its complete MLP costs 3,825,460 bytes. Learned pairs score .3973/.3820/1.3069; fixed polar scores .4007/.3874/.5548. Layer 27 reverses the learned-versus-polar ranking despite lower learned weight SSE. The nearby-rate independent scalar4 control costs 3,922,758 bytes and scores .3946/.3863/2.5545.

The corrected gfx1151 native reader takes about 30 microseconds for one full 3,072-channel gate/up plus SiLU evaluation. Polar, learned-pair and fitted-scalar readers are effectively tied. The expanded FP16 wave-row control takes 42.5 microseconds, but it is not an optimized GEMM or full-model baseline. Native outputs pass an independent NumPy check before timing. The initial wave-size bug and rejected panel remain recorded in the reader's report.

## Capture and storage contract

`model.py` validates all 197 matrix hashes in `expanded-scale384`, installs the image and preserves the tied embedding/head. It captures actual MLP inputs at layers 0, 14 and 27. Data and its operations guide live at `/path/to/workspace/data/kelana-subbit/vector-full/`.

- Train capture uses expanded fixture rows 464–467.
- Local held capture uses validation rows 8–11, separate from whole-model validation.
- Four 256-token windows produce each `layer00`, `layer14`, `layer27` array of shape `[1024,1024]`, stored as BF16 bits in uint16.
- Adjacent receipts hash the selected image, BF16 checkpoint, token fixture, script and capture.

The local target is the original BF16 MLP on these actual quantized-producer inputs. Every compressed arm uses the same selected ternary down. The original-gate/up diagnostic charges its BF16 pair separately. Full pair code arrays, tables, scales and descriptors are paid model payload. `.npz` container bytes are reported separately. A stored table already includes the gain, so decoding must not apply it twice. The paired scalar-scale code uses two two-bit labels and a four-bit scale index; the independent scalar4 control uses four bits per weight and FP16 group scales. They are distinct controls.

## Reproduction

From the Kelana checkout, run GPU actions through the maintained wrapper:

```bash
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
WRAP=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
D=research/quantization-discovery/representations/vector-full
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=2 "$WRAP" --runtime-max 55s --memory-gib 18 --host-reserve-gib 4 --exec "$PY" "$PWD/$D/model.py" capture --split train --offset 464 --windows 4
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=2 "$WRAP" --runtime-max 90s --memory-gib 18 --host-reserve-gib 4 --exec "$PY" "$PWD/$D/model.py" evaluate --config "$PWD/$D/early-middle-frozen.json" --split test --offset 0 --windows 32
```

The capture and evaluation commands reject existing outputs. A repeat needs a fresh capture selection or a copied configuration with a new panel name; retained evidence is not overwritten. CPU codec and local response commands are in [QUALITY.md](QUALITY.md). The wrapper serializes GPU use and restores resident Bonsai. Both whole-model panels restored the service; no model or service configuration changed.

The [response-aware follow-up](../vector-response/README.md) now tests the complete nonlinear consumer at fixed bytes. It improves the three-bit pair's full-model loss substantially, but still loses to selected ternary; the eight-bit pair repair loses to its own weight-fitted source. Repeating weight-only codebook search or treating the isolated FP16 reader comparison as a serving win would not answer that question.
