# Expanded whole-model ternary recovery

the project lead approved joint code-and-scale recovery with more training text on September
23, 2026. This round compares code learning with a matched scale-only control,
then tests discrete code proposals against actual whole-model training loss.
The source is the first-round `model-tuned96` image, not BF16 or a new model.
All complete images retain 128,678,649 payload bytes, 1.72708553 bits per unique
parameter. The selected result remains scale-only.

## Data and controls

`expand_train.py` freezes `expanded-tokens.npz` under
`/path/to/workspace/data/kelana-subbit/ternary/`. Its 512 training windows of 256 tokens
include the initial 32 windows and 480 new nonoverlapping windows. It leaves
the original 16 validation and 32 test windows byte-for-byte unchanged.
`expanded-tokens.json` records starts, source and fixture hashes. No held split
enters gradient computation or checkpoint selection.

The matched first pair starts from the same image and uses new train rows
32–159, 128 updates, 32,768 new tokens, scale learning rate .0005 and 16 train
check windows. The joint arm also permits all 196 body matrices to change trits
through the straight-through estimator, code learning rate .001 and at most
256 changed trits per matrix. The tied codes and every rotation sign stay fixed.
It saves the actual rounded codes, not latent weights or a residual.

`expanded-scale384` starts from the scale-only winner and runs another 256
updates at .0003 on train rows 160–415. Together with the first round, it has
seen 416 distinct windows, 106,496 distinct train tokens, and 512 optimization
steps. Each invocation resets Adam state; these are staged fits from exported
FP16 images, not seamless optimizer continuation. Selection uses training loss.

## Complete-model results

Validation is the same eight-window selection panel used in the first round.
Test is the frozen 32-window panel, 8,160 predictions. It remains excluded from
fitting but has been reported in earlier rounds, rather than being a new blind
benchmark. Lower NLL is better.

| Complete image | Validation NLL | Test NLL | Test perplexity |
| --- | ---: | ---: | ---: |
| BF16 reference | 3.6688 | 3.6392 | 38.06 |
| Scalar four-bit control, 4.1264 BPW | 4.6502 | 4.4513 | 85.74 |
| First-round ternary recovery | 5.6297 | 5.4286 | 227.83 |
| Expanded scale-only, 128 new steps | 4.9472 | 4.8423 | 126.76 |
| Matched joint code/scale, 128 new steps | 5.5530 | 5.3850 | 218.11 |
| Expanded scale-only, 384 new steps | 4.7331 | 4.6464 | 104.21 |
| Then train-accepted discrete codes | 4.7405 | 4.6453 | 104.10 |

More training text and scale optimization lower test loss by .7822 nats from
the first round. The result is still .1951 nats worse than the four-bit control
and 1.0072 nats worse than BF16. It does not match Bonsai-like quality retention.
The matched joint update changes exactly 50,176 trits and loses .5427 test nats
to scale-only training. It is not selected.

`compare_images.py` verifies image hashes, shape and rotation identity, counts
changed radix-243 trits and FP16 scale words, and records actual byte costs.
The matched scale arm changes zero trits and 4,484,014 scale words; the joint
arm changes 50,176 trits and 4,346,265 scale words. This rules out claiming a
joint-code benefit that was actually only a scale change.

## Discrete proposal experiment

`discrete_tune.py` freezes scales and tied codes. It averages complete-model
code gradients over fresh train rows 416–431 and ranks adjacent trit changes
globally across the 196 body matrices. A separate fixed train check panel,
rows 432–447, scores real forward passes at total budgets 1024, 256, 64 and 16.
Only a strictly improving proposal survives; rejected proposals are rolled back.
This check panel is training data used for selection, not held evidence.

The first round accepts 256 changed trits and lowers check-train NLL
4.838948 to 4.706454. Every second-round proposal loses, so the fitter stops.
The exported image has exactly 256 changed trits and zero changed scale words.
Its validation NLL worsens .00735 while test improves .00109. That does not
earn replacement of the scale-only image. It is useful evidence against both
large simultaneous STE updates and this small first-order proposal family as
an immediate route to a material generalization improvement.

## Reproduction and custody

All code, manifests, per-window losses, per-step histories and image-difference
receipts are retained in the owning directory. [results.json](results.json)
collects them without another inference run. Measurements use expanded BF16
weights for a common quality forward, not a packed ternary speed claim.
Resident Bonsai and the selected Qwen MoE runtime are unchanged.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
S=/path/to/workspace/projects/kelana/research/ternary
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
D=/path/to/workspace/data/kelana-subbit/ternary
$B --runtime-max 330s --memory-gib 24 --host-reserve-gib 4 --exec \
  "$P" "$S/tune.py" --source model-tuned96 --name expanded-scale128 \
  --fixture "$D/expanded-tokens.npz" --train-offset 32 --windows 128 \
  --steps 128 --tokens 256 --lr .0005 --evaluate-every 32 --score-windows 16
# Joint control uses identical settings plus all 28 layer IDs, code lr .001,
# code budget 256, a different name, 28 GiB admission and a 550s runtime bound.
$B --runtime-max 530s --memory-gib 24 --host-reserve-gib 4 --exec \
  "$P" "$S/tune.py" --source expanded-scale128 --name expanded-scale384 \
  --fixture "$D/expanded-tokens.npz" --train-offset 160 --windows 256 \
  --steps 256 --tokens 256 --lr .0003 --evaluate-every 64 --score-windows 16
$B --runtime-max 500s --memory-gib 28 --host-reserve-gib 4 --exec \
  "$P" "$S/discrete_tune.py" --source expanded-scale384 --name expanded-discrete \
  --fixture "$D/expanded-tokens.npz" --train-offset 416 \
  --gradient-windows 16 --check-windows 16 --rounds 8 --budgets 1024,256,64,16
```

The next useful code-learning experiment should compare teacher-guided
whole-model recovery or curvature-aware discrete moves against this stronger
scale-only control. Repeating a local matrix objective or counting changed codes
without a matched control does not address the measured failure.
