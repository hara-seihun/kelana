# Fresh-text whole-model ternary scale recovery

Eight gold-loss updates to the **complete** Qwen3-0.6B ternary model on previously unused WikiText train windows improve a newly frozen, disjoint sixteen-window test panel from **4.576138 to 4.561169 NLL** (4,080 predictions). The paired improvement is **0.014969 ± 0.005263 nats** (window standard error), favorable on 13/16 windows. This advances the selected 1.5× scale extrapolation without adding image bytes or changing the model's trits. It is a complete-model **quality/rate** result, not a native throughput or Bonsai-quality claim: the original BF16 loss on the previous test panel is 3.6392.

The source is `scale-extrapolate-1.5`, not the older `expanded-scale384`. Eight Adam steps at learning rate .00015 use train rows 448–455 of `expanded-tokens.npz` (256 tokens each); rows 448–451 are also the train-only checkpoint score. The exported `fresh-scale8` is the train-selected step 8. Row indices 448–511 were not used in the previous 384-step recovery or discrete train/check selection (which stopped at row 447). The 197 saved matrices retain their codes, rotation signs, shapes and BF16 norms bit-for-bit. Exactly **2,972,301 FP16 scale words change**, and the actual raw image is still **128,678,649 bytes / 1.72708553 BPW**. This image has *not* been passed through the separate exact paged-scale format, so no new 1.69-BPW page size is claimed.

`fixture.py` froze sixteen new 256-token test windows (seed 2026092429) before either arm was scored. It excludes the prior pilot/fresh-evaluation/test windows and the September 24 extrapolation selection panel. The two arms use identical model, token fixture, requested heads and BF16-expansion evaluator, in paired halves. [The receipt](/path/to/workspace/data/kelana-subbit/ternary/fresh-recovery/summary.json) ties both source manifests, full-image training receipt, all four per-window evaluations, fixture and scripts to hashes; complete source and candidate packed images live beside the data directory. `summarize.py` reads both complete images to check all unchanged fields and rates, then computes the matched comparison. The prior extrapolation test panel was also probed: its second half improves **4.478249 → 4.471480** by .006769, and its first half improves 4.667228 → 4.657705 by .009523. Those exploratory outputs are preserved in `exploratory-prior-panel.json`; the predecessor had already used these windows to select its coefficient, so they are not the independent result.

Run from Kelana root, under Bonsai's shared GPU reservation (each bounded command restores the resident service):

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
S=research/ternary/fresh-recovery
D=/path/to/workspace/data/kelana-subbit/ternary
# Construction uses tune.py as documented in the training.json receipt (destination is immutable).
$P "$S/fixture.py"   # only when tokens.npz does not exist
for name in scale-extrapolate-1.5 fresh-scale8; do
  for offset in 0 8; do
    "$B" --runtime-max 48s --memory-gib 16 --host-reserve-gib 4 --exec \
      "$P" "$S/evaluate.py" --name "$name" --offset "$offset" --windows 8
  done
done
$P "$S/summarize.py"
```

A longer recovery on additional independent *train* windows, with a new validation selection and new held panel, is the next quality question. One short eight-step update establishes that fresh training still moves the composed model; it does not close the gap to BF16 or justify implementing a native ternary reader yet. GPU service and selected Qwen runtime are unchanged.
