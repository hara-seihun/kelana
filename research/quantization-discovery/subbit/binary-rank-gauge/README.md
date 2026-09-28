# A zero-rate rank gauge for binary-factor group quantization

A binary factorization has a rank-coordinate freedom that the grouped activation quantizer does not. Reorder the first factor's output rows and the second factor's input columns together. The real linear map is unchanged; a 32-coordinate quantizer now groups different intermediate responses. Sorting coordinates by training-response energy reduces the held two-stage A7 ladder error on all four tested Qwen3-0.6B paid `mlp_up` projections without an additional inference instruction or stored bit. The gain is small, but it also composes with the independently fitted two-boundary ladder selectors on fresh inputs.

## Map and cost

Write the frozen paid projection as `diag(post) U V diag(pre)`, with binary `V` of shape 384 by 1024 and binary `U` of shape 3072 by 384. For any 384-coordinate permutation `P`, let `V' = P V` and `U' = U P⁻¹`. Then `U' V' = U V` over the reals. In the two-stage grouped reader, first quantize the input, reduce it against `V'` to an integer rank response `h`, then quantize `h` in 32-coordinate groups and reduce it against `U'`. The first factor's output **address** is permuted, so `h` is produced in the new order; no activation gather is needed. Only the grouping of `Q₂` changes. The common first-stage scale cancels when the second stage chooses its codes, just as in [the integer ladder](../binary-shifted-scales/README.md). The proof is for the unrounded real map; it does not assert bit-identical FP32 accumulation or identical quantized responses.

The rank permutation is selected offline. Repacking binary `V` rows and binary `U` columns retains their exact shape, one-bit payload, pre/post scales, 32-coordinate group count, seven bitplane dots per sign word, integer group multipliers, rank intermediate and final floating scales. There is no permutation metadata or online shuffle in the image. Actual GPU bandwidth/latency and the changed sign-word ordering have not been measured. A native producer must emit rank outputs in this order rather than produce the old order and gather afterward; the included packed-image round trips demonstrate this layout. Changing rank order may also change FP32 reduction scheduling, so an eventual numerical-map comparison needs to declare that choice.

The permutation is one stable descending sort of the first-stage *integer* rank-response mean square on 64 training activations. It never reads held activations, teacher outputs or the original dense weights. For comparison, a train-energy round-robin spread puts strong coordinates in different groups. Both are cost-free layouts, not post-hoc rowwise selectors.

## Paid-image response panel

The input fixtures are Qwen3-0.6B original-producer `mlp_up` activations. Train fixture positions 512–575 choose the rank order; validation positions 512–575 are held. These are separate WikiText splits and avoid the first four validation rows inspected by the parent A7 study. Every arm uses the same frozen `.55` paid one-bit factors and measures complete final-response relative RMS against that image's FP64 unquantized two-factor response, not original-weight or language loss. Both boundaries quantize A7 with 32-coordinate groups, cap eight and the safe `.75` two-choice selector unless named otherwise.

| Layer | Safe order train / held RMS | Sorted order train / held RMS | Held per-input wins / 64 |
| ---: | ---: | ---: | ---: |
| 0 | .017419 / .017512 | .017123 / .017419 | 37 |
| 7 | .016221 / .016683 | .015781 / .016547 | 39 |
| 14 | .015742 / .016261 | .015169 / .016117 | 41 |
| 27 | .012912 / .011547 | .012476 / .011249 | 49 |

The spread control's held RMS is .017579/.016684/.016246/.011598, respectively. It does not win as a generic change of rank order. The sorted order improves aggregate squared-response RMS by 0.53%, 0.81%, 0.89% and 2.58% relative to the safe control. Some individual held inputs worsen, by at most .00105/.00136/.00165/.00130 absolute relative RMS at these layers. Do not select a whole-model map on this isolated response alone.

[The separate two-boundary threshold fit](../binary-second-selector/README.md) was selected on earlier training rows. Freezing its published `.77/.77` layer-0 and `.78/.77` layer-14 thresholds, then replaying *both* rank orders on this panel, yields held RMS .017346→.017196 and .016126→.015917. The rank order is still chosen using safe first-stage training responses, not refitted to the pair or validation data. These are matched conditional gains on new inputs, not sums of the two reports' different-window percentages.

`OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-rank-gauge/measure.py` regenerates `/path/to/workspace/data/kelana-subbit/binary-rank-gauge/receipt.json`. The receipt includes source, paid-image and fixture SHA-256, packed U/V and permutation hashes, first-stage and final integer response hashes, per-input held errors, train/held complete-output RMS and the maximum FP64 reassociation difference for the real rank gauge, at most `1.45e-15` in this panel. Packing and unpacking both permuted sign planes reproduce every bit on each image. The A7 integer accumulator remains within the parent's signed-int32 full-domain bound `K·64·512`, at most 100,663,296 at the largest factor boundary.

This is a CPU conditional response result at unchanged paid image size and logical online work, not model NLL or native speed. The more valuable next experiment is to fit rank grouping together with the factor signs and both group selectors against quantized-producer MLP endpoint or gold-token loss. Compare a sorted rank layout to the original on fresh composed text first. Only if it survives should a complete native binary reader be timed against matched int4 expansion; never pay an online gather merely to reproduce this offline permutation.
