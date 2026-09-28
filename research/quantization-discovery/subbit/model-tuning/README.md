# End-to-end scale repair on the first complete sub-bit Qwen image

The complete Qwen3-0.6B binary-factor image contains 196 body matrices and the shared mixed-precision tied head/embedding. At 0.624544 bits per unique parameter it is complete, but its first independently fitted body collapses. The stronger frozen seed already has four train-response coordinate sweeps per matrix and improves the complete image to test NLL 9.656 and validation NLL 9.311, still far from the original 3.311 and 3.905. This study asks whether training **only existing FP16 factor output scales** against the original model's final hidden states can repair the remaining cross-layer error without adding runtime bytes.

It helps, but not enough. The saved image [`image-gain08/manifest.json`](/path/to/workspace/data/kelana-subbit/model-tuning/image-gain08/manifest.json) retains every binary sign, rank, input scale, norm, and tied-head/embedding byte. It replaces the 344,064 existing FP16 output-factor scales. Total payload remains **46,532,412 bytes, 0.624544 bits per unique model parameter**. Four held test windows improve from 9.656 to **9.117 NLL**; four held validation windows improve from 9.311 to **9.099**. The model is still nowhere near usable. Even with original BF16 head and embeddings, body-only test NLL improves from 9.446 to **8.804**, versus original 3.311. This is a bounded negative for local scale-only repair, not a proof that joint quantization training cannot work.

## What trained

[`fit.py`](fit.py) captures the original BF16 `model.model` final normalized hidden states for all eight fixed WikiText-2 raw **train** windows, 256 tokens each. These are stored as BF16 bit patterns in [`teacher.npz`](/path/to/workspace/data/kelana-subbit/model-tuning/teacher.npz), with pinned source/model/token hashes in `teacher.json`. It loads the complete *refined binary body* and registers one learnable FP32 output multiplier per existing `scale_post` channel, initialized to one; U and V signs, ranks and input scales stay frozen. The input embeddings and final head remain original during the final-hidden training fit. Training the body against this teacher on its actual quantized producer inputs is distinct from fitting each independent matrix on original producer inputs.

One Adam step processes each train window. The objective is final normalized hidden mean square error plus 0.1 times cosine gap plus 0.01 times average squared distance of the multipliers from one. Learning rate is 0.005, multipliers are clipped to [0.5, 2], and the seed is 7542. Foreground training used checkpoint spans 0→1, 1→3 and 3→8; Adam moments reset at each new job. The three intermediate receipts make that discontinuity explicit, so replay must use the same spans. Initial per-window squared error is about 7–11 on the respective current quantized producer. This is teacher-hidden matching, **not** head-NLL training. Eight train windows are a small calibration set, not evidence of broad language quality.

[`publish.py`](publish.py) multiplies each saved FP16 `scale_post` element by its fitted channel multiplier, rounds back to FP16 and writes a fresh complete image. It does not leave an FP32 gain array as an extra runtime parameter. Training's after-linear output hook is not bit-identical to the merged BF16 weight. The held results come from a fresh **merged-image reforward**, with the same expanded BF16 weight inference used for the seed. [`record.py`](record.py) checks all 196 images against their U/V signs, original `scale_pre` and exactly calculated FP16 `scale_post`, and checks that tied matrix, norms and config match their seed byte for byte. It also binds the learned checkpoint, teacher capture, source, evaluator, image manifest and held receipts into [`results.json`](results.json).

## Held model quality

The validation and test splits are distinct from each other and from the eight train windows. Each held split contains four fixed 256-token windows and 1,020 next-token predictions. The `body` arm has original tied embedding and head; its displayed 4.5676 model BPW is **not** a whole-model sub-bit image. The `complete` arm uses the same paid mixed tied image for both consumers. All rows of the deployed head participate in loss. These are model reforward quality measurements, not native compressed-kernel timing.

| Arm | Test seed → calibrated NLL | Validation seed → calibrated NLL | Test calibrated teacher KL |
| --- | ---: | ---: | ---: |
| Original BF16 | 3.311 → 3.311 | 3.905 → 3.905 | 0 |
| Binary body, original tied matrix | 9.446 → **8.804** | 9.219 → **8.844** | 6.045 |
| Complete 0.624544-BPW image | 9.656 → **9.117** | 9.311 → **9.099** | 6.381 |

Zero-byte end-to-end scale fitting recovers around 0.54 nats of test NLL over the already refined complete seed, but still leaves **5.81 nats** against the original. The body alone accounts for most of the collapse. Tuning more per-channel scales could further improve this arm, but the first complete pilot is not close enough to justify a long sweep of these 344,064 numbers. Changed signs/ranks, activation-aware joint training, or explicit rate allocation will need stronger evidence than the scale-only pilot. Its 0.624544 BPW is an accounting result, not a viable whole-model operating point.

## Reproduction and custody

The immutable seed is [`image-binary055-refined/manifest.json`](/path/to/workspace/data/kelana-subbit/full-model/image-binary055-refined/manifest.json). The complete trained image, original-teacher capture, `checkpoint{01,03,08}.{npz,json}`, `image-gain08.json` and [`quality-gain08.json`](/path/to/workspace/data/kelana-subbit/model-tuning/quality-gain08.json) are under `/path/to/workspace/data/kelana-subbit/model-tuning/`. `quality-gain08.json` names the evaluator/image source hashes and source snapshots live in its `sources/` directory. [`results.json`](results.json) is the compact checked report. The binaries stay outside Git.

GPU commands use Bonsai's admission wrapper, which stops and restores its resident service. Every command below fits a bounded foreground job. The full-model evaluator currently lives in its owning full-model study; it verifies the saved image SHA256s and measures original, body-only and complete arms on separate held windows.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
S=/path/to/workspace/projects/kelana/research/quantization-discovery/subbit/model-tuning
E=/path/to/workspace/projects/kelana/research/quantization-discovery/subbit/full-model/evaluate.py
D=/path/to/workspace/data/kelana-subbit/model-tuning
$B --runtime-max 43s --memory-gib 16 --exec "$P" "$S/fit.py" teacher
$B --runtime-max 43s --memory-gib 16 --exec "$P" "$S/fit.py" fit --start 0 --count 1
$B --runtime-max 43s --memory-gib 16 --exec "$P" "$S/fit.py" fit --start 1 --count 2
$B --runtime-max 43s --memory-gib 16 --exec "$P" "$S/fit.py" fit --start 3 --count 5
"$P" "$S/publish.py" 8
$B --runtime-max 43s --memory-gib 16 --exec "$P" "$E" \
  --image "$D/image-gain08" --arms reference body complete \
  --splits validation test --windows 4 --out "$D/quality-gain08.json"
python3 "$S/record.py"
```

Reproducing from scratch requires a fresh output directory or moving the existing learned data into durable custody first; `publish.py` refuses to overwrite an existing complete image. Do not train on validation/test windows or report the temporary hook's training quality as the merged image's held result.
