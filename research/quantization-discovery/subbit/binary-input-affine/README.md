# Sparse first-stage affine corrections on paid binary factors

A first-stage A7 zero point is a poor route to improving the frozen Qwen3-0.6B `mlp_up` image. It does reveal a cheaper *exact* way to consume this particular changed integer map: apply sign corrections only where the shifted quantizer actually changes an activation code. Most nonzero centers do no work at all.

## Map and construction

Keep the paid `.55` binary U/V planes, their scales and the existing two-choice group-32 A7 ladder. For each first-stage activation group, choose an integer center `z` in `[-8,8]`, then form `q_i = clip(rint(x_i/s)-z,-64,63)`. Its intended reconstructed code is `q_i+z`. The first binary factor therefore computes

`h_r = sum_g w_g [sum_i V_{r,g,i} q_{g,i} + z_g sum_i V_{r,g,i}]`.

The second factor retains the common symmetric A7 ladder with threshold `.77`; it receives the integer `h` above. The final scale is unchanged. Both centers are computed dynamically from the activation, not stored in the model. The first group chooses the `.75` step when its maximum fits the existing `.77` threshold. We compare a zero center, a min/max midrange center and the integer center that minimizes the group's 32-element squared reconstruction error over seventeen choices. The last policy checks zero first and leaves it selected on ties.

There is a simpler exact program for this same integer response. Let `q0=clip(rint(x/s),-64,63)` and `delta=q+z-q0`. Then

`h_r = h0_r + sum_{g,i:delta != 0} w_g delta_{g,i} V_{r,g,i}`.

This is an integer identity for *all* codes, including clipping and ties. It does not reconstruct int4 weights or pay a sign-row-sum correction on every group. Away from half-integer rounding ties, translation by an integer commutes with rounding. Thus `delta` is zero unless one of the shifted or original codes clips. For ties-to-even, an odd `z` may also change an exactly half-integer cell; the sparse identity still holds. The script independently computes the dense zero-point expression and applies each sparse correction to the baseline factor output, asserting equality over all 192 sampled rows and all four matrices.

The first-stage image has 384 rows and 32 groups of 32 signs. Precomputing one signed-byte row sum per group costs 12,288 bytes on top of 49,152 packed V bytes and 147,456 packed U bytes, a 6.25% factor-payload increase. Alternatively, the dense correction needs one extra sign-word population count plus a center multiply/add for each of 12,288 row/group pairs per input. A sparse arm needs a group min as well as the existing max, a shifted-code comparison over 1,024 coordinates per input, then a sign extraction and weighted add for each affected rank row. These are logical work counts, not gfx1151 timing. A changed cell costs 384 signed corrections; at 128 held inputs, the full dense row-sum arm would process 1,572,864 row/group corrections.

## Fresh held response

`measure.py` uses 64 `train[576:640]` rows and 128 disjoint `validation[576:704]` original-producer rows per layer. The denominator is the same paid binary factor image's FP64 unrounded output, not original-weight teacher behavior or full-model NLL. The policies have no trained parameters; the train panel is a paired diagnostic, and the held panel was not used for policy choice. The frozen first and second selector thresholds are both `.77`.

| Layer | Symmetric held RMS | Midrange held RMS | Group-SSE held RMS | Midrange changed cells / 131,072 | Group-SSE changed cells |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | .01737008 | .01735924 | .01736830 | 54 | 53 |
| 7 | .01616775 | .01616308 | .01616393 | 62 | 61 |
| 14 | .01596283 | .01594875 | .01594796 | 61 | 63 |
| 27 | .01093124 | .01093382 | .01093049 | 62 | 55 |

Midrange assigns nonzero centers to 3,928–3,953 of the 4,096 held groups per layer. Only 52–61 groups per layer actually change a reconstructed code. The local-SSE choice uses nonzero centers in just 51–62 groups, with the same tiny distortion difference. At layer 14, 63 changed cells require 24,192 signed rank updates across 128 inputs, versus 1,572,864 dense row/group corrections. Its output RMS improves by .00001487, about .093% relative; layer 27 reverses under midrange and barely moves under group SSE. The groupwise input-reconstruction criterion is not even the final response criterion.

The [receipt](/path/to/workspace/data/kelana-subbit/binary-input-affine/receipt.json) binds script, image and fixture SHA-256, center and effective-code hashes, both exact first-stage integer replays, final integer hashes, per-layer train/held response and correction counts. Run `OPENBLAS_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/binary-input-affine/measure.py` from Kelana. This is CPU original-producer evidence. No GPU, model-loss measurement, native reader, executable or service changed.

The peer's [second-stage affine result](../binary-affine-rank/README.md) is far more useful: its held response falls 5–7% with charged signed-row corrections. Do not build a native first-stage affine reader for the frozen codes on this margin. A new first-factor producer could deliberately place many valuable cells at asymmetric boundaries, but then fit the changed binary signs and both quantizers against composed quantized-producer loss. This sparse correction identity gives that experiment a direct consumer without making every group pay for an endpoint event.
