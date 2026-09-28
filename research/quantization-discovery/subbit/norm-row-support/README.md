# A tiny denominator coefficient can still own important K rows

The fitted 16-extra-row sparse K norm has several four-row strata with FP16 coefficients below .1. Can we omit those strata from the packed binary K output factor, then recover the causal observer with the remaining already-paid coefficients? Yes at layer 0, less so at layer 14. The score planes, selected group affine, Q/K image, two observing heads and 224-coordinate key cache remain frozen. This changes the K norm producer rather than expanding the code into int4.

For each group, delete any sampled four-row stratum whose fitted coefficient is at most .1, then refit the other FP16 denominator coefficients on the original train windows' finite causal score. Keep a deletion only if its refitted, unpenalized *smooth train* cross-entropy does not exceed the frozen parent. Selection never reads held windows. BF16-normalized full causal attention on four existing validation windows supplies the observation:

| Layer | Full sparse norm KL | Delete without refit | Delete and refit all | Train-selected KL | Raw K rows/layer after selection |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | .262074 | .262302 | .262000 | .262000 | 324 instead of 352 |
| 14 | .349021 | .350914 | .349821 | .349073 | 348 instead of 352 |

At layer 0, the train rule keeps all seven deletions across groups 0, 1, 2, 3 and 6. All four held-window means improve or stay within .00006 of the parent except the first, which rises .000060. At layer 14, it keeps only group 2's four-row deletion. Group 4 is the trap: its coefficient is just .06946, yet deleting those four rows raises that group's held KL .227926 to .243017. Refitting recovers .233905 but not the parent. Its smooth train CE likewise rises 2.141884 to 2.146183 after refit, so the train rule rejects it. Small coefficients alone do not price the causal consequences of deleting rows.

The selected layer-0 K program computes 324 output rows instead of 352 on the same rank-256 binary factor. Including the unchanged 262,144 input-factor signed terms, its counted producer drops from 352,256 to 345,088 signed terms/token, a further 2.04% reduction. Layer 14 drops to 351,232, or 0.29%. Against the full 1,024-output-row K producer, these represent 34.18% and 33.01% fewer counted terms. If a packed pruned image is made, the layer-0 output signs shrink by 896 bytes, sampled-row indices by 28 bytes and per-group norm coefficients by 14 bytes; the layer-14 increments are 128, 4 and 2 bytes. Selected score cache and 448 products/key over both Q heads do not change. The norm still squares and reduces the selected raw rows. These are counts of a proposed packed producer, not measured native latency or a new full-model image.

The source image has 16 extra sampled rows per group, with four energy-stratified bins. Zeroing a bin removes all four row outputs because its feature is absent from every denominator. The positive selected-row term remains, so the pruned norm is still positive for nonzero selected key energy. Coefficients are quantized to FP16 before held replay. The train fit is smooth FP32 and the held observation rounds raw K and normalized key values to BF16. It is not a globally optimal row-selection search, nor evidence that .1 is a transferable cutoff. The four held windows were already inspected in sibling Q/K studies. The new question is whether training row support *inside* the binary K factor on quantized-upstream text beats a packed equal-rate control in post-O and gold loss. The upcoming 128-plane score masks change the selected energy, so this support must be refit rather than transplanted to that image.

`measure.py` replays one group. `summarize.py` applies the train-only CE rule and hashes all sixteen raw group receipts. The source/model/capture/paid-image/parent hashes, exact row lists inherited from each parent, coefficients and four held KL values live in `/path/to/workspace/data/kelana-subbit/norm-row-support/layer{00,14}-group{0..7}.json` and the two summaries there. From the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/norm-row-support
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=2 "$P" "$D/measure.py" --layer 14 --group 4 --refit --output /path/to/workspace/data/kelana-subbit/norm-row-support/layer14-group4.json
python3 "$D/summarize.py"
```

This is CPU original-producer evidence. Bonsai's runtime and resident service did not change.
