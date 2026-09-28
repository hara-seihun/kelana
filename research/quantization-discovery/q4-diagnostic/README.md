# Four-bit conversion diagnosis

The stronger converter cuts complete-model test perplexity from 85.742 to **44.514**, against BF16's 38.062. Validation improves as well. The body caused most of the earlier damage; holding the tied embedding/head in BF16 did not rescue the simple rounding control. We now have a substantially stronger four-bit quality baseline, not a ternary quality match or a packed serving result.

the project lead requested this diagnosis after the complete ternary pilot lost about one nat against BF16. All arms use the same pinned Qwen3-0.6B checkpoint and frozen public text. The calibrated image has 197 actual packed matrices and 131,072 BF16 norm bytes, totaling 316,749,352 payload bytes at 4.251313 BPW.

## Native executable image

[The executable GGUF shootout](EXECUTABLE.md) exactly maps all 197 calibrated
matrices into upstream Q4_1 on Radeon 8060S and measures full wikitext-2 native
perplexity plus single-stream and fixed independent-prompt batched throughput.
The repeated FP16 group scales and origins enlarge the runnable tensor payload
from 316,749,352 to 372,752,384 bytes. At 378,704,000 GGUF file bytes it
scores 25.4210 native perplexity, beating stock IQ3_M (26.4931 at
402,878,880 bytes) and Q3_K_M (25.7607 at 413,979,040 bytes) with one HIP
binary. A same-byte tied-head source-Q4_1 control scores 27.5713. A lossy
Kelana-Q3_K requant loses to the matched source-Q3_K control, 42.6399 versus
31.8092 perplexity with the same pinned stock imatrix. These 512-token-chunk
native figures must not be mixed with the separate 256-token HF panel below.

## Off-the-shelf comparison

The [stock GGUF comparison](STOCK-GGUF.md) uses pinned Bartowski Qwen3-0.6B
images, identical text and the same BF16 scoring backend. Stock Q4_K_M reaches
40.824 test perplexity versus our 44.514, but uses 478.27 MB of tensor payload
versus 316.75 MB. It stores embedding and output separately and mixes Q4_K and
Q6_K tensors. The stock file closest to our actual byte budget, IQ2_M at
325.81 MB, reaches 124.351 perplexity. Both stored-coefficient and source-unique
BPW are reported; a Q4 label is not an equal-storage contract.

## Three-level transfer

The [signed and affine three-level follow-up](THREE-LEVEL.md) completed both
197-image conversions with the same sequential calibration pipeline. Strict
signed reaches test NLL 7.584679 at 1.728153 BPW; paid affine origin reaches
7.977037 at 1.853139 BPW. Both lose to the selected rotated, scale-repaired
ternary image's 4.646432 at 1.727086 BPW. The four-bit success did not transfer
by reducing the grid to three levels. Neither image is adopted.

## Existing rounding control

[evaluate.py](evaluate.py) evaluates original BF16, the tied embedding/head quantized alone, the body quantized alone, and the complete four-bit image. Every arm preserves the tied parameter identity and restores unquantized tensors from the BF16 checkpoint. Original norms remain BF16. The scalar decoder verifies all 197 image hashes before use.

| Arm | Complete payload bytes | Validation NLL | Test NLL | Test perplexity |
| --- | ---: | ---: | ---: | ---: |
| Original BF16 | 1,192,099,840 | 3.668815 | 3.639218 | 38.062 |
| Four-bit tied embedding/head only | 961,157,136 | 3.706544 | 3.681000 | 39.686 |
| Four-bit body only | 538,381,376 | 4.601931 | 4.406165 | 81.955 |
| Complete four-bit | 307,438,672 | 4.650166 | 4.451341 | 85.742 |

The body dominates this control's damage. Quantizing the tied matrix alone adds .04178 test nats, while quantizing the body alone adds .76695. Their joint excess is .81212, slightly larger than the sum. Keeping the head in BF16 does not solve the body problem.

The existing group-128 image uses odd symmetric levels, FP16 least-squares scales, several clipping starts and nearest rounding. It has no Hessian compensation and its alphabet excludes exact zero. A better converter must be compared against its actual images, not an assumed generic four-bit quality level. Image storage is counted by payload arrays and descriptors; NPZ container bytes are separate.

## Stronger grid and calibrated compensation

The [converter method](METHOD.md) stores unsigned four-bit codes plus an FP16 scale and origin per 128 input coefficients. It fits affine group grids, then uses the full input covariance for GPTQ-style error compensation. Q/K/V, attention output, gate/up and down are calibrated sequentially on the actual quantized producers. Each completed quantized layer produces the next layer's input cache. Calibration uses 32 train windows, 8,192 tokens, with no dense whole-model training.

| Complete image | Payload BPW | Validation NLL | Test NLL | Test perplexity |
| --- | ---: | ---: | ---: | ---: |
| Original BF16 | 16 | 3.668815 | 3.639218 | 38.062 |
| Existing symmetric odd-grid rounding | 4.12635 | 4.650166 | 4.451341 | 85.742 |
| Affine rounding, shared tied image | 4.25131 | 4.046508 | 3.980601 | 53.549 |
| Affine grid plus calibrated GPTQ | 4.25131 | 3.851346 | 3.795795 | 44.514 |

The affine rounding row uses **exactly the same tied image** as the calibrated row. Its manifest references the unchanged RTN body bank and calibrated tied matrix through [share_tied.py](share_tied.py). No hidden additional weights are used. This removes the small CPU/GPU rounding variation in the separately produced embedding images. The original independently produced affine RTN complete image scores 3.981112 test and 4.045799 validation; both controls remain recorded.

At identical bytes and tied matrix, calibrated body fitting improves complete-model test NLL by .184806 and validation by .195161 beyond affine rounding. With the tied matrix kept entirely BF16, affine rounding versus calibrated body gives test NLL 3.951311 versus 3.767451, and validation 4.021238 versus 3.810551. The gain is therefore in the body conversion, not an accidental head change.

The affine format/grid fitter also makes a large difference before covariance compensation. It costs 9,310,680 bytes more than the earlier one-scale symmetric format, about 3.03% of that image. These are not equal-rate representations. The experiment changes both the grid family and its range fitting, so it does not identify exact-zero representation or one clipping setting as the sole cause. The learned affine origin does not guarantee an exactly representable zero.

The final calibrated degradation is .156577 test nats, or **1.1695× BF16 perplexity**, instead of the earlier 2.2527× four-bit control. That removes most of the apparent four-bit problem. It does not establish the same retention at the selected ternary model's 1.72709 BPW. The selected ternary image is unchanged; its next comparisons should use this stronger four-bit baseline rather than only the simple rounding image.

[Compact results](results.json) hash every full loss receipt, including the exact-shared-head control. The actual images stay in `q4-diagnostic/calibrated/` and `q4-diagnostic/asymmetric-rtn/`. Both directories also own `norms.npz` and `norms.json`; these materialize the already charged BF16 coefficients without changing the evaluated image manifests or payload counts. New conversions include the norm-image receipt in their manifest. Original manifests remain immutable evaluation evidence.

## Fixed evaluation protocol

Validation is rows 0–7 of `ternary/expanded-tokens.npz`, 2,040 predicted tokens. Test is rows 0–31, 8,160 predictions. Every forward uses one 256-token window, BF16 arithmetic and the same SDPA implementation. No held token enters calibration. The evaluator counts each unique parameter once and verifies that embedding and output head remain tied after every substitution.

Full per-window receipts live at `/path/to/workspace/data/kelana-subbit/q4-diagnostic/`. They name the model, fixture, matrix manifest, decoder and evaluator hashes. The source selected ternary image remains unchanged throughout the diagnosis.

```bash
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/q4-diagnostic
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=2 /path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 90s --memory-gib 20 --host-reserve-gib 4 --exec "$PY" "$PWD/$D/evaluate.py" --converter rtn --name rtn-ablation --split test --windows 32
```

Existing receipts are immutable; choose a new `--name` for a repeat. The wrapper serializes GPU access and restores resident Bonsai afterward. This study does not deploy a service or claim an inference speedup.
