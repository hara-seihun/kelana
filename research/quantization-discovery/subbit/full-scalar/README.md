# Grouped scalar controls for the whole Qwen3-0.6B model

This is a deliberately ordinary control for the sub-bit full-model image, not a claim against GPTQ, AWQ or another activation-aware scalar method. The same pinned BF16 checkpoint supplies every original weight. `fit.py` calls `spectral_quant.quantize` on each matrix with signed odd reconstruction levels, group size 128, four initial clipping factors and five least-squares scale/code alternations per factor. Its row-blocked embedding call is exactly row-independent and does not alter that algorithm. There is no calibration input and no response-aware fitting. Both 2- and 4-bit arms quantize every one of the 196 body projection matrices and a single shared 151,936-by-1,024 embedding/head matrix. The original config ties those names, and the two checkpoint tensors match exactly. All 65,536 remaining scalar parameters, including layer norms, remain BF16.

| Arm | Matrices | Packed codes and scales | `.npz` containers | BF16 norms | Paid payload | Paid container | Paid whole-model BPW |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2-bit group128 LS | 197 | 158,311,504 B | 158,467,528 B | 131,072 B | 158,442,576 B | 158,598,600 B | 2.12657 |
| 4-bit group128 LS | 197 | 307,307,600 B | 307,463,624 B | 131,072 B | 307,438,672 B | 307,594,696 B | 4.12635 |

Both paid totals include the BF16 norms; the container figures count all 197 `.npz` files before adding those norms. One stored shape descriptor per matrix contributes 16 bytes to the payload; grouped FP16 scales contribute .125 bits per weight. The `.npz` container adds 156,024 bytes per arm. The unique model has 596,049,920 parameters. No embedding/head duplication enters these rates. The complete per-image names, SHA256 hashes, shapes, payload sizes and serialized sizes live in `accounting.json`; the five fit receipts and all 394 images live under `/path/to/workspace/data/kelana-subbit/full-scalar/`. Source and checkpoint hashes are in the receipts. Data images remain the owning packed artifacts, not regenerated approximations.

## Pilot continuation

Each arm expands the complete packed image to BF16 for ordinary model inference, with no native scalar kernel. It uses the existing four validation and four test windows of 256 tokens each from the pinned pilot fixture, not the separate fresh-window sample. Next-token NLL and teacher KL compare with the original BF16 model on exactly the same windows. This is a common quality control, not inference speed or a representative full-corpus WikiText score.

| Pilot split | BF16 NLL | 2-bit NLL | 2-bit teacher KL | 2-bit agreement | 4-bit NLL | 4-bit teacher KL | 4-bit agreement |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Validation, 4 × 256 | 3.90522 | 15.41435 | 12.51920 | 0.10% | 4.86962 | .92087 | 55.88% |
| Test, 4 × 256 | 3.31076 | 15.55316 | 13.33321 | 0.00% | 4.05740 | .79670 | 61.27% |

Even four bits per coefficient do not rescue this scalar control when all body matrices and the tied vocabulary matrix change at once. Two-bit grouped LS collapses completely, despite spending over three times the proposed .63-BPW sub-bit image. The all-model outcome, not a single-layer weight MSE, is the comparison that matters here. It does **not** establish a general limit on scalar quantization: this fit uses neither activation statistics nor outlier handling or mixed precision. In particular, an intelligent scalar allocation may protect the tied vocabulary rows and sensitive layers. The negative result only rules out this uniform 2/4-bit grouped LS control as a competitive explanation for the programme's model-level result.

The four committed `quality/*.json` receipts retain each window's reference NLL, candidate NLL, teacher KL and argmax agreement. Each GPU panel loaded all 197 images, kept the norm parameters BF16 and recomputed the paired reference. Bounded evaluation cost was 10.36 to 12.97 seconds of image loading and inference after model construction per panel; the 394 CPU packed-image fits took 28.73 seconds across five calls, on eight threads. The GPU reservation was released after each panel.

## Commands

```bash
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/full-scalar
O=/path/to/workspace/data/kelana-subbit/full-scalar
for first in 0 7 14 21; do
  $P "$D/fit.py" --first-layer "$first" --last-layer "$((first+7))" --out "$O"
done
$P "$D/fit.py" --embedding --out "$O"
$P "$D/account.py" --data "$O"
# Use Bonsai's shared GPU reservation for each bit depth and split, one panel at a time:
/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 48s --exec \
  "$P" "$D/evaluate.py" --data "$O" --bits 2 --split validation
```

The fit commands write immutable images and refuse to overwrite an existing image. To reproduce an existing result, use a clean output directory rather than replacing the supplied images.
