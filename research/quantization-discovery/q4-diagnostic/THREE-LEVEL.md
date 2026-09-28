# Three-level transfer

`three_level.py` asks whether the four-bit converter's affine grid and quantized-producer calibration help at three levels. This is **not** the selected 1.727-BPW strict signed ternary image. Its three values are `origin`, `origin + scale`, and `origin + 2*scale`; origin and scale are independent FP16 coefficients for every output row and 128-input-column group. The grid need not include zero. The encoder packs five base-three digits per byte, padding each matrix row to a full byte. `--strict` uses signed `{-1, 0, 1}` instead, with an implicit origin of minus the stored scale. It fits the exact per-group least-squares symmetric scale over all possible nonzero counts. No origin is stored or charged for this separate arm. A shape descriptor costs eight bytes per matrix. The single tied embedding/head is packed once. Every BF16 norm is retained in its own `norms.npz`, and manifest `payload_bytes` includes all matrices, descriptors, both FP16 group coefficients, and norms. Container file sizes are separate.

An affine matrix begins with four fixed clipping starts, each alternated through eight per-group assignments and affine least-squares updates. A strict signed matrix starts from the exact groupwise least-squares signed grid, with one FP16 scale. The body then rounds columns using a damped full inverse-Hessian factor. Error compensation runs within each group and across all later groups. Inputs come from the quantized predecessor: Q/K/V, then O, gate/up, down, and the next decoder layer. Its training set is the first 32 expanded training windows of 256 tokens. Neither held validation nor test inputs enter fitting. The embedding/head has no activation-fit stage because it is the same physical matrix for input lookup and final classification.

`three_level.decode(path, device='cpu')` expands either real packed image to an FP32 PyTorch matrix. The two manifests under `three-level-affine/` and `three-level-strict/` each have exactly 197 unique matrix records `{key,path,sha256,payload_bytes}`, plus a charged BF16 norm image. `evaluate.py --converter calibrated --manifest ... --decoder ...` accepts it unchanged. Decoded BF16 model loss tests representation quality, not native packed inference speed.

Run the conversion only after taking the shared GPU lane, using the existing Bonsai wrapper. Each layer invocation fits seven matrices, writes its successor's train-activation cache, and refreshes the manifest. Resuming a layer loads its already packed matrices before fitting later producers. Do not change calibration windows or damping mid-conversion.

```bash
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
C=/path/to/workspace/projects/kelana/research/quantization-discovery/q4-diagnostic
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
$B --runtime-max 48s --exec "$P" "$C/three_level.py" --embedding
for layer in $(seq 0 27); do
  $B --runtime-max 48s --exec "$P" "$C/three_level.py" --layer "$layer"
done
$B --runtime-max 48s --exec "$P" "$C/three_level.py" --strict --embedding
for layer in $(seq 0 27); do
  $B --runtime-max 48s --exec "$P" "$C/three_level.py" --strict --layer "$layer"
done
$B --runtime-max 48s --exec "$P" "$C/evaluate.py" --converter calibrated \
  --manifest /path/to/workspace/data/kelana-subbit/q4-diagnostic/three-level-affine/manifest.json \
  --decoder "$C/three_level.py" --name three-level-affine-test --split test \
  --offset 0 --windows 32 --arms reference,body,tied,complete
```

Use `--out` pointing to a new directory for a repeat fit. Image writes refuse replacement. The prior 1.727-BPW selected rotated and scale-repaired ternary image is untouched. The affine arm spends roughly 1.60 bits per coefficient on codes plus 0.25 bits per coefficient for the two FP16 group parameters. The strict arm spends about 1.60 bits on codes plus 0.125 bits for a single FP16 group scale. These controls share the quantized-producer fitting order and Hessian method with one another, not the selected image's rotation and later scale repair.

## Complete-model outcome

The two images were fitted on the same first 32 expanded training windows, without selecting hyperparameters on held data. Full manifests and per-image hashes are in `/path/to/workspace/data/kelana-subbit/q4-diagnostic/three-level-{affine,strict}/`. Exact decoded-image quality receipts are alongside those directories with names `three-level-{affine,strict}-{test,validation}-{test,validation}-0-{32,8}.json`. The positive four-bit result does not transfer: both three-level body images lose much more model quality than the already selected ternary image.

| Arm | Paid payload | BPW | Test body NLL | Test complete NLL | Validation body NLL | Validation complete NLL |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| BF16 reference | 1,192,099,840 B | 16 | 3.639218 | 3.639218 | 3.668815 | 3.668815 |
| Strict signed, sequential GPTQ | 128,758,184 B | 1.728153 | 7.002912 | 7.584679 | 7.838157 | 8.335283 |
| Affine three-level, sequential GPTQ | 138,070,440 B | 1.853139 | 7.914782 | 7.977037 | 8.536108 | 8.701291 |

The strict tied-only test loss is 4.380113; the affine tied-only loss is 4.297186. Body damage dominates both complete results. At these fixed predeclared fits, paying an origin worsened the body result by 0.911870 test nats and 0.697951 validation nats despite spending another 9,312,256 bytes. Different body weights and quantized activation caches mean these complete-model differences are method comparisons, not paired single-layer substitution effects. The existing selected signed ternary reaches test NLL 4.646432 at roughly 1.727 BPW with a rotated representation and later scale repair. It was fitted by a different procedure, so the table does not isolate rotation or scale repair as a causal explanation.
