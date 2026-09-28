# Bounded paid-code recovery on Qwen3-0.6B

The first complete ternary image fixes its trits during full-model scale training. I tested whether spending the same 1.72708553 BPW on a few jointly selected trit changes improves gold next-token loss. The result is a measured negative on held language quality, and a useful warning about the scale of a naive straight-through step.

The starting image is `model-tuned96`, with all 197 matrix images, tied embedding/head, original packed signs and 128,678,649 payload bytes. `tune.py --code-layers 0` creates FP32 latent trits for layer 0's seven matrices. The forward pass rounds them to {-1,0,1}, rounds group scales to FP16, expands the rotated weights, and computes the complete Qwen loss with layer checkpointing. Its straight-through gradient only chooses an optimization direction; the checkpoint selector and exported image always use actual rounded trits and FP16 scales. No latent or optimizer state is paid by the image. Layer 0 was chosen before looking at this panel; every other layer and the tied image retain their trits.

The latent starts inside each source trit cell, with original BF16 weight residual clamped to ±0.49. An unrestricted Adam step is surprisingly violent. At code rate .005, step four changes 47,949 K trits, 147,470 gate trits and 172,486 down trits, along with changes in the other four matrices. A four-window train NLL check jumps from 2.7935 to 9.9136. At rate .03 the same check reaches 11.8630. Both runs select their unchanged initial image. Their histories are `joint-code-l0-slow/training.json` and `joint-code-l0-12/training.json` under `/path/to/workspace/data/kelana-subbit/ternary/`. A local calibration response cannot justify a larger code step after this complete-model response.

The bounded arm projects each post-update latent back into its source cell except for at most 256 changed trits per selected matrix with a positive first-order gold-loss benefit on the current train window. This is a gradient-ranked trust region in the *number of changed paid trits*, not a bound on their full-model loss. It retains the best checkpoint by four-window train NLL. Twelve steps over the first twelve of 32 distinct 128-token train rows at code rate .005 and scale rate .0002 give exactly 256 changed trits in each of the seven layer-0 matrices, or 1,792 in total. The four-window train check falls from 2.7935 to 2.4604 at step eight. A matched twelve-step scale-only run from the same image, text and rates falls further to 2.3952. Both use identical paid image bytes. `joint-code-l0-budget/training.json` and `joint-scale-control/training.json` retain every step, checkpoint check, code-change count, train fixture hash and source manifest hash.

| Complete image, 1.72708553 BPW | Eight-window validation NLL | Frozen 32-window test NLL |
| --- | ---: | ---: |
| Starting `model-tuned96` | 5.629674 | 5.428594 |
| Matched scale-only continuation | 5.660207 | not selected for test |
| Bounded layer-0 code plus scale | 5.656368 | not selected for test |
| Bounded layer-0 codes transferred onto unchanged starting scales | 5.633132 | 5.456438 |

The transfer arm is `joint-code-only`. `splice_codes.py` takes the *packed* codes from the budgeted arm while retaining all source scales, signs, tied image, norms and other layer tensors. Its manifest charges the same 128,678,649 bytes. The code-only arm recovers most of the continuation's validation damage, but does not beat its source. Against the source on the frozen test panel it adds 0.027843 nats per token. Of 32 paired windows, 15 improve; the window-level standard error of the mean difference is 0.021907. This is not a significant universal negative for sparse code learning. It is enough to reject this particular trained image as a quality improvement. The quality JSONs in `quality/` retain all 2,040 validation and 8,160 test predictions by window. The original BF16 test NLL is 3.6392, so none of these images is close to Bonsai-like quality.

The result separates code movement from scale movement: the same 1,792 paid flips make the matched continuation 0.003840 nats better on validation than scale-only, yet both continuations lose to their common source. The run cycles only twelve train windows and selects on four; the underlying pilot offers 8,192 distinct train tokens total. More STE steps on those four check windows would measure memorization rather than improve the held contract. Next use a larger disjoint text corpus and choose sparse flips by an aggregate downstream gold-loss estimate or a full-model trust-region acceptance on several train windows. Test the resulting complete image at unchanged bytes against a similarly trained scale-only control. Do not prioritize a packed runtime for this image yet.

Reproduce the decisive runs with the existing GPU wrapper, which holds the exclusive lock and restores the resident service:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
S=/path/to/workspace/projects/kelana/research/ternary
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
$B --runtime-max 45s --memory-gib 24 --host-reserve-gib 4 --exec \
  "$P" "$S/tune.py" --source model-tuned96 --name joint-code-l0-budget \
  --steps 12 --windows 32 --tokens 128 --lr .0002 --code-layers 0 \
  --code-lr .005 --code-budget 256 --evaluate-every 4 --score-windows 4
$P "$S/splice_codes.py" --base model-tuned96 --donor joint-code-l0-budget \
  --name joint-code-only --layer 0
$B --runtime-max 43s --memory-gib 12 --host-reserve-gib 4 --exec \
  "$P" "$S/pilot.py" evaluate --name joint-code-only --split test --windows 32
```

Each GPU command ran in the foreground through the wrapper. The wrapper reported the resident Bonsai service absent on entry and started it on exit. The complete-model quality evaluation expands the paid image into BF16 for arithmetic; there is no packed inference timing or Qwen MoE runtime claim. This experiment is independent of the existing exact-engine Q8 and batch-logit work.
