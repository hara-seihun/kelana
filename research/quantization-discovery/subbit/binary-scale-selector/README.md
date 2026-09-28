# Selecting the A7 integer ladder for the complete binary-factor response

The safe `3/4` group step in the existing integer-ladder reader is chosen only when its largest activation does not clip. A lower step can still help if one or more coordinates clip, since the final observation is the *two-factor output*, not individual reconstructed activations. One scalar threshold per projection, fitted against the complete quantized output, improves the frozen layer-0 `mlp_up` paid-image response on held inputs without adding a dot, scale, or floating group reduction. The same approach barely moves layer 14. Fitting a threshold per group to the *linear* two-factor response instead overfits layer 14 and worsens its final quantized output.

## Map and fit

The [parent integer ladder](../binary-shifted-scales/README.md) sets a group upper step `s=M/(63·2^e)` at exponent `e=min(8,floor(log2(M/m_g)))`. The smaller choice is `3s/4`. At the first factor, choose it when `m_g/(63s) <= t` and `e<8`, and round/clip to signed A7 codes as before. The parent has `t=.75`. For `t>.75`, some maximum coordinates clip; this is an intentional approximate map. Both choices still have common output scale `B=M/(63·512)` and integer multipliers `2^(9-e)` or `3·2^(7-e)`. The second factor retains the parent's safe `.75` selector and integer reduction. Only the final output uses a floating scale. Stored U/V signs, weight rate and bitplane products are unchanged. The online difference is one static threshold constant for each first-stage group comparison, not another input-dependent projection.

One fit scans thirteen thresholds `.70,.71,...,.82` on the first 32 training fixture rows, computes the *entire* two-factor response, and chooses the lowest relative RMS against the frozen paid image's FP64 real response. One static scalar applies to all first-stage groups in that projection. A separate coordinate-descent control fits 32 group thresholds against the floating two-factor linear output *before* the second-stage quantizer; it precomputes each group's exact effect on that output and greedily optimizes its 32 training rows. This is an offline surrogate, not the selected fit. Validation rows 32–63, separate from the training split and from the parent study's first four inspected validation rows, are held out. No original-model teacher quality, causal loss or native speed is measured.

| Paid `mlp_up` layer | Selector | Train linear RMS | Train final RMS | Held linear RMS | Held final RMS | Held smaller choices / 1,024 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 0 | safe `.75` | .012935 | .017882 | .012627 | .017775 | 564 |
| 0 | linear group fit | .012774 | .017834 | .012724 | .017741 | 565 |
| 0 | final-response global `.77` | .012864 | .017846 | .012466 | **.017573** | 602 |
| 14 | safe `.75` | .012114 | .016201 | .011839 | .016480 | 587 |
| 14 | linear group fit | .011986 | .016140 | .012138 | .016745 | 587 |
| 14 | final-response global `.76` | .012089 | .016173 | .011786 | .016473 | 607 |

Layer 0's selected threshold lowers held final response RMS by 1.14% relative to safe `.75`; layer 14 changes by 0.04%. The linear per-group fit improves training error yet raises held layer-14 final error by 1.61%. Always taking the smaller step is much worse: held final RMS .073315/.085448, because clipping overwhelms the extra resolution. This is not evidence for a universal threshold or a quality-matched int4 win. It says that clipping can be useful inside a cheap integer consumer, but its selection must be fitted through the downstream quantizer.

The mathematical integer bound of the parent remains valid for both step choices: with A7 and cap 8, each sign group's magnitude is at most `32·64·512`, so the largest first-factor sum here is below `1024·64·512`, and the second is below `384·64·512`. A change of the threshold cannot overflow a signed int32 accumulator. Floating responses can reassociate, so this CPU FP64 study is not an FP32 bit-identity claim.

Run `OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-scale-selector/measure.py` from the Kelana root. `/path/to/workspace/data/kelana-subbit/binary-scale-selector/receipt.json` records script, paid-image and fixture SHA-256, all grid train errors, selected thresholds, two splits' linear/final responses and clipping counts. The next useful experiment fits both factor selectors against complete quantized-producer model behavior over larger text and measures the complete native bitplane reader. An isolated response RMS improvement this small does not justify changing the engine.
