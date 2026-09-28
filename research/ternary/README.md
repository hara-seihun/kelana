# Ternary Qwen conversion pilot

the project lead requested experiments that could match or beat Bonsai's ternary quality,
starting with Qwen3-0.6B, on September 23, 2026. This is a new 1.7-bit ternary
round, not another sub-bit factor-scale sweep. The source is the existing
original BF16 Qwen3-0.6B checkpoint at revision
`c1899de289a04d12100db370d81485cdf75e47ca`.

## Fresh matched code/scale recovery loses to scales alone

[The paid complete-model comparison](coupled-fresh/README.md) trains eight matched gold-loss steps from `fresh-duration32` on unused text. A layer-14 seven-matrix arm changes 448 ternary codes and reaches lower train loss than scales alone, but worsens newly frozen complete-model selection NLL **4.574458 → 4.576849** and withheld held NLL **4.768560 → 4.770172** (coupled minus scale .001612 ± .001404 nats). Both are independently decoded 16-KiB-code/256-row-scale images: **122,975,935 coupled vs 122,975,948 scale-only bytes**. This sparse first-order update does not improve the paid quality frontier; nominate composed multi-step changes instead of extending a train-only flip advantage.

## Latest scale-direction extrapolation does not improve the selected image

[The complete 1.5× scale-direction test](latest-extrapolate/README.md) extrapolates the `fresh-duration16` → `fresh-duration32` update without changing trits, signs or norms. On newly frozen disjoint text, the candidate worsens eight-window selection NLL **4.656302 → 4.657089**; withheld NLL changes **4.507242 → 4.506743**, an inconclusive **.000499 ± .001339** nats. The fully decoded 16-KiB-code/256-row-scale image costs **122,976,108 bytes**, 224 bytes more than the selected source. The earlier extrapolation of distant checkpoints is not a reason to extend this shorter latest direction; use new training and a matched coupled code/scale comparison instead.

## Shared signed-Hadamard coordinate across the complete paid image

[The checked 197-matrix sign dictionary](shared-rotation/README.md) stores 196 transformer sign vectors as prefixes of one 384-byte vector and the distinct tied head signs in 128 bytes. It saves **35,456 exact physical bytes** beyond the code/scale-page image: **122,940,428 bytes / 1.650068880 BPW**, with unchanged 4.498337 held NLL. The more useful complete-map identity is one rotated producer shared across Q/K/V or gate/up: a hypothetical direct consumer avoids 84 of 140 per-projection input transforms per token, but expanded BF16 evaluation performs none of those transforms. This is a paid exact representation and a structural construction, not native latency or Qwen3.6 quality.

## Exact scale-page bitshuffle bound

[The complete saved 256-row scale-page comparison](exact-rate/bitplane.md) checks all 4,656,128 FP16 scale words in the selected Qwen3-0.6B code-page image. Only 105/18,192 pages benefit from zlib-1 bitplane or byte-plane transforms; free page selection saves at most 2,010 bytes, while the actual tagged image grows **122,975,884 → 122,992,066 bytes** (1.650544760 → 1.650761950 BPW) at identical 4.498337 held NLL. Do not add this alternate decoder for such a small static-storage opportunity; instead improve paid complete-model quality and eventually price direct packed consumption.

## Exact paid trit-code pages

[The complete page-addressed trit-code image](code-pages/README.md) preserves every code, scale, sign and norm of the latest frozen image while reducing its paid physical rate from **1.690512432 to 1.650544760 BPW** (2,977,841 fewer bytes). Its decoded held NLL remains **4.498337**. [The complete native host-code panel](code-pages/NATIVE.md) costs **303.819 vs 15.457 ms** to observe all code bytes and **293.488 vs 0.285 ms** for one shuffled code per page. Interpreter overhead is not the cold page boundary. This is an exact storage-rate result, not a serving speedup or a quality recovery.

## Further independent-text complete-image recovery

[Sixteen more scale-only whole-model steps](fresh-duration32/README.md) after `fresh-duration16` improve a new disjoint eight-window held panel from **4.502883 to 4.498337 NLL** (paired **.004546 ± .002020 nats**, 6/8 wins) at unchanged 1.727086 raw BPW. The complete exact 256-row physical image costs **125,953,725 bytes / 1.690512432 BPW**, 192 bytes above its predecessor. All scales decode bitwise; no native inference claim follows. This new panel cannot be directly subtracted from the earlier held panel.

## Longer fresh-text complete-image continuation

[Sixteen additional whole-model scale updates](fresh-duration/README.md) on independent train text improve a newly frozen eight-window selection panel from **4.872097 to 4.864839 NLL** and its untouched eight-window held half from **4.343739 to 4.330215 NLL** (paired .013524 ± .002129 nats, 8/8 favorable). All 197 packed matrices retain trits and signs at **128,678,649 bytes / 1.727086 raw BPW**; 2,775,304 FP16 scales change. [The complete paid page image](fresh-duration/paid-rate.md) costs **125,953,533 bytes / 1.690509855 BPW**, only 96 physical bytes above the predecessor while improving held loss. Every scale word decodes bitwise; no native reader/TPS is claimed.

## Fresh-text recovery of the extrapolated complete image

[The paid page-coordinate follow-up](fresh-page-rate.md) checks all 4,656,128 FP16 scales in both the source and freshly recovered complete images. At 256-row pages, the two models each cost **125,953,437 physical bytes / 1.690509 BPW**; fresh held loss improves **4.576138 → 4.561169** at *equal paid rate*. This is a saved, checked scale image, not a native reader or a measured speedup.

[Eight fresh-text gold-loss updates](fresh-recovery/README.md) improve a newly frozen, disjoint sixteen-window test panel from **4.576138 to 4.561169 NLL** at the same **128,678,649-byte / 1.727086-BPW** complete raw image. All 197 code/sign matrices and norms remain fixed. This is a measured complete-model quality gain, not native packed inference or Bonsai-like retention.

## Whole-model scale continuation

[A frozen extrapolation of two gold-loss scale checkpoints](scale-extrapolation/README.md) improves complete Qwen3-0.6B ternary loss on 16 **new disjoint test windows** from 4.593977 to **4.572739 NLL** (paired improvement .021239 ± .005618 nats, 13/16 windows). Trits and signs are unchanged; the complete raw image remains **1.727086 BPW**, and its exactly decoded physical page image costs **1.692513 BPW**. This is a measured whole-model quality/rate gain, not native throughput or Bonsai-like retention; prior 4.646432 was on a different held panel.

## Exact complete-image scale coordinate

[The 64-row paged-scale construction](exact-rate/README.md) saves a physical complete image of the selected recovered ternary model at **126,082,213 bytes / 1.692237 BPW**, down from 128,678,649 bytes / 1.727086 BPW. It checks every one of 4,656,128 original FP16 scale words and leaves all packed trits, signs and norms unchanged, so its decoded complete-model loss is the selected 4.646432 NLL. This is an exact capacity/rate result, not a native speedup; indirect page reads must be priced before serving adoption. The quality gap to BF16 remains.

## Expanded-data result

The [joint-code and expanded-training follow-up](expanded-training.md) lowers
held test NLL from 5.4286 to **4.6464** at unchanged 1.7271 BPW. It uses 106,496
distinct training tokens. The matched all-layer joint code/scale update loses
to scales alone, while 256 train-accepted discrete trit changes make almost no
held difference. The selected image is `expanded-scale384`, 128,678,649 payload
bytes. It still loses to BF16's 3.6392 and does not establish Bonsai-like
quality retention. The original simple four-bit control scores 4.4513, but the
[new calibrated four-bit baseline](../quantization-discovery/q4-diagnostic/README.md)
now reaches **3.7958 NLL at 4.2513 BPW**, or 44.51 perplexity versus BF16's 38.06.
Body-only and tied-only ablations locate the earlier four-bit damage mostly in
the body; affine grids and calibrated error compensation recover most of it.
Use that stronger baseline for new comparisons. Earlier four-bit numbers below
remain measurements of the simple rounding control, not a four-bit limit.

[A single calibrated-Q4 layer](calibrated-splice.md) at 1.793698 BPW scores 4.625448 test NLL after matched eight-step complete-model recovery, against 4.648968 for all-ternary at 1.727086 BPW. It spends 4,963,040 extra bytes and improves 26/32 previously reported test windows, but its eight-window validation is flat at 4.725945 versus 4.725857. This is a paid complete-model quality result, not a chosen serving image or native timing. An [untouched validation-half replay](calibrated-splice.md#untouched-validation-half-frozen-image-replay) of the same frozen paid images favors Q4 by .011877 ± .008433 nats on windows 8–15 (5/8 windows); the combined 16-window validation edge is .005894 ± .005581. A [further sixteen newly frozen disjoint validation windows](calibrated-splice.md#new-disjoint-validation-text-the-paid-edge-vanishes) score 4.593013 Q4 against 4.592910 ternary: +.000103 ± .006164 paired nats, 7/16 wins. Across all 32 validation windows the paid edge is just .002896 ± .004125 nats. The earlier test direction does not justify this layer's 4,963,040 additional bytes; select a new allocation and recovery duration on genuinely new training/selection text before another frozen complete-model assessment.

[Matched complete-model mixed recovery](mixed-recovery.md) overturns the frozen-splice conclusion on the previously inspected panel: replacing layers 14–20 with symmetric four-bit matrices initially worsens validation NLL 4.733112 to 4.772191; eight gold-loss updates to retained ternary scales reach 4.711406 exploratory validation and 4.604734 previously inspected test at 2.170288 BPW, versus 4.725857 and 4.648968 for a matched 1.727086-BPW ternary control. But **frozen-image replay on untouched validation windows 8–15 reverses the sign**: 5.289023 mixed versus 5.262661 ternary, +.026362 ± .044097 paired nats. The seven-layer image spends 33,021,352 extra bytes and is not selected for serving. Its saved scales and complete-model receipts remain useful controls for a new rate allocation; no mixed-format reader or inference speed claim follows.

[Paid two-region interaction](mixed-interaction.md) tests whether simultaneous four-bit substitutions repair the single-region loss. The adjacent and separated pairs at 2.613491 BPW score 4.836586 and 4.908159 validation NLL against 4.733112 for ternary, with positive nonadditive losses of .011264 and .042479 nats. Neither pair warrants native inference work; retraining retained ternary scales against a fixed mixed image is the missing co-adaptation control.

[Paid layer-rate substitution](layer-rate.md) tests all four disjoint seven-layer blocks at 2.170288 BPW against the selected 1.72709-BPW image. Every independently calibrated four-bit block worsens eight-window validation loss. The least damaging block improves 32-window test NLL by only .000578 for 33,021,352 extra bytes. Frozen substitutions alone do not settle mixed-rate quality. The recovered layers 14–20 image above is the first co-adaptation control; it does not make the separately tested pair substitutions attractive without their own recovery.

[Paired code/scale repair](paired-repair/README.md) screens 139,300 local down-projection pairs and scores six nominees with matched single-trit and scale-only controls through complete-model gold loss. A proposal-panel barrier-crossing pair fails a separate train check. The frozen paired image worsens validation 4.733112 to 4.733498 and test 4.646432 to 4.646920 at unchanged bytes, so `expanded-scale384` remains selected. This bounds the tested single-group neighborhood, not all coupled repairs.

[Representation research](../quantization-discovery/representations/README.md) separately challenges the scalar-code/scale decomposition itself, rather than requiring every new method to preserve this image format.

## What is being compared

Bonsai 2's [whitepaper](https://github.com/PrismML-Eng/Bonsai-demo/blob/main/bonsai-2-27b-whitepaper.pdf)
describes ternary matrix weights in a signed block-Hadamard basis, FP16 scales
per 128 weights, selected high-precision recurrent/norm tensors and direct
packed consumers. It does not publish a reproducible conversion/training
recipe. Its 27B benchmark-retention percentage is not a target NLL ratio for
this different 0.6B model. Matching the bit rate alone is not matching Bonsai.

This pilot uses all 196 transformer matrices and one tied embedding/head image.
Norms stay BF16. Five trits occupy one byte; every 128 weights have one FP16
scale. Rotation signs are also stored and charged. Payload rate is about
1.727 bits per unique parameter, including norms and shape descriptors.
NPZ container bytes and JSON receipts are recorded separately. The format is
an actual saved packed image, not an entropy estimate.

`quantize.py` supplies exact per-group least-squares ternary rounding, signed
Hadamard rotation and full damped inverse-Hessian GPTQ. GPTQ propagates errors
between 128-column windows; it is not a diagonal or independent-block Hessian
approximation. Initial group scales remain fixed during column rounding.
`pilot.py` saves the radix-243 images and expands them to BF16 for whole-model
quality. It is not a compressed-runtime throughput benchmark.

`sequential.py` quantizes Q/K/V, O, gate/up and down in order, capturing each
family's actual input from quantized earlier families and layers. It also
supports train-only composed-block reconstruction through `reconstruct.py`.
That reconstruction uses straight-through ternary codes and FP16-rounded
scales; only packed codes/scales survive into the result.

## Data and execution

`/path/to/workspace/data/kelana-subbit/ternary/` owns frozen token fixtures, candidate
images, per-matrix provenance, loss receipts and GPU wrapper logs. It is
reachable through the [sub-bit data map](/path/to/workspace/data/kelana-subbit/README.md).
`prepare.py` creates 32 train, 16 validation and 32 test windows of 256 tokens,
excluding both earlier pilot fixture sets. Validation windows 0–7 are the
exploratory selection panel. Test text does not enter quantization or training.
The initial nonsequential GPTQ arm reuses the original eight-window train
producer capture; sequential arms use 16 new train windows.

Use the existing Python environment and GPU reservation:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
S=/path/to/workspace/projects/kelana/research/ternary
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
$B --runtime-max 160s --memory-gib 14 --host-reserve-gib 4 --exec \
  "$P" "$S/sequential.py" --name sequential-gptq
$B --runtime-max 70s --memory-gib 12 --host-reserve-gib 4 --exec \
  "$P" "$S/pilot.py" evaluate --name sequential-gptq --windows 8
```

Completed matrices and layers are retained on restart. Use a new candidate
name for changed numerical settings. The selected Bonsai and Qwen runtimes are
not changed by these experiments. Keep unique receipts and failed-arm evidence;
model images can be regenerated from their saved source and fitting inputs.

## First selection panel

Eight fresh validation windows give 2,040 predictions. Lower NLL is better.

| Complete model | Payload BPW | Validation NLL |
| --- | ---: | ---: |
| Original BF16 | 16 | 3.6688 |
| Existing scalar group-128 four-bit control | 4.1264 | 4.6502 |
| Ternary least-squares rounding | 1.7266 | 12.7836 |
| Signed block-1024 rotation plus rounding | 1.7271 | 13.2580 |
| Rotation plus original-producer GPTQ | 1.7271 | 9.7834 |
| Sequential GPTQ without rotation | 1.7266 | 9.0480 |
| Sequential rotated GPTQ, damping .01 | 1.7271 | 7.5774 |
| Sequential rotated GPTQ, damping .001 | 1.7271 | 8.5548 |
| Sequential rotated GPTQ plus 64-step block reconstruction | 1.7271 | 9.2381 |
| Sequential rotated GPTQ plus 32 whole-model scale steps | 1.7271 | 6.1156 |
| Then 96 more whole-model scale steps on 32 train windows | 1.7271 | 5.6297 |

These are substantially worse than BF16 and the four-bit control. We have not
matched Bonsai-like quality retention. Rotation helps the calibrated sequential
method but does not rescue naive rounding. Quantizing against the actual
producer is important. The lower-damping and locally reconstructed candidates
lose, so neither is the selected method.

For the original-producer rotated GPTQ arm, changing only the tied image gives
4.3579 NLL, while changing only the transformer body gives 9.3442. Damage is
mostly in the body. The body-only arm pays for original BF16 embeddings/head;
its full-model rate is not 1.7271 BPW.

The first block reconstruction learning rates, .05 for codes and .01 for
scales, damaged the train objective and selected the unchanged image in all
seven attempted layers. The bounded run stopped there. Rates .001/.001 with
64 steps improve local block response error, but worsen complete-model NLL.
This repeats the earlier sub-bit lesson: a local response objective is not a
reliable selector for composed language quality. Whole-model recovery must be
measured against whole-model loss.

## Whole-model recovery

`tune.py` trains the existing group scales through the entire model's gold
next-token loss. Trit codes and rotation signs stay fixed. Embedding and output
head share one trainable scale provider. Every forward rounds scales to FP16;
layer gradient checkpointing bounds transient memory. The exported image has
exactly the same 128,678,649 payload bytes as sequential GPTQ, with no added
residual matrices or adapters.

The first 32 Adam steps use 16 fresh train windows at learning rate .001.
The continuation uses all 32 train windows for 96 more steps at .0005. Checkpoint
selection uses train loss only. The selection-panel NLL falls from 7.5774 to
6.1156 to 5.6297. This helps much more than composed-block fitting, but remains
well behind the 4.6502 four-bit control and 3.6688 BF16 reference.

```sh
$B --runtime-max 240s --memory-gib 24 --host-reserve-gib 4 --exec \
  "$P" "$S/tune.py" --source sequential-gptq --name model-tuned \
  --steps 32 --windows 16 --lr .001
$B --runtime-max 220s --memory-gib 24 --host-reserve-gib 4 --exec \
  "$P" "$S/tune.py" --source model-tuned --name model-tuned96 \
  --steps 96 --windows 32 --lr .0005 --evaluate-every 32 --score-windows 16
```

## Bounded whole-model trit changes

[The paid-code follow-up](joint-codes.md) lets gold loss change up to 256 packed trits in each of layer 0's seven matrices while scales remain trainable. It changes 1,792 trits at unchanged 1.7271 BPW. The four-window train check improves, but a code-only transfer onto the starting scales scores 5.4564 on 32 frozen test windows against the source's 5.4286. Unbounded STE flips hundreds of thousands of trits and damages train loss. This tested image is not an improvement; use broader train text and a composed multi-window acceptance rule before another large code update.

## Frozen test result

After choosing the recovery arm on validation, the complete images were
measured on 32 separate test windows, 8,160 next-token predictions. No test
window entered calibration, scale training or checkpoint selection.

| Complete model | Payload BPW | Test NLL | Test perplexity |
| --- | ---: | ---: | ---: |
| Original BF16 | 16 | 3.6392 | 38.06 |
| Scalar four-bit control | 4.1264 | 4.4513 | 85.74 |
| Sequential rotated ternary GPTQ | 1.7271 | 7.1109 | 1225.23 |
| Ternary plus 128 total whole-model scale steps | 1.7271 | 5.4286 | 227.83 |

Recovery lowers test NLL by 1.6823 nats at identical image bytes, but leaves a
1.7894-nat gap to BF16 and loses clearly to the four-bit control. We have not
matched Bonsai-like quality. The surviving result is a working complete ternary
image and evidence that composed gold-loss recovery beats local reconstruction,
not a ready-to-serve model. [results.json](results.json) collects raw per-window
losses and image/fixture/source receipts. `summarize.py` regenerates it without
rerunning inference.

This is limited recovery training on 8,192 distinct train tokens, not a
reproduction of PrismML's undisclosed conversion recipe. The next meaningful
question is joint code-and-scale recovery against the complete model, with
more diverse train text and a fixed held panel. It is not another local
matrix-error fit. Native compressed inference timing is worthwhile only after
quality supports the representation.
