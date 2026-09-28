# Sharing learned value palettes does not pay

The learned signed-byte table behind the 112-byte narrow V cache has 16 levels for each of 224 coordinates. I tried to save its 3,584 table bytes by sharing the *shape* of a table across 2, 4 or 28 consecutive coordinates, leaving each coordinate its own FP16 amplitude. This is a paid-image experiment, not a proposed engine change. Every tested shared arm loses to the cheaper uniform signed-nibble control after its two-bit O codes are refitted.

For each group of `m` coordinates, take the previously trained real level matrix `T` of shape `m x 16`. Its leading singular vector gives the global minimum of `||T-abᵀ||²` over real rank-one tables. Orient `b` so its last entry exceeds its first, scale its maximum absolute entry to 127, and round it to one signed-byte table. Refit each coordinate's positive amplitude by least squares against the rounded table, then round that amplitude to FP16. Nearest-level assignments use the realized centers. This optimizes the *old tables*, not causal post-O loss; it is a cheap representational test of sharing rather than a conditional optimum for a new quantizer.

On Qwen3-0.6B, the original-producer layer-0/14 capture supplies eight train windows and four repeatedly inspected validation windows, each 256 tokens. The rank-28 right basis stays frozen. Both the individual and shared arms get the same train-only ridge selection and two response-code sweeps for the already-paid two-bit O image. The individual-table replay matches its published held score.

| Consecutive coordinates/table | Table plus step bytes/layer | Layer 0 held post-O error | Layer 14 held post-O error |
| ---: | ---: | ---: | ---: |
| Individual 16-byte tables | 4,032 | .384126 | .330807 |
| 2 | 2,240 | .385333 | .335839 |
| 4 | 1,344 | .386723 | .343261 |
| 28, one per GQA group | 576 | .386369 | .364938 |
| Uniform signed nibble, separately refitted O | 476 | .385148 | .334500 |
| Group-scaled E4M3, separately refitted O | group metadata; 224-byte logical cache | .377798 | .325434 |

Errors are relative squared full two-head causal post-O response to original V/O, using floating attention probabilities. The layer-14 pair-shared arm loses .005032 to the individual tables while saving 1,792 static bytes, and loses .001339 to the *smaller* uniform-nibble image. All shared arms are dominated by that uniform cache in this panel: they cost more static bytes and have higher held error. Layer 0 is similar, although its pair-shared arm is within .000185 of uniform. Even deleting every table byte except the coordinate steps could save only 3,584 bytes/layer, or .00911 V/O BPW over 3,145,728 V/O weights; it cannot change the 112-byte cache or the 224 table selections per produced value token. The group-wide real rank-one approximation retains only 91.2%/87.1% of mean table squared energy at layers 0/14; the pair-shared approximations retain 97.1%/96.8%, yet still lose after paid O refitting. Table Frobenius fit does not capture the causal objective.

The packed label is still an *index* into a signed-byte table. This arm needs 224 table selections per key and the two signed-byte probability dots, plus producer nearest-label selection. It does not inherit the direct signed-nibble dot8 lowering, which requires the nibble itself to be a signed value. No native time, quantized-upstream model loss or fresh quality claim follows from this CPU replay.

This closes static palette sharing as a useful metadata-only optimization for the frozen right basis and previously learned tables. The next question is whether a newly trained right basis and paid O codes can make a common palette work on quantized-producer complete-model text; that changes the coordinate, rather than compressing tables after training. Spend experimental effort there only if the shared shape also simplifies the native producer or table selection. Otherwise, the half-byte-versus-E4M3 cache and complete-model quality gap matter more than the 3.5 KB of static table data.

`measure.py --layer 0|14 --group-size 2|4|28` regenerates the train/held, per-window and frozen-parent-O receipts under `/path/to/workspace/data/kelana-subbit/value-shared-palette/` with `/path/to/workspace/data/fish-s2-pro/venv/bin/python`. Each JSON records source, model, capture, factor, original table, original paid O and newly refitted image hashes; the `.npz` files contain the realized palettes and paid O images. No GPU or Bonsai executable/service changed.
