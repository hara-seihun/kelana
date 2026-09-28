# Calibrate paid binary output scales with enough teacher responses

The Qwen3-0.6B paid binary `mlp_up` image already stores one FP16 output scale per row. Fitting those slots against 256 complete original-weight responses improves fresh held output RMS on all four tested layers with **no extra stored bit or online operation**. The identical regression on 64 responses overfits and loses on every layer. Fitting to the frozen image's own two-factor response instead also loses held on every layer, even with 256 responses. The target and calibration sample count, not more detailed activation-rounding scale tuning, make the difference.

## Complete reader and fit

Hold the paid U/V signs, input scales and safe `.75` C8/A7 ladder at both integer boundaries fixed. For output row `j`, let `p_ij` be the complete integer-reader output with its original FP16 post-scale on calibration activation `i`, and `t_ij` the original dense-weight response. Fit

`g_j = max(0, sum_i p_ij t_ij / sum_i p_ij²)`

and replace the stored scale with `float16(g_j post_j)`. The measured denominators are positive. This minimizes train squared error before FP16 rounding. The real two-factor image response, rather than the original teacher, is a separate activation-rounding target using the same formula.

The packed U/V signs and input/output FP16 scales occupy 204,800 bytes for this 3,072-by-1,024 projection, or .520833 bits per dense weight before container overhead. The replacement keeps that rate and the same packed-sign loads, seven activation bitplanes, two integer stages, output writes and final scale multiplication. It neither reconstructs int4 weights nor adds an online correction. Its fitted FP16 bytes differ from the paid parent and would require an image update before inference.

Train rows `[512,576)` give the 64-response arm, `[320,576)` the 256-response arm, and 128 disjoint validation rows `[576,704)` give the held panel. All inputs come from the original Qwen producer. The metric is FP64 relative Frobenius RMS of the complete projection response. Held-only per-row gains are an unattainable oracle for this frozen panel, not a model selection method.

| Layer | Dense teacher held control | 64 train | 256 train | Held-only oracle |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .671464 | .672896 | **.666439** | .658157 |
| 7 | .642848 | .647536 | **.639800** | .622956 |
| 14 | .575732 | .579364 | **.567685** | .551990 |
| 27 | .386752 | .387114 | **.379372** | .355796 |

At unchanged bytes and operations the 256-response teacher fit lowers held RMS by .47–1.91% relative to the parent. It recovers some teacher response but does not repair the much larger one-bit approximation. At layer 14 its 64-response train RMS drops .576941→.546985 yet held rises .575732→.579364. Extending calibration to 256 changes that held direction while using exactly the same family and validation rows. A one-scalar global teacher gain also improves all four held panels slightly, but less than the 256-row fit.

The same-image response gives a useful contrast:

| Layer | Held same-image control | 64 train | 256 train | Held-only oracle |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .017568 | .017716 | .017601 | .017498 |
| 7 | .016352 | .016494 | .016386 | .016285 |
| 14 | .016095 | .016234 | .016127 | .016035 |
| 27 | .011046 | .011281 | .011105 | .010994 |

Even held-only row scales recover at most .47% relative RMS of this quantization error. The separately measured [second-stage centered A7 coordinate](../binary-affine-rank/README.md) improves it 5.3–7.0% on the same held rows, at a charged center/sign-sum consumer cost. Do not spend more calibration on the frozen image's row scales to address activation rounding; change the integer coordinate. For teacher error, carry the 256-response gain into a composed MLP and quantized-upstream gold-loss comparison, rather than install an isolated projection result. The [joint full-model MLP scale fit](../full-model/MLP-SCALE-FIT.md) used 2,048 responses and likewise improved its held *composed* output, but follows a different projection map and objective. No complete-model NLL or native timing was measured here, and Bonsai's engine and resident service did not change.

Run `OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-output-gain/measure.py LAYER` for the 64-row arm or add `--train-start 320` for 256 rows, with `LAYER` in `0 7 14 27`. The [eight receipts](/path/to/workspace/data/kelana-subbit/binary-output-gain/) bind source and parent-consumer hashes, fixture and paid-image hashes, response and FP16 replacement-scale hashes, row splits, train/held errors, held-only oracle and global-gain control. CPU only; no GPU reservation was used.
