# Paired code and scale repair on Qwen3-0.6B

The paired edit did not improve the selected image. Its 32-window test NLL is 4.646920, against 4.646432 for `expanded-scale384`. Validation also worsens, 4.733498 against 4.733112. The same one-trit edit without its scale change gets 4.646211 test NLL, but worsens validation to 4.733769. Neither result warrants replacing the source. The winning scale-only control on the separate train check panel also worsens both held panels.

This was a real packed-image experiment at the same 128,678,649 payload bytes and 1.72708553 BPW, not an estimated change to a continuous model. [results.json](results.json) contains the image hashes, panel receipts and full-precision NLL aggregates. Original fixtures, per-window results and all three packed images live in `/path/to/workspace/data/kelana-subbit/ternary/paired-repair/`. The images each contain 197 matrix NPZ files plus norms, 128,960,613 physical NPZ bytes, and a manifest. Container overhead is not counted in payload BPW. The paired image changes one radix-243 trit and one FP16 scale word; the controls change one trit or one scale word, respectively. Every image has identical payload bytes.

## Search and selection

The source is the already trained `expanded-scale384` Qwen3-0.6B image. The single target is layer 12's `mlp.down_proj`, which follows the quantized gate/up producer. The search captures its *actual quantized-model inputs* from train rows 448 and 449, 96 tokens each. It compares the down response on those inputs with the original BF16 down weight. Rotation signs and Hadamard coordinates come from the saved image. Among the eight output rows with largest BF16 response discrepancy, it screens 139,300 adjacent-trit/FP16-scale combinations by their actual cached down-response squared error, not a linear estimate of the composed model. Three groups come from the best local paired fits and three from strongest local interactions. This local screen only nominates edits.

The complete model scores all six nominees as paired, trit-only and scale-only choices against gold next-token loss on the same proposal train rows. It checks the two strongest proposal nominees per arm on separate train rows 450 through 453. That is 18 proposal-arm and six finalist-arm complete-model trials; all three finalist arms were frozen before evaluating validation or test. The check panel is *training selection data*, not held evidence. The code-only and scale-only arms each get the same six proposal choices and two check finalists as the paired arm. All scales are rounded to FP16 for scoring, and the held scorer confirms the scored trit and scale tensors equal the saved packed images.

One candidate really does cross a proposal-panel barrier. At candidate 0, the baseline proposal NLL is 4.75973535; paired 4.75807691, trit-only 4.76093078 and scale-only 4.75988483. Its exact gold-loss mixed finite difference is -0.00300336. Yet its paired check loss, 4.87356508, is worse than the unchanged check loss 4.87353432. The check-selected paired candidate is instead candidate 5, whose own proposal loss is worse than baseline. On check it improves baseline by only 0.000235, while its matched scale-only change improves baseline by 0.000852. Its check mixed finite difference is +0.000138, not a favorable coupled effect. Local response fitting and the proposal-panel barrier have not survived independent train selection.

| Frozen image | Proposal train NLL | Check train NLL | Validation NLL, 8 windows | Test NLL, 32 windows | Trit / FP16 scale words changed |
| --- | ---: | ---: | ---: | ---: | ---: |
| Source | 4.759735 | 4.873534 | 4.733112 | 4.646432 | 0 / 0 |
| Paired candidate 5 | 4.760163 | 4.873300 | 4.733498 | 4.646920 | 1 / 1 |
| Trit-only candidate 5 | 4.759715 | 4.874014 | 4.733769 | 4.646211 | 1 / 0 |
| Scale-only candidate 5 | 4.759521 | 4.872683 | 4.734266 | 4.646742 | 0 / 1 |

The 32 test windows contain 8,160 predictions and were never used in nomination or choice. They had been evaluated in earlier ternary rounds, so they are a fixed held panel rather than a new blind benchmark. The tiny test advantage of the trit-only arm conflicts with validation; the paired arm loses to both the source and trit-only arm on test. This is a negative result for this six-nominee, single-group neighborhood, not a proof against coupled changes elsewhere or broader recovery. The local screen is biased toward down-output fit; a future attempt needs a stronger train-panel gold-loss nomination and more than one group before paying for another full held pass.

## Reproduce

Use the existing BF16 checkpoint, `expanded-tokens.npz` and source packed image. CPU BLAS uses one thread; GPU calls use the Bonsai admission wrapper, which restores its resident service on exit. The commands write once and refuse to overwrite existing results. Their outputs and source/checkpoint/fixture digests are in the search and image receipts.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
S=/path/to/workspace/projects/kelana/research/ternary/paired-repair
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=2
$B --runtime-max 49s --memory-gib 24 --host-reserve-gib 4 --exec "$P" "$S/experiment.py" nominate
$B --runtime-max 49s --memory-gib 24 --host-reserve-gib 4 --exec "$P" "$S/experiment.py" search
$B --runtime-max 49s --memory-gib 24 --host-reserve-gib 4 --exec "$P" "$S/experiment.py" held --arm all --split validation --windows 8
for offset in 0 8 16 24; do
  $B --runtime-max 49s --memory-gib 24 --host-reserve-gib 4 --exec "$P" "$S/experiment.py" held --arm pair --split test --offset "$offset" --windows 8
  $B --runtime-max 49s --memory-gib 24 --host-reserve-gib 4 --exec "$P" "$S/experiment.py" held --arm code --split test --offset "$offset" --windows 8
  $B --runtime-max 49s --memory-gib 24 --host-reserve-gib 4 --exec "$P" "$S/experiment.py" held --arm scale --split test --offset "$offset" --windows 8
done
$B --runtime-max 49s --memory-gib 24 --host-reserve-gib 4 --exec "$P" "$S/experiment.py" held --arm baseline --split validation --windows 8
$B --runtime-max 49s --memory-gib 24 --host-reserve-gib 4 --exec "$P" "$S/experiment.py" held --arm baseline --split test --windows 32
"$P" "$S/summarize.py"
```

`--arm all` can score the three images and baseline in a single chunk on a fresh run. This run scored the three images together and scored baseline separately, which is why rerunning the literal all-arm command against these retained files refuses to overwrite them. `summarize.py` reads only receipts and packed image hashes; it does not run inference. `experiment.py` loads the BF16 original to screen the down response, then runs the fully quantized model for selection and held loss. Neither script changes the installed Qwen or Bonsai service.
